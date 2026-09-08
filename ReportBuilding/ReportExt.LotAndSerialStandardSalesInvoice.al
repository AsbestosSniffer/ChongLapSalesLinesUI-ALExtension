namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.History;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

reportextension 50107 "Sales Invoice w/ Lot & Serial" extends "Standard Sales - Invoice"
{
    dataset
    {
        addlast(Line)
        {
            dataitem(TrackingSplitLine; "Sales Invoice Line")
            {
                UseTemporary = true;
                DataItemTableView = sorting("Document No.", "Line No.");

                column(TrkSplitItemNo; "No.")
                {
                }
                column(TrkSplitDescription; Description)
                {
                }
                column(TrkSplitQuantity; SplitQuantityText)
                {
                }
                column(TrkSplitUnitOfMeasure; "Unit of Measure")
                {
                }
                column(TrkSplitUnitPrice; SplitUnitPriceText)
                {
                }
                column(TrkSplitLineDiscountPercentText; SplitLineDiscountText)
                {
                }
                column(TrkSplitLineAmount; SplitLineAmountText)
                {
                }
                column(TrkLotNo; LotNo)
                {
                }
                column(TrkLotExpDate; LotExpDate)
                {
                }
                column(TrkSerialNo; SerialNo)
                {
                }
                column(TrkNetPrice; NetPrice)
                {
                }

                trigger OnPreDataItem()
                begin
                    BuildTrackingSplitBuffer(Line);
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
                    if not SerialNoPerSplitLine.Get("Line No.", SerialNo) then
                        SerialNo := '';
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
        SerialNo: Code[50];
        NetPrice: Decimal;
        LotNoPerSplitLine: Dictionary of [Integer, Code[50]];
        LotExpDatePerSplitLine: Dictionary of [Integer, Date];
        SerialNoPerSplitLine: Dictionary of [Integer, Code[50]];

    local procedure BuildTrackingSplitBuffer(SalesInvLine: Record "Sales Invoice Line")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingDocMgt: Codeunit "Item Tracking Doc. Management";
        TempItemLedgEntry: Record "Item Ledger Entry" temporary;
        InvoiceRowID: Text[250];
        TrackingKeys: List of [Text];
        TrackingLotNos: List of [Code[50]];
        TrackingSerialNos: List of [Code[50]];
        TrackingQtys: List of [Decimal];
        TrackingExpDates: List of [Date];
        TrackingKey: Text;
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
        Clear(SerialNoPerSplitLine);
        TrackingSplitLine.Reset();
        TrackingSplitLine.DeleteAll();

        if SalesInvLine.Type <> SalesInvLine.Type::Item then begin
            TrackingSplitLine := SalesInvLine;
            TrackingSplitLine.Insert();
            exit;
        end;

        InvoiceRowID := ItemTrackingMgt.ComposeRowID(Database::"Sales Invoice Line", 0, SalesInvLine."Document No.", '', 0, SalesInvLine."Line No.");
        ItemTrackingDocMgt.RetrieveEntriesFromPostedInvoice(TempItemLedgEntry, InvoiceRowID);

        if TempItemLedgEntry.FindSet() then
            repeat
                if (TempItemLedgEntry."Lot No." <> '') or (TempItemLedgEntry."Serial No." <> '') then begin
                    TrackingKey := TempItemLedgEntry."Lot No." + '|' + TempItemLedgEntry."Serial No.";
                    FoundIdx := TrackingKeys.IndexOf(TrackingKey);
                    if FoundIdx > 0 then
                        TrackingQtys.Set(FoundIdx, TrackingQtys.Get(FoundIdx) + Abs(TempItemLedgEntry.Quantity))
                    else begin
                        TrackingKeys.Add(TrackingKey);
                        TrackingLotNos.Add(TempItemLedgEntry."Lot No.");
                        TrackingSerialNos.Add(TempItemLedgEntry."Serial No.");
                        TrackingQtys.Add(Abs(TempItemLedgEntry.Quantity));
                        TrackingExpDates.Add(TempItemLedgEntry."Expiration Date");
                    end;
                end;
            until TempItemLedgEntry.Next() = 0;

        if TrackingKeys.Count() = 0 then begin
            TrackingSplitLine := SalesInvLine;
            TrackingSplitLine.Insert();
            exit;
        end;

        QtyPerUOM := SalesInvLine."Qty. per Unit of Measure";
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;

        TrackedQty := 0;
        for i := 1 to TrackingQtys.Count() do
            TrackedQty += TrackingQtys.Get(i);

        TotalQtyBase := SalesInvLine.Quantity * QtyPerUOM;
        if TotalQtyBase - TrackedQty > 0.00001 then begin
            TrackingKeys.Add('|');
            TrackingLotNos.Add('');
            TrackingSerialNos.Add('');
            TrackingQtys.Add(TotalQtyBase - TrackedQty);
            TrackingExpDates.Add(0D);
        end;

        SplitCount := TrackingKeys.Count();
        AssignedQty := 0;
        AssignedLineAmount := 0;
        AssignedAmount := 0;
        AssignedAmountInclVAT := 0;

        for i := 1 to SplitCount do begin
            TrackingSplitLine := SalesInvLine;
            TrackingSplitLine."Line No." := i;

            if i = SplitCount then begin
                TrackingSplitLine.Quantity := SalesInvLine.Quantity - AssignedQty;
                TrackingSplitLine."Line Amount" := SalesInvLine."Line Amount" - AssignedLineAmount;
                TrackingSplitLine.Amount := SalesInvLine.Amount - AssignedAmount;
                TrackingSplitLine."Amount Including VAT" := SalesInvLine."Amount Including VAT" - AssignedAmountInclVAT;
            end else begin
                Frac := TrackingQtys.Get(i) / TotalQtyBase;
                SplitQty := Round(SalesInvLine.Quantity * Frac, 0.00001);
                TrackingSplitLine.Quantity := SplitQty;
                TrackingSplitLine."Line Amount" := Round(SalesInvLine."Line Amount" * Frac, 0.01);
                TrackingSplitLine.Amount := Round(SalesInvLine.Amount * Frac, 0.01);
                TrackingSplitLine."Amount Including VAT" := Round(SalesInvLine."Amount Including VAT" * Frac, 0.01);
                AssignedQty += TrackingSplitLine.Quantity;
                AssignedLineAmount += TrackingSplitLine."Line Amount";
                AssignedAmount += TrackingSplitLine.Amount;
                AssignedAmountInclVAT += TrackingSplitLine."Amount Including VAT";
            end;

            TrackingSplitLine.Insert();
            LotNoPerSplitLine.Add(i, TrackingLotNos.Get(i));
            LotExpDatePerSplitLine.Add(i, TrackingExpDates.Get(i));
            SerialNoPerSplitLine.Add(i, TrackingSerialNos.Get(i));
        end;
    end;
}
