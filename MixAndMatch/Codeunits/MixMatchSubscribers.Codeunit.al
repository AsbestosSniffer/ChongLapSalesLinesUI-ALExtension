namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.Document;
using Microsoft.Utilities;

codeunit 50151 "Mix Match Subscribers"
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        ReassignLotsMsg: Label 'Mix & Match changed free-goods lines on %1 %2 while releasing it. If lot numbers were already assigned, run Assign Lot Nos. again.', Comment = '%1 = document type, %2 = document no.';
        FreeItemNotInSetErr: Label 'Item %1 is not in Mix & Match set %2, so it can''t be the free item. To stop giving these free goods, turn on Exclude from Mix & Match on the document.', Comment = '%1 = item no., %2 = set code';

    // Runs while the document is still open, before invoice discounts and VAT are calculated. Posting an open document
    // releases it through the same code, so this also covers posting, posting preview and batch posting.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnCodeOnAfterCheckCustomerCreated', '', false, false)]
    local procedure ApplyMixMatchOnRelease(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var IsHandled: Boolean; var LinesWereModified: Boolean)
    var
        MixMatchEngine: Codeunit "Mix Match Engine";
    begin
        if IsHandled then
            exit;
        if not MixMatchEngine.ApplyToDocument(SalesHeader, false) then
            exit;

        // Sales-Post only reloads its in-memory copy of the lines when release reports that lines were modified.
        LinesWereModified := true;

        if MixMatchEngine.TrackedLinesChanged() and GuiAllowed() and not PreviewMode then
            Message(ReassignLotsMsg, SalesHeader."Document Type", SalesHeader."No.");
    end;

    // Free-goods lines are regenerated when Mix & Match is applied, so they aren't copied into new quotes, orders or
    // invoices. Copying with Recalculate Lines would otherwise turn them into paid lines.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnCopySalesDocLineOnAfterCalcCopyThisLine', '', false, false)]
    local procedure SkipFreeGoodsOnCopyDocument(var ToSalesHeader: Record "Sales Header"; var ToSalesLine: Record "Sales Line"; var CopyThisLine: Boolean)
    begin
        // Copy Document Mgt. passes the line being copied from in the parameter named ToSalesLine.
        if not ToSalesLine."MM Free Goods" then
            exit;
        if IsMixMatchDocumentType(ToSalesHeader."Document Type") then
            CopyThisLine := false;
    end;

    // Copying an archived quote or order with Recalculate Lines re-validates each line, which clears the Mix & Match
    // fields (skipping the line there would count it as "not copied"). Keep a copied free-goods line recognisable so
    // applying Mix & Match updates or removes it instead of charging for it.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnAfterRecalculateSalesLine', '', false, false)]
    local procedure KeepFreeGoodsOnRecalculatedCopy(var ToSalesHeader: Record "Sales Header"; var ToSalesLine: Record "Sales Line"; var FromSalesLine: Record "Sales Line")
    begin
        if not FromSalesLine."MM Free Goods" then
            exit;
        if not IsMixMatchDocumentType(ToSalesHeader."Document Type") then
            exit;
        ToSalesLine."MM Free Goods" := true;
        ToSalesLine."MM Set Code" := FromSalesLine."MM Set Code";
        ToSalesLine."MM Rule Line No." := FromSalesLine."MM Rule Line No.";
        ToSalesLine."MM Free Item Chosen" := FromSalesLine."MM Free Item Chosen";
    end;

    // Validating No. re-initialises the line, which clears the Mix & Match fields. Keep a free-goods line free when the
    // new item is from the same set.
    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnAfterValidateEvent', 'No.', false, false)]
    local procedure KeepFreeGoodsOnItemChange(var Rec: Record "Sales Line"; var xRec: Record "Sales Line"; CurrFieldNo: Integer)
    var
        MixMatchSetItem: Record "Mix Match Set Item";
    begin
        if Rec.IsTemporary() then
            exit;
        if not xRec."MM Free Goods" then
            exit;
        if not IsMixMatchDocumentType(Rec."Document Type") then
            exit;
        if (Rec.Type <> Rec.Type::Item) or (Rec."No." = '') then
            exit;

        if MixMatchSetItem.Get(xRec."MM Set Code", Rec."No.") then begin
            Rec."MM Free Goods" := true;
            Rec."MM Set Code" := xRec."MM Set Code";
            Rec."MM Rule Line No." := xRec."MM Rule Line No.";
            Rec."MM Applied Disc. %" := 100;
            Rec."MM Free Item Chosen" := true;
            if Rec."Line Discount %" <> 100 then
                Rec.Validate("Line Discount %", 100);
            exit;
        end;

        if CurrFieldNo <> 0 then
            Error(FreeItemNotInSetErr, Rec."No.", xRec."MM Set Code");
    end;

    local procedure IsMixMatchDocumentType(DocumentType: Enum "Sales Document Type"): Boolean
    begin
        exit(DocumentType in ["Sales Document Type"::Quote, "Sales Document Type"::Order, "Sales Document Type"::Invoice]);
    end;
}
