namespace DefaultPublisher.ReportBuilding;

using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;

reportextension 50104 "Lot No. Purchase Order" extends "Standard Purchase - Order"
{
    dataset
    {
        addlast("Purchase Line")
        {
            dataitem(LotSplitLine; "Purchase Line")
            {
                UseTemporary = true;
                DataItemTableView = sorting("Document Type", "Document No.", "Line No.");

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
                column(SplitUnitCost; SplitUnitCostText)
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
                    BuildLotSplitBuffer("Purchase Line");
                end;

                trigger OnAfterGetRecord()
                begin
                    SplitQuantityText := Format(Quantity);
                    SplitUnitCostText := Format("Direct Unit Cost");
                    SplitLineDiscountText := Format("Line Discount %") + '%';
                    SplitLineAmountText := Format("Line Amount");
                    NetPrice := Round("Direct Unit Cost" * (1 - "Line Discount %" / 100), 0.01);
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
        SplitUnitCostText: Text[80];
        SplitLineDiscountText: Text[80];
        SplitLineAmountText: Text[80];
        LotNo: Code[50];
        LotExpDate: Date;
        NetPrice: Decimal;
        LotNoPerSplitLine: Dictionary of [Integer, Code[50]];
        LotExpDatePerSplitLine: Dictionary of [Integer, Date];

    local procedure BuildLotSplitBuffer(PurchLine: Record "Purchase Line")
    var
        ReservEntry: Record "Reservation Entry";
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

        if PurchLine.Type <> PurchLine.Type::Item then begin
            LotSplitLine := PurchLine;
            LotSplitLine.Insert();
            exit;
        end;

        ReservEntry.Reset();
        ReservEntry.SetRange("Source Type", Database::"Purchase Line");
        ReservEntry.SetRange("Source Subtype", PurchLine."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", PurchLine."Document No.");
        ReservEntry.SetRange("Source Ref. No.", PurchLine."Line No.");
        ReservEntry.SetFilter("Lot No.", '<>%1', '');
        if ReservEntry.FindSet() then
            repeat
                FoundIdx := LotNos.IndexOf(ReservEntry."Lot No.");
                if FoundIdx > 0 then
                    LotQtys.Set(FoundIdx, LotQtys.Get(FoundIdx) + Abs(ReservEntry."Quantity (Base)"))
                else begin
                    LotNos.Add(ReservEntry."Lot No.");
                    LotQtys.Add(Abs(ReservEntry."Quantity (Base)"));
                    LotExpDates.Add(ReservEntry."Expiration Date");
                end;
            until ReservEntry.Next() = 0;

        if LotNos.Count() = 0 then begin
            LotSplitLine := PurchLine;
            LotSplitLine.Insert();
            exit;
        end;

        QtyPerUOM := PurchLine."Qty. per Unit of Measure";
        if QtyPerUOM = 0 then
            QtyPerUOM := 1;

        TrackedQty := 0;
        for i := 1 to LotQtys.Count() do
            TrackedQty += LotQtys.Get(i);

        TotalQtyBase := PurchLine.Quantity * QtyPerUOM;
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
            LotSplitLine := PurchLine;
            LotSplitLine."Line No." := i;

            if i = SplitCount then begin
                LotSplitLine.Quantity := PurchLine.Quantity - AssignedQty;
                LotSplitLine."Line Amount" := PurchLine."Line Amount" - AssignedLineAmount;
                LotSplitLine.Amount := PurchLine.Amount - AssignedAmount;
                LotSplitLine."Amount Including VAT" := PurchLine."Amount Including VAT" - AssignedAmountInclVAT;
            end else begin
                Frac := LotQtys.Get(i) / TotalQtyBase;
                SplitQty := Round(PurchLine.Quantity * Frac, 0.00001);
                LotSplitLine.Quantity := SplitQty;
                LotSplitLine."Line Amount" := Round(PurchLine."Line Amount" * Frac, 0.01);
                LotSplitLine.Amount := Round(PurchLine.Amount * Frac, 0.01);
                LotSplitLine."Amount Including VAT" := Round(PurchLine."Amount Including VAT" * Frac, 0.01);
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
