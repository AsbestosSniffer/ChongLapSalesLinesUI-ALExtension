pageextension 50102 "Sales Quote Subform Ext" extends "Sales Quote Subform"
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
                    SalesHeader: Record "Sales Header";
                    ItemPickerCart: Page "Item Picker Cart";
                    DocumentNo: Code[20];
                begin
                    DocumentNo := CopyStr(Rec.GetFilter("Document No."), 1, MaxStrLen(DocumentNo));
                    if not SalesHeader.Get(SalesHeader."Document Type"::Quote, DocumentNo) then
                        exit;

                    ItemPickerCart.SetSalesHeader(SalesHeader);
                    ItemPickerCart.RunModal();

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
