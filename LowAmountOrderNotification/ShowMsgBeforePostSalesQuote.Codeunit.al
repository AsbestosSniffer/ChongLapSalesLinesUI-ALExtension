namespace DefaultPublisher.ALProject3;

using Microsoft.Sales.Document;
using Microsoft.Sales.Posting;

codeunit 50105 ShowMsgBeforePostSalesQuote
{
    var
        BelowThresholdQst: Label 'The total amount is %1 %2, which is below the threshold of %3 HKD.\Do you want to continue posting?', Comment = '%1 = document amount including VAT, %2 = currency code, %3 = threshold amount';
        PostingCancelledErr: Label 'Posting has been cancelled because the total amount is below the threshold.';

    // Raised once per posting run, before any posting writes.
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', false, false)]
    local procedure ShowMsgBeforePostSalesDoc(
        var SalesHeader: Record "Sales Header";
        CommitIsSuppressed: Boolean;
        PreviewMode: Boolean;
        var HideProgressWindow: Boolean;
        var IsHandled: Boolean;
        var CalledBy: Integer
    )
    var
        ThresholdAmount: Decimal;
    begin
        if IsHandled or PreviewMode or (not GuiAllowed()) then
            exit;

        ThresholdAmount := 500;

        SalesHeader.CalcFields("Amount Including VAT");
        if SalesHeader."Amount Including VAT" >= ThresholdAmount then
            exit;

        if Confirm(
             BelowThresholdQst,
             false,
             SalesHeader."Amount Including VAT",
             SalesHeader."Currency Code" = '' ? 'HKD' : SalesHeader."Currency Code",
             ThresholdAmount)
        then
            exit;

        Error(PostingCancelledErr);
    end;
}
