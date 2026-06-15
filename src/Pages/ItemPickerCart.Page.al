page 50100 "Item Picker Cart"
{
    PageType = Card;
    Caption = 'Add Items to Sales Lines';

    layout
    {
        area(content)
        {
            usercontroladdin(ItemPickerCart)
            {
                ApplicationArea = All;
                HorizontalShrink = true;
                HorizontalStretch = true;
                VerticalShrink = true;
                VerticalStretch = true;

                trigger ControlAddInReady()
                begin
                    SearchItems('');
                end;

                trigger RequestSearch(searchText: Text)
                begin
                    SearchItems(searchText);
                end;

                trigger AddLines(cartJson: Text)
                begin
                    AddLinesToDocument(cartJson);
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
        Media: Record Media;
        Base64Convert: Codeunit "Base64 Convert";
        PictureInStream: InStream;
        MimeType: Text;
    begin
        Item.CalcFields(Picture);
        if not Item.Picture.HasValue() then
            exit('');

        MimeType := 'image/png';
        if Media.Get(Item.Picture.MediaId()) then
            if Media."Mime Type" <> '' then
                MimeType := Media."Mime Type";

        Item.Picture.CreateInStream(PictureInStream);
        exit('data:' + MimeType + ';base64,' + Base64Convert.ToBase64(PictureInStream));
    end;

    local procedure AddLinesToDocument(CartJson: Text)
    var
        SalesLine: Record "Sales Line";
        CartArray: JsonArray;
        CartToken: JsonToken;
        CartObject: JsonObject;
        ValueToken: JsonToken;
        ItemNo: Code[20];
        Quantity: Decimal;
        NextLineNo: Integer;
    begin
        if not SalesHeaderSet then
            exit;

        if not CartArray.ReadFrom(CartJson) then
            exit;

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
    end;
}
