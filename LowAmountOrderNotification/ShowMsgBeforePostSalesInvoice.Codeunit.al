// namespace DefaultPublisher.ALProject3;

// using Microsoft.Sales.Posting;
// using Microsoft.Sales.Document;
// using System.Utilities;
// using Microsoft.Foundation.Enums;


// codeunit 50104 ShowMsgBeforePostSalesInvoice
// {
//     // trigger OnRun()
//     // begin

//     // end;
//     [EventSubscriber(ObjectType::Page, Page::"Sales Order", 'OnBeforePostSalesOrder', '', false, false)]
//     local procedure CheckLessThanThreshold(
//         var SalesHeader: Record "Sales Header";
//         PostingCodeunitID: Integer;
//         Navigate: Enum "Navigate After Posting"
//     )
//     var
//         ConfirmManagement: Codeunit "Confirm Management";
//         ConfirmText: Text;
//     begin

//         SalesHeader.CalcFields("Amount Including VAT");

//         // Message('Debug: Entered CheckLessThanThreshold');

//         if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
//             exit;

//         if SalesHeader."Amount Including VAT" >= 5000 then
//             exit;

//         // Show confirmation dialog
//         ConfirmText := StrSubstNo(
//             'The total amount is %1 %2, which is below the threshold of 500 HKD.\Do you want to continue posting?',
//             SalesHeader."Amount Including VAT",
//             SalesHeader."Currency Code" = '' ? 'HKD' : SalesHeader."Currency Code"
//         );

//         if not ConfirmManagement.GetResponseOrDefault(ConfirmText, true) then
//             Error('');

//         // if (SalesHeader."Currency Code" <> '') or (SalesHeader."Currency Code" <> 'HKD') then
//         //     exit;


//         // Message(
//         //     'Sales Order Amount Less than 5000 HKD.'
//         // );

//     end;

//     var
//         myInt: Integer;
// }