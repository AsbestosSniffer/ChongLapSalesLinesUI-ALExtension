The Shpfy Product Mapping codeunit has this interesting 

*\ShopifyUOMCorrection\Codeunit\30181\Shpfy+Product+Mapping.dal* 172:
```al
                                    if ShopifyProduct."Has Variants" then
                                        case ShopifyVariant."UoM Option Id" of
                                            1:
                                                Founded := ItemReferenceMgt.FindByReference(CopyStr(ShopifyVariant.SKU.ToUpper(), 1, 50), "Item Reference Type"::Vendor, CopyStr(ShopifyVariant."Option 1 Value", 1, 10), ItemNo, VariantCode);
                                            2:
                                                Founded := ItemReferenceMgt.FindByReference(CopyStr(ShopifyVariant.SKU.ToUpper(), 1, 50), "Item Reference Type"::Vendor, CopyStr(ShopifyVariant."Option 2 Value", 1, 10), ItemNo, VariantCode);
                                            3:
                                                Founded := ItemReferenceMgt.FindByReference(CopyStr(ShopifyVariant.SKU.ToUpper(), 1, 50), "Item Reference Type"::Vendor, CopyStr(ShopifyVariant."Option 3 Value", 1, 10), ItemNo, VariantCode);
                                            else
                                                Founded := ItemReferenceMgt.FindByReference(CopyStr(ShopifyVariant.SKU.ToUpper(), 1, 50), "Item Reference Type"::Vendor, '', ItemNo, VariantCode);
                                        end
                                    else
                                        Founded := ItemReferenceMgt.FindByReference(CopyStr(ShopifyVariant.SKU.ToUpper(), 1, 50), "Item Reference Type"::Vendor, '', ItemNo, VariantCode);

```

But if you want to delve into the codeunit level, here's an idea for a solution that could work partially and in the important ways: we could modify the "Create Sales Document" procedure on the "Shopify Orders" page which would result in us getting the correct UoM for converted Sales Orders but the Shopify Orders page (specifically the "Unit of Measure Code" column/field) would be incorrect.  

Similarly, could create a button in the "Shopify Orders" page that would update the (incorrect) "Unit of Measure Code" by using the information in "Variant Description" ("Pcs" or "Box (10 pcs)"). 

The ideal solution would be triggered with an earlier event tho: it would trigger before the order even appears in the "Shopify Orders" page/table. But what codeunit handles that?