controladdin ItemPickerCart
{
    Scripts = 'ControlAddIns/Resources/ItemPickerCart.js';
    StyleSheets = 'ControlAddIns/Resources/ItemPickerCart.css';
    StartupScript = 'ControlAddIns/Resources/ItemPickerCartStartup.js';

    RequestedHeight = 600;
    RequestedWidth = 1000;
    MinimumHeight = 400;
    MinimumWidth = 600;
    VerticalStretch = true;
    HorizontalStretch = true;
    VerticalShrink = true;
    HorizontalShrink = true;

    // AL -> JavaScript
    procedure LoadItems(itemsJson: Text);
    procedure ShowMessage(message: Text);

    // JavaScript -> AL
    event ControlAddInReady();
    event RequestSearch(searchText: Text);
    event AddLines(cartJson: Text);
    event RequestClose();
}
