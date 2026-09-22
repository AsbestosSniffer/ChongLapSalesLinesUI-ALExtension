namespace DefaultPublisher.MixAndMatch;

// Mirrors the options of Assign-to Type on sales price lists ("Sales Price Source Type").
// All Customers is 0 so sets created before this field existed apply to all customers, as they always have.
enum 50151 "Mix Match Assign-to Type"
{
    Extensible = false;

    value(0; "All Customers")
    {
        Caption = 'All Customers';
    }
    value(1; Customer)
    {
        Caption = 'Customer';
    }
    value(2; "Customer Price Group")
    {
        Caption = 'Customer Price Group';
    }
    value(3; "Customer Disc. Group")
    {
        Caption = 'Customer Disc. Group';
    }
    value(4; Campaign)
    {
        Caption = 'Campaign';
    }
    value(5; Contact)
    {
        Caption = 'Contact';
    }
}
