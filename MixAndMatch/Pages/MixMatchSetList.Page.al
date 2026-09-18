namespace DefaultPublisher.MixAndMatch;

page 50150 "Mix Match Set List"
{
    ApplicationArea = All;
    Caption = 'Mix & Match Sets';
    CardPageId = "Mix Match Set Card";
    Editable = false;
    PageType = List;
    SourceTable = "Mix Match Set";
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Sets)
            {
                field("Code"; Rec."Code")
                {
                }
                field(Description; Rec.Description)
                {
                }
                field("Starting Date"; Rec."Starting Date")
                {
                }
                field("Ending Date"; Rec."Ending Date")
                {
                }
                field("Unit of Measure Code"; Rec."Unit of Measure Code")
                {
                }
                field(Active; Rec.Active)
                {
                }
                field("No. of Items"; Rec."No. of Items")
                {
                }
                field("No. of Tiers"; Rec."No. of Tiers")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ExportToExcel)
            {
                Caption = 'Export to Excel';
                Image = ExportToExcel;
                ToolTip = 'Download all Mix & Match sets with their items and tiers, and the Mix & Match setup, as an Excel workbook that can be imported into another company or environment.';

                trigger OnAction()
                var
                    MixMatchExcelMgt: Codeunit "Mix Match Excel Mgt.";
                begin
                    MixMatchExcelMgt.ExportToExcel();
                end;
            }
            action(ImportFromExcel)
            {
                Caption = 'Import from Excel';
                Image = ImportExcel;
                ToolTip = 'Import Mix & Match sets, items, tiers and setup from a workbook created with Export to Excel. Sets with the same code are replaced; other sets are not changed.';

                trigger OnAction()
                var
                    MixMatchExcelMgt: Codeunit "Mix Match Excel Mgt.";
                begin
                    MixMatchExcelMgt.ImportFromExcel();
                    CurrPage.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(ExportToExcel_Promoted; ExportToExcel)
                {
                }
                actionref(ImportFromExcel_Promoted; ImportFromExcel)
                {
                }
            }
        }
        area(Navigation)
        {
            action(Setup)
            {
                Caption = 'Mix & Match Setup';
                Image = Setup;
                RunObject = page "Mix Match Setup";
                ToolTip = 'Set the goods subtotal from which set items get their set''s highest discount.';
            }
        }
    }
}
