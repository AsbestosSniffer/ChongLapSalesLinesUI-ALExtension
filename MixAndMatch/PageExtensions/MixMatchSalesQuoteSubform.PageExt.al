namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.Document;

pageextension 50153 "Mix Match Sales Quote Subform" extends "Sales Quote Subform"
{
    layout
    {
        addafter("Line Discount %")
        {
            field("MM Free Goods"; Rec."MM Free Goods")
            {
                ApplicationArea = All;
            }
            field("MM Set Code"; Rec."MM Set Code")
            {
                ApplicationArea = All;
                Visible = false;
            }
            field("MM Best Disc. Override"; Rec."MM Best Disc. Override")
            {
                ApplicationArea = All;
                Visible = false;
            }
        }
        modify("No.")
        {
            trigger OnAfterValidate()
            begin
                NotifyMixMatchMayBeOutdated();
            end;
        }
        modify(Quantity)
        {
            trigger OnAfterValidate()
            begin
                NotifyMixMatchMayBeOutdated();
            end;
        }
        modify("Unit of Measure Code")
        {
            trigger OnAfterValidate()
            begin
                NotifyMixMatchMayBeOutdated();
            end;
        }
        modify("Unit Price")
        {
            trigger OnAfterValidate()
            begin
                NotifyMixMatchMayBeOutdated();
            end;
        }
    }

    actions
    {
        addlast(processing)
        {
            action(MixMatchChangeFreeItem)
            {
                ApplicationArea = All;
                Caption = 'Change Free Item';
                Enabled = Rec."MM Free Goods";
                Image = Item;
                ToolTip = 'Choose another item from the Mix & Match set for this free-goods line. The choice is kept when Mix & Match is applied again.';

                trigger OnAction()
                var
                    MixMatchEngine: Codeunit "Mix Match Engine";
                begin
                    CurrPage.SaveRecord();
                    MixMatchEngine.ChangeFreeItem(Rec);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    local procedure NotifyMixMatchMayBeOutdated()
    var
        MixMatchEngine: Codeunit "Mix Match Engine";
    begin
        MixMatchEngine.SendRecalcNotification(Rec);
    end;
}
