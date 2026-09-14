namespace DefaultPublisher.MixAndMatch;

using Microsoft.Inventory.Item;

table 50151 "Mix Match Set Item"
{
    Caption = 'Mix & Match Set Item';
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
            ToolTip = 'Specifies the Mix & Match set the item belongs to.';
        }
        field(2; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            NotBlank = true;
            TableRelation = Item;
            ToolTip = 'Specifies an item that counts toward the set''s tiers.';

            trigger OnValidate()
            begin
                CheckActiveSet();
            end;
        }
        field(3; Description; Text[100])
        {
            CalcFormula = lookup(Item.Description where("No." = field("Item No.")));
            Caption = 'Description';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies the item description.';
        }
        field(4; "Base Unit of Measure"; Code[10])
        {
            CalcFormula = lookup(Item."Base Unit of Measure" where("No." = field("Item No.")));
            Caption = 'Base Unit of Measure';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies the item''s base unit of measure.';
        }
    }

    keys
    {
        key(PK; "Set Code", "Item No.")
        {
            Clustered = true;
        }
        key(ItemNo; "Item No.")
        {
        }
    }

    trigger OnInsert()
    begin
        CheckActiveSet();
    end;

    trigger OnRename()
    begin
        CheckActiveSet();
    end;

    // Items can be added to an active set, but only if they pass the same checks as activation.
    local procedure CheckActiveSet()
    var
        MixMatchSet: Record "Mix Match Set";
    begin
        if "Item No." = '' then
            exit;
        if not MixMatchSet.Get("Set Code") then
            exit;
        if MixMatchSet.Active then
            MixMatchSet.CheckItemCanBeActive("Item No.");
    end;
}
