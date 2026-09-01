namespace DefaultPublisher.ALProject3;

using Microsoft.Sales.Document;
using System.Utilities;
using System.Automation;



codeunit 50105 ShowMsgBeforePostSalesQuote
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Approvals Mgmt.", 'OnBeforePrePostApprovalCheckSales', '', false, false)]
    local procedure ShowMsgBeforePostSalesQuote(
        var SalesHeader: Record "Sales Header";
        var IsHandled: Boolean;
        var Result: Boolean
    )
    var
        ConfirmText: Text;
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        SalesHeader.CalcFields("Amount Including VAT");
        if SalesHeader."Amount Including VAT" >= 5000 then
            exit;

        ConfirmText := StrSubstNo(
            'The total amount is %1 %2, which is below the threshold of 5000 HKD.\Do you want to continue posting?',
            SalesHeader."Amount Including VAT",
            SalesHeader."Currency Code" = '' ? 'HKD' : SalesHeader."Currency Code"
        );

        if Confirm(ConfirmText, false) then
            exit
        else begin
            Error('Posting has been cancelled because the total amount is below the threshold.');
            IsHandled := true;
            Result := false;
        end;
    end;
}