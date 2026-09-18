namespace DefaultPublisher.MixAndMatch;

using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.UOM;
using Microsoft.Inventory.Item;
using System.IO;
using System.Utilities;

// Moves the Mix & Match configuration (sets, their items and tiers, and the setup) between companies and
// environments as an Excel workbook with one sheet per table.
codeunit 50152 "Mix Match Excel Mgt."
{
    InherentEntitlements = X;
    InherentPermissions = X;

    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        // Sheet names and headings are not translated, so a file exported in one language imports in another.
        SetsSheetTok: Label 'Sets', Locked = true;
        ItemsSheetTok: Label 'Items', Locked = true;
        TiersSheetTok: Label 'Tiers', Locked = true;
        SetupSheetTok: Label 'Setup', Locked = true;
        CodeColTok: Label 'Code', Locked = true;
        DescriptionColTok: Label 'Description', Locked = true;
        StartingDateColTok: Label 'Starting Date', Locked = true;
        EndingDateColTok: Label 'Ending Date', Locked = true;
        CountingUoMColTok: Label 'Counting Unit of Measure', Locked = true;
        ActiveColTok: Label 'Active', Locked = true;
        SetCodeColTok: Label 'Set Code', Locked = true;
        ItemNoColTok: Label 'Item No.', Locked = true;
        TypeColTok: Label 'Type', Locked = true;
        MinimumQuantityColTok: Label 'Minimum Quantity', Locked = true;
        DiscountPctColTok: Label 'Discount %', Locked = true;
        FreeQuantityColTok: Label 'Free Quantity', Locked = true;
        FreeQtyPerMultipleColTok: Label 'Free Qty. per Multiple', Locked = true;
        DefaultFreeItemNoColTok: Label 'Default Free Item No.', Locked = true;
        BestDiscThresholdColTok: Label 'Best Discount Subtotal (LCY)', Locked = true;
        LcyCodeColTok: Label 'LCY Code', Locked = true;
        YesTok: Label 'Yes', Locked = true;
        NoTok: Label 'No', Locked = true;
        ColumnLettersTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', Locked = true;
        UnsafeFileNameCharsTok: Label '\/:*?"<>|', Locked = true;
        ExportFileNameTxt: Label 'Mix & Match - %1.xlsx', Comment = '%1 = company name';
        ExportDialogTitleTxt: Label 'Export Mix & Match to Excel';
        ImportDialogTitleTxt: Label 'Import Mix & Match from Excel';
        ExcelFileFilterTxt: Label 'Excel Files (*.xlsx)|*.xlsx';
        BlankDateCommentTxt: Label 'Leave blank for no limit.';
        CountingUoMCommentTxt: Label 'Leave blank to count in each item''s base unit of measure.';
        ActiveCommentTxt: Label 'Yes or No. Active sets are checked and activated after importing.';
        ReferenceOnlyCommentTxt: Label 'For reference only. Not imported.';
        TypeCommentTxt: Label 'Discount, Free Goods, or Discount and Free Goods.';
        YesNoCommentTxt: Label 'Yes or No.';
        FreeItemCommentTxt: Label 'Must be listed for the same set on the Items sheet. Leave blank to give the cheapest set item on the document.';
        NotMixMatchFileErr: Label '%1 can''t be imported because it isn''t a Mix & Match export. %2', Comment = '%1 = file name, %2 = reason';
        WrongHeaderErr: Label 'Sheet %1, cell %2 should contain the heading "%3" but contains "%4". Use a workbook created with Export to Excel.', Comment = '%1 = sheet name, %2 = cell reference such as B1, %3 = expected heading, %4 = actual heading';
        ValueRequiredErr: Label 'Sheet %1, cell %2: %3 must have a value.', Comment = '%1 = sheet name, %2 = cell reference, %3 = column heading';
        ValueTooLongErr: Label 'Sheet %1, cell %2: %3 can be at most %4 characters.', Comment = '%1 = sheet name, %2 = cell reference, %3 = column heading, %4 = maximum length';
        InvalidNumberErr: Label 'Sheet %1, cell %2: "%3" is not a valid number for %4.', Comment = '%1 = sheet name, %2 = cell reference, %3 = cell value, %4 = column heading';
        NegativeNumberErr: Label 'Sheet %1, cell %2: %3 can''t be negative.', Comment = '%1 = sheet name, %2 = cell reference, %3 = column heading';
        InvalidDateErr: Label 'Sheet %1, cell %2: "%3" is not a valid date for %4.', Comment = '%1 = sheet name, %2 = cell reference, %3 = cell value, %4 = column heading';
        InvalidYesNoErr: Label 'Sheet %1, cell %2: "%3" is not valid for %4. Use Yes or No.', Comment = '%1 = sheet name, %2 = cell reference, %3 = cell value, %4 = column heading';
        InvalidTypeErr: Label 'Sheet %1, cell %2: "%3" is not a valid tier type. Use Discount, Free Goods, or Discount and Free Goods.', Comment = '%1 = sheet name, %2 = cell reference, %3 = cell value';
        DuplicateSetErr: Label 'Sheet %1, cell %2: set %3 is listed more than once.', Comment = '%1 = sheet name, %2 = cell reference, %3 = set code';
        DateRangeErr: Label 'Sheet %1, row %2: the starting date of set %3 is after its ending date.', Comment = '%1 = sheet name, %2 = row number, %3 = set code';
        UnitOfMeasureNotFoundErr: Label 'Sheet %1, cell %2: unit of measure %3 doesn''t exist in this company.', Comment = '%1 = sheet name, %2 = cell reference, %3 = unit of measure code';
        SetNotOnSetsSheetErr: Label 'Sheet %1, cell %2: set %3 isn''t listed on the Sets sheet.', Comment = '%1 = sheet name, %2 = cell reference, %3 = set code';
        ItemNotFoundErr: Label 'Sheet %1, cell %2: item %3 doesn''t exist in this company.', Comment = '%1 = sheet name, %2 = cell reference, %3 = item no.';
        DuplicateItemErr: Label 'Sheet %1, row %2: item %3 is listed more than once for set %4.', Comment = '%1 = sheet name, %2 = row number, %3 = item no., %4 = set code';
        MinimumQuantityErr: Label 'Sheet %1, cell %2: Minimum Quantity must be greater than 0.', Comment = '%1 = sheet name, %2 = cell reference';
        DiscountTooHighErr: Label 'Sheet %1, cell %2: Discount % can''t be more than 100.', Comment = '%1 = sheet name, %2 = cell reference';
        DiscountTierHasFreeGoodsErr: Label 'Sheet %1, row %2: a Discount tier can''t give free goods. Change the type to Discount and Free Goods, or clear Free Quantity, Free Qty. per Multiple and Default Free Item No.', Comment = '%1 = sheet name, %2 = row number';
        FreeGoodsTierHasDiscountErr: Label 'Sheet %1, row %2: a Free Goods tier can''t give a discount. Change the type to Discount and Free Goods, or clear Discount %.', Comment = '%1 = sheet name, %2 = row number';
        MissingDiscountErr: Label 'Sheet %1, row %2: a %3 tier needs a Discount %.', Comment = '%1 = sheet name, %2 = row number, %3 = tier type';
        MissingFreeQuantityErr: Label 'Sheet %1, row %2: a %3 tier needs a Free Quantity.', Comment = '%1 = sheet name, %2 = row number, %3 = tier type';
        FreeItemNotInSetErr: Label 'Sheet %1, cell %2: default free item %3 isn''t listed for set %4 on the Items sheet.', Comment = '%1 = sheet name, %2 = cell reference, %3 = item no., %4 = set code';
        ConfirmImportQst: Label 'Import %1 Mix & Match sets with %2 items and %3 tiers from %4?\\%5 of these sets already exist in this company and will be replaced, including their items and tiers. Sets that aren''t in the file stay as they are. Best Discount Subtotal (LCY) will be set to %6.%7\\If any part of the file can''t be imported, nothing is imported.', Comment = '%1 = number of sets, %2 = number of items, %3 = number of tiers, %4 = file name, %5 = number of sets that already exist, %6 = threshold amount, %7 = optional currency warning';
        CurrencyWarningTxt: Label '\\Warning: the file was exported from a company whose local currency is %1, but this company''s local currency is %2.', Comment = '%1 = local currency code in the file, %2 = local currency code of this company';
        ImportDoneMsg: Label 'Imported %1 Mix & Match sets (%2 new, %3 replaced) with %4 items and %5 tiers, and activated %6 of them. Best Discount Subtotal (LCY) is now %7.', Comment = '%1 = number of sets, %2 = new sets, %3 = replaced sets, %4 = items, %5 = tiers, %6 = activated sets, %7 = threshold amount';

    procedure ExportToExcel()
    var
        TempBlob: Codeunit "Temp Blob";
        ExcelOutStream: OutStream;
        ExcelInStream: InStream;
        FileName: Text;
    begin
        StartSheet();
        AddSetsSheet();
        TempExcelBuffer.CreateNewBook(SetsSheetTok);
        TempExcelBuffer.WriteSheet('', CompanyName(), UserId());

        StartSheet();
        AddItemsSheet();
        TempExcelBuffer.SelectOrAddSheet(ItemsSheetTok);
        TempExcelBuffer.WriteSheet('', CompanyName(), UserId());

        StartSheet();
        AddTiersSheet();
        TempExcelBuffer.SelectOrAddSheet(TiersSheetTok);
        TempExcelBuffer.WriteSheet('', CompanyName(), UserId());

        StartSheet();
        AddSetupSheet();
        TempExcelBuffer.SelectOrAddSheet(SetupSheetTok);
        TempExcelBuffer.WriteSheet('', CompanyName(), UserId());

        TempExcelBuffer.CloseBook();

        TempBlob.CreateOutStream(ExcelOutStream);
        TempExcelBuffer.SaveToStream(ExcelOutStream, true);
        TempBlob.CreateInStream(ExcelInStream);
        FileName := StrSubstNo(ExportFileNameTxt, DelChr(CompanyName(), '=', UnsafeFileNameCharsTok));
        DownloadFromStream(ExcelInStream, ExportDialogTitleTxt, '', ExcelFileFilterTxt, FileName);
    end;

    procedure ImportFromExcel()
    var
        TempMixMatchSet: Record "Mix Match Set" temporary;
        TempMixMatchSetItem: Record "Mix Match Set Item" temporary;
        TempMixMatchRule: Record "Mix Match Rule" temporary;
        GeneralLedgerSetup: Record "General Ledger Setup";
        ExcelInStream: InStream;
        FileName: Text;
        OpenBookErrorText: Text;
        CurrencyWarningText: Text;
        FileLcyCode: Code[10];
        BestDiscThreshold: Decimal;
        NewSetCount: Integer;
        ReplacedSetCount: Integer;
        ActivatedSetCount: Integer;
    begin
        if not UploadIntoStream(ImportDialogTitleTxt, '', ExcelFileFilterTxt, FileName, ExcelInStream) then
            exit;

        // Read and check the whole file before writing anything, so errors can point at the exact cell.
        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();
        OpenBookErrorText := TempExcelBuffer.OpenBookStream(ExcelInStream, SetsSheetTok);
        if OpenBookErrorText <> '' then
            Error(NotMixMatchFileErr, FileName, OpenBookErrorText);

        TempExcelBuffer.ReadSheetContinous(SetsSheetTok, false);
        ReadSets(TempMixMatchSet);
        TempExcelBuffer.ReadSheetContinous(ItemsSheetTok, false);
        ReadSetItems(TempMixMatchSet, TempMixMatchSetItem);
        TempExcelBuffer.ReadSheetContinous(TiersSheetTok, false);
        ReadTiers(TempMixMatchSet, TempMixMatchSetItem, TempMixMatchRule);
        TempExcelBuffer.ReadSheetContinous(SetupSheetTok, false);
        BestDiscThreshold := ReadSetup(FileLcyCode);
        TempExcelBuffer.CloseBook();

        if GeneralLedgerSetup.Get() then
            if (FileLcyCode <> '') and (GeneralLedgerSetup."LCY Code" <> '') and (FileLcyCode <> GeneralLedgerSetup."LCY Code") then
                CurrencyWarningText := StrSubstNo(CurrencyWarningTxt, FileLcyCode, GeneralLedgerSetup."LCY Code");

        TempMixMatchSet.Reset();
        TempMixMatchSetItem.Reset();
        TempMixMatchRule.Reset();
        if not Confirm(
             ConfirmImportQst, false,
             TempMixMatchSet.Count(), TempMixMatchSetItem.Count(), TempMixMatchRule.Count(), FileName,
             CountExistingSets(TempMixMatchSet), BestDiscThreshold, CurrencyWarningText)
        then
            exit;

        // No commits from here on: an error while writing or activating rolls back the whole import.
        WriteSets(TempMixMatchSet, TempMixMatchSetItem, TempMixMatchRule, NewSetCount, ReplacedSetCount);
        ActivatedSetCount := ActivateSets(TempMixMatchSet);
        WriteSetup(BestDiscThreshold);

        TempMixMatchSet.Reset();
        Message(
          ImportDoneMsg, TempMixMatchSet.Count(), NewSetCount, ReplacedSetCount,
          TempMixMatchSetItem.Count(), TempMixMatchRule.Count(), ActivatedSetCount, BestDiscThreshold);
    end;

    local procedure StartSheet()
    begin
        TempExcelBuffer.Reset();
        TempExcelBuffer.DeleteAll();
        TempExcelBuffer.ClearNewRow();
    end;

    local procedure AddSetsSheet()
    var
        MixMatchSet: Record "Mix Match Set";
    begin
        TempExcelBuffer.NewRow();
        AddHeaderCell(CodeColTok, '');
        AddHeaderCell(DescriptionColTok, '');
        AddHeaderCell(StartingDateColTok, BlankDateCommentTxt);
        AddHeaderCell(EndingDateColTok, BlankDateCommentTxt);
        AddHeaderCell(CountingUoMColTok, CountingUoMCommentTxt);
        AddHeaderCell(ActiveColTok, ActiveCommentTxt);

        if MixMatchSet.FindSet() then
            repeat
                TempExcelBuffer.NewRow();
                AddTextCell(MixMatchSet."Code");
                AddTextCell(MixMatchSet.Description);
                AddDateCell(MixMatchSet."Starting Date");
                AddDateCell(MixMatchSet."Ending Date");
                AddTextCell(MixMatchSet."Unit of Measure Code");
                AddYesNoCell(MixMatchSet.Active);
            until MixMatchSet.Next() = 0;
    end;

    local procedure AddItemsSheet()
    var
        MixMatchSetItem: Record "Mix Match Set Item";
    begin
        TempExcelBuffer.NewRow();
        AddHeaderCell(SetCodeColTok, '');
        AddHeaderCell(ItemNoColTok, '');
        AddHeaderCell(DescriptionColTok, ReferenceOnlyCommentTxt);

        MixMatchSetItem.SetAutoCalcFields(Description);
        if MixMatchSetItem.FindSet() then
            repeat
                TempExcelBuffer.NewRow();
                AddTextCell(MixMatchSetItem."Set Code");
                AddTextCell(MixMatchSetItem."Item No.");
                AddTextCell(MixMatchSetItem.Description);
            until MixMatchSetItem.Next() = 0;
    end;

    local procedure AddTiersSheet()
    var
        MixMatchRule: Record "Mix Match Rule";
    begin
        TempExcelBuffer.NewRow();
        AddHeaderCell(SetCodeColTok, '');
        AddHeaderCell(TypeColTok, TypeCommentTxt);
        AddHeaderCell(MinimumQuantityColTok, '');
        AddHeaderCell(DiscountPctColTok, '');
        AddHeaderCell(FreeQuantityColTok, '');
        AddHeaderCell(FreeQtyPerMultipleColTok, YesNoCommentTxt);
        AddHeaderCell(DefaultFreeItemNoColTok, FreeItemCommentTxt);

        MixMatchRule.SetCurrentKey("Set Code", "Minimum Quantity");
        if MixMatchRule.FindSet() then
            repeat
                TempExcelBuffer.NewRow();
                AddTextCell(MixMatchRule."Set Code");
                AddTextCell(GetRuleTypeName(MixMatchRule.Type));
                AddNumberCell(MixMatchRule."Minimum Quantity");
                AddNumberCell(MixMatchRule."Discount %");
                AddNumberCell(MixMatchRule."Free Quantity");
                AddYesNoCell(MixMatchRule."Free Qty. per Multiple");
                AddTextCell(MixMatchRule."Default Free Item No.");
            until MixMatchRule.Next() = 0;
    end;

    local procedure AddSetupSheet()
    var
        MixMatchSetup: Record "Mix Match Setup";
        GeneralLedgerSetup: Record "General Ledger Setup";
    begin
        TempExcelBuffer.NewRow();
        AddHeaderCell(BestDiscThresholdColTok, '');
        AddHeaderCell(LcyCodeColTok, ReferenceOnlyCommentTxt);

        if GeneralLedgerSetup.Get() then;
        TempExcelBuffer.NewRow();
        AddNumberCell(MixMatchSetup.GetBestDiscountThreshold());
        AddTextCell(GeneralLedgerSetup."LCY Code");
    end;

    local procedure AddHeaderCell(Heading: Text; CommentText: Text)
    begin
        TempExcelBuffer.AddColumn(Heading, false, CommentText, true, false, false, '', TempExcelBuffer."Cell Type"::Text);
    end;

    local procedure AddTextCell(Value: Text)
    begin
        TempExcelBuffer.AddColumn(Value, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Text);
    end;

    local procedure AddNumberCell(Value: Decimal)
    begin
        TempExcelBuffer.AddColumn(Value, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Number);
    end;

    local procedure AddDateCell(Value: Date)
    begin
        if Value = 0D then
            AddTextCell('')
        else
            TempExcelBuffer.AddColumn(Value, false, '', false, false, false, '', TempExcelBuffer."Cell Type"::Date);
    end;

    local procedure AddYesNoCell(Value: Boolean)
    begin
        if Value then
            AddTextCell(YesTok)
        else
            AddTextCell(NoTok);
    end;

    local procedure ReadSets(var TempMixMatchSet: Record "Mix Match Set" temporary)
    var
        UnitOfMeasure: Record "Unit of Measure";
        SetCode: Text;
        RowNo: Integer;
    begin
        CheckHeaderCell(SetsSheetTok, 1, CodeColTok);
        CheckHeaderCell(SetsSheetTok, 2, DescriptionColTok);
        CheckHeaderCell(SetsSheetTok, 3, StartingDateColTok);
        CheckHeaderCell(SetsSheetTok, 4, EndingDateColTok);
        CheckHeaderCell(SetsSheetTok, 5, CountingUoMColTok);
        CheckHeaderCell(SetsSheetTok, 6, ActiveColTok);

        for RowNo := 2 to GetLastRowNo() do
            if not IsRowBlank(RowNo, 6) then begin
                SetCode := GetCodeValue(SetsSheetTok, RowNo, 1, CodeColTok, MaxStrLen(TempMixMatchSet."Code"), true);
                if TempMixMatchSet.Get(SetCode) then
                    Error(DuplicateSetErr, SetsSheetTok, GetCellReference(RowNo, 1), SetCode);

                TempMixMatchSet.Init();
                TempMixMatchSet."Code" := CopyStr(SetCode, 1, MaxStrLen(TempMixMatchSet."Code"));
                TempMixMatchSet.Description := CopyStr(GetTextValue(SetsSheetTok, RowNo, 2, DescriptionColTok, MaxStrLen(TempMixMatchSet.Description)), 1, MaxStrLen(TempMixMatchSet.Description));
                TempMixMatchSet."Starting Date" := GetDateValue(SetsSheetTok, RowNo, 3, StartingDateColTok);
                TempMixMatchSet."Ending Date" := GetDateValue(SetsSheetTok, RowNo, 4, EndingDateColTok);
                if (TempMixMatchSet."Starting Date" <> 0D) and (TempMixMatchSet."Ending Date" <> 0D) and
                   (TempMixMatchSet."Starting Date" > TempMixMatchSet."Ending Date")
                then
                    Error(DateRangeErr, SetsSheetTok, RowNo, SetCode);

                TempMixMatchSet."Unit of Measure Code" := CopyStr(GetCodeValue(SetsSheetTok, RowNo, 5, CountingUoMColTok, MaxStrLen(TempMixMatchSet."Unit of Measure Code"), false), 1, MaxStrLen(TempMixMatchSet."Unit of Measure Code"));
                if TempMixMatchSet."Unit of Measure Code" <> '' then
                    if not UnitOfMeasure.Get(TempMixMatchSet."Unit of Measure Code") then
                        Error(UnitOfMeasureNotFoundErr, SetsSheetTok, GetCellReference(RowNo, 5), TempMixMatchSet."Unit of Measure Code");

                TempMixMatchSet.Active := GetYesNoValue(SetsSheetTok, RowNo, 6, ActiveColTok);
                TempMixMatchSet.Insert();
            end;
    end;

    local procedure ReadSetItems(var TempMixMatchSet: Record "Mix Match Set" temporary; var TempMixMatchSetItem: Record "Mix Match Set Item" temporary)
    var
        Item: Record Item;
        SetCode: Text;
        ItemNo: Text;
        RowNo: Integer;
    begin
        CheckHeaderCell(ItemsSheetTok, 1, SetCodeColTok);
        CheckHeaderCell(ItemsSheetTok, 2, ItemNoColTok);

        for RowNo := 2 to GetLastRowNo() do
            if not IsRowBlank(RowNo, 2) then begin
                SetCode := GetCodeValue(ItemsSheetTok, RowNo, 1, SetCodeColTok, MaxStrLen(TempMixMatchSetItem."Set Code"), true);
                if not TempMixMatchSet.Get(SetCode) then
                    Error(SetNotOnSetsSheetErr, ItemsSheetTok, GetCellReference(RowNo, 1), SetCode);

                ItemNo := GetCodeValue(ItemsSheetTok, RowNo, 2, ItemNoColTok, MaxStrLen(TempMixMatchSetItem."Item No."), true);
                if not Item.Get(ItemNo) then
                    Error(ItemNotFoundErr, ItemsSheetTok, GetCellReference(RowNo, 2), ItemNo);
                if TempMixMatchSetItem.Get(SetCode, ItemNo) then
                    Error(DuplicateItemErr, ItemsSheetTok, RowNo, ItemNo, SetCode);

                TempMixMatchSetItem.Init();
                TempMixMatchSetItem."Set Code" := CopyStr(SetCode, 1, MaxStrLen(TempMixMatchSetItem."Set Code"));
                TempMixMatchSetItem."Item No." := CopyStr(ItemNo, 1, MaxStrLen(TempMixMatchSetItem."Item No."));
                TempMixMatchSetItem.Insert();
            end;
    end;

    // Checks each tier on its own. Tier ordering rules are checked when an Active set is activated,
    // the same as when tiers are entered by hand.
    local procedure ReadTiers(var TempMixMatchSet: Record "Mix Match Set" temporary; var TempMixMatchSetItem: Record "Mix Match Set Item" temporary; var TempMixMatchRule: Record "Mix Match Rule" temporary)
    var
        RuleType: Enum "Mix Match Rule Type";
        SetCode: Text;
        FreeItemNo: Text;
        MinimumQuantity: Decimal;
        DiscountPct: Decimal;
        FreeQuantity: Decimal;
        FreeQtyPerMultiple: Boolean;
        RowNo: Integer;
    begin
        CheckHeaderCell(TiersSheetTok, 1, SetCodeColTok);
        CheckHeaderCell(TiersSheetTok, 2, TypeColTok);
        CheckHeaderCell(TiersSheetTok, 3, MinimumQuantityColTok);
        CheckHeaderCell(TiersSheetTok, 4, DiscountPctColTok);
        CheckHeaderCell(TiersSheetTok, 5, FreeQuantityColTok);
        CheckHeaderCell(TiersSheetTok, 6, FreeQtyPerMultipleColTok);
        CheckHeaderCell(TiersSheetTok, 7, DefaultFreeItemNoColTok);

        for RowNo := 2 to GetLastRowNo() do
            if not IsRowBlank(RowNo, 7) then begin
                SetCode := GetCodeValue(TiersSheetTok, RowNo, 1, SetCodeColTok, MaxStrLen(TempMixMatchRule."Set Code"), true);
                if not TempMixMatchSet.Get(SetCode) then
                    Error(SetNotOnSetsSheetErr, TiersSheetTok, GetCellReference(RowNo, 1), SetCode);

                RuleType := GetRuleTypeValue(TiersSheetTok, RowNo, 2);
                MinimumQuantity := GetDecimalValue(TiersSheetTok, RowNo, 3, MinimumQuantityColTok, true);
                DiscountPct := GetDecimalValue(TiersSheetTok, RowNo, 4, DiscountPctColTok, false);
                FreeQuantity := GetDecimalValue(TiersSheetTok, RowNo, 5, FreeQuantityColTok, false);
                FreeQtyPerMultiple := GetYesNoValue(TiersSheetTok, RowNo, 6, FreeQtyPerMultipleColTok);
                FreeItemNo := GetCodeValue(TiersSheetTok, RowNo, 7, DefaultFreeItemNoColTok, MaxStrLen(TempMixMatchRule."Default Free Item No."), false);

                if MinimumQuantity <= 0 then
                    Error(MinimumQuantityErr, TiersSheetTok, GetCellReference(RowNo, 3));
                if DiscountPct > 100 then
                    Error(DiscountTooHighErr, TiersSheetTok, GetCellReference(RowNo, 4));
                case RuleType of
                    RuleType::Discount:
                        begin
                            if (FreeQuantity <> 0) or FreeQtyPerMultiple or (FreeItemNo <> '') then
                                Error(DiscountTierHasFreeGoodsErr, TiersSheetTok, RowNo);
                            if DiscountPct = 0 then
                                Error(MissingDiscountErr, TiersSheetTok, RowNo, RuleType);
                        end;
                    RuleType::"Free Goods":
                        begin
                            if DiscountPct <> 0 then
                                Error(FreeGoodsTierHasDiscountErr, TiersSheetTok, RowNo);
                            if FreeQuantity = 0 then
                                Error(MissingFreeQuantityErr, TiersSheetTok, RowNo, RuleType);
                        end;
                    RuleType::"Discount and Free Goods":
                        begin
                            if DiscountPct = 0 then
                                Error(MissingDiscountErr, TiersSheetTok, RowNo, RuleType);
                            if FreeQuantity = 0 then
                                Error(MissingFreeQuantityErr, TiersSheetTok, RowNo, RuleType);
                        end;
                end;
                if FreeItemNo <> '' then
                    if not TempMixMatchSetItem.Get(SetCode, FreeItemNo) then
                        Error(FreeItemNotInSetErr, TiersSheetTok, GetCellReference(RowNo, 7), FreeItemNo, SetCode);

                TempMixMatchRule.Init();
                TempMixMatchRule."Set Code" := CopyStr(SetCode, 1, MaxStrLen(TempMixMatchRule."Set Code"));
                TempMixMatchRule."Line No." := GetNextTierLineNo(TempMixMatchRule, TempMixMatchRule."Set Code");
                TempMixMatchRule.Type := RuleType;
                TempMixMatchRule."Minimum Quantity" := MinimumQuantity;
                TempMixMatchRule."Discount %" := DiscountPct;
                TempMixMatchRule."Free Quantity" := FreeQuantity;
                TempMixMatchRule."Free Qty. per Multiple" := FreeQtyPerMultiple;
                TempMixMatchRule."Default Free Item No." := CopyStr(FreeItemNo, 1, MaxStrLen(TempMixMatchRule."Default Free Item No."));
                TempMixMatchRule.Insert();
            end;
    end;

    local procedure ReadSetup(var FileLcyCode: Code[10]): Decimal
    begin
        CheckHeaderCell(SetupSheetTok, 1, BestDiscThresholdColTok);
        FileLcyCode := CopyStr(GetCodeValue(SetupSheetTok, 2, 2, LcyCodeColTok, MaxStrLen(FileLcyCode), false), 1, MaxStrLen(FileLcyCode));
        exit(GetDecimalValue(SetupSheetTok, 2, 1, BestDiscThresholdColTok, true));
    end;

    local procedure GetNextTierLineNo(var TempMixMatchRule: Record "Mix Match Rule" temporary; SetCode: Code[20]) LineNo: Integer
    var
        TempLastMixMatchRule: Record "Mix Match Rule" temporary;
    begin
        TempLastMixMatchRule.Copy(TempMixMatchRule, true);
        TempLastMixMatchRule.Reset();
        TempLastMixMatchRule.SetRange("Set Code", SetCode);
        if TempLastMixMatchRule.FindLast() then
            LineNo := TempLastMixMatchRule."Line No.";
        LineNo += 10000;
    end;

    local procedure CountExistingSets(var TempMixMatchSet: Record "Mix Match Set" temporary) ExistingCount: Integer
    var
        MixMatchSet: Record "Mix Match Set";
    begin
        if TempMixMatchSet.FindSet() then
            repeat
                if MixMatchSet.Get(TempMixMatchSet."Code") then
                    ExistingCount += 1;
            until TempMixMatchSet.Next() = 0;
    end;

    local procedure WriteSets(var TempMixMatchSet: Record "Mix Match Set" temporary; var TempMixMatchSetItem: Record "Mix Match Set Item" temporary; var TempMixMatchRule: Record "Mix Match Rule" temporary; var NewSetCount: Integer; var ReplacedSetCount: Integer)
    var
        MixMatchSet: Record "Mix Match Set";
        MixMatchSetItem: Record "Mix Match Set Item";
        MixMatchRule: Record "Mix Match Rule";
    begin
        TempMixMatchSet.Reset();
        if not TempMixMatchSet.FindSet() then
            exit;

        repeat
            if MixMatchSet.Get(TempMixMatchSet."Code") then begin
                // Tiers can only change on an inactive set; the set is activated again afterwards if the file says so.
                if MixMatchSet.Active then
                    MixMatchSet.Deactivate();
                MixMatchSetItem.SetRange("Set Code", MixMatchSet."Code");
                MixMatchSetItem.DeleteAll();
                MixMatchRule.SetRange("Set Code", MixMatchSet."Code");
                MixMatchRule.DeleteAll();
                ReplacedSetCount += 1;
            end else begin
                MixMatchSet.Init();
                MixMatchSet."Code" := TempMixMatchSet."Code";
                MixMatchSet.Insert(true);
                NewSetCount += 1;
            end;

            MixMatchSet.Validate(Description, TempMixMatchSet.Description);
            MixMatchSet.Validate("Starting Date", TempMixMatchSet."Starting Date");
            MixMatchSet.Validate("Ending Date", TempMixMatchSet."Ending Date");
            MixMatchSet.Validate("Unit of Measure Code", TempMixMatchSet."Unit of Measure Code");
            MixMatchSet.Modify(true);

            TempMixMatchSetItem.SetRange("Set Code", TempMixMatchSet."Code");
            if TempMixMatchSetItem.FindSet() then
                repeat
                    MixMatchSetItem.Init();
                    MixMatchSetItem."Set Code" := TempMixMatchSetItem."Set Code";
                    MixMatchSetItem.Validate("Item No.", TempMixMatchSetItem."Item No.");
                    MixMatchSetItem.Insert(true);
                until TempMixMatchSetItem.Next() = 0;

            // Items are inserted first because Default Free Item No. must be one of the set's items.
            TempMixMatchRule.SetRange("Set Code", TempMixMatchSet."Code");
            if TempMixMatchRule.FindSet() then
                repeat
                    MixMatchRule.Init();
                    MixMatchRule."Set Code" := TempMixMatchRule."Set Code";
                    MixMatchRule."Line No." := TempMixMatchRule."Line No.";
                    MixMatchRule.Validate(Type, TempMixMatchRule.Type);
                    MixMatchRule.Validate("Minimum Quantity", TempMixMatchRule."Minimum Quantity");
                    MixMatchRule.Validate("Discount %", TempMixMatchRule."Discount %");
                    MixMatchRule.Validate("Free Quantity", TempMixMatchRule."Free Quantity");
                    MixMatchRule.Validate("Free Qty. per Multiple", TempMixMatchRule."Free Qty. per Multiple");
                    MixMatchRule.Validate("Default Free Item No.", TempMixMatchRule."Default Free Item No.");
                    MixMatchRule.Insert(true);
                until TempMixMatchRule.Next() = 0;
        until TempMixMatchSet.Next() = 0;

        TempMixMatchSetItem.Reset();
        TempMixMatchRule.Reset();
    end;

    // Activation runs the same checks as the Activate action, including overlaps with active sets that aren't in the file.
    local procedure ActivateSets(var TempMixMatchSet: Record "Mix Match Set" temporary) ActivatedSetCount: Integer
    var
        MixMatchSet: Record "Mix Match Set";
    begin
        TempMixMatchSet.Reset();
        TempMixMatchSet.SetRange(Active, true);
        if TempMixMatchSet.FindSet() then
            repeat
                MixMatchSet.Get(TempMixMatchSet."Code");
                MixMatchSet.Activate();
                ActivatedSetCount += 1;
            until TempMixMatchSet.Next() = 0;
        TempMixMatchSet.Reset();
    end;

    local procedure WriteSetup(BestDiscThreshold: Decimal)
    var
        MixMatchSetup: Record "Mix Match Setup";
    begin
        if not MixMatchSetup.Get() then begin
            MixMatchSetup.Init();
            MixMatchSetup.Insert(true);
        end;
        MixMatchSetup.Validate("Best Disc. Threshold (LCY)", BestDiscThreshold);
        MixMatchSetup.Modify(true);
    end;

    local procedure CheckHeaderCell(SheetName: Text; ColumnNo: Integer; ExpectedHeading: Text)
    var
        ActualHeading: Text;
    begin
        ActualHeading := GetCellText(1, ColumnNo);
        if UpperCase(ActualHeading) <> UpperCase(ExpectedHeading) then
            Error(WrongHeaderErr, SheetName, GetCellReference(1, ColumnNo), ExpectedHeading, ActualHeading);
    end;

    local procedure GetLastRowNo(): Integer
    begin
        TempExcelBuffer.Reset();
        if TempExcelBuffer.FindLast() then
            exit(TempExcelBuffer."Row No.");
        exit(0);
    end;

    local procedure IsRowBlank(RowNo: Integer; ColumnCount: Integer): Boolean
    var
        ColumnNo: Integer;
    begin
        for ColumnNo := 1 to ColumnCount do
            if GetCellText(RowNo, ColumnNo) <> '' then
                exit(false);
        exit(true);
    end;

    local procedure GetCellText(RowNo: Integer; ColumnNo: Integer): Text
    begin
        if TempExcelBuffer.Get(RowNo, ColumnNo) then
            exit(DelChr(TempExcelBuffer."Cell Value as Text", '<>', ' '));
        exit('');
    end;

    local procedure GetCellReference(RowNo: Integer; ColumnNo: Integer): Text
    begin
        exit(CopyStr(ColumnLettersTok, ColumnNo, 1) + Format(RowNo));
    end;

    local procedure GetCodeValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer; Heading: Text; MaxLength: Integer; Required: Boolean): Text
    var
        ValueText: Text;
    begin
        ValueText := UpperCase(GetCellText(RowNo, ColumnNo));
        if (ValueText = '') and Required then
            Error(ValueRequiredErr, SheetName, GetCellReference(RowNo, ColumnNo), Heading);
        if StrLen(ValueText) > MaxLength then
            Error(ValueTooLongErr, SheetName, GetCellReference(RowNo, ColumnNo), Heading, MaxLength);
        exit(ValueText);
    end;

    local procedure GetTextValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer; Heading: Text; MaxLength: Integer): Text
    var
        ValueText: Text;
    begin
        ValueText := GetCellText(RowNo, ColumnNo);
        if StrLen(ValueText) > MaxLength then
            Error(ValueTooLongErr, SheetName, GetCellReference(RowNo, ColumnNo), Heading, MaxLength);
        exit(ValueText);
    end;

    // Number cells come back in the session's number format; typed text may use either that or a plain 1234.5 format.
    local procedure GetDecimalValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer; Heading: Text; Required: Boolean) Value: Decimal
    var
        ValueText: Text;
    begin
        ValueText := GetCellText(RowNo, ColumnNo);
        if ValueText = '' then begin
            if Required then
                Error(ValueRequiredErr, SheetName, GetCellReference(RowNo, ColumnNo), Heading);
            exit(0);
        end;
        if not Evaluate(Value, ValueText) then
            if not Evaluate(Value, ValueText, 9) then
                Error(InvalidNumberErr, SheetName, GetCellReference(RowNo, ColumnNo), ValueText, Heading);
        if Value < 0 then
            Error(NegativeNumberErr, SheetName, GetCellReference(RowNo, ColumnNo), Heading);
    end;

    // Date cells come back in the session's date format. Also accepts typed ISO dates (2026-09-14) and
    // Excel date serial numbers, which appear when a date cell has lost its date formatting.
    local procedure GetDateValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer; Heading: Text) Value: Date
    var
        ValueText: Text;
        SerialNo: Decimal;
    begin
        ValueText := GetCellText(RowNo, ColumnNo);
        if ValueText = '' then
            exit(0D);

        if (StrLen(ValueText) = 10) and (CopyStr(ValueText, 5, 1) = '-') and (CopyStr(ValueText, 8, 1) = '-') then
            if Evaluate(Value, ValueText, 9) then
                exit(Value);

        if (StrLen(ValueText) = 5) and (DelChr(ValueText, '=', '0123456789') = '') then
            if Evaluate(SerialNo, ValueText) then
                exit(DT2Date(TempExcelBuffer.ConvertDateTimeDecimalToDateTime(SerialNo)));

        if not Evaluate(Value, ValueText) then
            Error(InvalidDateErr, SheetName, GetCellReference(RowNo, ColumnNo), ValueText, Heading);
    end;

    local procedure GetYesNoValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer; Heading: Text) Value: Boolean
    var
        ValueText: Text;
    begin
        ValueText := GetCellText(RowNo, ColumnNo);
        case UpperCase(ValueText) of
            '', 'NO', 'N', 'FALSE', '0':
                exit(false);
            'YES', 'Y', 'TRUE', '1':
                exit(true);
        end;
        if not Evaluate(Value, ValueText) then
            Error(InvalidYesNoErr, SheetName, GetCellReference(RowNo, ColumnNo), ValueText, Heading);
    end;

    // Exported as the enum value name so the file doesn't depend on the user's language; captions are accepted too.
    local procedure GetRuleTypeValue(SheetName: Text; RowNo: Integer; ColumnNo: Integer) RuleType: Enum "Mix Match Rule Type"
    var
        ValueText: Text;
        TypeNames: List of [Text];
        TypeOrdinals: List of [Integer];
        Index: Integer;
    begin
        ValueText := UpperCase(GetCellText(RowNo, ColumnNo));
        if ValueText = '' then
            Error(ValueRequiredErr, SheetName, GetCellReference(RowNo, ColumnNo), TypeColTok);

        TypeNames := Enum::"Mix Match Rule Type".Names();
        TypeOrdinals := Enum::"Mix Match Rule Type".Ordinals();
        for Index := 1 to TypeOrdinals.Count() do begin
            RuleType := Enum::"Mix Match Rule Type".FromInteger(TypeOrdinals.Get(Index));
            if (ValueText = UpperCase(TypeNames.Get(Index))) or (ValueText = UpperCase(Format(RuleType))) then
                exit(RuleType);
        end;
        Error(InvalidTypeErr, SheetName, GetCellReference(RowNo, ColumnNo), GetCellText(RowNo, ColumnNo));
    end;

    local procedure GetRuleTypeName(RuleType: Enum "Mix Match Rule Type"): Text
    begin
        exit(RuleType.Names().Get(RuleType.Ordinals().IndexOf(RuleType.AsInteger())));
    end;
}
