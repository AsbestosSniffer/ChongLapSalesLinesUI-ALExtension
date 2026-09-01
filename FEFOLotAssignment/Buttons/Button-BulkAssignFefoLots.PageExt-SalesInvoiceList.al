namespace ALProject3;
using Microsoft.Sales.Document;

pageextension 50115 ButtonBulkAssignFefo_SIList extends "Sales Invoice List"
{
    actions
    {
        addlast(Processing)
        {
            action(AssignFefoLotsAllInvoices)
            {
                ApplicationArea = All;
                Caption = 'Assign FEFO Lots (All Invoices)';
                ToolTip = 'Go through all unposted sales invoices, oldest to newest by Order Date, and assign lot reservations in FEFO order.';
                Image = LotInfo;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    BulkHelper: Codeunit BulkAssignFefoLotsMgt;
                begin
                    BulkHelper.AssignFefoLotsToUnpostedInvoices();
                end;
            }
            action(AssignFefoLotsSelectedInvoices)
            {
                ApplicationArea = All;
                Caption = 'Assign FEFO Lots (Selected Invoices)';
                ToolTip = 'Assign FEFO lot reservations to the selected sales invoices only, processed oldest to newest by Order Date.';
                Image = LotInfo;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    BulkHelper: Codeunit BulkAssignFefoLotsMgt;
                begin
                    CurrPage.SetSelectionFilter(SalesHeader);
                    BulkHelper.AssignFefoLotsToSelectedInvoices(SalesHeader);
                end;
            }
            action(DeleteReserveEntriesSelectedInvoices)
            {
                ApplicationArea = All;
                Caption = 'Delete Reserve Entries (Selected Invoices)';
                ToolTip = 'Delete all lot reservation entries for the selected sales invoices.';
                Image = DeleteRow;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    SalesHeader: Record "Sales Header";
                    BulkHelper: Codeunit BulkAssignFefoLotsMgt;
                begin
                    CurrPage.SetSelectionFilter(SalesHeader);
                    BulkHelper.DeleteReserveEntriesForSelectedInvoices(SalesHeader);
                end;
            }
        }
    }
}
