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
                Caption = 'Delete Lot Tracking';
                Image = DeleteRow;
                trigger OnAction()
                var
                    Helper: Codeunit ReserveEntriesHelper;
                begin
                    CurrPage.SaveRecord();
                    Helper.DeleteReserveEntries(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(AuditFefoLotTracking)
            {
                ApplicationArea = All;
                Caption = 'Audit Lot Tracking';
                ToolTip = 'Check the inventory used by this document for malformed reservation entries without changing data.';
                Image = View;
                trigger OnAction()
                var
                    Helper: Codeunit ReserveEntriesHelper;
                begin
                    Message('%1', Helper.AuditLotTracking(Rec));
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
                    CurrPage.SaveRecord();
                    Helper.CreateReserveEntries(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }
}
