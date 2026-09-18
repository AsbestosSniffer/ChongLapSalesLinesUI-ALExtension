namespace DefaultPublisher.MixAndMatch;

// Everyone can read the sets and run the engine (inherent permissions on the objects); this set is for users who
// maintain sets, tiers and setup.
permissionset 50150 "Mix Match"
{
    Assignable = true;
    Caption = 'Mix & Match';

    Permissions =
        tabledata "Mix Match Set" = RIMD,
        tabledata "Mix Match Set Item" = RIMD,
        tabledata "Mix Match Rule" = RIMD,
        tabledata "Mix Match Setup" = RIMD,
        table "Mix Match Set" = X,
        table "Mix Match Set Item" = X,
        table "Mix Match Rule" = X,
        table "Mix Match Setup" = X,
        codeunit "Mix Match Engine" = X,
        codeunit "Mix Match Subscribers" = X,
        codeunit "Mix Match Excel Mgt." = X,
        page "Mix Match Set List" = X,
        page "Mix Match Set Card" = X,
        page "Mix Match Set Items" = X,
        page "Mix Match Rules" = X,
        page "Mix Match Setup" = X;
}
