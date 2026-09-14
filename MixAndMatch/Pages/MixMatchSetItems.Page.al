namespace DefaultPublisher.MixAndMatch;

page 50152 "Mix Match Set Items"
{
    ApplicationArea = All;
    Caption = 'Items';
    DelayedInsert = true;
    PageType = ListPart;
    SourceTable = "Mix Match Set Item";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Item No."; Rec."Item No.")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Base Unit of Measure"; Rec."Base Unit of Measure")
                {
                }
            }
        }
    }
}
