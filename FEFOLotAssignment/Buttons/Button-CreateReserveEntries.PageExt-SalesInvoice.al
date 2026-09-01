namespace ALProject3;
using Microsoft.Sales.Document;

pageextension 50112 ButtonCreateReserveEntries_SI extends "Sales Invoice Subform"
{
    actions
    {
        // Add changes to page actions here
        addlast(processing)
        {
            action(DeleteReserveEntries)
            {
                ApplicationArea = All;
                Caption = 'Delete Reserve Entries';
                Image = DeleteRow;
                trigger OnAction()
                var
                    Helper: Codeunit ReserveEntriesHelper;
                begin
                    Message('Button Delete Reserve Entries clicked.');
                    Helper.DeleteReserveEntries(Rec);
                end;
            }
            action(CreateReserveEntries)
            {
                ApplicationArea = All;
                Caption = 'Assign Lot Nos.';
                Image = LotInfo;
                trigger OnAction()
                var
                    Helper: Codeunit ReserveEntriesHelper;
                begin
                    Message('Button Assign Lot Nos. clicked.');
                    Helper.CreateReserveEntries(Rec);
                end;
            }
        }
    }
}