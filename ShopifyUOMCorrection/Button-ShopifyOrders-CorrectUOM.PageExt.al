namespace DefaultPublisher.ShopifyUOMCorrection;

using Microsoft.Integration.Shopify;

pageextension 50142 CorrectUOMShopifyOrders extends "Shpfy Orders"
{
    actions
    {
        addlast(processing)
        {
            action(CorrectUOM)
            {
                ApplicationArea = All;
                Caption = 'Rectify UoM';
                Image = UnitOfMeasure;
                ToolTip = 'Set the Unit of Measure Code on the lines of the selected orders to the unit chosen in Shopify, as shown in the Variant Description (for example Pcs or Box). Orders that already have a sales document are skipped.';

                trigger OnAction()
                var
                    ShopifyOrderHeader: Record "Shpfy Order Header";
                    ShopifyUOMCorrection: Codeunit ShopifyUOMCorrection;
                begin
                    CurrPage.SetSelectionFilter(ShopifyOrderHeader);
                    ShopifyUOMCorrection.CorrectUnitOfMeasure(ShopifyOrderHeader);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
