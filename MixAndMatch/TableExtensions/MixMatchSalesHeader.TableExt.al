namespace DefaultPublisher.MixAndMatch;

using Microsoft.Sales.Document;

tableextension 50150 "Mix Match Sales Header" extends "Sales Header"
{
    fields
    {
        field(50150; "MM Exclude"; Boolean)
        {
            Caption = 'Exclude from Mix & Match';
            DataClassification = CustomerContent;
            ToolTip = 'Specifies that no Mix & Match discounts or free goods apply to this document. Apply Mix & Match removes any that were added earlier.';
        }
    }
}
