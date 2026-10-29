codeunit 50111 ReserveEntriesHelper
{
    procedure CreateReserveEntries(CurrentSalesLine: Record "Sales Line")
    var
        Details: Text;
    begin
        Details := AssignDocument(CurrentSalesLine, true);
        if Details = '' then
            Message('No lot-tracked item lines found on this document.')
        else
            Message('FEFO lot assignment results (quantities in base units):%1', Details);
    end;

    // Bulk callers receive shortages AND skips, without per-document dialogs.
    procedure AssignFefoLots(CurrentSalesLine: Record "Sales Line"): Text
    begin
        exit(AssignDocument(CurrentSalesLine, false));
    end;

    local procedure AssignDocument(CurrentSalesLine: Record "Sales Line"; IncludeSuccess: Boolean): Text
    var
        SalesLine: Record "Sales Line";
        Details: Text;
        StatusText: Text;
        QtyShort: Decimal;
        Skipped: Boolean;
    begin
        SetDocumentFilter(SalesLine, CurrentSalesLine);
        if SalesLine.FindSet() then
            repeat
                QtyShort := AssignFefoLotsToLine(SalesLine, StatusText, Skipped);
                if (StatusText <> '') and (IncludeSuccess or Skipped or (QtyShort > 0)) then
                    Details += '\' + StatusText;
            until SalesLine.Next() = 0;
        exit(Details);
    end;

    // Single-line entry point shared by the quantity and Shopify subscribers.
    procedure AssignFefoLotsToLine(var SalesLine: Record "Sales Line"; var StatusText: Text; var Skipped: Boolean): Decimal
    var
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ReservationEntry: Record "Reservation Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TempSummary: Record "Entry Summary" temporary;
        BestSummary: Record "Entry Summary" temporary;
        Reason: Text;
        QtyLeft: Decimal;
        QtyAssigned: Decimal;
        LotCount: Integer;
    begin
        Clear(StatusText);
        Skipped := false;
        if not IsLotTrackedItem(SalesLine, Item, ItemTrackingCode) then
            exit(0);

        // Serialize this service's allocations for the same item, even when there
        // are no reservation entries yet. No commits within a document.
        Item.LockTable();
        Item.Get(SalesLine."No.");
        ReservationEntry.LockTable();
        ItemLedgerEntry.LockTable();

        Reason := GetLineProtectionReason(SalesLine, ItemTrackingCode);
        if Reason = '' then
            Reason := GetInventoryAuditReason(SalesLine);
        if Reason <> '' then begin
            Skipped := true;
            StatusText := StrSubstNo('Line %1 (%2): skipped - %3', SalesLine."Line No.", SalesLine."No.", Reason);
            exit(0);
        end;

        SalesLine.TestField("Qty. per Unit of Measure");
        SalesLine.TestField("Document No.");
        SalesLine.TestField("Line No.");
        DeleteTrackingForLine(SalesLine);
        LoadAvailability(SalesLine, ItemTrackingCode, TempSummary);
        QtyLeft := SalesLine."Outstanding Qty. (Base)";

        while (QtyLeft > 0) and FindNextLot(SalesLine, TempSummary, BestSummary, ItemTrackingCode, GetPostingDate(SalesLine)) do begin
            QtyAssigned := MinQty(QtyLeft, BestSummary."Total Available Quantity");
            CreateLotTracking(SalesLine, BestSummary, QtyAssigned);
            QtyLeft -= QtyAssigned;
            LotCount += 1;
            // A summary aggregates receipts for a lot; consume it only once.
            TempSummary.Get(BestSummary."Entry No.");
            TempSummary.Delete();
        end;

        StatusText := StrSubstNo('Line %1 (%2): assigned %3 of %4 base unit(s) across %5 lot(s).',
            SalesLine."Line No.", SalesLine."No.", SalesLine."Outstanding Qty. (Base)" - QtyLeft,
            SalesLine."Outstanding Qty. (Base)", LotCount);
        if QtyLeft > 0 then
            StatusText += StrSubstNo(' %1 base unit(s) short.', QtyLeft);
        exit(QtyLeft);
    end;

    procedure DeleteReserveEntries(CurrentSalesLine: Record "Sales Line")
    begin
        Message('Lot tracking removal results:%1', DeleteLotTracking(CurrentSalesLine));
    end;

    procedure DeleteLotTracking(CurrentSalesLine: Record "Sales Line"): Text
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        ReservationEntry: Record "Reservation Entry";
        Details: Text;
        Reason: Text;
    begin
        SetDocumentFilter(SalesLine, CurrentSalesLine);
        if SalesLine.FindSet() then
            repeat
                if IsLotTrackedItem(SalesLine, Item, ItemTrackingCode) then begin
                    Item.LockTable();
                    Item.Get(SalesLine."No.");
                    ReservationEntry.LockTable();
                    Reason := GetLineProtectionReason(SalesLine, ItemTrackingCode);
                    if Reason = '' then begin
                        DeleteTrackingForLine(SalesLine);
                        Details += StrSubstNo('\Line %1 (%2): unhandled lot tracking removed.', SalesLine."Line No.", SalesLine."No.");
                    end else
                        Details += StrSubstNo('\Line %1 (%2): skipped - %3', SalesLine."Line No.", SalesLine."No.", Reason);
                end;
            until SalesLine.Next() = 0;
        if Details = '' then
            Details := '\No lot-tracked item lines found on this document.';
        exit(Details);
    end;

    // Read-only audit: do not silently reclassify or repair legacy entries.
    procedure AuditLotTracking(CurrentSalesLine: Record "Sales Line"): Text
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        ItemTrackingCode: Record "Item Tracking Code";
        Details: Text;
        Reason: Text;
    begin
        SetDocumentFilter(SalesLine, CurrentSalesLine);
        if SalesLine.FindSet() then
            repeat
                if IsLotTrackedItem(SalesLine, Item, ItemTrackingCode) then begin
                    Reason := GetInventoryAuditReason(SalesLine);
                    if Reason <> '' then
                        Details += StrSubstNo('\Line %1 (%2): %3', SalesLine."Line No.", SalesLine."No.", Reason);
                end;
            until SalesLine.Next() = 0;
        if Details = '' then
            exit('No malformed reservation entries found in the inventory pools used by this document.');
        exit('First issue per line/inventory pool (no data changed):' + Details);
    end;

    local procedure SetDocumentFilter(var SalesLine: Record "Sales Line"; CurrentSalesLine: Record "Sales Line")
    begin
        CurrentSalesLine.TestField("Document No.");
        SalesLine.SetRange("Document Type", CurrentSalesLine."Document Type");
        SalesLine.SetRange("Document No.", CurrentSalesLine."Document No.");
    end;

    local procedure IsLotTrackedItem(SalesLine: Record "Sales Line"; var Item: Record Item; var ItemTrackingCode: Record "Item Tracking Code"): Boolean
    begin
        if (SalesLine.Type <> SalesLine.Type::Item) or (SalesLine."No." = '') then
            exit(false);
        if not Item.Get(SalesLine."No.") then
            exit(false);
        if not ItemTrackingCode.Get(Item."Item Tracking Code") then
            exit(false);
        // Retain support for LOTEXP, which uses expiration dates without lot-specific tracking.
        exit(ItemTrackingCode."Lot Specific Tracking" or ItemTrackingCode."Use Expiration Dates");
    end;

    local procedure GetLineProtectionReason(SalesLine: Record "Sales Line"; ItemTrackingCode: Record "Item Tracking Code"): Text
    var
        ReservationEntry: Record "Reservation Entry";
        TrackingSpecification: Record "Tracking Specification";
        WhseShipmentLine: Record "Warehouse Shipment Line";
        WhseActivityLine: Record "Warehouse Activity Line";
        Reason: Text;
    begin
        if not (SalesLine."Document Type" in [SalesLine."Document Type"::Order, SalesLine."Document Type"::Invoice]) then
            exit('only sales orders and unposted sales invoices are supported.');
        if SalesLine.IsTemporary() then
            exit('temporary sales lines are not supported.');
        if (SalesLine.Quantity < 0) or (SalesLine."Outstanding Qty. (Base)" < 0) then
            exit('negative sales quantities are not supported.');
        if (SalesLine."Quantity Shipped" <> 0) or (SalesLine."Quantity Invoiced" <> 0) or (SalesLine."Shipment No." <> '') then
            exit('posted shipment or invoice quantities exist.');
        if SalesLine."Drop Shipment" or SalesLine."Special Order" or (SalesLine."Qty. to Assemble to Order" <> 0) then
            exit('the line is linked to drop shipment, special order or assembly supply.');
        if ItemTrackingCode."SN Specific Tracking" or ItemTrackingCode."SN Sales Outbound Tracking" or
           ItemTrackingCode."Package Specific Tracking" or ItemTrackingCode."Package Sales Outb. Tracking"
        then
            exit('serial/package tracking requires the standard Item Tracking Lines flow.');

        TrackingSpecification.SetSourceFilter(Database::"Sales Line", SalesLine."Document Type".AsInteger(),
            SalesLine."Document No.", SalesLine."Line No.", false);
        TrackingSpecification.SetSourceFilter('', 0);
        TrackingSpecification.SetFilter("Quantity Handled (Base)", '<>0');
        if not TrackingSpecification.IsEmpty() then
            exit('handled item tracking exists.');

        WhseShipmentLine.SetRange("Source Type", Database::"Sales Line");
        WhseShipmentLine.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        WhseShipmentLine.SetRange("Source No.", SalesLine."Document No.");
        WhseShipmentLine.SetRange("Source Line No.", SalesLine."Line No.");
        if not WhseShipmentLine.IsEmpty() then
            exit('a warehouse shipment exists.');
        WhseActivityLine.SetRange("Source Type", Database::"Sales Line");
        WhseActivityLine.SetRange("Source Subtype", SalesLine."Document Type".AsInteger());
        WhseActivityLine.SetRange("Source No.", SalesLine."Document No.");
        WhseActivityLine.SetRange("Source Line No.", SalesLine."Line No.");
        if not WhseActivityLine.IsEmpty() then
            exit('warehouse activity exists.');

        ReservationEntry.SetSourceFilter(Database::"Sales Line", SalesLine."Document Type".AsInteger(),
            SalesLine."Document No.", SalesLine."Line No.", false);
        ReservationEntry.SetSourceFilter('', 0);
        if ReservationEntry.FindSet() then
            repeat
                Reason := GetEntryAuditReason(ReservationEntry);
                if Reason <> '' then
                    exit(Reason);
                if ReservationEntry."Reservation Status" = ReservationEntry."Reservation Status"::Reservation then
                    exit('a firm reservation exists; use standard reservation management to change it.');
                if ReservationEntry."Disallow Cancellation" then
                    exit('an entry disallows cancellation.');
                if (ReservationEntry."Serial No." <> '') or (ReservationEntry."Package No." <> '') or ReservationEntry.Positive then
                    exit('tracking outside ordinary outbound lot demand exists.');
            until ReservationEntry.Next() = 0;
        exit('');
    end;

    local procedure GetInventoryAuditReason(SalesLine: Record "Sales Line"): Text
    var
        ReservationEntry: Record "Reservation Entry";
        Reason: Text;
    begin
        ReservationEntry.SetRange("Item No.", SalesLine."No.");
        ReservationEntry.SetRange("Variant Code", SalesLine."Variant Code");
        ReservationEntry.SetRange("Location Code", SalesLine."Location Code");
        if ReservationEntry.FindSet() then
            repeat
                Reason := GetEntryAuditReason(ReservationEntry);
                if Reason <> '' then
                    exit(Reason);
            until ReservationEntry.Next() = 0;
        exit('');
    end;

    local procedure GetEntryAuditReason(ReservationEntry: Record "Reservation Entry"): Text
    var
        Partner: Record "Reservation Entry";
    begin
        if ReservationEntry."Item Tracking" <> ReservationEntry.GetItemTrackingEntryType() then
            exit(StrSubstNo('entry %1 has inconsistent item tracking; audit/repair it before assignment.', ReservationEntry."Entry No."));
        if (ReservationEntry."Quantity (Base)" <> 0) and (ReservationEntry.Positive <> (ReservationEntry."Quantity (Base)" > 0)) then
            exit(StrSubstNo('entry %1 has an inconsistent quantity sign; audit/repair it before assignment.', ReservationEntry."Entry No."));
        if ReservationEntry."Reservation Status" in [ReservationEntry."Reservation Status"::Reservation, ReservationEntry."Reservation Status"::Tracking] then begin
            if not Partner.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then
                exit(StrSubstNo('entry %1 is missing its paired entry; audit/repair it before assignment.', ReservationEntry."Entry No."));
            if (Partner."Quantity (Base)" <> -ReservationEntry."Quantity (Base)") or
               (Partner."Item No." <> ReservationEntry."Item No.") or
               (Partner."Variant Code" <> ReservationEntry."Variant Code") or
               (Partner."Location Code" <> ReservationEntry."Location Code") or
               (Partner."Reservation Status" <> ReservationEntry."Reservation Status")
            then
                exit(StrSubstNo('entry %1 has an inconsistent pair; audit/repair it before assignment.', ReservationEntry."Entry No."));
        end else
            if Partner.Get(ReservationEntry."Entry No.", not ReservationEntry.Positive) then
                exit(StrSubstNo('entry %1 has an unexpected paired entry; audit/repair it before assignment.', ReservationEntry."Entry No."));
        exit('');
    end;

    local procedure DeleteTrackingForLine(SalesLine: Record "Sales Line")
    var
        ReservationManagement: Codeunit "Reservation Management";
    begin
        ReservationManagement.SetReservSource(SalesLine);
        ReservationManagement.SetItemTrackingHandling(1); // Allow deletion, after protection checks.
        ReservationManagement.DeleteReservEntries(true, 0);
    end;

    local procedure LoadAvailability(SalesLine: Record "Sales Line"; ItemTrackingCode: Record "Item Tracking Code"; var TempSummary: Record "Entry Summary" temporary)
    var
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        SalesLineReserve: Codeunit "Sales Line-Reserve";
        TrackingDataCollection: Codeunit "Item Tracking Data Collection";
    begin
        SalesLineReserve.InitFromSalesLine(TempTrackingSpecification, SalesLine);
        TrackingDataCollection.SetCurrentBinAndItemTrkgCode(SalesLine."Bin Code", ItemTrackingCode);
        TrackingDataCollection.RetrieveLookupData(TempTrackingSpecification, true);
        TrackingDataCollection.GetTempGlobalEntrySummary(TempSummary);
        TempSummary.SetRange("Serial No.", '');
        TempSummary.SetRange("Package No.", '');
        TempSummary.SetFilter("Lot No.", '<>%1', '');
        TempSummary.SetFilter("Table ID", '<>%1', 0);
        TempSummary.SetFilter("Total Available Quantity", '>0');
        TempSummary.SetFilter("Total Quantity", '>0');
    end;

    local procedure FindNextLot(SalesLine: Record "Sales Line"; var TempSummary: Record "Entry Summary" temporary; var BestSummary: Record "Entry Summary" temporary; ItemTrackingCode: Record "Item Tracking Code"; PostingDate: Date): Boolean
    var
        LotInfo: Record "Lot No. Information";
        Found: Boolean;
        Eligible: Boolean;
        AvailableQty: Decimal;
    begin
        if TempSummary.FindSet() then
            repeat
                Eligible := true;
                if ItemTrackingCode."Strict Expiration Posting" and (TempSummary."Expiration Date" <> 0D) then
                    Eligible := TempSummary."Expiration Date" >= PostingDate;
                // Lot information is optional, but its Blocked flag must be respected.
                if LotInfo.Get(SalesLine."No.", SalesLine."Variant Code", TempSummary."Lot No.") then
                    Eligible := Eligible and not LotInfo.Blocked;
                AvailableQty := TempSummary."Total Available Quantity";
                if TempSummary."Bin Active" then
                    AvailableQty := MinQty(AvailableQty, TempSummary.QtyAvailableToSelectFromBin());
                // Match standard AutoSelectTrackingNo: nonspecific firm reservations
                // must not be consumed by another order's automatic lot assignment.
                AvailableQty -= TempSummary."Non-specific Reserved Qty.";
                Eligible := Eligible and (AvailableQty > 0);
                if Eligible then
                    if (not Found) or EarlierLot(TempSummary, BestSummary) then begin
                        BestSummary := TempSummary;
                        BestSummary."Total Available Quantity" := AvailableQty;
                        Found := true;
                    end;
            until TempSummary.Next() = 0;
        exit(Found);
    end;

    local procedure EarlierLot(Candidate: Record "Entry Summary" temporary; Best: Record "Entry Summary" temporary): Boolean
    begin
        if Candidate."Expiration Date" <> Best."Expiration Date" then begin
            if Candidate."Expiration Date" = 0D then
                exit(false);
            if Best."Expiration Date" = 0D then
                exit(true);
            exit(Candidate."Expiration Date" < Best."Expiration Date");
        end;
        if Candidate."Lot No." <> Best."Lot No." then
            exit(Candidate."Lot No." < Best."Lot No.");
        exit(Candidate."Entry No." < Best."Entry No.");
    end;

    local procedure CreateLotTracking(SalesLine: Record "Sales Line"; Summary: Record "Entry Summary" temporary; QtyBase: Decimal)
    var
        Tracking: Record "Reservation Entry";
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
        EntryStatus: Enum "Reservation Status";
    begin
        Tracking."Lot No." := Summary."Lot No.";
        CreateReservEntry.CreateReservEntryFor(Database::"Sales Line", SalesLine."Document Type".AsInteger(),
            SalesLine."Document No.", '', 0, SalesLine."Line No.", SalesLine."Qty. per Unit of Measure", 0, QtyBase, Tracking);
        CreateReservEntry.SetDates(Summary."Warranty Date", Summary."Expiration Date");
        // Keep the standard defaults for unhandled tracking: both quantities equal
        // the assigned base quantity (Tracking Specification.InitQtyToShip). Setting
        // handle quantity to zero here would hide the demand from lot availability.
        EntryStatus := EntryStatus::Prospect;
        if ItemTrackingManagement.IsOrderNetworkEntity(Database::"Sales Line", SalesLine."Document Type".AsInteger()) then
            EntryStatus := EntryStatus::Surplus;
        CreateReservEntry.CreateEntry(SalesLine."No.", SalesLine."Variant Code", SalesLine."Location Code",
            SalesLine.Description, 0D, SalesLine."Shipment Date", 0, EntryStatus);
    end;

    local procedure GetPostingDate(SalesLine: Record "Sales Line"): Date
    var
        SalesHeader: Record "Sales Header";
    begin
        if SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
            if SalesHeader."Posting Date" <> 0D then
                exit(SalesHeader."Posting Date");
        exit(WorkDate());
    end;

    local procedure MinQty(First: Decimal; Second: Decimal): Decimal
    begin
        if Second < 0 then
            exit(0);
        if First < Second then
            exit(First);
        exit(Second);
    end;
}
