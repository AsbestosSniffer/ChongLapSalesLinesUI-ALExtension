codeunit 50111 ReserveEntriesHelper
{
    procedure DeleteReserveEntries(CurrentSalesLine: Record "Sales Line")
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", CurrentSalesLine."Document Type");
        SalesLine.SetRange("Document No.", CurrentSalesLine."Document No.");
        if SalesLine.FindSet() then begin
            repeat
                DeleteReservationEntriesForLine(SalesLine);
            until SalesLine.Next() = 0;
        end;
    end;

    local procedure DeleteReservationEntriesForLine(var SalesLine: Record "Sales Line")
    var
        DemandEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
    begin
        // Entries for the Sales Line side were created with Positive = false.
        DemandEntry.SetSourceFilter(
            Database::"Sales Line",
            SalesLine."Document Type".AsInteger(),
            SalesLine."Document No.",
            SalesLine."Line No.",
            false);

        if DemandEntry.FindSet() then
            repeat
                // Remove the linked supply-side entry (Source Type = Item Ledger Entry, Positive = true)
                // so it doesn't stay behind and falsely tie up inventory.
                SupplyEntry.Reset();
                SupplyEntry.SetRange("Source Type", Database::"Item Ledger Entry");
                SupplyEntry.SetRange(Positive, true);
                SupplyEntry.SetRange("Item No.", DemandEntry."Item No.");
                SupplyEntry.SetRange("Variant Code", DemandEntry."Variant Code");
                SupplyEntry.SetRange("Location Code", DemandEntry."Location Code");
                SupplyEntry.SetRange("Lot No.", DemandEntry."Lot No.");
                SupplyEntry.SetRange("Quantity (Base)", DemandEntry."Quantity (Base)");
                if SupplyEntry.FindFirst() then
                    SupplyEntry.Delete();
            until DemandEntry.Next() = 0;

        DemandEntry.DeleteAll();
    end;

    procedure CreateReserveEntries(CurrentSalesLine: Record "Sales Line")
    var
        DetailText: Text;
    begin
        DetailText := AssignFefoLotsWithDetails(CurrentSalesLine);
        if DetailText <> '' then
            Message('FEFO lot assignment results:%1', DetailText)
        else
            Message('No lot-tracked item lines found on this document.');
    end;

    // Same as CreateReserveEntries, but returns only shortage details instead of showing a Message,
    // so callers that process many documents (e.g. a bulk action) can show one summary at the end.
    procedure AssignFefoLots(CurrentSalesLine: Record "Sales Line"): Text
    var
        SalesLine: Record "Sales Line";
        StatusText: Text;
        ShortageText: Text;
        QtyShort: Decimal;
    begin
        SalesLine.SetRange("Document Type", CurrentSalesLine."Document Type");
        SalesLine.SetRange("Document No.", CurrentSalesLine."Document No.");
        if SalesLine.FindSet() then
            repeat
                QtyShort := CreateReservationEntriesForLine(SalesLine, StatusText);
                if QtyShort > 0 then
                    ShortageText += StrSubstNo('\Line %1 (%2): %3 unit(s) could not be reserved.', SalesLine."Line No.", SalesLine."No.", QtyShort);
            until SalesLine.Next() = 0;

        exit(ShortageText);
    end;

    // Same as AssignFefoLots, but returns a status line for every lot-tracked item line
    // (success or failure), so the single-document button can show what actually happened.
    local procedure AssignFefoLotsWithDetails(CurrentSalesLine: Record "Sales Line"): Text
    var
        SalesLine: Record "Sales Line";
        StatusText: Text;
        DetailText: Text;
    begin
        SalesLine.SetRange("Document Type", CurrentSalesLine."Document Type");
        SalesLine.SetRange("Document No.", CurrentSalesLine."Document No.");
        if SalesLine.FindSet() then
            repeat
                CreateReservationEntriesForLine(SalesLine, StatusText);
                if StatusText <> '' then
                    DetailText += '\' + StatusText;
            until SalesLine.Next() = 0;

        exit(DetailText);
    end;

    // Diagnostic helper: reports what tracking info is actually present on the most recent
    // open Item Ledger Entry for this item/location/variant, so we can tell whether
    // inventory is identified by Lot No., Serial No., or Package No.
    local procedure DescribeSampleLedgerEntry(SalesLine: Record "Sales Line"): Text
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetRange("Item No.", SalesLine."No.");
        ItemLedgerEntry.SetRange("Location Code", SalesLine."Location Code");
        ItemLedgerEntry.SetRange("Variant Code", SalesLine."Variant Code");
        ItemLedgerEntry.SetFilter("Remaining Quantity", '>0');
        ItemLedgerEntry.SetRange(Open, true);

        if not ItemLedgerEntry.FindFirst() then
            exit(StrSubstNo('No open Item Ledger Entries found for Location ''%1'', Variant ''%2''.', SalesLine."Location Code", SalesLine."Variant Code"));

        exit(StrSubstNo('Sample open entry - Lot No.=''%1'', Serial No.=''%2'', Package No.=''%3'', Expiration Date=%4, Remaining Qty=%5.',
            ItemLedgerEntry."Lot No.", ItemLedgerEntry."Serial No.", ItemLedgerEntry."Package No.", ItemLedgerEntry."Expiration Date", ItemLedgerEntry."Remaining Quantity"));
    end;

    local procedure CreateReservationEntriesForLine(var SalesLine: Record "Sales Line"; var StatusText: Text): Decimal
    var
        ReservationEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        QtyLeftToReserve: Decimal;
        QtyInCurrentLedgerEntry: Decimal;
        NextReservationEntryNo: Integer;
        EntriesCreated: Integer;
        UsedEntryNos: List of [Integer];
    begin
        StatusText := '';

        // Lines that aren't actual item lines (comments, G/L accounts, etc.) are
        // skipped silently - they're not relevant to FEFO lot assignment.
        if SalesLine.Type <> SalesLine.Type::Item then
            exit;

        if SalesLine."No." = '' then
            exit;

        if not Item.Get(SalesLine."No.") then begin
            StatusText := StrSubstNo('Line %1: item ''%2'' not found.', SalesLine."Line No.", SalesLine."No.");
            exit;
        end;

        // Must run before filtering Item Ledger Entries, otherwise the FEFO search
        // and the resulting Reservation Entries use a different location than the line ends up with.
        SetLocationCode(SalesLine);

        if not ItemTrackingCode.Get(Item."Item Tracking Code") then begin
            StatusText := StrSubstNo('Line %1 (%2): item is not set up for lot tracking (Item Tracking Code = ''%3'').', SalesLine."Line No.", SalesLine."No.", Item."Item Tracking Code");
            exit;
        end;

        // Some tracking codes (e.g. this company's "LOTEXP") have "Lot Specific Tracking" = No
        // but still identify inventory by Lot No. with expiration dates, so accept either flag.
        if not (ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Use Expiration Dates") then begin
            StatusText := StrSubstNo(
                'Line %1 (%2): item tracking code ''%3'' does not use lot or expiration-date tracking (SN Specific Tracking=%4, Package Specific Tracking=%5). %6',
                SalesLine."Line No.", SalesLine."No.", Item."Item Tracking Code",
                ItemTrackingCode."SN Specific Tracking", ItemTrackingCode."Package Specific Tracking",
                DescribeSampleLedgerEntry(SalesLine));
            exit;
        end;

        QtyLeftToReserve := SalesLine."Quantity (Base)";

        DeleteReservationEntriesForLine(SalesLine);

        ReservationEntry.LockTable();
        if ReservationEntry.FindLast() then
            NextReservationEntryNo := ReservationEntry."Entry No."
        else
            NextReservationEntryNo := 0;

        while (QtyLeftToReserve > 0) and FindNextFefoLedgerEntry(SalesLine, UsedEntryNos, ItemLedgerEntry) do begin
            UsedEntryNos.Add(ItemLedgerEntry."Entry No.");
            EntriesCreated += 1;

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
                QtyLeftToReserve := 0;
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
        end;

        if EntriesCreated = 0 then
            StatusText := StrSubstNo('Line %1 (%2): no available lot-tracked inventory found for Location ''%3'', Variant ''%4''.', SalesLine."Line No.", SalesLine."No.", SalesLine."Location Code", SalesLine."Variant Code")
        else if QtyLeftToReserve > 0 then
            StatusText := StrSubstNo('Line %1 (%2): reserved %3 of %4 unit(s) across %5 lot(s); %6 unit(s) short.', SalesLine."Line No.", SalesLine."No.", SalesLine."Quantity (Base)" - QtyLeftToReserve, SalesLine."Quantity (Base)", EntriesCreated, QtyLeftToReserve)
        else
            StatusText := StrSubstNo('Line %1 (%2): reserved %3 unit(s) across %4 lot(s).', SalesLine."Line No.", SalesLine."No.", SalesLine."Quantity (Base)", EntriesCreated);

        exit(QtyLeftToReserve);
    end;

    // Picks the open Item Ledger Entry (not already used for this line) with the earliest
    // Expiration Date, falling back to Lot No. then Entry No. as tie-breakers. Entries with
    // no Expiration Date are treated as expiring last. Avoids SetCurrentKey/SetAscending on
    // "Expiration Date", which is not part of any key on Item Ledger Entry and would error.
    local procedure FindNextFefoLedgerEntry(SalesLine: Record "Sales Line"; UsedEntryNos: List of [Integer]; var BestEntry: Record "Item Ledger Entry"): Boolean
    var
        Candidate: Record "Item Ledger Entry";
        NoExpirationDate: Date;
        CandidateExpDate: Date;
        BestExpDate: Date;
        Found: Boolean;
    begin
        NoExpirationDate := DMY2Date(31, 12, 9999);

        Candidate.SetRange("Item No.", SalesLine."No.");
        Candidate.SetRange("Location Code", SalesLine."Location Code");
        Candidate.SetRange("Variant Code", SalesLine."Variant Code");
        Candidate.SetFilter("Remaining Quantity", '>0');
        Candidate.SetRange(Open, true);

        Found := false;
        if Candidate.FindSet() then
            repeat
                if not UsedEntryNos.Contains(Candidate."Entry No.") then begin
                    CandidateExpDate := Candidate."Expiration Date";
                    if CandidateExpDate = 0D then
                        CandidateExpDate := NoExpirationDate;

                    if not Found then begin
                        BestEntry := Candidate;
                        Found := true;
                    end else begin
                        BestExpDate := BestEntry."Expiration Date";
                        if BestExpDate = 0D then
                            BestExpDate := NoExpirationDate;

                        if (CandidateExpDate < BestExpDate)
                           or ((CandidateExpDate = BestExpDate) and (Candidate."Lot No." < BestEntry."Lot No."))
                           or ((CandidateExpDate = BestExpDate) and (Candidate."Lot No." = BestEntry."Lot No.") and (Candidate."Entry No." < BestEntry."Entry No."))
                        then
                            BestEntry := Candidate;
                    end;
                end;
            until Candidate.Next() = 0;

        exit(Found);
    end;

    local procedure SetLocationCode(var SalesLine: Record "Sales Line")
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get();

        // Only force the line to the company's default location if one is actually configured.
        // Otherwise leave the line's existing Location Code alone - overwriting it with blank
        // breaks "Location Mandatory" lines (Location Code must have a value).
        if CompanyInfo."Location Code" = '' then
            exit;

        if SalesLine."Location Code" <> CompanyInfo."Location Code" then begin
            SalesLine."Location Code" := CompanyInfo."Location Code";
            SalesLine.Modify();
        end;
    end;
}
