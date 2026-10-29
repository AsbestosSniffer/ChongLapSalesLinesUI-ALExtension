# FEFO Lot Assignment

Version **1.0.20261029.1** corrects lot assignment and the Lot No. List availability totals.

## Behavior

- **Assign Lot Nos.** reassigns eligible unhandled lot tracking on every item line of the current document. Bulk actions retain oldest Order Date first, then document number.
- Quantity changes in the Sales Order Subform and Shopify item-line creation use the same service for that line only. Quantity-change skips/shortages produce a notification; Shopify skips/shortages emit extension telemetry event FEFO0001.
- This assigns tracking, without adding firm reservations. Standard Create Reserv. Entry APIs populate entry numbers, signs, quantities, tracking classification and dates. Orders use Surplus; standalone invoices use Prospect, as standard Item Tracking Lines does.
- Selection uses standard item-tracking availability, scoped to the sales line's item, location and variant. It accounts for existing tracked demand and nonspecific firm reservations, and respects the bin when present. **The sales line's location is never overwritten with Company Information's default location.**
- FEFO sorts by expiration date, then lot number; blank expiration dates sort last. Receipts for the same lot are aggregated. Blocked lots are excluded. With Strict Expiration Posting enabled, lots expired before the document Posting Date (Work Date if blank) are excluded.
- The target is the outstanding base quantity. Handle/invoice tracking quantities use the standard unhandled-tracking defaults (the assigned base quantity). They are not zeroed when the source quantity to ship is zero, because that would hide the assigned demand from availability. Result messages report base units and distinct selected lots. Insufficient stock leaves a partial assignment.
- Firm reservations, posted/handled tracking, warehouse shipment/activity allocations, drop shipments, special orders, assembly supply and serial/package requirements are protected and reported as skips. Negative quantities are skipped; zero quantities clear eligible tracking.
- **Delete Lot Tracking** uses standard reservation management and the complete sales-line source identity. It observes the same line protections. Bulk removal produces one combined result.
- Item locking serializes this service's allocations for an item. Reservation and inventory locks cover availability reads and writes. No commits are introduced inside a document; an error rolls back that transaction.

## Audit before upgrading affected documents

The old extension could create a lot-bearing reservation entry with Item Tracking = None, a negative supply quantity marked positive, or an invalid reservation pair. Such entries can be invisible to standard availability.

1. Take a sandbox copy and retain the installed package/version.
2. Use **Audit Lot Tracking** in the Sales Order or Sales Invoice lines. It reads reservation entries in each line's item/location/variant inventory pool and reports the first inconsistent classification, sign or pair for each pool. It changes no data. Inspect the reported entry and its opposite-Positive record using their shared Entry No.
3. Confirm the sales-document source identity, item, location, variant, quantities, posting/warehouse state and both sides' ownership before any repair. This audit is a structural check, not proof an entry was created by this extension. Unrelated entries in the same inventory pool are included because they affect availability.
4. Have an administrator prepare a targeted, reviewed repair for confirmed legacy entries. Preserve valid firm reservations and posted/warehouse tracking. Do not globally reclassify entries or delete supply rows by matching lot/quantity.
5. Rerun the audit after each repair, then assign through the corrected action and verify totals. New assignment refuses inventory pools containing malformed entries; removal refuses malformed entries on its own line. There is deliberately no automatic upgrade/data-repair code.

## Build and automated regression suite

Run from this directory:

    .\Build.ps1
    .\Build.ps1 -IncludeTests

The script finds the installed AL extension compiler and a compatible .NET runtime, or accepts -CompilerPath, -DotnetPath and -PackageCachePath. It generates code and treats compiler warnings as errors.

- Production: .build/FEFO.1.0.20261029.1.app.
- Test-enabled: .build/FEFO.1.0.20261029.1.Tests.app.

The test-enabled package has the **same application ID/version** and includes codeunits 50148 and 50149 only when FEFO_TESTS is defined. Install it only into a disposable sandbox. Run codeunit **50148 FEFO Test Runner** using the AL debugger or the tenant's test tooling. The runner uses function-level transaction isolation, reports failures and rolls back test fixtures. Do not install both builds together; use a separate clean sandbox or uninstall the test build before installing the production build of the same version.

The 16 regression tests exercise the actual assignment service and standard availability collector: requested/available totals, competing orders, receipts sharing a lot, splitting across lots, date/tie ordering, repeat assignment/removal, alternate units, firm reservation protection, legacy-data audit, warehouse/posted protection, invoice status and exact source identity, expired/blocked lots, zero/negative quantities, standard API equivalence, nonspecific reservations location/variant isolation, and lot demand when the source quantity to ship is zero.

Fixtures use synthetic, unposted inventory and sales rows to isolate allocation behavior. They do not validate financial posting. The tests require a Business Central runtime and standard company setup; compiling them is not the same as executing them.

## Sandbox acceptance and release

1. Confirm the installed tenant version. Build against its symbols. The available local cache is BC **28.4**; the manifest retains minimum application **27.5** and runtime **15.0**. A successful 28.4 build does not establish compatibility with every earlier tenant.
2. Execute the 16 regression tests. On an item with 100 units in one lot, compare manual selection of 20 with FEFO on equivalent fresh documents. Save, close and reopen Item Tracking Lines and Lot No. List: requested **20**, available **80** in both cases.
3. Use normal customer/item/posting setup to test shipment, invoice and alternate-unit posting. Include a partially shipped line: assignment/removal must skip it without changing its tracking.
4. Test quantity increases/decreases from the Sales Order UI and a Shopify import with multiple lines. Verify only the affected line is reassigned and review shortage/skip notifications or telemetry.
5. Test current-document, selected-document and all-document actions on orders and invoices. Include two lines/orders competing for one lot and selected nonadjacent records. Check priority, shortages, skipped lines and one combined bulk result.
6. Test firm and nonspecific reservations, warehouse shipment and inventory-pick activity, serial/package items, blank expiration dates, blocked lots, different locations/variants, and zero quantities. Check base/handle/invoice quantities and that unrelated entries survive removal.
7. Run two concurrent FEFO assignments for the same item. Check that the second sees the first allocation after locks are released and that no stock is allocated twice. If either transaction errors, verify rollback.
8. Complete the legacy-data audit/targeted repair, publish the production package through the usual deployment process, and monitor FEFO0001 telemetry and bulk skip/shortage results. Keep the prior package available; reverting code does not reverse tracking already assigned.

## Verification performed locally

The production and test-enabled packages are compiled with code generation and warnings as errors against the cached BC 28.4 symbols. Runtime test execution, manual UI comparison, posting, Shopify import and concurrency checks must be completed in the tenant's sandbox before deployment. No tenant data has been changed by this source update.
