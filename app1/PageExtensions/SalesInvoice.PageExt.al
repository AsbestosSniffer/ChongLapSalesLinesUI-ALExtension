pageextension 50103 "Sales Invoice Ext" extends "Sales Invoice"
{
    actions
    {
        addlast(processing)
        {
            action(OpenItemPickerCart)
            {
                ApplicationArea = All;
                Caption = 'Quick Add Items';
                Image = Item;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Open a quick item picker to search, pick and add multiple items to the sales lines at once.';

                trigger OnAction()
                var
                    ItemPickerCart: Page "Item Picker Cart";
                begin
                    CurrPage.SaveRecord();
                    ItemPickerCart.SetSalesHeader(Rec);
                    ItemPickerCart.RunModal();

                    Rec.Get(Rec."Document Type", Rec."No.");
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
