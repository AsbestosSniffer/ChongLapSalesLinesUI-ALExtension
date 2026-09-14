namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.Document;

pageextension 50150 "Mix Match Sales Quote" extends "Sales Quote"
{
    layout
    {
        addlast(General)
        {
            field("MM Exclude"; Rec."MM Exclude")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action(MixMatchApply)
            {
                ApplicationArea = All;
                Caption = 'Apply Mix & Match';
                Image = CalculateInvoiceDiscount;
                ToolTip = 'Recalculate Mix & Match discounts and free goods on this document. This also happens automatically when the document is released or posted.';

                trigger OnAction()
                var
                    MixMatchEngine: Codeunit "Mix Match Engine";
                begin
                    CurrPage.SaveRecord();
                    MixMatchEngine.ApplyToDocument(Rec, true);
                    CurrPage.Update(false);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(MixMatchApply_Promoted; MixMatchApply)
            {
            }
        }
    }
}
