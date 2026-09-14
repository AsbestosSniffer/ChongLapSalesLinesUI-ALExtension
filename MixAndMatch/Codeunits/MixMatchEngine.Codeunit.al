namespace DefaultPublisher.MixAndMatch;

using Microsoft.Inventory.Item;
using Microsoft.Sales.Document;

codeunit 50150 "Mix Match Engine"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        SetCodeByItem: Dictionary of [Code[20], Code[20]];
        SummaryText: Text;
        TrackedLineChanged: Boolean;
        WrongDocumentTypeTxt: Label 'Mix & Match only applies to sales quotes, orders and invoices.';
        NotOpenTxt: Label 'Mix & Match was not applied because %1 %2 is not open.', Comment = '%1 = document type, %2 = document no.';
        ShopifyOrderTxt: Label 'Mix & Match was not applied because this document came from Shopify and keeps its Shopify pricing.';
        PartlyPostedTxt: Label 'Mix & Match was not applied because part of this document has already been shipped, invoiced or prepaid.';
        ExcludedTxt: Label 'This document is excluded from Mix & Match, so no Mix & Match discounts or free goods apply.';
        NoSetsTxt: Label 'None of the items on this document are in an active Mix & Match set.';
        OverrideSummaryTxt: Label 'Goods subtotal %1 (LCY) is at or above %2, so set items get their set''s highest discount.', Comment = '%1 = goods subtotal, %2 = threshold';
        SetSummaryTxt: Label 'Set %1: %2 units', Comment = '%1 = set code, %2 = qualifying quantity';
        NoTierSummaryTxt: Label ', no tier reached';
        DiscountSummaryTxt: Label ', %1 discount', Comment = '%1 = discount percentage, such as 10%';
        OverrideDiscountSummaryTxt: Label ', %1 discount (subtotal override)', Comment = '%1 = discount percentage, such as 12%';
        FreeGoodsSummaryTxt: Label ', %1 x %2 free', Comment = '%1 = free quantity, %2 = item no.';
        NotFreeGoodsLineErr: Label 'Select a Mix & Match free-goods line first.';
        RecalcNotificationMsg: Label 'Lines changed. Choose Apply Mix & Match to update Mix & Match discounts and free goods now. They are also updated automatically when the document is released or posted.';

    // Recalculates Mix & Match discounts and free-goods lines on an open quote, order or invoice.
    // Returns true when any sales line was inserted, modified or deleted.
    procedure ApplyToDocument(var SalesHeader: Record "Sales Header"; ShowSummary: Boolean) LinesChanged: Boolean
    var
        SkipReason: Text;
    begin
        Clear(SetCodeByItem);
        SummaryText := '';
        TrackedLineChanged := false;

        if not CanApply(SalesHeader, SkipReason) then begin
            if ShowSummary then
                Message('%1', SkipReason);
            exit(false);
        end;

        LinesChanged := Recalculate(SalesHeader);
        if LinesChanged then
            RefreshHeader(SalesHeader);

        if ShowSummary then
            Message('%1', SummaryText);
    end;

    // True when the last ApplyToDocument changed a free-goods line for an item with item tracking,
    // so lot numbers assigned earlier may no longer match the line.
    procedure TrackedLinesChanged(): Boolean
    begin
        exit(TrackedLineChanged);
    end;

    procedure ChangeFreeItem(var SalesLine: Record "Sales Line")
    var
        Item: Record Item;
        TempItem: Record Item temporary;
        MixMatchSet: Record "Mix Match Set";
        MixMatchSetItem: Record "Mix Match Set Item";
        FreeQty: Decimal;
    begin
        if not SalesLine."MM Free Goods" then
            Error(NotFreeGoodsLineErr);
        MixMatchSet.Get(SalesLine."MM Set Code");

        MixMatchSetItem.SetRange("Set Code", MixMatchSet."Code");
        if MixMatchSetItem.FindSet() then
            repeat
                if Item.Get(MixMatchSetItem."Item No.") then begin
                    TempItem := Item;
                    TempItem.Insert();
                end;
            until MixMatchSetItem.Next() = 0;

        if TempItem.Get(SalesLine."No.") then;
        if Page.RunModal(Page::"Item Lookup", TempItem) <> Action::LookupOK then
            exit;
        if TempItem."No." = SalesLine."No." then
            exit;

        // Validating No. re-initialises the line; the Sales Line subscriber in Mix Match Subscribers keeps it a free-goods line.
        FreeQty := SalesLine.Quantity;
        SalesLine.Validate("No.", TempItem."No.");
        SalesLine.Validate("Unit of Measure Code", GetFreeLineUnitOfMeasure(MixMatchSet, TempItem."No."));
        if SalesLine.Quantity <> FreeQty then
            SalesLine.Validate(Quantity, FreeQty);
        MakeLineFree(SalesLine, MixMatchSet."Code", SalesLine."MM Rule Line No.");
        SalesLine."MM Free Item Chosen" := true;
        SalesLine.Modify(true);
    end;

    procedure SendRecalcNotification(SalesLine: Record "Sales Line")
    var
        SalesHeader: Record "Sales Header";
        RecalcNotification: Notification;
    begin
        if not IsMixMatchDocumentType(SalesLine."Document Type") then
            exit;
        if not SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.") then
            exit;
        if SalesHeader."MM Exclude" or (SalesHeader."Shpfy Order Id" <> 0) then
            exit;
        if not DocumentHasSetItems(SalesHeader, SalesLine) then
            exit;

        RecalcNotification.Id := GetRecalcNotificationId();
        RecalcNotification.Message := RecalcNotificationMsg;
        RecalcNotification.Scope := NotificationScope::LocalScope;
        RecalcNotification.Send();
    end;

    local procedure CanApply(SalesHeader: Record "Sales Header"; var SkipReason: Text): Boolean
    begin
        if not IsMixMatchDocumentType(SalesHeader."Document Type") then begin
            SkipReason := WrongDocumentTypeTxt;
            exit(false);
        end;
        if SalesHeader.Status <> SalesHeader.Status::Open then begin
            SkipReason := StrSubstNo(NotOpenTxt, SalesHeader."Document Type", SalesHeader."No.");
            exit(false);
        end;
        if SalesHeader."Shpfy Order Id" <> 0 then begin
            SkipReason := ShopifyOrderTxt;
            exit(false);
        end;
        // Repricing after part of the document was posted would make later invoices disagree with earlier ones.
        if HasPostedQuantities(SalesHeader) then begin
            SkipReason := PartlyPostedTxt;
            exit(false);
        end;
        exit(true);
    end;

    local procedure IsMixMatchDocumentType(DocumentType: Enum "Sales Document Type"): Boolean
    begin
        exit(DocumentType in ["Sales Document Type"::Quote, "Sales Document Type"::Order, "Sales Document Type"::Invoice]);
    end;

    local procedure HasPostedQuantities(SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("Quantity Shipped", '<>0');
        if not SalesLine.IsEmpty() then
            exit(true);
        SalesLine.SetRange("Quantity Shipped");
        SalesLine.SetFilter("Quantity Invoiced", '<>0');
        if not SalesLine.IsEmpty() then
            exit(true);
        SalesLine.SetRange("Quantity Invoiced");
        SalesLine.SetFilter("Prepmt. Amt. Inv.", '<>0');
        exit(not SalesLine.IsEmpty());
    end;

    local procedure Recalculate(SalesHeader: Record "Sales Header") LinesChanged: Boolean
    var
        MixMatchSet: Record "Mix Match Set";
        TempSetLine: Record "Sales Line" temporary;
        SetCodes: List of [Code[20]];
        SetCode: Code[20];
        GoodsSubtotalLCY: Decimal;
        ThresholdLCY: Decimal;
        OverrideOn: Boolean;
    begin
        if SalesHeader."MM Exclude" then
            AddSummaryLine(ExcludedTxt)
        else begin
            CollectSetLines(SalesHeader, TempSetLine, SetCodes);
            if SetCodes.Count() = 0 then
                AddSummaryLine(NoSetsTxt)
            else begin
                OverrideOn := IsBestDiscountOverrideOn(SalesHeader, GoodsSubtotalLCY, ThresholdLCY);
                if OverrideOn then
                    AddSummaryLine(StrSubstNo(OverrideSummaryTxt, Round(GoodsSubtotalLCY, 0.01), ThresholdLCY));
            end;
        end;

        foreach SetCode in SetCodes do begin
            MixMatchSet.Get(SetCode);
            TempSetLine.SetRange("MM Set Code", SetCode);
            if ApplySet(SalesHeader, MixMatchSet, TempSetLine, OverrideOn) then
                LinesChanged := true;
        end;
        TempSetLine.Reset();

        if CleanUpOrphanLines(SalesHeader, TempSetLine, SetCodes) then
            LinesChanged := true;
    end;

    // Buffers the paid item lines that take part, grouped by the set their item belongs to. On the buffer,
    // MM Set Code is the item's current set and MM Std. Line Disc. % is the line's standard (non Mix & Match) discount.
    local procedure CollectSetLines(SalesHeader: Record "Sales Header"; var TempSetLine: Record "Sales Line" temporary; var SetCodes: List of [Code[20]])
    var
        SalesLine: Record "Sales Line";
        SetCode: Code[20];
        PricingDate: Date;
    begin
        PricingDate := GetPricingDate(SalesHeader);
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("MM Free Goods", false);
        if SalesLine.FindSet() then
            repeat
                if IsEligibleLine(SalesLine) then begin
                    SetCode := FindActiveSetCode(SalesLine."No.", PricingDate);
                    if SetCode <> '' then begin
                        TempSetLine := SalesLine;
                        TempSetLine."MM Set Code" := SetCode;
                        TempSetLine."MM Std. Line Disc. %" := GetStandardDiscount(SalesLine);
                        TempSetLine.Insert();
                        if not SetCodes.Contains(SetCode) then
                            SetCodes.Add(SetCode);
                    end;
                end;
            until SalesLine.Next() = 0;
    end;

    local procedure IsEligibleLine(SalesLine: Record "Sales Line"): Boolean
    begin
        if (SalesLine."No." = '') or (SalesLine.Quantity <= 0) then
            exit(false);
        // Invoice lines fetched from shipments were already priced on their order.
        if SalesLine."Shipment No." <> '' then
            exit(false);
        exit(SalesLine."Allow Line Disc.");
    end;

    // If the line still carries the discount Mix & Match gave it, its standard discount is the one remembered then.
    // Otherwise BC pricing or the user changed the discount since, and the current value is the standard one.
    local procedure GetStandardDiscount(SalesLine: Record "Sales Line"): Decimal
    begin
        if (SalesLine."MM Set Code" <> '') and (SalesLine."Line Discount %" = SalesLine."MM Applied Disc. %") then
            exit(SalesLine."MM Std. Line Disc. %");
        exit(SalesLine."Line Discount %");
    end;

    local procedure FindActiveSetCode(ItemNo: Code[20]; PricingDate: Date): Code[20]
    var
        MixMatchSetItem: Record "Mix Match Set Item";
        MixMatchSet: Record "Mix Match Set";
        SetCode: Code[20];
    begin
        if SetCodeByItem.Get(ItemNo, SetCode) then
            exit(SetCode);

        MixMatchSetItem.SetCurrentKey("Item No.");
        MixMatchSetItem.SetRange("Item No.", ItemNo);
        if MixMatchSetItem.FindSet() then
            repeat
                if MixMatchSet.Get(MixMatchSetItem."Set Code") then
                    if MixMatchSet.IsActiveOn(PricingDate) then
                        SetCode := MixMatchSet."Code";
            until (SetCode <> '') or (MixMatchSetItem.Next() = 0);

        SetCodeByItem.Add(ItemNo, SetCode);
        exit(SetCode);
    end;

    // Same date BC pricing uses: posting date for invoices, order date for quotes and orders.
    local procedure GetPricingDate(SalesHeader: Record "Sales Header") PricingDate: Date
    begin
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Invoice then
            PricingDate := SalesHeader."Posting Date"
        else
            PricingDate := SalesHeader."Order Date";
        if PricingDate = 0D then
            PricingDate := WorkDate();
    end;

    // The goods subtotal is taken before any discount, so applying the discounts can't switch the override off again.
    local procedure IsBestDiscountOverrideOn(SalesHeader: Record "Sales Header"; var GoodsSubtotalLCY: Decimal; var ThresholdLCY: Decimal): Boolean
    var
        MixMatchSetup: Record "Mix Match Setup";
        SalesLine: Record "Sales Line";
    begin
        GoodsSubtotalLCY := 0;
        ThresholdLCY := MixMatchSetup.GetBestDiscountThreshold();
        if ThresholdLCY <= 0 then
            exit(false);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetRange("MM Free Goods", false);
        SalesLine.SetFilter(Quantity, '>0');
        SalesLine.SetLoadFields(Quantity, "Unit Price");
        if SalesLine.FindSet() then
            repeat
                GoodsSubtotalLCY += SalesLine.Quantity * SalesLine."Unit Price";
            until SalesLine.Next() = 0;

        if SalesHeader."Currency Code" <> '' then
            if SalesHeader."Currency Factor" <> 0 then
                GoodsSubtotalLCY := GoodsSubtotalLCY / SalesHeader."Currency Factor";

        exit(GoodsSubtotalLCY >= ThresholdLCY);
    end;

    local procedure ApplySet(SalesHeader: Record "Sales Header"; MixMatchSet: Record "Mix Match Set"; var TempSetLine: Record "Sales Line" temporary; OverrideOn: Boolean) LinesChanged: Boolean
    var
        SalesLine: Record "Sales Line";
        ChosenRule: Record "Mix Match Rule";
        TopRule: Record "Mix Match Rule";
        FreeItemNo: Code[20];
        QualifyingQty: Decimal;
        LineDiscountPct: Decimal;
        FreeQty: Decimal;
        LineRuleLineNo: Integer;
        HasChosenRule: Boolean;
        UseTopRule: Boolean;
        TagLines: Boolean;
    begin
        QualifyingQty := CalcQualifyingQty(MixMatchSet, TempSetLine);
        if OverrideOn then
            UseTopRule := FindTopDiscountRule(MixMatchSet."Code", TopRule);
        HasChosenRule := ChooseRule(MixMatchSet."Code", TempSetLine, QualifyingQty, UseTopRule, TopRule."Discount %", ChosenRule, FreeQty);

        // Under the subtotal override the discount comes from the set's top tier; free goods still come from the chosen tier.
        if UseTopRule then begin
            TagLines := true;
            LineRuleLineNo := TopRule."Line No.";
            LineDiscountPct := TopRule."Discount %";
        end else
            if HasChosenRule then begin
                TagLines := true;
                LineRuleLineNo := ChosenRule."Line No.";
                LineDiscountPct := ChosenRule."Discount %";
            end;

        if TempSetLine.FindSet() then
            repeat
                SalesLine.Get(TempSetLine."Document Type", TempSetLine."Document No.", TempSetLine."Line No.");
                if TagLines then begin
                    if UpdatePaidLine(
                         SalesLine, MixMatchSet."Code", LineRuleLineNo, TempSetLine."MM Std. Line Disc. %",
                         MaxDecimal(TempSetLine."MM Std. Line Disc. %", LineDiscountPct), UseTopRule)
                    then
                        LinesChanged := true;
                end else
                    if ResetPaidLine(SalesLine, TempSetLine."MM Std. Line Disc. %") then
                        LinesChanged := true;
            until TempSetLine.Next() = 0;

        if SyncFreeGoodsLine(SalesHeader, MixMatchSet, TempSetLine, ChosenRule, FreeQty, FreeItemNo) then
            LinesChanged := true;

        AddSetSummary(MixMatchSet."Code", QualifyingQty, TagLines, LineDiscountPct, UseTopRule, FreeQty, FreeItemNo);
    end;

    // Picks the tier that gives the lowest total for the set's lines; ties go to more free goods, then to the higher
    // minimum quantity. With the subtotal override on, every candidate is priced at the top discount, so free goods decide.
    local procedure ChooseRule(SetCode: Code[20]; var TempSetLine: Record "Sales Line" temporary; QualifyingQty: Decimal; UseTopRule: Boolean; TopDiscountPct: Decimal; var ChosenRule: Record "Mix Match Rule"; var ChosenFreeQty: Decimal) HasChosenRule: Boolean
    var
        MixMatchRule: Record "Mix Match Rule";
        CandidateDiscountPct: Decimal;
        CandidateTotal: Decimal;
        CandidateFreeQty: Decimal;
        BestTotal: Decimal;
        BestMinQty: Decimal;
    begin
        // The baseline is "no tier".
        if UseTopRule then
            BestTotal := CalcSetTotal(TempSetLine, TopDiscountPct)
        else
            BestTotal := CalcSetTotal(TempSetLine, 0);
        ChosenFreeQty := 0;
        BestMinQty := 0;

        MixMatchRule.SetRange("Set Code", SetCode);
        if MixMatchRule.FindSet() then
            repeat
                if (MixMatchRule."Minimum Quantity" > 0) and (MixMatchRule."Minimum Quantity" <= QualifyingQty) then begin
                    if UseTopRule then
                        CandidateDiscountPct := TopDiscountPct
                    else
                        CandidateDiscountPct := MixMatchRule."Discount %";
                    CandidateTotal := CalcSetTotal(TempSetLine, CandidateDiscountPct);
                    CandidateFreeQty := CalcFreeQty(MixMatchRule, QualifyingQty);
                    if IsBetterCandidate(CandidateTotal, CandidateFreeQty, MixMatchRule."Minimum Quantity", BestTotal, ChosenFreeQty, BestMinQty) then begin
                        ChosenRule := MixMatchRule;
                        HasChosenRule := true;
                        BestTotal := CandidateTotal;
                        ChosenFreeQty := CandidateFreeQty;
                        BestMinQty := MixMatchRule."Minimum Quantity";
                    end;
                end;
            until MixMatchRule.Next() = 0;
    end;

    local procedure IsBetterCandidate(Total: Decimal; FreeQty: Decimal; MinQty: Decimal; BestTotal: Decimal; BestFreeQty: Decimal; BestMinQty: Decimal): Boolean
    begin
        if Total <> BestTotal then
            exit(Total < BestTotal);
        if FreeQty <> BestFreeQty then
            exit(FreeQty > BestFreeQty);
        exit(MinQty > BestMinQty);
    end;

    local procedure FindTopDiscountRule(SetCode: Code[20]; var TopRule: Record "Mix Match Rule") Found: Boolean
    var
        MixMatchRule: Record "Mix Match Rule";
    begin
        MixMatchRule.SetRange("Set Code", SetCode);
        MixMatchRule.SetFilter("Discount %", '>0');
        if MixMatchRule.FindSet() then
            repeat
                if not Found then begin
                    TopRule := MixMatchRule;
                    Found := true;
                end else
                    if (MixMatchRule."Discount %" > TopRule."Discount %") or
                       ((MixMatchRule."Discount %" = TopRule."Discount %") and (MixMatchRule."Minimum Quantity" > TopRule."Minimum Quantity"))
                    then
                        TopRule := MixMatchRule;
            until MixMatchRule.Next() = 0;
    end;

    // Total of the set's lines when each line gets the higher of its standard discount and DiscountPct.
    local procedure CalcSetTotal(var TempSetLine: Record "Sales Line" temporary; DiscountPct: Decimal) Total: Decimal
    begin
        if TempSetLine.FindSet() then
            repeat
                Total += TempSetLine.Quantity * TempSetLine."Unit Price" * (100 - MaxDecimal(TempSetLine."MM Std. Line Disc. %", DiscountPct)) / 100;
            until TempSetLine.Next() = 0;
    end;

    local procedure CalcQualifyingQty(MixMatchSet: Record "Mix Match Set"; var TempSetLine: Record "Sales Line" temporary) QualifyingQty: Decimal
    begin
        if TempSetLine.FindSet() then
            repeat
                QualifyingQty += ToCountingQty(MixMatchSet, TempSetLine."No.", TempSetLine."Quantity (Base)");
            until TempSetLine.Next() = 0;
    end;

    local procedure ToCountingQty(MixMatchSet: Record "Mix Match Set"; ItemNo: Code[20]; QtyBase: Decimal): Decimal
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        if MixMatchSet."Unit of Measure Code" = '' then
            exit(QtyBase);
        if ItemUnitOfMeasure.Get(ItemNo, MixMatchSet."Unit of Measure Code") then
            if ItemUnitOfMeasure."Qty. per Unit of Measure" <> 0 then
                exit(QtyBase / ItemUnitOfMeasure."Qty. per Unit of Measure");
        exit(QtyBase);
    end;

    local procedure CalcFreeQty(MixMatchRule: Record "Mix Match Rule"; QualifyingQty: Decimal): Decimal
    begin
        if MixMatchRule."Free Quantity" <= 0 then
            exit(0);
        if MixMatchRule."Free Qty. per Multiple" then
            if MixMatchRule."Minimum Quantity" > 0 then
                exit(MixMatchRule."Free Quantity" * Round(QualifyingQty / MixMatchRule."Minimum Quantity", 1, '<'));
        exit(MixMatchRule."Free Quantity");
    end;

    local procedure UpdatePaidLine(var SalesLine: Record "Sales Line"; SetCode: Code[20]; RuleLineNo: Integer; StdDiscountPct: Decimal; TargetDiscountPct: Decimal; OverrideApplied: Boolean) Changed: Boolean
    begin
        if SalesLine."Line Discount %" <> TargetDiscountPct then begin
            SalesLine.Validate("Line Discount %", TargetDiscountPct);
            Changed := true;
        end;
        if (SalesLine."MM Set Code" <> SetCode) or (SalesLine."MM Rule Line No." <> RuleLineNo) or
           (SalesLine."MM Applied Disc. %" <> TargetDiscountPct) or (SalesLine."MM Std. Line Disc. %" <> StdDiscountPct) or
           (SalesLine."MM Best Disc. Override" <> OverrideApplied)
        then begin
            SalesLine."MM Set Code" := SetCode;
            SalesLine."MM Rule Line No." := RuleLineNo;
            SalesLine."MM Applied Disc. %" := TargetDiscountPct;
            SalesLine."MM Std. Line Disc. %" := StdDiscountPct;
            SalesLine."MM Best Disc. Override" := OverrideApplied;
            Changed := true;
        end;
        if Changed then
            SalesLine.Modify(true);
    end;

    // Gives a line that Mix & Match discounted earlier its standard discount back. Lines never touched are left alone.
    local procedure ResetPaidLine(var SalesLine: Record "Sales Line"; StdDiscountPct: Decimal): Boolean
    begin
        if SalesLine."MM Set Code" = '' then
            exit(false);
        if SalesLine."Line Discount %" <> StdDiscountPct then
            SalesLine.Validate("Line Discount %", StdDiscountPct);
        ClearMixMatchFields(SalesLine);
        SalesLine.Modify(true);
        exit(true);
    end;

    local procedure ClearMixMatchFields(var SalesLine: Record "Sales Line")
    begin
        SalesLine."MM Set Code" := '';
        SalesLine."MM Rule Line No." := 0;
        SalesLine."MM Free Goods" := false;
        SalesLine."MM Free Item Chosen" := false;
        SalesLine."MM Applied Disc. %" := 0;
        SalesLine."MM Std. Line Disc. %" := 0;
        SalesLine."MM Best Disc. Override" := false;
    end;

    // Keeps one free-goods line per set in step with the entitlement. The existing line is updated in place when its
    // item stays the same, so lot reservations on it survive; otherwise it is replaced.
    local procedure SyncFreeGoodsLine(SalesHeader: Record "Sales Header"; MixMatchSet: Record "Mix Match Set"; var TempSetLine: Record "Sales Line" temporary; FreeGoodsRule: Record "Mix Match Rule"; FreeQty: Decimal; var FreeItemNo: Code[20]) Changed: Boolean
    var
        FreeLine: Record "Sales Line";
        KeptFreeLine: Record "Sales Line";
        ObsoleteLineNos: List of [Integer];
        LineNo: Integer;
        IsFirstLine: Boolean;
        KeepFirstLine: Boolean;
    begin
        FreeItemNo := '';
        FreeLine.SetRange("Document Type", SalesHeader."Document Type");
        FreeLine.SetRange("Document No.", SalesHeader."No.");
        FreeLine.SetRange("MM Free Goods", true);
        FreeLine.SetRange("MM Set Code", MixMatchSet."Code");
        IsFirstLine := true;
        if FreeLine.FindSet() then
            repeat
                if IsFirstLine and (FreeQty > 0) then begin
                    FreeItemNo := GetFreeItemNo(MixMatchSet, FreeGoodsRule, TempSetLine, FreeLine, true);
                    KeepFirstLine := FreeLine."No." = FreeItemNo;
                end;
                if IsFirstLine and KeepFirstLine then
                    KeptFreeLine := FreeLine
                else
                    ObsoleteLineNos.Add(FreeLine."Line No.");
                IsFirstLine := false;
            until FreeLine.Next() = 0;

        foreach LineNo in ObsoleteLineNos do begin
            FreeLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo);
            NoteTrackedLine(FreeLine."No.");
            FreeLine.Delete(true);
            Changed := true;
        end;

        if FreeQty <= 0 then
            exit;

        if KeepFirstLine then begin
            if UpdateFreeGoodsLine(KeptFreeLine, MixMatchSet, FreeGoodsRule, FreeQty) then
                Changed := true;
            exit;
        end;

        if FreeItemNo = '' then
            FreeItemNo := GetFreeItemNo(MixMatchSet, FreeGoodsRule, TempSetLine, FreeLine, false);
        InsertFreeGoodsLine(SalesHeader, MixMatchSet, FreeGoodsRule, FreeItemNo, FreeQty);
        Changed := true;
    end;

    // The item chosen on the document wins, then the tier's default free item, then the cheapest set item on the document.
    local procedure GetFreeItemNo(MixMatchSet: Record "Mix Match Set"; FreeGoodsRule: Record "Mix Match Rule"; var TempSetLine: Record "Sales Line" temporary; ExistingFreeLine: Record "Sales Line"; HasExistingFreeLine: Boolean): Code[20]
    var
        MixMatchSetItem: Record "Mix Match Set Item";
    begin
        if HasExistingFreeLine then
            if ExistingFreeLine."MM Free Item Chosen" then
                if MixMatchSetItem.Get(MixMatchSet."Code", ExistingFreeLine."No.") then
                    exit(ExistingFreeLine."No.");

        if FreeGoodsRule."Default Free Item No." <> '' then
            if MixMatchSetItem.Get(MixMatchSet."Code", FreeGoodsRule."Default Free Item No.") then
                exit(FreeGoodsRule."Default Free Item No.");

        exit(FindCheapestItemNo(MixMatchSet, TempSetLine));
    end;

    local procedure FindCheapestItemNo(MixMatchSet: Record "Mix Match Set"; var TempSetLine: Record "Sales Line" temporary) CheapestItemNo: Code[20]
    var
        UnitPrice: Decimal;
        CheapestUnitPrice: Decimal;
    begin
        if TempSetLine.FindSet() then
            repeat
                UnitPrice := GetPricePerCountingUnit(MixMatchSet, TempSetLine);
                if CheapestItemNo = '' then begin
                    CheapestItemNo := TempSetLine."No.";
                    CheapestUnitPrice := UnitPrice;
                end else
                    if (UnitPrice < CheapestUnitPrice) or ((UnitPrice = CheapestUnitPrice) and (TempSetLine."No." < CheapestItemNo)) then begin
                        CheapestItemNo := TempSetLine."No.";
                        CheapestUnitPrice := UnitPrice;
                    end;
            until TempSetLine.Next() = 0;
    end;

    local procedure GetPricePerCountingUnit(MixMatchSet: Record "Mix Match Set"; var TempSetLine: Record "Sales Line" temporary): Decimal
    var
        QtyPerUnitOfMeasure: Decimal;
        CountingUnitsPerBaseUnit: Decimal;
    begin
        QtyPerUnitOfMeasure := TempSetLine."Qty. per Unit of Measure";
        if QtyPerUnitOfMeasure = 0 then
            QtyPerUnitOfMeasure := 1;
        CountingUnitsPerBaseUnit := ToCountingQty(MixMatchSet, TempSetLine."No.", 1);
        if CountingUnitsPerBaseUnit = 0 then
            CountingUnitsPerBaseUnit := 1;
        exit(TempSetLine."Unit Price" / QtyPerUnitOfMeasure / CountingUnitsPerBaseUnit);
    end;

    local procedure UpdateFreeGoodsLine(var FreeLine: Record "Sales Line"; MixMatchSet: Record "Mix Match Set"; FreeGoodsRule: Record "Mix Match Rule"; FreeQty: Decimal) Changed: Boolean
    var
        UnitOfMeasureCode: Code[10];
    begin
        UnitOfMeasureCode := GetFreeLineUnitOfMeasure(MixMatchSet, FreeLine."No.");
        if FreeLine."Unit of Measure Code" <> UnitOfMeasureCode then begin
            FreeLine.Validate("Unit of Measure Code", UnitOfMeasureCode);
            Changed := true;
        end;
        if FreeLine.Quantity <> FreeQty then begin
            FreeLine.Validate(Quantity, FreeQty);
            Changed := true;
        end;
        if Changed then
            NoteTrackedLine(FreeLine."No.");
        if MakeLineFree(FreeLine, MixMatchSet."Code", FreeGoodsRule."Line No.") then
            Changed := true;
        if Changed then
            FreeLine.Modify(true);
    end;

    local procedure InsertFreeGoodsLine(SalesHeader: Record "Sales Header"; MixMatchSet: Record "Mix Match Set"; FreeGoodsRule: Record "Mix Match Rule"; ItemNo: Code[20]; FreeQty: Decimal)
    var
        FreeLine: Record "Sales Line";
    begin
        FreeLine.Init();
        FreeLine."Document Type" := SalesHeader."Document Type";
        FreeLine."Document No." := SalesHeader."No.";
        FreeLine."Line No." := GetNextLineNo(SalesHeader);
        FreeLine.Insert(true);

        FreeLine.Validate(Type, FreeLine.Type::Item);
        FreeLine.Validate("No.", ItemNo);
        FreeLine.Validate("Unit of Measure Code", GetFreeLineUnitOfMeasure(MixMatchSet, ItemNo));
        FreeLine.Validate(Quantity, FreeQty);
        MakeLineFree(FreeLine, MixMatchSet."Code", FreeGoodsRule."Line No.");
        FreeLine.Modify(true);
        NoteTrackedLine(ItemNo);
    end;

    // Validating quantity or unit of measure reprices the line, so the 100% discount is set last.
    local procedure MakeLineFree(var FreeLine: Record "Sales Line"; SetCode: Code[20]; RuleLineNo: Integer) Changed: Boolean
    begin
        if FreeLine."Line Discount %" <> 100 then begin
            FreeLine.Validate("Line Discount %", 100);
            Changed := true;
        end;
        if FreeLine."Allow Invoice Disc." then begin
            FreeLine.Validate("Allow Invoice Disc.", false);
            Changed := true;
        end;
        if (not FreeLine."MM Free Goods") or (FreeLine."MM Set Code" <> SetCode) or (FreeLine."MM Rule Line No." <> RuleLineNo) or
           (FreeLine."MM Applied Disc. %" <> 100) or (FreeLine."MM Std. Line Disc. %" <> 0) or FreeLine."MM Best Disc. Override"
        then begin
            FreeLine."MM Free Goods" := true;
            FreeLine."MM Set Code" := SetCode;
            FreeLine."MM Rule Line No." := RuleLineNo;
            FreeLine."MM Applied Disc. %" := 100;
            FreeLine."MM Std. Line Disc. %" := 0;
            FreeLine."MM Best Disc. Override" := false;
            Changed := true;
        end;
    end;

    local procedure GetFreeLineUnitOfMeasure(MixMatchSet: Record "Mix Match Set"; ItemNo: Code[20]): Code[10]
    var
        Item: Record Item;
    begin
        if MixMatchSet."Unit of Measure Code" <> '' then
            exit(MixMatchSet."Unit of Measure Code");
        Item.SetLoadFields("Base Unit of Measure");
        Item.Get(ItemNo);
        exit(Item."Base Unit of Measure");
    end;

    local procedure GetNextLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetLoadFields("Line No.");
        if SalesLine.FindLast() then
            exit(SalesLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure NoteTrackedLine(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        Item.SetLoadFields("Item Tracking Code");
        if Item.Get(ItemNo) then
            if Item."Item Tracking Code" <> '' then
                TrackedLineChanged := true;
    end;

    // Lines tagged by an earlier run whose set no longer takes part (item left the set, set expired or deactivated,
    // document excluded, line no longer eligible) get their standard discount back; free-goods lines for such sets are deleted.
    local procedure CleanUpOrphanLines(SalesHeader: Record "Sales Header"; var TempSetLine: Record "Sales Line" temporary; SetCodes: List of [Code[20]]) Changed: Boolean
    var
        SalesLine: Record "Sales Line";
        OrphanLineNos: List of [Integer];
        LineNo: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("MM Set Code", '<>%1', '');
        if SalesLine.FindSet() then
            repeat
                if SalesLine."MM Free Goods" then begin
                    if not SetCodes.Contains(SalesLine."MM Set Code") then
                        OrphanLineNos.Add(SalesLine."Line No.");
                end else
                    if not TempSetLine.Get(SalesLine."Document Type", SalesLine."Document No.", SalesLine."Line No.") then
                        OrphanLineNos.Add(SalesLine."Line No.");
            until SalesLine.Next() = 0;

        foreach LineNo in OrphanLineNos do begin
            SalesLine.Get(SalesHeader."Document Type", SalesHeader."No.", LineNo);
            if SalesLine."MM Free Goods" then begin
                NoteTrackedLine(SalesLine."No.");
                SalesLine.Delete(true);
            end else
                ResetPaidLine(SalesLine, GetStandardDiscount(SalesLine));
            Changed := true;
        end;
    end;

    // Validating Line Discount % can modify the header (ReduceInvoiceDiscValueOnHeader), so re-read it before the caller
    // saves it. Release Sales Document uses the same pattern after calculating invoice discounts.
    local procedure RefreshHeader(var SalesHeader: Record "Sales Header")
    var
        PostingDate: Date;
        PrintPostedDocuments: Boolean;
    begin
        PostingDate := SalesHeader."Posting Date";
        PrintPostedDocuments := SalesHeader."Print Posted Documents";
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        SalesHeader."Print Posted Documents" := PrintPostedDocuments;
        if PostingDate <> SalesHeader."Posting Date" then
            SalesHeader.Validate("Posting Date", PostingDate);
    end;

    local procedure DocumentHasSetItems(SalesHeader: Record "Sales Header"; ChangedLine: Record "Sales Line"): Boolean
    var
        SalesLine: Record "Sales Line";
        PricingDate: Date;
    begin
        PricingDate := GetPricingDate(SalesHeader);
        // The changed line may not be saved yet, so check it on its own.
        if (ChangedLine.Type = ChangedLine.Type::Item) and (ChangedLine."No." <> '') then
            if FindActiveSetCode(ChangedLine."No.", PricingDate) <> '' then
                exit(true);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange(Type, SalesLine.Type::Item);
        SalesLine.SetFilter("No.", '<>%1', '');
        SalesLine.SetLoadFields("No.");
        if SalesLine.FindSet() then
            repeat
                if FindActiveSetCode(SalesLine."No.", PricingDate) <> '' then
                    exit(true);
            until SalesLine.Next() = 0;
        exit(false);
    end;

    local procedure GetRecalcNotificationId(): Guid
    begin
        exit('6f0c1a52-8d3e-4b7a-9c21-5e4d7b8a9f10');
    end;

    local procedure AddSetSummary(SetCode: Code[20]; QualifyingQty: Decimal; TagLines: Boolean; LineDiscountPct: Decimal; OverrideApplied: Boolean; FreeQty: Decimal; FreeItemNo: Code[20])
    var
        SummaryLine: Text;
    begin
        SummaryLine := StrSubstNo(SetSummaryTxt, SetCode, QualifyingQty);
        if (not TagLines) and (FreeQty <= 0) then
            SummaryLine += NoTierSummaryTxt
        else begin
            if LineDiscountPct > 0 then
                if OverrideApplied then
                    SummaryLine += StrSubstNo(OverrideDiscountSummaryTxt, Format(LineDiscountPct) + '%')
                else
                    SummaryLine += StrSubstNo(DiscountSummaryTxt, Format(LineDiscountPct) + '%');
            if FreeQty > 0 then
                SummaryLine += StrSubstNo(FreeGoodsSummaryTxt, FreeQty, FreeItemNo);
        end;
        AddSummaryLine(SummaryLine);
    end;

    local procedure AddSummaryLine(SummaryLine: Text)
    begin
        if SummaryText <> '' then
            SummaryText += '\';
        SummaryText += SummaryLine;
    end;

    local procedure MaxDecimal(Value1: Decimal; Value2: Decimal): Decimal
    begin
        if Value1 > Value2 then
            exit(Value1);
        exit(Value2);
    end;
}
