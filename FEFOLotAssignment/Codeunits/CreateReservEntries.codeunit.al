namespace DefaultPublisher.ALProject3;

using Microsoft.Sales.Document;

codeunit 50102 DetectNewSalesLine
{
    [EventSubscriber(ObjectType::Page, Page::"Sales Order Subform", 'OnAfterQuantityOnAfterValidate', '', false, false)]
    local procedure OnAfterQuantityOnAfterValidateSalesLine(var SalesLine: Record "Sales Line"; xSalesLine: Record "Sales Line")
    var
        Helper: Codeunit ReserveEntriesHelper;
        StatusText: Text;
        Skipped: Boolean;
        QtyShort: Decimal;
        ResultNotification: Notification;
    begin
        if SalesLine.Quantity = xSalesLine.Quantity then
            exit;

        QtyShort := Helper.AssignFefoLotsToLine(SalesLine, StatusText, Skipped);
        if GuiAllowed and ((QtyShort > 0) or Skipped) then begin
            ResultNotification.Message := StatusText;
            ResultNotification.Scope := NotificationScope::LocalScope;
            ResultNotification.Send();
        end;
    end;
}
