namespace ALProject3;
using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;
codeunit 50103 ConvertShopifyOrderReserveInv
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Shpfy Order Events", 'OnAfterCreateItemSalesLine', '', false, false)]
    local procedure OnAfterCreateItemSalesLine(ShopifyOrderHeader: Record "Shpfy Order Header"; ShopifyOrderLine: Record "Shpfy Order Line"; SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line")
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
            NextReservationEntryNo := ReservationEntry."Entry No." + 1
        else
            NextReservationEntryNo := 1;

        // Delete existing reservations for this sales line
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.DeleteAll();

        if ItemLedgerEntry.FindSet() then begin
            repeat
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