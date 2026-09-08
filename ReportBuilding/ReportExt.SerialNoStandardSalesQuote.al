namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;

reportextension 50105 "Sales Quote w/ Serial No." extends "Standard Sales - Quote"
{
    dataset
    {
        add(Line)
        {
            column(SerialNo; SerialNo)
            {
            }
            column(SerialNoCaption; SerialNoCaptionLbl)
            {
            }
        }

        modify(Line)
        {
            trigger OnAfterAfterGetRecord()
            begin
                if not SerialNoPerLine.Get(Line."Line No.", SerialNo) then
                    SerialNo := '';
                // NetPrice := Round(Line."Unit Price" * (1 - Line."Line Discount %" / 100), 0.01);
            end;
        }

        modify(Header)
        {
            trigger OnAfterAfterGetRecord()
            begin
                SplitLinesBySerialNo();
            end;
        }
    }

    var
        SerialNo: Code[50];
        SerialNoCaptionLbl: Label 'Serial No.';
        SerialNoPerLine: Dictionary of [Integer, Code[50]];
        NetPrice: Decimal;
        NetPriceCaptionLbl: Label 'Net';

    local procedure SplitLinesBySerialNo()
    var
        SnapshotLine: Record "Sales Line" temporary;
        ReservEntry: Record "Reservation Entry";
        SerialNos: List of [Code[50]];
        SerialQtysBase: List of [Decimal];
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
        Clear(SerialNoPerLine);

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
                Clear(SerialNos);
                Clear(SerialQtysBase);

                ReservEntry.Reset();
                ReservEntry.SetRange("Source Type", Database::"Sales Line");
                ReservEntry.SetRange("Source Subtype", SnapshotLine."Document Type".AsInteger());
                ReservEntry.SetRange("Source ID", SnapshotLine."Document No.");
                ReservEntry.SetRange("Source Ref. No.", SnapshotLine."Line No.");
                ReservEntry.SetFilter("Serial No.", '<>%1', '');
                if ReservEntry.FindSet() then
                    repeat
                        FoundIdx := SerialNos.IndexOf(ReservEntry."Serial No.");
                        if FoundIdx > 0 then
                            SerialQtysBase.Set(FoundIdx, SerialQtysBase.Get(FoundIdx) + Abs(ReservEntry."Quantity (Base)"))
                        else begin
                            SerialNos.Add(ReservEntry."Serial No.");
                            SerialQtysBase.Add(Abs(ReservEntry."Quantity (Base)"));
                        end;
                    until ReservEntry.Next() = 0;

                if SerialNos.Count() = 0 then begin
                    Line := SnapshotLine;
                    Line.Insert();
                end else begin
                    QtyPerUOM := SnapshotLine."Qty. per Unit of Measure";
                    if QtyPerUOM = 0 then
                        QtyPerUOM := 1;

                    TrackedQtyBase := 0;
                    for i := 1 to SerialQtysBase.Count() do
                        TrackedQtyBase += SerialQtysBase.Get(i);

                    TotalQtyBase := SnapshotLine.Quantity * QtyPerUOM;
                    if TotalQtyBase - TrackedQtyBase > 0.00001 then begin
                        SerialNos.Add('');
                        SerialQtysBase.Add(TotalQtyBase - TrackedQtyBase);
                    end;

                    SplitCount := SerialNos.Count();
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
                            Frac := SerialQtysBase.Get(i) / TotalQtyBase;
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
                        SerialNoPerLine.Add(LineNo, SerialNos.Get(i));
                    end;
                end;
            end;
        until SnapshotLine.Next() = 0;
    end;
}
