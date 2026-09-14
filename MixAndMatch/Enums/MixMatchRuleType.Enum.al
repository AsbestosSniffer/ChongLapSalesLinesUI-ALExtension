namespace DefaultPublisher.MixAndMatch;

enum 50150 "Mix Match Rule Type"
{
    Extensible = false;

    value(0; Discount)
    {
        Caption = 'Discount';
    }
    value(1; "Free Goods")
    {
        Caption = 'Free Goods';
    }
    value(2; "Discount and Free Goods")
    {
        Caption = 'Discount + Free Goods';
    }
}
