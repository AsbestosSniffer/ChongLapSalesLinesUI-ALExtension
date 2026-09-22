namespace DefaultPublisher.MixAndMatch;

page 50151 "Mix Match Set Card"
{
    ApplicationArea = All;
    Caption = 'Mix & Match Set';
    PageType = Card;
    SourceTable = "Mix Match Set";

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Starting Date"; Rec."Starting Date")
                {
                    Editable = not Rec.Active;
                }
                field("Ending Date"; Rec."Ending Date")
                {
                    Editable = not Rec.Active;
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                    Editable = not Rec.Active;
                }
                field("Assign-to Type"; Rec."Assign-to Type")
                {
                    Editable = not Rec.Active;
                    Importance = Promoted;

                    trigger OnValidate()
                    begin
                        SetAssignToNoEnabled();
                        CurrPage.Update(true);
                    end;
                }
                field("Assign-to No."; Rec."Assign-to No.")
                {
                    Editable = not Rec.Active;
                    Enabled = AssignToNoEnabled;
                    Importance = Promoted;
                    ShowMandatory = AssignToNoEnabled;
                }
                field(Active; Rec.Active)
                {
                }
            }
            part(Items; "Mix Match Set Items")
            {
                SubPageLink = "Set Code" = field("Code");
                UpdatePropagation = Both;
            }
            part(Tiers; "Mix Match Rules")
            {
                Editable = not Rec.Active;
                SubPageLink = "Set Code" = field("Code");
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActivateSet)
            {
                Caption = 'Activate';
                Enabled = not Rec.Active;
                Image = ReleaseDoc;
                ToolTip = 'Check the set''s items and tiers, then start applying the set to sales documents.';

                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Rec.Activate();
                    CurrPage.Update(false);
                end;
            }
            action(DeactivateSet)
            {
                Caption = 'Deactivate';
                Enabled = Rec.Active;
                Image = ReOpen;
                ToolTip = 'Stop applying the set so its tiers can be edited. Documents keep their current lines until Mix & Match is applied again.';

                trigger OnAction()
                begin
                    Rec.Deactivate();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ActivateSet_Promoted; ActivateSet)
                {
                }
                actionref(DeactivateSet_Promoted; DeactivateSet)
                {
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        SetAssignToNoEnabled();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        SetAssignToNoEnabled();
    end;

    var
        AssignToNoEnabled: Boolean;

    local procedure SetAssignToNoEnabled()
    begin
        AssignToNoEnabled := Rec."Assign-to Type" <> Rec."Assign-to Type"::"All Customers";
    end;
}
