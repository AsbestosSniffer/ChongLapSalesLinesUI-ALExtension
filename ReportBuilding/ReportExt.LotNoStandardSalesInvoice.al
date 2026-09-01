namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.History;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

reportextension 50103 "Lot No. Standard Sales Invoice" extends "Standard Sales - Invoice"
{
    dataset
    {
        addlast(Line)
        {
            dataitem(LotSplitLine; "Sales Invoice Line")
            {
                UseTemporary = true;
                DataItemTableView = sorting("Document No.", "Line No.");

                column(SplitItemNo; "No.")
                {
                }
                column(SplitDescription; Description)
                {
                }
                column(SplitQuantity; SplitQuantityText)
                {
                }
                column(SplitUnitOfMeasure; "Unit of Measure")
                {
                }
                column(SplitUnitPrice; SplitUnitPriceText)
                {
                }
                column(SplitLineDiscountPercentText; SplitLineDiscountText)
                {
                }
                column(SplitLineAmount; SplitLineAmountText)
                {
                }
                column(LotNo; LotNo)
                {
                }
                column(LotExpDate; LotExpDate)
                {
                }
                column(NetPrice; NetPrice)
                {
                }

                trigger OnPreDataItem()
                begin
                    BuildLotSplitBuffer(Line);
                end;

                trigger OnAfterGetRecord()
                begin
                    SplitQuantityText := Format(Quantity);
                    SplitUnitPriceText := Format("Unit Price");
                    SplitLineDiscountText := Format("Line Discount %") + '%';
                    SplitLineAmountText := Format("Line Amount");
                    NetPrice := Round("Unit Price" * (1 - "Line Discount %" / 100), 0.01);
                    if not LotNoPerSplitLine.Get("Line No.", LotNo) then
                        LotNo := '';
                    if not LotExpDatePerSplitLine.Get("Line No.", LotExpDate) then
                        Clear(LotExpDate);
                end;
            }
        }
    }

    var
        SplitQuantityText: Text[80];
        SplitUnitPriceText: Text[80];
        SplitLineDiscountText: Text[80];
        SplitLineAmountText: Text[80];
        LotNo: Code[50];
        LotExpDate: Date;
        NetPrice: Decimal;
        LotNoPerSplitLine: Dictionary of [Integer, Code[50]];
        LotExpDatePerSplitLine: Dictionary of [Integer, Date];

    local procedure BuildLotSplitBuffer(SalesInvLine: Record "Sales Invoice Line")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingDocMgt: Codeunit "Item Tracking Doc. Management";
        TempItemLedgEntry: Record "Item Ledger Entry" temporary;
        InvoiceRowID: Text[250];
        LotNos: List of [Code[50]];
        LotQtys: List of [Decimal];
        LotExpDates: List of [Date];
        FoundIdx: Integer;
        QtyPerUOM: Decimal;
        TrackedQty: Decimal;
        TotalQtyBase: Decimal;
        Frac: Decimal;
        SplitQty: Decimal;
        AssignedQty: Decimal;
        AssignedLineAmount: Decimal;
        AssignedAmount: Decimal;
        AssignedAmountInclVAT: Decimal;
        SplitCount: Integer;
        i: Integer;
    begin
        Clear(LotNoPerSplitLine);
        Clear(LotExpDatePerSplitLine);
        LotSplitLine.Reset();
        LotSplitLine.DeleteAll();

        if SalesInvLine.Type <> SalesInvLine.Type::Item then begin
            LotSplitLine := SalesInvLine;
            LotSplitLine.Insert();
            exit;
        end;

        InvoiceRowID := ItemTrackingMgt.ComposeRowID(Database::"Sales Invoice Line", 0, SalesInvLine."Document No.", '', 0, SalesInvLine."Line No.");
        ItemTrackingDocMgt.RetrieveEntriesFromPostedInvoice(TempItemLedgEntry, InvoiceRowID);

        if TempItemLedgEntry.FindSet() then
            repeat
                if TempItemLedgEntry."Lot No." <> '' then begin
                    FoundIdx := LotNos.IndexOf(TempItemLedgEntry."Lot No.");
                    if FoundIdx > 0 then
                        LotQtys.Set(FoundIdx, LotQtys.Get(FoundIdx) + Abs(TempItemLedgEntry.Quantity))
                    else begin
                        LotNos.Add(TempItemLedgEntry."Lot No.");
                        LotQtys.Add(Abs(TempItemLedgEntry.Quantity));
                        LotExpDates.Add(TempItemLedgEntry."Expiration Date");
                    end;
                end;
            until TempItemLedgEntry.Next() = 0;

        if LotNos.Count() = 0 then begin
            LotSplitLine := SalesInvLine;
            LotSplitLine.Insert();
            exit;
        end;

        QtyPerUOM := SalesInvLine."Qty. per Unit of Measure";
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;

        TrackedQty := 0;
        for i := 1 to LotQtys.Count() do
            TrackedQty += LotQtys.Get(i);

        TotalQtyBase := SalesInvLine.Quantity * QtyPerUOM;
        if TotalQtyBase - TrackedQty > 0.00001 then begin
            LotNos.Add('');
            LotQtys.Add(TotalQtyBase - TrackedQty);
            LotExpDates.Add(0D);
        end;

        SplitCount := LotNos.Count();
        AssignedQty := 0;
        AssignedLineAmount := 0;
        AssignedAmount := 0;
        AssignedAmountInclVAT := 0;

        for i := 1 to SplitCount do begin
            LotSplitLine := SalesInvLine;
            LotSplitLine."Line No." := i;

            if i = SplitCount then begin
                LotSplitLine.Quantity := SalesInvLine.Quantity - AssignedQty;
                LotSplitLine."Line Amount" := SalesInvLine."Line Amount" - AssignedLineAmount;
                LotSplitLine.Amount := SalesInvLine.Amount - AssignedAmount;
                LotSplitLine."Amount Including VAT" := SalesInvLine."Amount Including VAT" - AssignedAmountInclVAT;
            end else begin
                Frac := LotQtys.Get(i) / TotalQtyBase;
                SplitQty := Round(SalesInvLine.Quantity * Frac, 0.00001);
                LotSplitLine.Quantity := SplitQty;
                LotSplitLine."Line Amount" := Round(SalesInvLine."Line Amount" * Frac, 0.01);
                LotSplitLine.Amount := Round(SalesInvLine.Amount * Frac, 0.01);
                LotSplitLine."Amount Including VAT" := Round(SalesInvLine."Amount Including VAT" * Frac, 0.01);
                AssignedQty += LotSplitLine.Quantity;
                AssignedLineAmount += LotSplitLine."Line Amount";
                AssignedAmount += LotSplitLine.Amount;
                AssignedAmountInclVAT += LotSplitLine."Amount Including VAT";
            end;

            LotSplitLine.Insert();
            LotNoPerSplitLine.Add(i, LotNos.Get(i));
            LotExpDatePerSplitLine.Add(i, LotExpDates.Get(i));
        end;
    end;
}
