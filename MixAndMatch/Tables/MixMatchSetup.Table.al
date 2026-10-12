namespace DefaultPublisher.MixAndMatch;

using Microsoft.Inventory.Item;

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
        field(3; "Free Goods Threshold (LCY)"; Decimal)
        {
            AutoFormatType = 1;
            Caption = 'Free Goods Subtotal (LCY)';
            MinValue = 0;
            ToolTip = 'Specifies the goods subtotal, before any discount, from which the buyer gets the default free goods, in addition to the free goods given by Mix & Match tiers. Enter 0 to turn this off.';

            trigger OnValidate()
            begin
                if "Free Goods Threshold (LCY)" > 0 then begin
                    if "Free Goods Item No." = '' then
                        FieldError("Free Goods Item No.", ThresholdNeedsItemErr);
                    if "Free Goods Quantity" <= 0 then
                        FieldError("Free Goods Quantity", ThresholdNeedsQtyErr);
                end;
            end;
        }
        field(4; "Free Goods Item No."; Code[20])
        {
            Caption = 'Free Goods Item No.';
            TableRelation = Item;
            ToolTip = 'Specifies the item given as free goods when the document''s goods subtotal reaches the Free Goods Subtotal (LCY) threshold. The buyer can choose a different item on the document with the Change Free Item action.';
        }
        field(5; "Free Goods Quantity"; Decimal)
        {
            Caption = 'Free Goods Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies how many units of the free item are added on top of the order, in the item''s base unit of measure, when the document''s goods subtotal reaches the Free Goods Subtotal (LCY) threshold.';

            trigger OnValidate()
            begin
                if ("Free Goods Quantity" > 0) and ("Free Goods Item No." = '') then
                    FieldError("Free Goods Item No.", QtyNeedsItemErr);
            end;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        ThresholdNeedsItemErr: Label 'The free goods threshold needs a Free Goods Item No. Set one, or enter 0 to turn the free goods threshold off.';
        ThresholdNeedsQtyErr: Label 'The free goods threshold needs a Free Goods Quantity. Set one, or enter 0 to turn the free goods threshold off.';
        QtyNeedsItemErr: Label 'A free goods quantity needs a Free Goods Item No.';

    procedure GetBestDiscountThreshold(): Decimal
    begin
        if not Get() then
            Init();
        exit("Best Disc. Threshold (LCY)");
    end;

    procedure GetFreeGoodsSettings(var FreeGoodsThresholdLCY: Decimal; var FreeGoodsItemNo: Code[20]; var FreeGoodsQuantity: Decimal)
    begin
        if not Get() then
            Init();
        FreeGoodsThresholdLCY := "Free Goods Threshold (LCY)";
        FreeGoodsItemNo := "Free Goods Item No.";
        FreeGoodsQuantity := "Free Goods Quantity";
    end;
}
