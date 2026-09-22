namespace DefaultPublisher.ShopifyUOMCorrection;

using Microsoft.Foundation.UOM;
using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;

/// <summary>
/// Sets the Unit of Measure Code on Shopify order lines from the unit the customer picked in Shopify.
/// The Shopify Connector only reads the UoM from a variant option when the shop has "UoM as Variant" set up;
/// otherwise it falls back to the item's Sales Unit of Measure. The chosen unit still shows up in the
/// line's Variant Description (e.g. "Pcs" or "Box (10 pcs)"), so this reads it from there.
/// </summary>
codeunit 50141 ShopifyUOMCorrection
{
    var
        NoOrdersSelectedMsg: Label 'No Shopify orders are selected.';
        SummaryMsg: Label 'Unit of measure check finished for %1 Shopify order(s).\\Lines corrected: %2\Lines already correct: %3\Lines with no unit of measure in the variant description: %4', Comment = '%1 = number of orders, %2 = corrected lines, %3 = correct lines, %4 = lines without a recognisable unit';
        ChangesHeaderTxt: Label 'Corrected:', Locked = true;
        UnmatchedHeaderTxt: Label 'No unit of measure recognised in:', Locked = true;
        AmbiguousHeaderTxt: Label 'Skipped, variant description matches more than one unit of measure:', Locked = true;
        ProcessedHeaderTxt: Label 'Skipped, a sales document already exists (change the unit there instead):', Locked = true;
        ChangeLineTxt: Label '%1 %2: %3 -> %4', Comment = '%1 = Shopify order no., %2 = item no., %3 = old unit, %4 = new unit', Locked = true;
        LineTxt: Label '%1 %2: "%3"', Comment = '%1 = Shopify order no., %2 = item no., %3 = variant description', Locked = true;
        OrderTxt: Label '%1', Comment = '%1 = Shopify order no.', Locked = true;

    /// <summary>
    /// Corrects the unit of measure on all lines of the given Shopify orders and shows a summary.
    /// Orders that already have a sales document are skipped.
    /// </summary>
    procedure CorrectUnitOfMeasure(var ShopifyOrderHeader: Record "Shpfy Order Header")
    var
        Changes: TextBuilder;
        Unmatched: TextBuilder;
        Ambiguous: TextBuilder;
        ProcessedOrders: TextBuilder;
        OrderCount: Integer;
        ChangedCount: Integer;
        CorrectCount: Integer;
        UnmatchedCount: Integer;
    begin
        if not ShopifyOrderHeader.FindSet() then begin
            if GuiAllowed() then
                Message(NoOrdersSelectedMsg);
            exit;
        end;

        repeat
            OrderCount += 1;
            if HasSalesDocument(ShopifyOrderHeader) then
                ProcessedOrders.AppendLine(StrSubstNo(OrderTxt, ShopifyOrderHeader."Shopify Order No."))
            else
                CorrectOrderLines(ShopifyOrderHeader, Changes, Unmatched, Ambiguous, ChangedCount, CorrectCount, UnmatchedCount);
        until ShopifyOrderHeader.Next() = 0;

        if GuiAllowed() then
            Message(BuildSummary(OrderCount, ChangedCount, CorrectCount, UnmatchedCount, Changes, Unmatched, Ambiguous, ProcessedOrders));
    end;

    local procedure CorrectOrderLines(ShopifyOrderHeader: Record "Shpfy Order Header"; var Changes: TextBuilder; var Unmatched: TextBuilder; var Ambiguous: TextBuilder; var ChangedCount: Integer; var CorrectCount: Integer; var UnmatchedCount: Integer)
    var
        ShopifyOrderLine: Record "Shpfy Order Line";
        UnitOfMeasureCode: Code[10];
        OldUnitOfMeasureCode: Code[10];
        MatchCount: Integer;
    begin
        ShopifyOrderLine.SetRange("Shopify Order Id", ShopifyOrderHeader."Shopify Order Id");
        ShopifyOrderLine.SetRange(Tip, false);
        ShopifyOrderLine.SetRange("Gift Card", false);
        ShopifyOrderLine.SetFilter("Item No.", '<>%1', '');
        if not ShopifyOrderLine.FindSet(true) then
            exit;

        repeat
            MatchCount := FindUnitOfMeasureInVariantDescription(ShopifyOrderLine."Item No.", ShopifyOrderLine."Variant Description", UnitOfMeasureCode);
            case true of
                MatchCount = 0:
                    begin
                        UnmatchedCount += 1;
                        if ShopifyOrderLine."Variant Description" <> '' then
                            Unmatched.AppendLine(StrSubstNo(LineTxt, ShopifyOrderHeader."Shopify Order No.", ShopifyOrderLine."Item No.", ShopifyOrderLine."Variant Description"));
                    end;
                MatchCount > 1:
                    Ambiguous.AppendLine(StrSubstNo(LineTxt, ShopifyOrderHeader."Shopify Order No.", ShopifyOrderLine."Item No.", ShopifyOrderLine."Variant Description"));
                UnitOfMeasureCode = ShopifyOrderLine."Unit of Measure Code":
                    CorrectCount += 1;
                else begin
                    OldUnitOfMeasureCode := ShopifyOrderLine."Unit of Measure Code";
                    ShopifyOrderLine.Validate("Unit of Measure Code", UnitOfMeasureCode);
                    ShopifyOrderLine.Modify(true);
                    ChangedCount += 1;
                    Changes.AppendLine(StrSubstNo(ChangeLineTxt, ShopifyOrderHeader."Shopify Order No.", ShopifyOrderLine."Item No.", OldUnitOfMeasureCode, UnitOfMeasureCode));
                end;
            end;
        until ShopifyOrderLine.Next() = 0;
    end;

    /// <summary>
    /// Looks for one of the item's units of measure in a Shopify variant description.
    /// The description is split into its options ("Box (10 pcs) / Sterile" -> "Box (10 pcs)", "Sterile"), and each
    /// option is compared, as a whole and by its first word, against the item's unit of measure codes and descriptions.
    /// So "Pcs" matches PCS and "Box (10 pcs)" matches BOX, while "6cm x 10cm" matches nothing.
    /// </summary>
    /// <returns>The number of distinct units found; UnitOfMeasureCode is only meaningful when this is 1.</returns>
    local procedure FindUnitOfMeasureInVariantDescription(ItemNo: Code[20]; VariantDescription: Text; var UnitOfMeasureCode: Code[10]) MatchCount: Integer
    var
        RawOption: Text;
        Option: Text;
        FirstWord: Text;
    begin
        UnitOfMeasureCode := '';
        foreach RawOption in VariantDescription.Split('/') do begin
            Option := RawOption.Trim();
            if Option <> '' then begin
                MatchCandidate(ItemNo, Option, UnitOfMeasureCode, MatchCount);
                FirstWord := Option.Split(' ', '(').Get(1).Trim();
                if FirstWord <> Option then
                    MatchCandidate(ItemNo, FirstWord, UnitOfMeasureCode, MatchCount);
            end;
        end;
    end;

    local procedure MatchCandidate(ItemNo: Code[20]; Candidate: Text; var UnitOfMeasureCode: Code[10]; var MatchCount: Integer)
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        UnitOfMeasure: Record "Unit of Measure";
    begin
        if Candidate = '' then
            exit;

        if StrLen(Candidate) <= MaxStrLen(ItemUnitOfMeasure.Code) then
            if ItemUnitOfMeasure.Get(ItemNo, UpperCase(Candidate)) then begin
                RegisterMatch(ItemUnitOfMeasure.Code, UnitOfMeasureCode, MatchCount);
                exit;
            end;

        ItemUnitOfMeasure.SetRange("Item No.", ItemNo);
        if ItemUnitOfMeasure.FindSet() then
            repeat
                if UnitOfMeasure.Get(ItemUnitOfMeasure.Code) then
                    if (UnitOfMeasure.Description <> '') and (LowerCase(UnitOfMeasure.Description) = LowerCase(Candidate)) then
                        RegisterMatch(ItemUnitOfMeasure.Code, UnitOfMeasureCode, MatchCount);
            until ItemUnitOfMeasure.Next() = 0;
    end;

    local procedure RegisterMatch(FoundCode: Code[10]; var UnitOfMeasureCode: Code[10]; var MatchCount: Integer)
    begin
        if FoundCode = UnitOfMeasureCode then
            exit;
        MatchCount += 1;
        if MatchCount = 1 then
            UnitOfMeasureCode := FoundCode;
    end;

    local procedure HasSalesDocument(ShopifyOrderHeader: Record "Shpfy Order Header"): Boolean
    begin
        exit(ShopifyOrderHeader.Processed or (ShopifyOrderHeader."Sales Order No." <> '') or (ShopifyOrderHeader."Sales Invoice No." <> ''));
    end;

    local procedure BuildSummary(OrderCount: Integer; ChangedCount: Integer; CorrectCount: Integer; UnmatchedCount: Integer; Changes: TextBuilder; Unmatched: TextBuilder; Ambiguous: TextBuilder; ProcessedOrders: TextBuilder): Text
    var
        Summary: TextBuilder;
    begin
        Summary.Append(StrSubstNo(SummaryMsg, OrderCount, ChangedCount, CorrectCount, UnmatchedCount));
        AppendSection(Summary, ChangesHeaderTxt, Changes);
        AppendSection(Summary, AmbiguousHeaderTxt, Ambiguous);
        AppendSection(Summary, ProcessedHeaderTxt, ProcessedOrders);
        AppendSection(Summary, UnmatchedHeaderTxt, Unmatched);
        exit(Summary.ToText());
    end;

    local procedure AppendSection(var Summary: TextBuilder; Header: Text; Section: TextBuilder)
    begin
        if Section.Length() = 0 then
            exit;
        Summary.AppendLine();
        Summary.AppendLine();
        Summary.AppendLine(Header);
        Summary.Append(Section.ToText());
    end;
}
