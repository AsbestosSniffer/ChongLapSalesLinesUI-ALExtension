namespace DefaultPublisher.MixAndMatch;

using Microsoft.CRM.Campaign;
using Microsoft.CRM.Contact;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.Pricing;

table 50150 "Mix Match Set"
{
    Caption = 'Mix & Match Set';
    DataCaptionFields = "Code", Description;
    DataClassification = CustomerContent;
    DrillDownPageId = "Mix Match Set List";
    InherentEntitlements = RX;
    InherentPermissions = RX;
    LookupPageId = "Mix Match Set List";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
            ToolTip = 'Specifies the code of the Mix & Match set.';
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            ToolTip = 'Specifies a description of the promotion.';
        }
        field(3; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
            ToolTip = 'Specifies the first date the set applies. Leave blank if the set applies from any date.';

            trigger OnValidate()
            begin
                TestField(Active, false);
            end;
        }
        field(4; "Ending Date"; Date)
        {
            Caption = 'Ending Date';
            ToolTip = 'Specifies the last date the set applies. Leave blank if the set has no end date.';

            trigger OnValidate()
            begin
                TestField(Active, false);
            end;
        }
        field(5; "Unit of Measure Code"; Code[10])
        {
            Caption = 'Counting Unit of Measure';
            TableRelation = "Unit of Measure";
            ToolTip = 'Specifies the unit that tier minimum quantities and free quantities are counted in, such as BOX. Leave blank to count in each item''s base unit of measure.';

            trigger OnValidate()
            begin
                TestField(Active, false);
            end;
        }
        field(6; Active; Boolean)
        {
            Caption = 'Active';
            Editable = false;
            ToolTip = 'Specifies whether the set is applied to sales documents. Use the Activate and Deactivate actions to change it.';
        }
        field(7; "No. of Items"; Integer)
        {
            CalcFormula = count("Mix Match Set Item" where("Set Code" = field("Code")));
            Caption = 'No. of Items';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies how many items are in the set.';
        }
        field(8; "No. of Tiers"; Integer)
        {
            CalcFormula = count("Mix Match Rule" where("Set Code" = field("Code")));
            Caption = 'No. of Tiers';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies how many tiers the set has.';
        }
        field(9; "Assign-to Type"; Enum "Mix Match Assign-to Type")
        {
            Caption = 'Assign-to Type';
            ToolTip = 'Specifies the type of entity the set is assigned to, as on sales price lists. All Customers applies the set to every sales document.';

            trigger OnValidate()
            begin
                TestField(Active, false);
                if "Assign-to Type" <> xRec."Assign-to Type" then
                    "Assign-to No." := '';
            end;
        }
        field(10; "Assign-to No."; Code[20])
        {
            Caption = 'Assign-to No.';
            TableRelation = if ("Assign-to Type" = const(Customer)) Customer
            else
            if ("Assign-to Type" = const("Customer Price Group")) "Customer Price Group"
            else
            if ("Assign-to Type" = const("Customer Disc. Group")) "Customer Discount Group"
            else
            if ("Assign-to Type" = const(Campaign)) Campaign
            else
            if ("Assign-to Type" = const(Contact)) Contact;
            ToolTip = 'Specifies the entity the set is assigned to. The options depend on the Assign-to Type field. The set then applies only to documents for that entity, the same way a sales price list does.';

            trigger OnValidate()
            begin
                TestField(Active, false);
                if "Assign-to No." <> '' then
                    if "Assign-to Type" = "Assign-to Type"::"All Customers" then
                        Error(NoForAllCustomersErr, FieldCaption("Assign-to No."), "Assign-to Type");
            end;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    trigger OnDelete()
    var
        MixMatchSetItem: Record "Mix Match Set Item";
        MixMatchRule: Record "Mix Match Rule";
    begin
        TestField(Active, false);

        MixMatchSetItem.SetRange("Set Code", "Code");
        MixMatchSetItem.DeleteAll();
        MixMatchRule.SetRange("Set Code", "Code");
        MixMatchRule.DeleteAll();
    end;

    trigger OnRename()
    begin
        Error(RenameNotAllowedErr);
    end;

    var
        RenameNotAllowedErr: Label 'You cannot rename a Mix & Match set. Create a new set instead.';
        DateRangeErr: Label 'The starting date must be on or before the ending date.';
        NoItemsErr: Label 'Add at least one item to Mix & Match set %1 before activating it.', Comment = '%1 = set code';
        NoTiersErr: Label 'Add at least one tier to Mix & Match set %1 before activating it.', Comment = '%1 = set code';
        MissingUnitOfMeasureErr: Label 'Item %1 has no unit of measure %2, which Mix & Match set %3 counts in.', Comment = '%1 = item no., %2 = unit of measure code, %3 = set code';
        ItemInOtherSetErr: Label 'Item %1 is already in active Mix & Match set %2, which has the same Assign-to Type and Assign-to No. for an overlapping period. Sets can share items only if they are assigned differently, for example one to All Customers and one to a specific customer; a document then gets whichever applicable set gives the lowest total.', Comment = '%1 = item no., %2 = other set code';
        NoForAllCustomersErr: Label '%1 must be blank when Assign-to Type is %2.', Comment = '%1 = Assign-to No. caption, %2 = All Customers';
        DuplicateMinQtyErr: Label 'Mix & Match set %1 has more than one tier starting at %2 units.', Comment = '%1 = set code, %2 = minimum quantity';
        DiscountDecreasesErr: Label 'In Mix & Match set %1, the tier from %2 units gives a lower discount (%3) than the tier from %4 units (%5). A higher tier must keep at least the discount of the tiers below it.', Comment = '%1 = set code, %2 = higher minimum quantity, %3 = its discount, %4 = lower minimum quantity, %5 = its discount';
        FreeQtyDecreasesErr: Label 'In Mix & Match set %1, the tier from %2 units gives fewer free goods (%3) than the tier from %4 units (%5). A higher tier must give at least the free goods of the tiers below it.', Comment = '%1 = set code, %2 = higher minimum quantity, %3 = its free quantity, %4 = lower minimum quantity, %5 = its free quantity';

    procedure IsActiveOn(CheckDate: Date): Boolean
    begin
        if not Active then
            exit(false);
        if ("Starting Date" <> 0D) and (CheckDate < "Starting Date") then
            exit(false);
        if ("Ending Date" <> 0D) and (CheckDate > "Ending Date") then
            exit(false);
        exit(true);
    end;

    procedure Activate()
    var
        MixMatchSetItem: Record "Mix Match Set Item";
    begin
        TestField(Active, false);
        if ("Starting Date" <> 0D) and ("Ending Date" <> 0D) and ("Starting Date" > "Ending Date") then
            Error(DateRangeErr);
        if "Assign-to Type" <> "Assign-to Type"::"All Customers" then
            TestField("Assign-to No.");

        MixMatchSetItem.SetRange("Set Code", "Code");
        if not MixMatchSetItem.FindSet() then
            Error(NoItemsErr, "Code");
        repeat
            CheckItemCanBeActive(MixMatchSetItem."Item No.");
        until MixMatchSetItem.Next() = 0;

        CheckTiers();

        Active := true;
        Modify(true);
    end;

    procedure Deactivate()
    begin
        TestField(Active, true);
        Active := false;
        Modify(true);
    end;

    procedure CheckItemCanBeActive(ItemNo: Code[20])
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        OtherSetItem: Record "Mix Match Set Item";
        OtherSet: Record "Mix Match Set";
    begin
        if "Unit of Measure Code" <> '' then
            if not ItemUnitOfMeasure.Get(ItemNo, "Unit of Measure Code") then
                Error(MissingUnitOfMeasureErr, ItemNo, "Unit of Measure Code", "Code");

        OtherSetItem.SetCurrentKey("Item No.");
        OtherSetItem.SetRange("Item No.", ItemNo);
        if OtherSetItem.FindSet() then
            repeat
                if OtherSetItem."Set Code" <> "Code" then
                    if OtherSet.Get(OtherSetItem."Set Code") then
                        if OtherSet.Active and DateRangeOverlaps(OtherSet) and HasSameAssignment(OtherSet) then
                            Error(ItemInOtherSetErr, ItemNo, OtherSet."Code");
            until OtherSetItem.Next() = 0;
    end;

    // True when this set applies to the sales line's document, using the same sources BC uses to find
    // sales price lists for a line (codeunit "Sales Line - Price", AddCustomerSources): the bill-to customer
    // and contact, the header's campaign or else the customer's activated campaigns, and the line's
    // customer price group and customer discount group.
    procedure AppliesTo(SalesHeader: Record "Sales Header"; SalesLine: Record "Sales Line"): Boolean
    begin
        if ("Assign-to Type" <> "Assign-to Type"::"All Customers") and ("Assign-to No." = '') then
            exit(false);

        case "Assign-to Type" of
            "Assign-to Type"::"All Customers":
                exit(true);
            "Assign-to Type"::Customer:
                exit("Assign-to No." = SalesHeader."Bill-to Customer No.");
            "Assign-to Type"::Contact:
                exit("Assign-to No." = SalesHeader."Bill-to Contact No.");
            "Assign-to Type"::"Customer Price Group":
                exit("Assign-to No." = SalesLine."Customer Price Group");
            "Assign-to Type"::"Customer Disc. Group":
                exit("Assign-to No." = SalesLine."Customer Disc. Group");
            "Assign-to Type"::Campaign:
                exit(CampaignApplies(SalesHeader));
        end;
        exit(false);
    end;

    // True when Assign-to No. exists for the current Assign-to Type (always true for All Customers).
    procedure AssignToNoExists(): Boolean
    var
        Customer: Record Customer;
        CustomerPriceGroup: Record "Customer Price Group";
        CustomerDiscountGroup: Record "Customer Discount Group";
        Campaign: Record Campaign;
        Contact: Record Contact;
    begin
        case "Assign-to Type" of
            "Assign-to Type"::"All Customers":
                exit(true);
            "Assign-to Type"::Customer:
                exit(Customer.Get("Assign-to No."));
            "Assign-to Type"::"Customer Price Group":
                exit(CustomerPriceGroup.Get("Assign-to No."));
            "Assign-to Type"::"Customer Disc. Group":
                exit(CustomerDiscountGroup.Get("Assign-to No."));
            "Assign-to Type"::Campaign:
                exit(Campaign.Get("Assign-to No."));
            "Assign-to Type"::Contact:
                exit(Contact.Get("Assign-to No."));
        end;
        exit(false);
    end;

    // Like BC pricing: the header's campaign if it has one; otherwise the campaigns activated for the bill-to
    // customer, or, only if the customer has none, those activated for the bill-to contact's company.
    local procedure CampaignApplies(SalesHeader: Record "Sales Header"): Boolean
    var
        CampaignTargetGroup: Record "Campaign Target Group";
        Contact: Record Contact;
    begin
        if SalesHeader."Campaign No." <> '' then
            exit(SalesHeader."Campaign No." = "Assign-to No.");

        CampaignTargetGroup.SetRange(Type, CampaignTargetGroup.Type::Customer);
        CampaignTargetGroup.SetRange("No.", SalesHeader."Bill-to Customer No.");
        if CampaignTargetGroup.IsEmpty() then begin
            if not Contact.Get(SalesHeader."Bill-to Contact No.") then
                exit(false);
            CampaignTargetGroup.SetRange(Type, CampaignTargetGroup.Type::Contact);
            CampaignTargetGroup.SetRange("No.", Contact."Company No.");
        end;
        CampaignTargetGroup.SetRange("Campaign No.", "Assign-to No.");
        exit(not CampaignTargetGroup.IsEmpty());
    end;

    // Sets assigned differently may share items: when more than one applies to a document, the engine gives each
    // shared item to the set that yields the lowest total. Two sets with the identical assignment, however, are
    // almost certainly a duplicate promotion, so that is still refused.
    local procedure HasSameAssignment(OtherSet: Record "Mix Match Set"): Boolean
    begin
        exit(("Assign-to Type" = OtherSet."Assign-to Type") and ("Assign-to No." = OtherSet."Assign-to No."));
    end;

    // Lower is more specific. Used only to break ties between competing sets that give the same total.
    procedure GetSpecificityRank(): Integer
    begin
        case "Assign-to Type" of
            "Assign-to Type"::Customer:
                exit(0);
            "Assign-to Type"::Contact:
                exit(1);
            "Assign-to Type"::Campaign:
                exit(2);
            "Assign-to Type"::"Customer Disc. Group":
                exit(3);
            "Assign-to Type"::"Customer Price Group":
                exit(4);
        end;
        exit(5);
    end;

    // A blank starting or ending date leaves the range open on that side.
    local procedure DateRangeOverlaps(OtherSet: Record "Mix Match Set"): Boolean
    begin
        if ("Starting Date" <> 0D) and (OtherSet."Ending Date" <> 0D) then
            if "Starting Date" > OtherSet."Ending Date" then
                exit(false);
        if (OtherSet."Starting Date" <> 0D) and ("Ending Date" <> 0D) then
            if OtherSet."Starting Date" > "Ending Date" then
                exit(false);
        exit(true);
    end;

    local procedure CheckTiers()
    var
        MixMatchRule: Record "Mix Match Rule";
        LowerRule: Record "Mix Match Rule";
        HasLowerRule: Boolean;
    begin
        MixMatchRule.SetCurrentKey("Set Code", "Minimum Quantity");
        MixMatchRule.SetRange("Set Code", "Code");
        if not MixMatchRule.FindSet() then
            Error(NoTiersErr, "Code");

        repeat
            MixMatchRule.CheckConsistency();
            if HasLowerRule then begin
                if MixMatchRule."Minimum Quantity" = LowerRule."Minimum Quantity" then
                    Error(DuplicateMinQtyErr, "Code", MixMatchRule."Minimum Quantity");
                if MixMatchRule."Discount %" < LowerRule."Discount %" then
                    Error(
                      DiscountDecreasesErr, "Code",
                      MixMatchRule."Minimum Quantity", Format(MixMatchRule."Discount %") + '%',
                      LowerRule."Minimum Quantity", Format(LowerRule."Discount %") + '%');
                if MixMatchRule."Free Quantity" < LowerRule."Free Quantity" then
                    Error(
                      FreeQtyDecreasesErr, "Code",
                      MixMatchRule."Minimum Quantity", MixMatchRule."Free Quantity",
                      LowerRule."Minimum Quantity", LowerRule."Free Quantity");
            end;
            LowerRule := MixMatchRule;
            HasLowerRule := true;
        until MixMatchRule.Next() = 0;
    end;
}
