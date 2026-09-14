namespace DefaultPublisher.MixAndMatch;

table 50152 "Mix Match Rule"
{
    Caption = 'Mix & Match Tier';
    DataClassification = CustomerContent;
    InherentEntitlements = RX;
    InherentPermissions = RX;

    fields
    {
        field(1; "Set Code"; Code[20])
        {
            Caption = 'Set Code';
            NotBlank = true;
            TableRelation = "Mix Match Set";
            ToolTip = 'Specifies the Mix & Match set the tier belongs to.';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(3; Type; Enum "Mix Match Rule Type")
        {
            Caption = 'Type';
            ToolTip = 'Specifies whether the tier gives a discount, free goods, or both.';

            trigger OnValidate()
            begin
                case Type of
                    Type::Discount:
                        begin
                            "Free Quantity" := 0;
                            "Free Qty. per Multiple" := false;
                            "Default Free Item No." := '';
                        end;
                    Type::"Free Goods":
                        "Discount %" := 0;
                end;
            end;
        }
        field(4; "Minimum Quantity"; Decimal)
        {
            Caption = 'Minimum Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies how many units from the set, in any mix of its items, the document needs for this tier.';
        }
        field(5; "Discount %"; Decimal)
        {
            Caption = 'Discount %';
            DecimalPlaces = 0 : 5;
            MaxValue = 100;
            MinValue = 0;
            ToolTip = 'Specifies the line discount given on the set''s lines. A line keeps its own discount if that is higher.';

            trigger OnValidate()
            begin
                if "Discount %" <> 0 then
                    if Type = Type::"Free Goods" then
                        FieldError(Type);
            end;
        }
        field(6; "Free Quantity"; Decimal)
        {
            Caption = 'Free Quantity';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
            ToolTip = 'Specifies how many free units are added on top of the order, in the set''s counting unit.';

            trigger OnValidate()
            begin
                if "Free Quantity" <> 0 then
                    if Type = Type::Discount then
                        FieldError(Type);
            end;
        }
        field(7; "Free Qty. per Multiple"; Boolean)
        {
            Caption = 'Free Qty. per Multiple';
            ToolTip = 'Specifies whether the free quantity is given for every full multiple of the minimum quantity (buy 100 on a buy-50 tier gives twice the free goods) instead of once.';

            trigger OnValidate()
            begin
                if "Free Qty. per Multiple" then
                    if Type = Type::Discount then
                        FieldError(Type);
            end;
        }
        field(8; "Default Free Item No."; Code[20])
        {
            Caption = 'Default Free Item No.';
            TableRelation = "Mix Match Set Item"."Item No." where("Set Code" = field("Set Code"));
            ToolTip = 'Specifies the item given as free goods unless another set item is chosen on the document. Leave blank to give the cheapest set item on the document.';

            trigger OnValidate()
            begin
                if "Default Free Item No." <> '' then
                    if Type = Type::Discount then
                        FieldError(Type);
            end;
        }
    }

    keys
    {
        key(PK; "Set Code", "Line No.")
        {
            Clustered = true;
        }
        key(MinimumQuantity; "Set Code", "Minimum Quantity")
        {
        }
    }

    trigger OnInsert()
    begin
        TestSetInactive();
    end;

    trigger OnModify()
    begin
        TestSetInactive();
    end;

    trigger OnDelete()
    begin
        TestSetInactive();
    end;

    trigger OnRename()
    begin
        TestSetInactive();
    end;

    var
        FreeItemNotInSetErr: Label 'Default free item %1 is not an item in Mix & Match set %2.', Comment = '%1 = item no., %2 = set code';

    procedure CheckConsistency()
    var
        MixMatchSetItem: Record "Mix Match Set Item";
    begin
        TestField("Minimum Quantity");
        case Type of
            Type::Discount:
                TestField("Discount %");
            Type::"Free Goods":
                TestField("Free Quantity");
            Type::"Discount and Free Goods":
                begin
                    TestField("Discount %");
                    TestField("Free Quantity");
                end;
        end;

        if "Default Free Item No." <> '' then
            if not MixMatchSetItem.Get("Set Code", "Default Free Item No.") then
                Error(FreeItemNotInSetErr, "Default Free Item No.", "Set Code");
    end;

    local procedure TestSetInactive()
    var
        MixMatchSet: Record "Mix Match Set";
    begin
        if MixMatchSet.Get("Set Code") then
            MixMatchSet.TestField(Active, false);
    end;
}
