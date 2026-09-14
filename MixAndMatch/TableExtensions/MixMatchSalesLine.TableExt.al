namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.Document;

// Field IDs must stay identical in the posted and archived line extensions so TransferFields carries them over.
tableextension 50151 "Mix Match Sales Line" extends "Sales Line"
{
    fields
    {
        field(50150; "MM Set Code"; Code[20])
        {
            Caption = 'Mix & Match Set';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies the Mix & Match set that the line counts toward.';
        }
        field(50151; "MM Rule Line No."; Integer)
        {
            Caption = 'Mix & Match Tier Line No.';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies the tier that gave the line its discount or free goods.';
        }
        field(50152; "MM Free Goods"; Boolean)
        {
            Caption = 'Mix & Match Free Goods';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies that the line holds free goods added by Mix & Match.';
        }
        field(50153; "MM Free Item Chosen"; Boolean)
        {
            Caption = 'Free Item Chosen Manually';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies that the free item was chosen on the document, so Mix & Match keeps it instead of the tier''s default free item.';
        }
        field(50154; "MM Applied Disc. %"; Decimal)
        {
            Caption = 'Mix & Match Applied Discount %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Specifies the line discount that Mix & Match set on the line.';
        }
        field(50155; "MM Std. Line Disc. %"; Decimal)
        {
            Caption = 'Standard Line Discount %';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
            Editable = false;
            ToolTip = 'Specifies the line discount the line had before Mix & Match, which is restored if Mix & Match no longer applies.';
        }
        field(50156; "MM Best Disc. Override"; Boolean)
        {
            Caption = 'Mix & Match Subtotal Best Discount';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies that the line got its set''s highest discount because the document''s goods subtotal reached the Mix & Match threshold.';
        }
    }
}
