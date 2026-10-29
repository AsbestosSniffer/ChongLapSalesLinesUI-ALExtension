#if FEFO_TESTS
// Compile only with /define:FEFO_TESTS. Synthetic fixtures are rolled back by the
// test runner; never run this package against production data.
codeunit 50149 "FEFO Assignment Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    [Test]
    procedure AssignmentUpdatesStandardTotals()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        Entry: Record "Reservation Entry";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        Assign(Line, 0);
        AssertTotals(Line, 'LOT-A', 20, 80);
        FilterEntries(Entry, Line);
        AssertEqual(1, Entry.Count(), 'One demand entry');
        Entry.FindFirst();
        Entry.TestField(Positive, false);
        Entry.TestField("Reservation Status", Entry."Reservation Status"::Surplus);
        Entry.TestField("Item Tracking", Entry."Item Tracking"::"Lot No.");
        Entry.TestField("Quantity (Base)", -20);
        Entry.TestField(Quantity, -20);
        Entry.TestField("Qty. to Handle (Base)", -20);
        Entry.TestField("Qty. to Invoice (Base)", -20);
        Entry.TestField("Expiration Date", WorkDate() + 30);
        Entry.Reset();
        Entry.SetRange("Item No.", Item."No.");
        Entry.SetRange(Positive, true);
        AssertEqual(0, Entry.Count(), 'No fabricated supply entry');
    end;

    [Test]
    procedure CompetingOrdersCannotReuseAssignedStock()
    var
        Item: Record Item;
        FirstLine: Record "Sales Line";
        SecondLine: Record "Sales Line";
    begin
        Fixture(Item, FirstLine, 80, Enum::"Sales Document Type"::Order);
        AddInventory(FirstLine, 'LOT-A', 100, WorkDate() + 30);
        CreateSalesLine(Item, SecondLine, 50, Enum::"Sales Document Type"::Order);
        Assign(FirstLine, 0);
        Assign(SecondLine, 30);
        AssertTotals(SecondLine, 'LOT-A', 100, 0);
        AssertLotQty(SecondLine, 'LOT-A', -20);
    end;

    [Test]
    procedure ReceiptsForOneLotAreAggregatedAndSplitAcrossLots()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        Entry: Record "Reservation Entry";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'EARLY', 8, WorkDate() + 10);
        AddInventory(Line, 'EARLY', 7, WorkDate() + 10);
        AddInventory(Line, 'LATE', 20, WorkDate() + 20);
        Assign(Line, 0);
        AssertLotQty(Line, 'EARLY', -15);
        AssertLotQty(Line, 'LATE', -5);
        FilterEntries(Entry, Line);
        AssertEqual(2, Entry.Count(), 'One entry per selected lot');
    end;

    [Test]
    procedure FefoUsesExpirationThenLotAndBlankDatesLast()
    var
        Item: Record Item;
        Line: Record "Sales Line";
    begin
        Fixture(Item, Line, 2, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'BLANK', 20, 0D);
        AddInventory(Line, 'Z-EARLY', 1, WorkDate() + 10);
        AddInventory(Line, 'A-EARLY', 1, WorkDate() + 10);
        AddInventory(Line, 'A-LATE', 20, WorkDate() + 20);
        Assign(Line, 0);
        AssertLotQty(Line, 'A-EARLY', -1);
        AssertLotQty(Line, 'Z-EARLY', -1);
        AssertLotQty(Line, 'A-LATE', 0);
        AssertLotQty(Line, 'BLANK', 0);
        SetQuantity(Line, 1);
        Assign(Line, 0);
        AssertLotQty(Line, 'A-EARLY', -1);
    end;

    [Test]
    procedure ReassignmentAndDeletionAreScopedAndIdempotent()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        OtherLine: Record "Sales Line";
        Helper: Codeunit ReserveEntriesHelper;
        Details: Text;
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        CreateSalesLine(Item, OtherLine, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        Assign(Line, 0);
        Assign(OtherLine, 0);
        Assign(Line, 0);
        AssertTotals(Line, 'LOT-A', 40, 60);
        Details := Helper.DeleteLotTracking(Line);
        AssertLotQty(Line, 'LOT-A', 0);
        AssertLotQty(OtherLine, 'LOT-A', -20);
        AssertTotals(OtherLine, 'LOT-A', 20, 80);
        Details := Helper.DeleteLotTracking(Line);
        AssertTotals(OtherLine, 'LOT-A', 20, 80);
    end;

    [Test]
    procedure AlternateUnitsPreserveBaseQuantities()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        Entry: Record "Reservation Entry";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        Line."Qty. per Unit of Measure" := 10;
        Line.Quantity := 2;
        Line."Outstanding Quantity" := 2;
        Line."Qty. to Ship" := 2;
        Line."Qty. to Invoice" := 2;
        Line.Modify();
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        Assign(Line, 0);
        FilterEntries(Entry, Line);
        Entry.FindFirst();
        Entry.TestField("Qty. per Unit of Measure", 10);
        Entry.TestField(Quantity, -2);
        Entry.TestField("Quantity (Base)", -20);
        AssertTotals(Line, 'LOT-A', 20, 80);
    end;

    [Test]
    procedure FirmReservationsArePreserved()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        Demand: Record "Reservation Entry";
        Supply: Record "Reservation Entry";
        Helper: Codeunit ReserveEntriesHelper;
        Details: Text;
        LedgerNo: Integer;
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        LedgerNo := AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        ManualAssignment(Line, 'LOT-A', 20, WorkDate() + 30);
        FilterEntries(Demand, Line);
        Demand.FindFirst();
        Demand."Reservation Status" := Demand."Reservation Status"::Reservation;
        Demand.Modify();
        Supply := Demand;
        Supply.Positive := true;
        Supply."Quantity (Base)" := 20;
        Supply.Quantity := 20;
        Supply."Qty. to Handle (Base)" := 20;
        Supply."Qty. to Invoice (Base)" := 20;
        Supply.SetSource(Database::"Item Ledger Entry", 0, '', LedgerNo, '', 0);
        Supply.Insert();
        AssertSkipped(Line, 'firm reservation');
        Details := Helper.DeleteLotTracking(Line);
        Demand.Get(Demand."Entry No.", false);
        Supply.Get(Supply."Entry No.", true);
        Demand.TestField("Quantity (Base)", -20);
        Supply.TestField("Quantity (Base)", 20);
    end;

    [Test]
    procedure MalformedLegacyEntriesRequireAuditWithoutChangingData()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        OtherLine: Record "Sales Line";
        Entry: Record "Reservation Entry";
        Helper: Codeunit ReserveEntriesHelper;
        Details: Text;
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        ManualAssignment(Line, 'LOT-A', 20, WorkDate() + 30);
        FilterEntries(Entry, Line);
        Entry.FindFirst();
        Entry."Item Tracking" := Entry."Item Tracking"::None;
        Entry.Modify();
        AssertSkipped(Line, 'inconsistent item tracking');
        CreateSalesLine(Item, OtherLine, 20, Enum::"Sales Document Type"::Order);
        AssertSkipped(OtherLine, 'inconsistent item tracking'); // Do not ignore another document's invisible demand.
        Details := Helper.AuditLotTracking(Line);
        if StrPos(Details, 'inconsistent item tracking') = 0 then
            Error('Expected an audit finding, received: %1', Details);
        Details := Helper.DeleteLotTracking(Line);
        Entry.Get(Entry."Entry No.", false);
        Entry.TestField("Item Tracking", Entry."Item Tracking"::None);
        Entry.TestField("Quantity (Base)", -20);
    end;

    [Test]
    procedure WarehouseAndPostedLinesArePreserved()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        WhseLine: Record "Warehouse Shipment Line";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        ManualAssignment(Line, 'LOT-A', 20, WorkDate() + 30);
        WhseLine."No." := Line."Document No.";
        WhseLine."Line No." := Line."Line No.";
        WhseLine."Source Type" := Database::"Sales Line";
        WhseLine."Source Subtype" := Line."Document Type".AsInteger();
        WhseLine."Source No." := Line."Document No.";
        WhseLine."Source Line No." := Line."Line No.";
        WhseLine.Insert();
        AssertSkipped(Line, 'warehouse shipment');
        AssertLotQty(Line, 'LOT-A', -20);
        WhseLine.Delete();
        Line."Quantity Shipped" := 1;
        Line.Modify();
        AssertSkipped(Line, 'posted shipment');
        AssertLotQty(Line, 'LOT-A', -20);
    end;

    [Test]
    procedure InvoiceTrackingUsesStandardProspectStatusAndExactSource()
    var
        Item: Record Item;
        OrderLine: Record "Sales Line";
        InvoiceLine: Record "Sales Line";
        InvoiceHeader: Record "Sales Header";
        Entry: Record "Reservation Entry";
        Helper: Codeunit ReserveEntriesHelper;
        Details: Text;
    begin
        Fixture(Item, OrderLine, 20, Enum::"Sales Document Type"::Order);
        AddInventory(OrderLine, 'LOT-A', 100, WorkDate() + 30);
        // Deliberately reuse the document and line numbers across document types.
        InvoiceHeader."Document Type" := InvoiceHeader."Document Type"::Invoice;
        InvoiceHeader."No." := OrderLine."Document No.";
        InvoiceHeader."Posting Date" := WorkDate();
        InvoiceHeader.Insert();
        InvoiceLine := OrderLine;
        InvoiceLine."Document Type" := InvoiceLine."Document Type"::Invoice;
        InvoiceLine.Insert();
        Assign(OrderLine, 0);
        Assign(InvoiceLine, 0);
        FilterEntries(Entry, InvoiceLine);
        Entry.FindFirst();
        Entry.TestField("Reservation Status", Entry."Reservation Status"::Prospect);
        Details := Helper.DeleteLotTracking(InvoiceLine);
        AssertLotQty(InvoiceLine, 'LOT-A', 0);
        AssertLotQty(OrderLine, 'LOT-A', -20);
    end;

    [Test]
    procedure StrictExpirationAndBlockedLotsAreExcluded()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        TrackingCode: Record "Item Tracking Code";
        LotInfo: Record "Lot No. Information";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        TrackingCode.Get(Item."Item Tracking Code");
        TrackingCode."Strict Expiration Posting" := true;
        TrackingCode.Modify();
        AddInventory(Line, 'EXPIRED', 20, WorkDate() - 1);
        AddInventory(Line, 'BLOCKED', 20, WorkDate() + 1);
        AddInventory(Line, 'VALID', 20, WorkDate() + 30);
        LotInfo."Item No." := Item."No.";
        LotInfo."Lot No." := 'BLOCKED';
        LotInfo.Blocked := true;
        LotInfo.Insert();
        Assign(Line, 0);
        AssertLotQty(Line, 'VALID', -20);
        AssertLotQty(Line, 'EXPIRED', 0);
        AssertLotQty(Line, 'BLOCKED', 0);
    end;

    [Test]
    procedure ZeroQuantityClearsTrackingAndNegativeQuantityIsSkipped()
    var
        Item: Record Item;
        Line: Record "Sales Line";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        Assign(Line, 0);
        SetQuantity(Line, 0);
        Assign(Line, 0);
        AssertLotQty(Line, 'LOT-A', 0);
        SetQuantity(Line, -1);
        AssertSkipped(Line, 'negative sales quantities');
        AssertLotQty(Line, 'LOT-A', 0);
    end;

    [Test]
    procedure StandardManualCreationAndFefoProduceSameTotals()
    var
        Item: Record Item;
        ManualLine: Record "Sales Line";
        FefoLine: Record "Sales Line";
        Helper: Codeunit ReserveEntriesHelper;
        Details: Text;
    begin
        Fixture(Item, ManualLine, 20, Enum::"Sales Document Type"::Order);
        AddInventory(ManualLine, 'LOT-A', 100, WorkDate() + 30);
        ManualAssignment(ManualLine, 'LOT-A', 20, WorkDate() + 30);
        AssertTotals(ManualLine, 'LOT-A', 20, 80);
        Details := Helper.DeleteLotTracking(ManualLine);
        CreateSalesLine(Item, FefoLine, 20, Enum::"Sales Document Type"::Order);
        Assign(FefoLine, 0);
        AssertTotals(FefoLine, 'LOT-A', 20, 80);
    end;

    [Test]
    procedure NonspecificFirmReservationsReduceAutomaticAvailability()
    var
        Item: Record Item;
        ReservedLine: Record "Sales Line";
        Line: Record "Sales Line";
        Demand: Record "Reservation Entry";
        Supply: Record "Reservation Entry";
        CreateEntry: Codeunit "Create Reserv. Entry";
        LedgerNo: Integer;
    begin
        Fixture(Item, ReservedLine, 80, Enum::"Sales Document Type"::Order);
        LedgerNo := AddInventory(ReservedLine, 'LOT-A', 100, WorkDate() + 30);
        CreateEntry.CreateReservEntryFor(Database::"Sales Line", ReservedLine."Document Type".AsInteger(),
            ReservedLine."Document No.", '', 0, ReservedLine."Line No.", 1, 0, 80, Demand);
        CreateEntry.CreateEntry(Item."No.", '', '', '', 0D, WorkDate(), 0, Enum::"Reservation Status"::Surplus);
        CreateEntry.GetLastEntry(Demand);
        Demand."Reservation Status" := Demand."Reservation Status"::Reservation;
        Demand.Modify();
        Supply := Demand;
        Supply.Positive := true;
        Supply."Quantity (Base)" := 80;
        Supply.Quantity := 80;
        Supply."Qty. to Handle (Base)" := 80;
        Supply."Qty. to Invoice (Base)" := 80;
        Supply.SetSource(Database::"Item Ledger Entry", 0, '', LedgerNo, '', 0);
        Supply.Insert();
        CreateSalesLine(Item, Line, 50, Enum::"Sales Document Type"::Order);
        Assign(Line, 30);
        AssertLotQty(Line, 'LOT-A', -20);
        Demand.Get(Demand."Entry No.", false);
        Demand.TestField("Quantity (Base)", -80);
    end;

    [Test]
    procedure OtherLocationsAndVariantsCannotFillShortage()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        OtherLine: Record "Sales Line";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        AddInventory(Line, 'LOT-A', 5, WorkDate() + 30);
        OtherLine := Line;
        OtherLine."Location Code" := 'OTHER';
        AddInventory(OtherLine, 'LOT-A', 100, WorkDate() + 1);
        OtherLine."Location Code" := '';
        OtherLine."Variant Code" := 'OTHER';
        AddInventory(OtherLine, 'LOT-A', 100, WorkDate() + 1);
        Assign(Line, 15);
        AssertLotQty(Line, 'LOT-A', -5);
        Line.TestField("Location Code", '');
        Line.TestField("Variant Code", '');
    end;

    [Test]
    procedure ZeroSourceShipQuantityDoesNotHideAssignedLotDemand()
    var
        Item: Record Item;
        Line: Record "Sales Line";
        Entry: Record "Reservation Entry";
    begin
        Fixture(Item, Line, 20, Enum::"Sales Document Type"::Order);
        Line."Qty. to Ship" := 0;
        Line."Qty. to Ship (Base)" := 0;
        Line."Qty. to Invoice" := 0;
        Line."Qty. to Invoice (Base)" := 0;
        Line.Modify();
        AddInventory(Line, 'LOT-A', 100, WorkDate() + 30);
        Assign(Line, 0);
        FilterEntries(Entry, Line);
        Entry.FindFirst();
        Entry.TestField("Qty. to Handle (Base)", -20);
        Entry.TestField("Qty. to Invoice (Base)", -20);
        AssertTotals(Line, 'LOT-A', 20, 80);
    end;

    local procedure Fixture(var Item: Record Item; var Line: Record "Sales Line"; Qty: Decimal; DocType: Enum "Sales Document Type")
    var
        TrackingCode: Record "Item Tracking Code";
        UnitOfMeasure: Record "Unit of Measure";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        TrackingCode.Code := CopyStr(NewNo(), 1, MaxStrLen(TrackingCode.Code));
        TrackingCode."Lot Specific Tracking" := true;
        TrackingCode."Use Expiration Dates" := true;
        TrackingCode.Insert();
        UnitOfMeasure.Code := CopyStr(NewNo(), 1, MaxStrLen(UnitOfMeasure.Code));
        UnitOfMeasure.Insert();
        Item."No." := NewNo();
        Item."Item Tracking Code" := TrackingCode.Code;
        Item."Base Unit of Measure" := UnitOfMeasure.Code;
        Item.Insert();
        ItemUnitOfMeasure."Item No." := Item."No.";
        ItemUnitOfMeasure.Code := UnitOfMeasure.Code;
        ItemUnitOfMeasure."Qty. per Unit of Measure" := 1;
        ItemUnitOfMeasure.Insert();
        CreateSalesLine(Item, Line, Qty, DocType);
    end;

    local procedure CreateSalesLine(Item: Record Item; var Line: Record "Sales Line"; Qty: Decimal; DocType: Enum "Sales Document Type")
    var
        Header: Record "Sales Header";
    begin
        Header."Document Type" := DocType;
        Header."No." := NewNo();
        Header."Posting Date" := WorkDate();
        Header.Insert();
        Line.Init();
        Line."Document Type" := DocType;
        Line."Document No." := Header."No.";
        Line."Line No." := 10000;
        Line.Type := Line.Type::Item;
        Line."No." := Item."No.";
        Line."Unit of Measure Code" := Item."Base Unit of Measure";
        Line."Qty. per Unit of Measure" := 1;
        Line."Qty. Rounding Precision (Base)" := 0.00001;
        Line."Shipment Date" := WorkDate();
        Line.Insert();
        SetQuantity(Line, Qty);
    end;

    local procedure SetQuantity(var Line: Record "Sales Line"; Qty: Decimal)
    begin
        // Bypass UI events in fixture setup; each test invokes the real service explicitly.
        Line.Quantity := Qty;
        Line."Quantity (Base)" := Qty;
        Line."Outstanding Quantity" := Qty;
        Line."Outstanding Qty. (Base)" := Qty;
        Line."Qty. to Ship" := Qty;
        Line."Qty. to Ship (Base)" := Qty;
        Line."Qty. to Invoice" := Qty;
        Line."Qty. to Invoice (Base)" := Qty;
        Line.Modify();
    end;

    local procedure AddInventory(Line: Record "Sales Line"; LotNo: Code[50]; Qty: Decimal; ExpirationDate: Date): Integer
    var
        Ledger: Record "Item Ledger Entry";
        EntryNo: Integer;
    begin
        // Synthetic inventory is sufficient to exercise the standard availability
        // collector; actual posting is covered separately by sandbox acceptance tests.
        Ledger.LockTable();
        if Ledger.FindLast() then
            EntryNo := Ledger."Entry No.";
        Ledger.Init();
        Ledger."Entry No." := EntryNo + 1;
        Ledger."Item No." := Line."No.";
        Ledger."Location Code" := Line."Location Code";
        Ledger."Variant Code" := Line."Variant Code";
        Ledger."Lot No." := LotNo;
        Ledger."Expiration Date" := ExpirationDate;
        Ledger."Posting Date" := WorkDate();
        Ledger.Quantity := Qty;
        Ledger."Remaining Quantity" := Qty;
        Ledger.Positive := true;
        Ledger.Open := true;
        Ledger.Insert();
        exit(Ledger."Entry No.");
    end;

    local procedure ManualAssignment(Line: Record "Sales Line"; LotNo: Code[50]; QtyBase: Decimal; ExpirationDate: Date)
    var
        Tracking: Record "Reservation Entry";
        CreateEntry: Codeunit "Create Reserv. Entry";
    begin
        Tracking."Lot No." := LotNo;
        CreateEntry.CreateReservEntryFor(Database::"Sales Line", Line."Document Type".AsInteger(),
            Line."Document No.", '', 0, Line."Line No.", Line."Qty. per Unit of Measure", 0, QtyBase, Tracking);
        CreateEntry.SetDates(0D, ExpirationDate);
        CreateEntry.CreateEntry(Line."No.", Line."Variant Code", Line."Location Code", '', 0D,
            Line."Shipment Date", 0, Enum::"Reservation Status"::Surplus);
    end;

    local procedure Assign(var Line: Record "Sales Line"; ExpectedShortage: Decimal)
    var
        Helper: Codeunit ReserveEntriesHelper;
        StatusText: Text;
        Skipped: Boolean;
        Shortage: Decimal;
    begin
        Shortage := Helper.AssignFefoLotsToLine(Line, StatusText, Skipped);
        if Skipped then
            Error('Unexpected skip: %1', StatusText);
        AssertEqual(ExpectedShortage, Shortage, StatusText);
    end;

    local procedure AssertSkipped(var Line: Record "Sales Line"; ExpectedReason: Text)
    var
        Helper: Codeunit ReserveEntriesHelper;
        StatusText: Text;
        Skipped: Boolean;
        Shortage: Decimal;
    begin
        Shortage := Helper.AssignFefoLotsToLine(Line, StatusText, Skipped);
        if not Skipped then
            Error('Expected a protected line to be skipped: %1', StatusText);
        if StrPos(StatusText, ExpectedReason) = 0 then
            Error('Expected skip reason "%1", received: %2', ExpectedReason, StatusText);
        AssertEqual(0, Shortage, 'A skip must not masquerade as a stock shortage');
    end;

    local procedure AssertTotals(Line: Record "Sales Line"; LotNo: Code[50]; Requested: Decimal; Available: Decimal)
    var
        Spec: Record "Tracking Specification" temporary;
        Summary: Record "Entry Summary" temporary;
        Reserve: Codeunit "Sales Line-Reserve";
        Collector: Codeunit "Item Tracking Data Collection";
    begin
        Reserve.InitFromSalesLine(Spec, Line);
        Collector.RetrieveLookupData(Spec, true);
        Collector.GetTempGlobalEntrySummary(Summary);
        Summary.SetRange("Lot No.", LotNo);
        Summary.SetRange("Serial No.", '');
        Summary.SetFilter("Table ID", '<>%1', 0);
        if not Summary.FindFirst() then
            Error('No standard availability summary for lot %1.', LotNo);
        AssertEqual(Requested, Summary."Total Requested Quantity", 'Standard requested total');
        AssertEqual(Available, Summary."Total Available Quantity", 'Standard available total');
    end;

    local procedure AssertLotQty(Line: Record "Sales Line"; LotNo: Code[50]; Qty: Decimal)
    var
        Entry: Record "Reservation Entry";
    begin
        FilterEntries(Entry, Line);
        Entry.SetRange("Lot No.", LotNo);
        Entry.CalcSums("Quantity (Base)");
        AssertEqual(Qty, Entry."Quantity (Base)", StrSubstNo('Lot %1 on %2', LotNo, Line."Document No."));
    end;

    local procedure FilterEntries(var Entry: Record "Reservation Entry"; Line: Record "Sales Line")
    begin
        Entry.Reset();
        Entry.SetSourceFilter(Database::"Sales Line", Line."Document Type".AsInteger(), Line."Document No.", Line."Line No.", false);
        Entry.SetSourceFilter('', 0);
    end;

    local procedure AssertEqual(Expected: Decimal; Actual: Decimal; Context: Text)
    begin
        if Expected <> Actual then
            Error('%1: expected %2, actual %3.', Context, Expected, Actual);
    end;

    local procedure NewNo(): Code[20]
    begin
        exit(CopyStr(DelChr(Format(CreateGuid()), '=', '{}-'), 1, 20));
    end;
}

codeunit 50148 "FEFO Test Runner"
{
    Subtype = TestRunner;
    TestIsolation = Function;

    var
        Failures: Text;
        TestsRun: Integer;

    trigger OnRun()
    begin
        Clear(Failures);
        TestsRun := 0;
        Codeunit.Run(Codeunit::"FEFO Assignment Tests");
        if Failures <> '' then
            Error('FEFO regression tests failed:%1', Failures);
        Message('%1 FEFO regression tests passed.', TestsRun);
    end;

    trigger OnAfterTestRun(CodeunitId: Integer; CodeunitName: Text; FunctionName: Text; Permissions: TestPermissions; Success: Boolean)
    begin
        if FunctionName = '' then
            exit;
        TestsRun += 1;
        if not Success then
            Failures += StrSubstNo('\%1: %2', FunctionName, GetLastErrorText());
    end;
}
#endif
