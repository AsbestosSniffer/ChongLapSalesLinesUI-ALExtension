namespace DefaultPublisher.ShopifyUOMCorrection;

using Microsoft.Integration.Shopify;

pageextension 50143 CorrectUOMShopifyOrder extends "Shpfy Order"
{
    actions
    {
        addafter(FindMappings)
        {
            action(CorrectUOM)
            {
                ApplicationArea = All;
                Caption = 'Rectify UoM';
                Image = UnitOfMeasure;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                PromotedOnly = true;
                ToolTip = 'Set the Unit of Measure Code on each line to the unit chosen in Shopify, as shown in the Variant Description (for example Pcs or Box). Run this before Create Sales Document.';

                trigger OnAction()
                var
                    ShopifyOrderHeader: Record "Shpfy Order Header";
                    ShopifyUOMCorrection: Codeunit ShopifyUOMCorrection;
                begin
                    CurrPage.SaveRecord();
                    ShopifyOrderHeader.Get(Rec."Shopify Order Id");
                    ShopifyOrderHeader.SetRecFilter();
                    ShopifyUOMCorrection.CorrectUnitOfMeasure(ShopifyOrderHeader);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
