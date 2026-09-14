namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.History;

tableextension 50152 "Mix Match Sales Inv. Line" extends "Sales Invoice Line"
{
    fields
    {
        field(50150; "MM Set Code"; Code[20])
        {
            Caption = 'Mix & Match Set';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies the Mix & Match set that the line counted toward.';
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
            ToolTip = 'Specifies that the line held free goods added by Mix & Match.';
        }
        field(50153; "MM Free Item Chosen"; Boolean)
        {
            Caption = 'Free Item Chosen Manually';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies that the free item was chosen on the document.';
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
            ToolTip = 'Specifies the line discount the line had before Mix & Match.';
        }
        field(50156; "MM Best Disc. Override"; Boolean)
        {
            Caption = 'Mix & Match Subtotal Best Discount';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies that the line got its set''s highest discount because the goods subtotal reached the Mix & Match threshold.';
        }
    }
}
