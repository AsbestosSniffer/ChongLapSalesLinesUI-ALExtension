// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.ALProject3;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;

codeunit 50102 DetectNewSalesLine
{
    [EventSubscriber(ObjectType::Page, Page::"Sales Order Subform", 'OnAfterQuantityOnAfterValidate', '', false, false)]
    local procedure OnAfterQuantityOnAfterValidateSalesLine(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line")
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TempItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        NextReservationEntryNo: Integer;
        QtyLeftToReserve: Decimal;
        QtyInCurrentLedgerEntry: Decimal;
    begin
        // Only process if sales quantity has changed
        if SalesLine.Quantity = xSalesLine.Quantity then
            exit;

        if SalesLine."No." = '' then
            exit;

        if not Item.Get(SalesLine."No.") then
            exit;

        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            exit;

        if not ItemTrackingCode."Lot Specific Tracking" then
            exit;

        QtyLeftToReserve := SalesLine."Quantity (Base)";

        ItemLedgerEntry.SetCurrentKey("Item No.", "Lot No.");
        ItemLedgerEntry.SetRange("Item No.", SalesLine."No.");
        ItemLedgerEntry.SetAscending("Lot No.", true);


        if ReservationEntry.FindLast() then
            NextReservationEntryNo := ReservationEntry."Entry No."
        else
            NextReservationEntryNo := 1;

        // Delete existing reservations for this sales line
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.DeleteAll();

        if ItemLedgerEntry.FindSet() then begin
            repeat
                // QtyInCurrentLot := 0;
                // // Accumulate quantity in the same lot in QtyInCurrentLot
                // repeat
                //     QtyInCurrentLot += ItemLedgerEntry."Remaining Quantity";
                //     if QtyInCurrentLot > QtyLeftToReserve then
                //         break;
                //     TempItemLedgerEntry := ItemLedgerEntry;
                //     if (TempItemLedgerEntry.Next() = 0) or (TempItemLedgerEntry."Lot No." <> ItemLedgerEntry."Lot No.") then
                //         break;
                //     ItemLedgerEntry := TempItemLedgerEntry;
                // until false;

                // Create Reservation Entry for the lot
                ReservationEntry.Reset();
                NextReservationEntryNo += 1;
                ReservationEntry.Init();
                ReservationEntry."Entry No." := NextReservationEntryNo;
                ReservationEntry."Item No." := SalesLine."No.";
                ReservationEntry."Lot No." := ItemLedgerEntry."Lot No.";

                // Mandatory fields
                ReservationEntry."Location Code" := SalesLine."Location Code";
                ReservationEntry."Variant Code" := SalesLine."Variant Code";

                QtyInCurrentLedgerEntry := ItemLedgerEntry."Remaining Quantity";
                if QtyLeftToReserve <= QtyInCurrentLedgerEntry then begin
                    ReservationEntry."Quantity (Base)" := -QtyLeftToReserve;
                    ReservationEntry."Qty. to Handle (Base)" := -QtyLeftToReserve;
                    ReservationEntry."Qty. to Invoice (Base)" := -QtyLeftToReserve;
                    QtyLeftToReserve := 0
                end else begin
                    ReservationEntry."Quantity (Base)" := -QtyInCurrentLedgerEntry;
                    ReservationEntry."Qty. to Handle (Base)" := -QtyInCurrentLedgerEntry;
                    ReservationEntry."Qty. to Invoice (Base)" := -QtyInCurrentLedgerEntry;
                    QtyLeftToReserve -= QtyInCurrentLedgerEntry;
                end;

                ReservationEntry."Source Type" := Database::"Sales Line";
                ReservationEntry."Source Subtype" := SalesLine."Document Type".AsInteger();
                ReservationEntry."Source ID" := SalesLine."Document No.";
                ReservationEntry."Source Ref. No." := SalesLine."Line No.";
                ReservationEntry.Positive := false;
                ReservationEntry.Insert();

                ReservationEntry."Source Type" := Database::"Item Ledger Entry";
                ReservationEntry."Source Subtype" := ItemLedgerEntry."Document Type".AsInteger();
                ReservationEntry."Source ID" := ItemLedgerEntry."Document No.";
                ReservationEntry."Source Ref. No." := ItemLedgerEntry."Entry No.";
                ReservationEntry.Positive := true;
                ReservationEntry.Insert();

            until (QtyLeftToReserve <= 0) or (ItemLedgerEntry.Next() = 0);
        end;
    end;

    var
        myInt: Integer;
}