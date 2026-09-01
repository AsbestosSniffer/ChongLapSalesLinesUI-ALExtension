namespace ALProject3;
using Microsoft.Sales.Document;

pageextension 50114 ButtonBulkAssignFefo_SOList extends "Sales Order List"
{
    actions
    {
        addlast(Processing)
        {
            action(AssignFefoLotsAllOrders)
            {
                ApplicationArea = All;
                Caption = 'Assign FEFO Lots (All Orders)';
                ToolTip = 'Go through all unposted sales orders, oldest to newest by Order Date, and assign lot reservations in FEFO order.';
                Image = LotInfo;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    BulkHelper: Codeunit BulkAssignFefoLotsMgt;
                begin
                    BulkHelper.AssignFefoLotsToUnpostedOrders();
                end;
            }
            action(AssignFefoLotsSelectedOrders)
            {
                ApplicationArea = All;
                Caption = 'Assign FEFO Lots (Selected Orders)';
                ToolTip = 'Assign FEFO lot reservations to the selected sales orders only, processed oldest to newest by Order Date.';
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
                    BulkHelper.AssignFefoLotsToSelectedOrders(SalesHeader);
                end;
            }
            action(DeleteReserveEntriesSelectedOrders)
            {
                ApplicationArea = All;
                Caption = 'Delete Reserve Entries (Selected Orders)';
                ToolTip = 'Delete all lot reservation entries for the selected sales orders.';
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
                    BulkHelper.DeleteReserveEntriesForSelectedOrders(SalesHeader);
                end;
            }
        }
    }
}
