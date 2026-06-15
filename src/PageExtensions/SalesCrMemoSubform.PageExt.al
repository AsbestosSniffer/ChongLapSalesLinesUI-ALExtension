pageextension 50104 "Sales CrMemo Subform Ext" extends "Sales Cr.Memo Subform"
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
                    if not SalesHeader.Get(SalesHeader."Document Type"::"Credit Memo", DocumentNo) then
                        exit;

                    ItemPickerCart.SetSalesHeader(SalesHeader);
                    ItemPickerCart.RunModal();

                    CurrPage.Update(false);
                end;
            }
        }
    }
}
