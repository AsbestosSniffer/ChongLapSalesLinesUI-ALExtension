pageextension 50100 "HA PO PDF View" extends "Sales Order"
{
    actions
    {
        addlast(Processing)
        {
            action("ViewHAPoPdf")
            {
                ApplicationArea = All;
                Caption = 'View PO PDF';
                Image = Document;
                ToolTip = 'Open the original HA Purchase Order PDF in SharePoint.';

                trigger OnAction()
                var
                    PdfLookupUrl: Text;
                begin
                    if Rec."External Document No." = '' then begin
                        Message('This Sales Order has no External Document No. — PDF lookup is only available for orders created from HA Purchase Orders.');
                        exit;
                    end;
                    PdfLookupUrl :=
                        'https://hatobc-soprocessing-c7g5h6andta6h2hw.eastasia-01.azurewebsites.net' +
                        '/api/po_pdf?po_number=' +
                        Rec."External Document No.";
                    Hyperlink(PdfLookupUrl);
                end;
            }
        }
    }
}
