namespace DefaultPublisher.MixAndMatch;

page 50154 "Mix Match Setup"
{
    ApplicationArea = All;
    Caption = 'Mix & Match Setup';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "Mix Match Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field("Best Disc. Threshold (LCY)"; Rec."Best Disc. Threshold (LCY)")
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;
    end;
}
