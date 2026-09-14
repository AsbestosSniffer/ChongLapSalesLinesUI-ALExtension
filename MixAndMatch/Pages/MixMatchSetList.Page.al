namespace DefaultPublisher.MixAndMatch;

page 50150 "Mix Match Set List"
{
    ApplicationArea = All;
    Caption = 'Mix & Match Sets';
    CardPageId = "Mix Match Set Card";
    Editable = false;
    PageType = List;
    SourceTable = "Mix Match Set";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Sets)
            {
                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Starting Date"; Rec."Starting Date")
                {
                }
                field("Ending Date"; Rec."Ending Date")
                {
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                }
                field(Active; Rec.Active)
                {
                }
                field("No. of Items"; Rec."No. of Items")
                {
                }
                field("No. of Tiers"; Rec."No. of Tiers")
                {
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Setup)
            {
                Caption = 'Mix & Match Setup';
                Image = Setup;
                RunObject = page "Mix Match Setup";
                ToolTip = 'Set the goods subtotal from which set items get their set''s highest discount.';
            }
        }
    }
}
