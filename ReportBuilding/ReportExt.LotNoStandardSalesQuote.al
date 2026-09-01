namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;

reportextension 50102 "Lot No. Standard Sales Quote" extends "Standard Sales - Quote"
{
    dataset
    {
        add(Line)
        {
            column(LotNo; LotNo)
            {
            }
            column(LotNoCaption; LotNoCaptionLbl)
            {
            }
            column(LotExpDate; LotExpDate)
            {
            }
            column(LotExpDateCaption; LotExpDateCaptionLbl)
            {
            }
            column(NetPrice; NetPrice)
            {
            }
            column(NetPriceCaption; NetPriceCaptionLbl)
            {
            }
        }

        modify(Line)
        {
            trigger OnAfterAfterGetRecord()
            begin
                if not LotNoPerLine.Get(Line."Line No.", LotNo) then
                    LotNo := '';
                if not LotExpDatePerLine.Get(Line."Line No.", LotExpDate) then
                    Clear(LotExpDate);
                NetPrice := Round(Line."Unit Price" * (1 - Line."Line Discount %" / 100), 0.01);
            end;
        }

        modify(Header)
        {
            trigger OnAfterAfterGetRecord()
            begin
                SplitLinesByLot();
            end;
        }
    }

    var
        LotNo: Code[50];
        LotNoCaptionLbl: Label 'Lot';
        LotNoPerLine: Dictionary of [Integer, Code[50]];
        LotExpDate: Date;
        LotExpDateCaptionLbl: Label 'Exp';
        LotExpDatePerLine: Dictionary of [Integer, Date];
        NetPrice: Decimal;
        NetPriceCaptionLbl: Label 'Net';

    local procedure SplitLinesByLot()
    var
        SnapshotLine: Record "Sales Line" temporary;
        ReservEntry: Record "Reservation Entry";
        ItemLedgEntry: Record "Item Ledger Entry";
        LotNos: List of [Code[50]];
        LotQtysBase: List of [Decimal];
        LotExpDates: List of [Date];
        QtyPerUOM: Decimal;
        TrackedQtyBase: Decimal;
        TotalQtyBase: Decimal;
        Frac: Decimal;
        SplitQty: Decimal;
        AssignedQty: Decimal;
        AssignedLineAmount: Decimal;
        AssignedAmount: Decimal;
        AssignedAmountInclVAT: Decimal;
        FoundIdx: Integer;
        SplitCount: Integer;
        LineNo: Integer;
        i: Integer;
    begin
        Clear(LotNoPerLine);
        Clear(LotExpDatePerLine);

        if not Line.FindSet() then
            exit;
        repeat
            SnapshotLine := Line;
            SnapshotLine.Insert();
        until Line.Next() = 0;
        Line.DeleteAll();

        SnapshotLine.FindSet();
        repeat
            if SnapshotLine.Type <> SnapshotLine.Type::Item then begin
                Line := SnapshotLine;
                Line.Insert();
            end else begin
                Clear(LotNos);
                Clear(LotQtysBase);
                Clear(LotExpDates);

                ReservEntry.Reset();
                ReservEntry.SetRange("Source Type", Database::"Sales Line");
                ReservEntry.SetRange("Source Subtype", SnapshotLine."Document Type".AsInteger());
                ReservEntry.SetRange("Source ID", SnapshotLine."Document No.");
                ReservEntry.SetRange("Source Ref. No.", SnapshotLine."Line No.");
                ReservEntry.SetFilter("Lot No.", '<>%1', '');
                if ReservEntry.FindSet() then
                    repeat
                        FoundIdx := LotNos.IndexOf(ReservEntry."Lot No.");
                        if FoundIdx > 0 then
                            LotQtysBase.Set(FoundIdx, LotQtysBase.Get(FoundIdx) + Abs(ReservEntry."Quantity (Base)"))
                        else begin
                            LotNos.Add(ReservEntry."Lot No.");
                            LotQtysBase.Add(Abs(ReservEntry."Quantity (Base)"));
                        end;
                    until ReservEntry.Next() = 0;

                for i := 1 to LotNos.Count() do begin
                    ItemLedgEntry.Reset();
                    ItemLedgEntry.SetRange("Item No.", SnapshotLine."No.");
                    ItemLedgEntry.SetRange("Lot No.", LotNos.Get(i));
                    if ItemLedgEntry.FindFirst() then
                        LotExpDates.Add(ItemLedgEntry."Expiration Date")
                    else
                        LotExpDates.Add(0D);
                end;

                if LotNos.Count() = 0 then begin
                    Line := SnapshotLine;
                    Line.Insert();
                end else begin
                    QtyPerUOM := SnapshotLine."Qty. per Unit of Measure";
                    if QtyPerUOM = 0 then
                        QtyPerUOM := 1;

                    TrackedQtyBase := 0;
                    for i := 1 to LotQtysBase.Count() do
                        TrackedQtyBase += LotQtysBase.Get(i);

                    TotalQtyBase := SnapshotLine.Quantity * QtyPerUOM;
                    if TotalQtyBase - TrackedQtyBase > 0.00001 then begin
                        LotNos.Add('');
                        LotQtysBase.Add(TotalQtyBase - TrackedQtyBase);
                        LotExpDates.Add(0D);
                    end;

                    SplitCount := LotNos.Count();
                    AssignedQty := 0;
                    AssignedLineAmount := 0;
                    AssignedAmount := 0;
                    AssignedAmountInclVAT := 0;

                    for i := 1 to SplitCount do begin
                        // Numbered below the original so trailing-blank-line filters
                        // (which use an upper-bound on Line No.) can't drop a split row.
                        LineNo := SnapshotLine."Line No." - (SplitCount - i);
                        Line := SnapshotLine;
                        Line."Line No." := LineNo;

                        if i = SplitCount then begin
                            Line.Quantity := SnapshotLine.Quantity - AssignedQty;
                            Line."Line Amount" := SnapshotLine."Line Amount" - AssignedLineAmount;
                            Line.Amount := SnapshotLine.Amount - AssignedAmount;
                            Line."Amount Including VAT" := SnapshotLine."Amount Including VAT" - AssignedAmountInclVAT;
                        end else begin
                            Frac := LotQtysBase.Get(i) / TotalQtyBase;
                            SplitQty := Round(SnapshotLine.Quantity * Frac, 0.00001);
                            Line.Quantity := SplitQty;
                            Line."Line Amount" := Round(SnapshotLine."Line Amount" * Frac, 0.01);
                            Line.Amount := Round(SnapshotLine.Amount * Frac, 0.01);
                            Line."Amount Including VAT" := Round(SnapshotLine."Amount Including VAT" * Frac, 0.01);
                            AssignedQty += Line.Quantity;
                            AssignedLineAmount += Line."Line Amount";
                            AssignedAmount += Line.Amount;
                            AssignedAmountInclVAT += Line."Amount Including VAT";
                        end;

                        Line.Insert();
                        LotNoPerLine.Add(LineNo, LotNos.Get(i));
                        LotExpDatePerLine.Add(LineNo, LotExpDates.Get(i));
                    end;
                end;
            end;
        until SnapshotLine.Next() = 0;
    end;
}
