codeunit 50113 BulkAssignFefoLotsMgt
{
    procedure AssignFefoLotsToUnpostedOrders()
    begin
        AssignFefoLotsToUnposted(Enum::"Sales Document Type"::Order, 'unposted sales order(s)');
    end;

    procedure AssignFefoLotsToUnpostedInvoices()
    begin
        AssignFefoLotsToUnposted(Enum::"Sales Document Type"::Invoice, 'unposted sales invoice(s)');
    end;

    // SelectedHeader is expected to come from CurrPage.SetSelectionFilter, i.e. it already
    // carries a filter narrowing it down to the records the user highlighted on the page.
    procedure AssignFefoLotsToSelectedOrders(var SelectedHeader: Record "Sales Header")
    begin
        AssignFefoLotsToSelected(SelectedHeader, 'selected sales order(s)');
    end;

    procedure AssignFefoLotsToSelectedInvoices(var SelectedHeader: Record "Sales Header")
    begin
        AssignFefoLotsToSelected(SelectedHeader, 'selected sales invoice(s)');
    end;

    procedure DeleteReserveEntriesForSelectedOrders(var SelectedHeader: Record "Sales Header")
    begin
        DeleteReserveEntriesForSelected(SelectedHeader, 'selected sales order(s)');
    end;

    procedure DeleteReserveEntriesForSelectedInvoices(var SelectedHeader: Record "Sales Header")
    begin
        DeleteReserveEntriesForSelected(SelectedHeader, 'selected sales invoice(s)');
    end;

    local procedure AssignFefoLotsToUnposted(DocumentType: Enum "Sales Document Type"; DocTypeCaption: Text)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReserveHelper: Codeunit ReserveEntriesHelper;
        ProcessedNos: List of [Code[20]];
        AllShortages: Text;
        DocShortage: Text;
        TotalCount: Integer;
        Window: Dialog;
    begin
        SalesHeader.SetRange("Document Type", DocumentType);
        TotalCount := SalesHeader.Count();
        if TotalCount = 0 then begin
            Message('There are no %1.', DocTypeCaption);
            exit;
        end;

        if not Confirm('This will assign FEFO lot reservations to all %1 %2, processed oldest to newest by Order Date. Continue?', false, TotalCount, DocTypeCaption) then
            exit;

        Window.Open('Assigning FEFO lots to document #1##########\Progress: @2@@@@@@@@@@@@@@@@@@@@');
        while FindNextHeaderByDate(SalesHeader, DocumentType, ProcessedNos) do begin
            ProcessedNos.Add(SalesHeader."No.");
            Window.Update(1, SalesHeader."No.");
            Window.Update(2, Round(ProcessedNos.Count() / TotalCount * 10000, 1));

            Clear(SalesLine);
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            DocShortage := ReserveHelper.AssignFefoLots(SalesLine);
            if DocShortage <> '' then
                AllShortages += StrSubstNo('\Document %1:%2', SalesHeader."No.", DocShortage);
        end;
        Window.Close();

        if AllShortages <> '' then
            Message('FEFO lot assignment completed for %1 %2.\Some lines could not be fully reserved due to insufficient stock:%3', ProcessedNos.Count(), DocTypeCaption, AllShortages)
        else
            Message('FEFO lot assignment completed for %1 %2.', ProcessedNos.Count(), DocTypeCaption);
    end;

    local procedure AssignFefoLotsToSelected(var SelectedHeader: Record "Sales Header"; DocTypeCaption: Text)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ReserveHelper: Codeunit ReserveEntriesHelper;
        ProcessedNos: List of [Code[20]];
        AllShortages: Text;
        DocShortage: Text;
        TotalCount: Integer;
        Window: Dialog;
    begin
        TotalCount := SelectedHeader.Count();
        if TotalCount = 0 then begin
            Message('No %1 selected.', DocTypeCaption);
            exit;
        end;

        if not Confirm('This will assign FEFO lot reservations to %1 %2, processed oldest to newest by Order Date. Continue?', false, TotalCount, DocTypeCaption) then
            exit;

        Window.Open('Assigning FEFO lots to document #1##########\Progress: @2@@@@@@@@@@@@@@@@@@@@');
        while FindNextSelectedHeaderByDate(SelectedHeader, SalesHeader, ProcessedNos) do begin
            ProcessedNos.Add(SalesHeader."No.");
            Window.Update(1, SalesHeader."No.");
            Window.Update(2, Round(ProcessedNos.Count() / TotalCount * 10000, 1));

            Clear(SalesLine);
            SalesLine."Document Type" := SalesHeader."Document Type";
            SalesLine."Document No." := SalesHeader."No.";
            DocShortage := ReserveHelper.AssignFefoLots(SalesLine);
            if DocShortage <> '' then
                AllShortages += StrSubstNo('\Document %1:%2', SalesHeader."No.", DocShortage);
        end;
        Window.Close();

        if AllShortages <> '' then
            Message('FEFO lot assignment completed for %1 %2.\Some lines could not be fully reserved due to insufficient stock:%3', ProcessedNos.Count(), DocTypeCaption, AllShortages)
        else
            Message('FEFO lot assignment completed for %1 %2.', ProcessedNos.Count(), DocTypeCaption);
    end;

    local procedure DeleteReserveEntriesForSelected(var SelectedHeader: Record "Sales Header"; DocTypeCaption: Text)
    var
        SalesLine: Record "Sales Line";
        ReserveHelper: Codeunit ReserveEntriesHelper;
        TotalCount: Integer;
        ProcessedCount: Integer;
        Window: Dialog;
    begin
        TotalCount := SelectedHeader.Count();
        if TotalCount = 0 then begin
            Message('No %1 selected.', DocTypeCaption);
            exit;
        end;

        if not Confirm('This will delete all lot reservation entries for %1 %2. Continue?', false, TotalCount, DocTypeCaption) then
            exit;

        Window.Open('Deleting reservation entries for document #1##########\Progress: @2@@@@@@@@@@@@@@@@@@@@');
        if SelectedHeader.FindSet() then
            repeat
                ProcessedCount += 1;
                Window.Update(1, SelectedHeader."No.");
                Window.Update(2, Round(ProcessedCount / TotalCount * 10000, 1));

                Clear(SalesLine);
                SalesLine."Document Type" := SelectedHeader."Document Type";
                SalesLine."Document No." := SelectedHeader."No.";
                ReserveHelper.DeleteReserveEntries(SalesLine);
            until SelectedHeader.Next() = 0;
        Window.Close();

        Message('Reservation entries deleted for %1 %2.', ProcessedCount, DocTypeCaption);
    end;

    // Picks the unposted document (not already processed) with the earliest Order Date,
    // falling back to "No." as a tie-breaker. Avoids SetCurrentKey/SetAscending on "Order Date",
    // which is not part of any key on Sales Header and would error.
    local procedure FindNextHeaderByDate(var BestHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; ProcessedNos: List of [Code[20]]): Boolean
    var
        Candidate: Record "Sales Header";
        Found: Boolean;
    begin
        Candidate.SetRange("Document Type", DocumentType);

        Found := false;
        if Candidate.FindSet() then
            repeat
                if not ProcessedNos.Contains(Candidate."No.") then
                    if (not Found)
                       or (Candidate."Order Date" < BestHeader."Order Date")
                       or ((Candidate."Order Date" = BestHeader."Order Date") and (Candidate."No." < BestHeader."No."))
                    then begin
                        BestHeader := Candidate;
                        Found := true;
                    end;
            until Candidate.Next() = 0;

        exit(Found);
    end;

    // Same as FindNextHeaderByDate, but iterates SelectedHeader directly instead of a
    // re-filtered Candidate. CurrPage.SetSelectionFilter marks the selected records via
    // Mark/MarkedOnly, which CopyFilters does not carry over to another record variable -
    // only FindSet/Next on SelectedHeader itself respects that selection.
    local procedure FindNextSelectedHeaderByDate(var SelectedHeader: Record "Sales Header"; var BestHeader: Record "Sales Header"; ProcessedNos: List of [Code[20]]): Boolean
    var
        Found: Boolean;
    begin
        Found := false;
        if SelectedHeader.FindSet() then
            repeat
                if not ProcessedNos.Contains(SelectedHeader."No.") then
                    if (not Found)
                       or (SelectedHeader."Order Date" < BestHeader."Order Date")
                       or ((SelectedHeader."Order Date" = BestHeader."Order Date") and (SelectedHeader."No." < BestHeader."No."))
                    then begin
                        BestHeader := SelectedHeader;
                        Found := true;
                    end;
            until SelectedHeader.Next() = 0;

        exit(Found);
    end;
}
