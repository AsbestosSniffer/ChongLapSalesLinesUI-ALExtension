namespace ALProject3;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Document;

codeunit 50103 ConvertShopifyOrderReserveInv
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Shpfy Order Events", 'OnAfterCreateItemSalesLine', '', false, false)]
    local procedure OnAfterCreateItemSalesLine(ShopifyOrderHeader: Record "Shpfy Order Header"; ShopifyOrderLine: Record "Shpfy Order Line"; SalesHeader: Record "Sales Header"; var SalesLine: Record "Sales Line")
    var
        Helper: Codeunit ReserveEntriesHelper;
        StatusText: Text;
        Skipped: Boolean;
        QtyShort: Decimal;
    begin
        QtyShort := Helper.AssignFefoLotsToLine(SalesLine, StatusText, Skipped);
        if Skipped or (QtyShort > 0) then
            Session.LogMessage('FEFO0001', StatusText, Verbosity::Warning, DataClassification::CustomerContent, TelemetryScope::ExtensionPublisher, 'Category', 'FEFO');
    end;
}
