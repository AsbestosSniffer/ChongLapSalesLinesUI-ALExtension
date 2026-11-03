page 50100 "Item Picker Cart"
{
    PageType = Card;
    Caption = 'Add Items to Sales Lines';

    layout
    {
        area(content)
        {
            usercontrol(ItemPickerCart; ItemPickerCart)
            {
                ApplicationArea = All;

                trigger ControlAddInReady()
                begin
                    SearchItems('');
                end;

                trigger RequestSearch(searchText: Text)
                begin
                    SearchItems(searchText);
                end;

                trigger AddLines(cartJson: Text; paymentOption: Text)
                begin
                    AddLinesToDocument(cartJson, paymentOption);
                    CurrPage.Close();
                end;

                trigger RequestClose()
                begin
                    CurrPage.Close();
                end;
            }
        }
    }

    var
        SalesHeader: Record "Sales Header";
        SalesHeaderSet: Boolean;

    procedure SetSalesHeader(NewSalesHeader: Record "Sales Header")
    begin
        SalesHeader := NewSalesHeader;
        SalesHeaderSet := true;
    end;

    local procedure SearchItems(SearchText: Text)
    var
        Item: Record Item;
        ItemsArray: JsonArray;
        FoundItems: Dictionary of [Code[20], Boolean];
        ItemsJsonText: Text;
        MaxResults: Integer;
    begin
        MaxResults := 30;

        if SearchText = '' then begin
            Item.SetRange(Blocked, false);
            AddItemsToArray(Item, ItemsArray, FoundItems, MaxResults);
        end else begin
            Item.Reset();
            Item.SetRange(Blocked, false);
            Item.SetFilter("No.", '@*' + SearchText + '*');
            AddItemsToArray(Item, ItemsArray, FoundItems, MaxResults);

            Item.Reset();
            Item.SetRange(Blocked, false);
            Item.SetFilter(Description, '@*' + SearchText + '*');
            AddItemsToArray(Item, ItemsArray, FoundItems, MaxResults);
        end;

        ItemsArray.WriteTo(ItemsJsonText);
        CurrPage.ItemPickerCart.LoadItems(ItemsJsonText);
    end;

    local procedure AddItemsToArray(var Item: Record Item; var ItemsArray: JsonArray; var FoundItems: Dictionary of [Code[20], Boolean]; MaxResults: Integer)
    var
        ItemObject: JsonObject;
    begin
        if not Item.FindSet() then
            exit;

        repeat
            if ItemsArray.Count() >= MaxResults then
                exit;

            if not FoundItems.ContainsKey(Item."No.") then begin
                FoundItems.Add(Item."No.", true);

                Clear(ItemObject);
                ItemObject.Add('no', Item."No.");
                ItemObject.Add('description', Item.Description);
                ItemObject.Add('unitPrice', Item."Unit Price");
                ItemObject.Add('uom', Item."Base Unit of Measure");
                ItemObject.Add('picture', GetItemPictureAsBase64(Item));
                ItemsArray.Add(ItemObject);
            end;
        until Item.Next() = 0;
    end;

    local procedure GetItemPictureAsBase64(var Item: Record Item): Text
    var
        TenantMedia: Record "Tenant Media";
        Base64Convert: Codeunit "Base64 Convert";
        PictureInStream: InStream;
        MimeType: Text;
    begin
        if Item.Picture.Count() = 0 then
            exit('');

        if not TenantMedia.Get(Item.Picture.Item(1)) then
            exit('');

        TenantMedia.CalcFields(Content);
        if not TenantMedia.Content.HasValue() then
            exit('');

        MimeType := TenantMedia."Mime Type";
        if MimeType = '' then
            MimeType := 'image/png';

        TenantMedia.Content.CreateInStream(PictureInStream);
        exit('data:' + MimeType + ';base64,' + Base64Convert.ToBase64(PictureInStream));
    end;

    local procedure AddLinesToDocument(CartJson: Text; PaymentOption: Text)
    var
        SalesLine: Record "Sales Line";
        CartArray: JsonArray;
        CartToken: JsonToken;
        CartObject: JsonObject;
        ValueToken: JsonToken;
        ItemNo: Code[20];
        Quantity: Decimal;
        NextLineNo: Integer;
        PaymentDays: Integer;
        InvoiceDiscountPct: Decimal;
        InvalidPaymentOptionErr: Label 'Select either 30 days / 0% or 7 days / 2%.';
        InvalidCartErr: Label 'The cart could not be read. Close Quick Add and try again.';
    begin
        if not SalesHeaderSet then
            exit;

        if not CartArray.ReadFrom(CartJson) then
            Error(InvalidCartErr);

        case PaymentOption of
            '30':
                begin
                    PaymentDays := 30;
                    InvoiceDiscountPct := 0;
                end;
            '7':
                begin
                    PaymentDays := 7;
                    InvoiceDiscountPct := 2;
                end;
            else
                Error(InvalidPaymentOptionErr);
        end;

        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        SalesHeader.TestStatusOpen();
        SalesHeader.Validate("Payment Terms Code", GetPaymentTermsCode(PaymentDays));
        SalesHeader.Modify(true);

        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindLast() then
            NextLineNo := SalesLine."Line No."
        else
            NextLineNo := 0;

        foreach CartToken in CartArray do begin
            CartObject := CartToken.AsObject();

            ItemNo := '';
            if CartObject.Get('no', ValueToken) then
                ItemNo := CopyStr(ValueToken.AsValue().AsText(), 1, MaxStrLen(ItemNo));

            Quantity := 0;
            if CartObject.Get('quantity', ValueToken) then
                Quantity := ValueToken.AsValue().AsDecimal();

            if (ItemNo <> '') and (Quantity <> 0) then begin
                NextLineNo += 10000;

                SalesLine.Init();
                SalesLine."Document Type" := SalesHeader."Document Type";
                SalesLine."Document No." := SalesHeader."No.";
                SalesLine."Line No." := NextLineNo;
                SalesLine.Insert(true);

                SalesLine.Validate(Type, SalesLine.Type::Item);
                SalesLine.Validate("No.", ItemNo);
                SalesLine.Validate(Quantity, Quantity);
                SalesLine.Modify(true);
            end;
        end;

        ApplyInvoiceDiscount(InvoiceDiscountPct);
    end;

    local procedure GetPaymentTermsCode(PaymentDays: Integer): Code[10]
    var
        PaymentTerms: Record "Payment Terms";
        DueDateCalculation: DateFormula;
        MissingPaymentTermsErr: Label 'Set up a payment term with a due date calculation of %1 days and a payment discount of 0% before using this option.', Comment = '%1 = number of days';
    begin
        Evaluate(DueDateCalculation, StrSubstNo('<%1D>', PaymentDays));
        PaymentTerms.SetRange("Due Date Calculation", DueDateCalculation);
        // The selected discount is an invoice discount, not a cash payment discount.
        PaymentTerms.SetRange("Discount %", 0);
        if not PaymentTerms.FindFirst() then
            Error(MissingPaymentTermsErr, PaymentDays);

        exit(PaymentTerms.Code);
    end;

    local procedure ApplyInvoiceDiscount(InvoiceDiscountPct: Decimal)
    var
        SalesLine: Record "Sales Line";
        Currency: Record Currency;
        DocumentTotals: Codeunit "Document Totals";
        SalesCalcDiscountByType: Codeunit "Sales - Calc Discount By Type";
        InvoiceDiscountAmount: Decimal;
    begin
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        if SalesHeader."Currency Code" = '' then
            Currency.InitRoundingPrecision()
        else
            Currency.Get(SalesHeader."Currency Code");

        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        // Use the same calculation as the standard Invoice Discount % field.
        InvoiceDiscountAmount := Round(
            DocumentTotals.CalcTotalSalesAmountOnlyDiscountAllowed(SalesLine) * InvoiceDiscountPct / 100,
            Currency."Amount Rounding Precision");
        SalesCalcDiscountByType.ApplyInvDiscBasedOnAmt(InvoiceDiscountAmount, SalesHeader);
    end;
}
