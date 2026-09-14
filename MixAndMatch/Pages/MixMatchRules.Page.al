namespace DefaultPublisher.MixAndMatch;

page 50153 "Mix Match Rules"
{
    ApplicationArea = All;
    AutoSplitKey = true;
    Caption = 'Tiers';
    DelayedInsert = true;
    PageType = ListPart;
    SourceTable = "Mix Match Rule";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(Type; Rec.Type)
                {
                }
                field("Minimum Quantity"; Rec."Minimum Quantity")
                {
                }
                field("Discount %"; Rec."Discount %")
                {
                }
                field("Free Quantity"; Rec."Free Quantity")
                {
                }
                field("Free Qty. per Multiple"; Rec."Free Qty. per Multiple")
                {
                }
                field("Default Free Item No."; Rec."Default Free Item No.")
                {
                }
            }
        }
    }
}
