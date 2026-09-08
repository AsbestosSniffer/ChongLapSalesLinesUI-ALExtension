namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.History;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;

reportextension 50106 "Sales Invoice w/ Serial No." extends "Standard Sales - Invoice"
{
    dataset
    {
        addlast(Line)
        {
            dataitem(SerialSplitLine; "Sales Invoice Line")
            {
                UseTemporary = true;
                DataItemTableView = sorting("Document No.", "Line No.");

                column(SerSplitItemNo; "No.")
                {
                }
                column(SerSplitDescription; Description)
                {
                }
                column(SerSplitQuantity; SplitQuantityText)
                {
                }
                column(SerSplitUnitOfMeasure; "Unit of Measure")
                {
                }
                column(SerSplitUnitPrice; SplitUnitPriceText)
                {
                }
                column(SerSplitLineDiscountPercentText; SplitLineDiscountText)
                {
                }
                column(SerSplitLineAmount; SplitLineAmountText)
                {
                }
                column(SerSplitSerialNo; SerialNo)
                {
                }

                trigger OnPreDataItem()
                begin
                    BuildSerialSplitBuffer(Line);
                end;

                trigger OnAfterGetRecord()
                begin
                    SplitQuantityText := Format(Quantity);
                    SplitUnitPriceText := Format("Unit Price");
                    SplitLineDiscountText := Format("Line Discount %") + '%';
                    SplitLineAmountText := Format("Line Amount");
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
        SerialNo: Code[50];
        SerialNoPerSplitLine: Dictionary of [Integer, Code[50]];

    local procedure BuildSerialSplitBuffer(SalesInvLine: Record "Sales Invoice Line")
    var
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        ItemTrackingDocMgt: Codeunit "Item Tracking Doc. Management";
        TempItemLedgEntry: Record "Item Ledger Entry" temporary;
        InvoiceRowID: Text[250];
        SerialNos: List of [Code[50]];
        SerialQtys: List of [Decimal];
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
        Clear(SerialNoPerSplitLine);
        SerialSplitLine.Reset();
        SerialSplitLine.DeleteAll();

        if SalesInvLine.Type <> SalesInvLine.Type::Item then begin
            SerialSplitLine := SalesInvLine;
            SerialSplitLine.Insert();
            exit;
        end;

        InvoiceRowID := ItemTrackingMgt.ComposeRowID(Database::"Sales Invoice Line", 0, SalesInvLine."Document No.", '', 0, SalesInvLine."Line No.");
        ItemTrackingDocMgt.RetrieveEntriesFromPostedInvoice(TempItemLedgEntry, InvoiceRowID);

        if TempItemLedgEntry.FindSet() then
            repeat
                if TempItemLedgEntry."Serial No." <> '' then begin
                    FoundIdx := SerialNos.IndexOf(TempItemLedgEntry."Serial No.");
                    if FoundIdx > 0 then
                        SerialQtys.Set(FoundIdx, SerialQtys.Get(FoundIdx) + Abs(TempItemLedgEntry.Quantity))
                    else begin
                        SerialNos.Add(TempItemLedgEntry."Serial No.");
                        SerialQtys.Add(Abs(TempItemLedgEntry.Quantity));
                    end;
                end;
            until TempItemLedgEntry.Next() = 0;

        if SerialNos.Count() = 0 then begin
            SerialSplitLine := SalesInvLine;
            SerialSplitLine.Insert();
            exit;
        end;

        QtyPerUOM := SalesInvLine."Qty. per Unit of Measure";
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;

        TrackedQty := 0;
        for i := 1 to SerialQtys.Count() do
            TrackedQty += SerialQtys.Get(i);

        TotalQtyBase := SalesInvLine.Quantity * QtyPerUOM;
        if TotalQtyBase - TrackedQty > 0.00001 then begin
            SerialNos.Add('');
            SerialQtys.Add(TotalQtyBase - TrackedQty);
        end;

        SplitCount := SerialNos.Count();
        AssignedQty := 0;
        AssignedLineAmount := 0;
        AssignedAmount := 0;
        AssignedAmountInclVAT := 0;

        for i := 1 to SplitCount do begin
            SerialSplitLine := SalesInvLine;
            SerialSplitLine."Line No." := i;

            if i = SplitCount then begin
                SerialSplitLine.Quantity := SalesInvLine.Quantity - AssignedQty;
                SerialSplitLine."Line Amount" := SalesInvLine."Line Amount" - AssignedLineAmount;
                SerialSplitLine.Amount := SalesInvLine.Amount - AssignedAmount;
                SerialSplitLine."Amount Including VAT" := SalesInvLine."Amount Including VAT" - AssignedAmountInclVAT;
            end else begin
                Frac := SerialQtys.Get(i) / TotalQtyBase;
                SplitQty := Round(SalesInvLine.Quantity * Frac, 0.00001);
                SerialSplitLine.Quantity := SplitQty;
                SerialSplitLine."Line Amount" := Round(SalesInvLine."Line Amount" * Frac, 0.01);
                SerialSplitLine.Amount := Round(SalesInvLine.Amount * Frac, 0.01);
                SerialSplitLine."Amount Including VAT" := Round(SalesInvLine."Amount Including VAT" * Frac, 0.01);
                AssignedQty += SerialSplitLine.Quantity;
                AssignedLineAmount += SerialSplitLine."Line Amount";
                AssignedAmount += SerialSplitLine.Amount;
                AssignedAmountInclVAT += SerialSplitLine."Amount Including VAT";
            end;

            SerialSplitLine.Insert();
            SerialNoPerSplitLine.Add(i, SerialNos.Get(i));
        end;
    end;
}
