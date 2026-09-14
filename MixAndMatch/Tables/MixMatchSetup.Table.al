namespace DefaultPublisher.MixAndMatch;

table 50153 "Mix Match Setup"
{
    Caption = 'Mix & Match Setup';
    DataClassification = CustomerContent;
    InherentEntitlements = RX;
    InherentPermissions = RX;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(2; "Best Disc. Threshold (LCY)"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Best Discount Subtotal (LCY)';
            InitValue = 1000;
            MinValue = 0;
            ToolTip = 'Specifies the goods subtotal, before any discount, from which every set item on a document gets its set''s highest tier discount regardless of quantity. Free goods still need the tier quantity. Enter 0 to turn this off.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetBestDiscountThreshold(): Decimal
    begin
        if not Get() then
            Init();
        exit("Best Disc. Threshold (LCY)");
    end;
}
