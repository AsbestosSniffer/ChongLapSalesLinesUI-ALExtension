namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.Archive;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;

reportextension 50101 "Lot No. Archived Sales Quote" extends "Archived Sales Quote"
{
    dataset
    {
        add(RoundLoop)
        {
            column(LotNo; LotNo)
            {
            }
            column(LotNoCaption; LotNoCaptionLbl)
            {
            }
        }

        modify(RoundLoop)
        {
            trigger OnAfterAfterGetRecord()
            begin
                LotNo := GetFirstLotNo("Sales Line Archive");
            end;
        }
    }

    var
        LotNo: Code[50];
        LotNoCaptionLbl: Label 'Lot No.';

    local procedure GetFirstLotNo(SalesLineArch: Record "Sales Line Archive"): Code[50]
    var
        ReservEntry: Record "Reservation Entry";
    begin
        if SalesLineArch.Type <> SalesLineArch.Type::Item then
            exit('');

        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Source Subtype", SalesLineArch."Document Type".AsInteger());
        ReservEntry.SetRange("Source ID", SalesLineArch."Document No.");
        ReservEntry.SetRange("Source Ref. No.", SalesLineArch."Line No.");
        ReservEntry.SetFilter("Lot No.", '<>%1', '');
        if ReservEntry.FindFirst() then
            exit(ReservEntry."Lot No.");
    end;
}
