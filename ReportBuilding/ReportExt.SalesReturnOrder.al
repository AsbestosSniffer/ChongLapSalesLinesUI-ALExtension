namespace DefaultPublisher.ReportBuilding;

using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Tracking;
using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.Address;

reportextension 50108 "Sales Return Order Details" extends "Return Order Confirmation"
{
    dataset
    {
        add("Sales Header")
        {
            column(ReturnExternalDocumentNo; "External Document No.") { }
            column(ReturnYourReference; "Your Reference") { }
            column(ReturnOrderDate; Format("Order Date", 0, 4)) { }
            column(ReturnPostingDate; Format("Posting Date", 0, 4)) { }
            column(ReturnLocationCode; "Location Code") { }
            column(ReturnCurrencyCode; ReturnCurrencyCode) { }
            column(ReturnPricesIncludingVAT; Format("Prices Including VAT")) { }
            column(ReturnFromAddress1; ReturnFromAddress[1]) { }
            column(ReturnFromAddress2; ReturnFromAddress[2]) { }
            column(ReturnFromAddress3; ReturnFromAddress[3]) { }
            column(ReturnFromAddress4; ReturnFromAddress[4]) { }
            column(ReturnFromAddress5; ReturnFromAddress[5]) { }
            column(ReturnFromAddress6; ReturnFromAddress[6]) { }
            column(ReturnFromAddress7; ReturnFromAddress[7]) { }
            column(ReturnFromAddress8; ReturnFromAddress[8]) { }
        }

        modify("Sales Header")
        {
            trigger OnAfterAfterGetRecord()
            var
                Currency: Record Currency;
                GeneralLedgerSetup: Record "General Ledger Setup";
                FormatAddress: Codeunit "Format Address";
            begin
                FormatAddress.SetLanguageCode("Sales Header"."Language Code");
                FormatAddress.SalesHeaderSellTo(ReturnFromAddress, "Sales Header");
                ReturnCurrencyCode := "Sales Header"."Currency Code";
                if ReturnCurrencyCode = '' then begin
                    GeneralLedgerSetup.Get();
                    ReturnCurrencyCode := GeneralLedgerSetup."LCY Code";
                    Currency.InitRoundingPrecision();
                end else
                    Currency.Get(ReturnCurrencyCode);
                UnitAmountRoundingPrecision := Currency."Unit-Amount Rounding Precision";
            end;
        }

        add(RoundLoop)
        {
            column(ReturnReasonCode; "Sales Line"."Return Reason Code") { }
            column(ReturnLineLocationCode; "Sales Line"."Location Code") { }
            column(ReturnQtyToReceive; "Sales Line"."Return Qty. to Receive") { }
            column(ReturnQtyReceived; "Sales Line"."Return Qty. Received") { }
            column(ReturnOutstandingQuantity; "Sales Line"."Outstanding Quantity") { }
            column(ReturnLotNo; LotNos) { }
            column(ReturnLotExpDate; ExpirationDates) { }
            column(ReturnSerialNo; SerialNos) { }
            column(ReturnTrackingDetails; TrackingDetails) { }
            column(ReturnLineDetails; LineDetails) { }
            column(ReturnQuantityText; QuantityText) { }
            column(ReturnUnitPriceText; UnitPriceText) { }
            column(ReturnDiscountText; DiscountText) { }
            column(ReturnNetPriceText; NetPriceText) { }
            column(ReturnLineAmountText; LineAmountText) { }
            column(ReturnNetPrice; NetPrice)
            {
                AutoFormatExpression = "Sales Header"."Currency Code";
                AutoFormatType = 2;
            }
        }

        modify(RoundLoop)
        {
            trigger OnAfterAfterGetRecord()
            begin
                // RoundLoop is the printable line iterator; Sales Line itself is skipped.
                Clear(LotNos);
                Clear(ExpirationDates);
                Clear(SerialNos);
                Clear(TrackingDetails);
                Clear(TrackingKeys);
                Clear(LineDetails);
                Clear(QuantityText);
                Clear(UnitPriceText);
                Clear(DiscountText);
                Clear(NetPriceText);
                Clear(LineAmountText);
                NetPrice := 0;
                if "Sales Line".Type = "Sales Line".Type::" " then
                    exit;

                NetPrice := Round("Sales Line"."Unit Price" * (1 - "Sales Line"."Line Discount %" / 100), UnitAmountRoundingPrecision);
                QuantityText := Format("Sales Line".Quantity);
                UnitPriceText := Format("Sales Line"."Unit Price");
                DiscountText := Format("Sales Line"."Line Discount %");
                NetPriceText := Format(NetPrice);
                LineAmountText := Format("Sales Line"."Line Amount");
                if "Sales Line".Type = "Sales Line".Type::Item then begin
                    LineDetails := StrSubstNo(LineDetailsLbl, "Sales Line"."Return Reason Code", "Sales Line"."Location Code",
                        Format("Sales Line"."Return Qty. to Receive"), Format("Sales Line"."Return Qty. Received"),
                        Format("Sales Line"."Outstanding Quantity"));
                    CollectTracking("Sales Line");
                end;
            end;
        }
    }

    rendering
    {
        layout(SalesReturnOrderMaster)
        {
            Type = Word;
            LayoutFile = 'templates/SalesReturnOrder-Master.docx';
            Caption = 'Sales Return Order - Tracking Details';
            Summary = 'Return confirmation with customer references, receipt quantities, return reasons, lot, expiry, serial numbers and net prices.';
        }
    }

    var
        ReturnCurrencyCode: Code[10];
        ReturnFromAddress: array[8] of Text[100];
        UnitAmountRoundingPrecision: Decimal;
        NetPrice: Decimal;
        LotNos: Text;
        ExpirationDates: Text;
        SerialNos: Text;
        TrackingDetails: Text;
        LineDetails: Text;
        QuantityText: Text;
        UnitPriceText: Text;
        DiscountText: Text;
        NetPriceText: Text;
        LineAmountText: Text;
        TrackingKeys: List of [Text];
        LineDetailsLbl: Label 'Reason: %1    Location: %2    To receive: %3    Received: %4    Outstanding: %5', Comment = '%1 = return reason, %2 = location, %3 = quantity to receive, %4 = quantity received, %5 = outstanding quantity';

    local procedure CollectTracking(SalesLine: Record "Sales Line")
    var
        ReservationEntry: Record "Reservation Entry";
        ReturnReceiptLine: Record "Return Receipt Line";
        ItemEntryRelation: Record "Item Entry Relation";
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ReservationEntry.SetRange("Source Type", Database::"Sales Line");
        ReservationEntry.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        ReservationEntry.SetRange("Source ID", SalesLine."Document No.");
        ReservationEntry.SetRange("Source Batch Name", '');
        ReservationEntry.SetRange("Source Prod. Order Line", 0);
        ReservationEntry.SetRange("Source Ref. No.", SalesLine."Line No.");
        ReservationEntry.SetRange(Positive, true);
        if ReservationEntry.FindSet() then
            repeat
                AddTracking(ReservationEntry."Lot No.", ReservationEntry."Serial No.", ReservationEntry."Expiration Date");
            until ReservationEntry.Next() = 0;

        // Posting removes reservation entries. Include this order line's posted receipts
        // so partially/fully received returns retain their tracking information.
        ReturnReceiptLine.SetRange("Return Order No.", SalesLine."Document No.");
        ReturnReceiptLine.SetRange("Return Order Line No.", SalesLine."Line No.");
        ReturnReceiptLine.SetRange(Type, ReturnReceiptLine.Type::Item);
        ReturnReceiptLine.SetRange("No.", SalesLine."No.");
        ReturnReceiptLine.SetFilter(Quantity, '<>0');
        if ReturnReceiptLine.FindSet() then
            repeat
                if ReturnReceiptLine."Item Rcpt. Entry No." <> 0 then begin
                    if ItemLedgerEntry.Get(ReturnReceiptLine."Item Rcpt. Entry No.") then
                        AddTracking(ItemLedgerEntry."Lot No.", ItemLedgerEntry."Serial No.", ItemLedgerEntry."Expiration Date");
                end else begin
                    ItemEntryRelation.Reset();
                    ItemEntryRelation.SetRange("Source Type", Database::"Return Receipt Line");
                    ItemEntryRelation.SetRange("Source Subtype", 0);
                    ItemEntryRelation.SetRange("Source ID", ReturnReceiptLine."Document No.");
                    ItemEntryRelation.SetRange("Source Ref. No.", ReturnReceiptLine."Line No.");
                    if ItemEntryRelation.FindSet() then
                        repeat
                            if ItemLedgerEntry.Get(ItemEntryRelation."Item Entry No.") then
                                AddTracking(ItemLedgerEntry."Lot No.", ItemLedgerEntry."Serial No.", ItemLedgerEntry."Expiration Date");
                        until ItemEntryRelation.Next() = 0;
                end;
            until ReturnReceiptLine.Next() = 0;
    end;

    local procedure AddTracking(LotNo: Code[50]; SerialNo: Code[50]; ExpirationDate: Date)
    var
        TrackingKey: Text;
        ExpirationDateText: Text;
        Separator: Text[1];
    begin
        if (LotNo = '') and (SerialNo = '') then
            exit;
        TrackingKey := StrSubstNo('%1|%2|%3', LotNo, SerialNo, Format(ExpirationDate, 0, 9));
        if TrackingKeys.Contains(TrackingKey) then
            exit;
        TrackingKeys.Add(TrackingKey);

        // One aligned entry per line in each tracking column; never split financial rows.
        if TrackingKeys.Count() > 1 then
            Separator[1] := 10;
        if LotNo = '' then
            LotNo := '-';
        if SerialNo = '' then
            SerialNo := '-';
        ExpirationDateText := '-';
        if ExpirationDate <> 0D then
            ExpirationDateText := Format(ExpirationDate, 0, '<Day,2>/<Month,2>/<Year>');
        LotNos += Separator + LotNo;
        SerialNos += Separator + SerialNo;
        ExpirationDates += Separator + ExpirationDateText;
        TrackingDetails += Separator + StrSubstNo('Lot: %1    Exp: %2    Serial: %3', LotNo, ExpirationDateText, SerialNo);
    end;
}
