# pos_tablet

A new Flutter project.

## EllanPOS branding

The bundled `assets/branding/ellan_pos.png` artwork is used by the splash,
sign-in/onboarding screens and home header, including offline. Company-specific
branding and store names remain separate.

To regenerate Android, iOS and web launcher icons after replacing the artwork:

```sh
flutter pub get
dart run flutter_launcher_icons
```

Linux uses the bundled artwork as its GTK window icon. Windows and macOS runner
projects are not included. Native launcher icon changes need a full rebuild and
reinstall; hot reload is not enough. Installed web apps may cache the old icon.

## Launch layout profile

The home top bar provides a text **Lock** action on phones and tablets.
Staff logout remains available from My Profile, not the top bar or its menu.

The monorepo launcher defaults to the tablet profile:

```sh
./run.sh
./run.sh android
```

Pass `--mobile` to preview the mobile layout on a wider browser, desktop or
tablet screen:

```sh
./run.sh --mobile
./run.sh web 9090 --mobile
./run.sh android Pixel_7 --mobile
```

The mobile profile constrains the app viewport to 480 logical pixels and
centers it on wider displays. On a phone, it uses the available screen width.
The setting is passed as `APP_LAYOUT` by the launcher; direct Flutter launches
can use `--dart-define=APP_LAYOUT=mobile`.

## Offline catalogue images

Run Products sync while online after adding or changing variant images in admin.
The sibling `pos-core-ib-main` package downloads S3/local-storage images to the
device's persistent database directory. Order tiles, catalogue cards and cart
thumbnails use those saved files and do not need internet after a successful sync.
Persisted cart drafts retain the local image path.

If an image cannot be downloaded, sync reports a failure and keeps the previous
saved image. Check connectivity/storage permissions and sync again. A product with
no image, or whose image has not yet synced, displays a placeholder. Rebuild the
app with the updated local core package; the SQLite cache migration is automatic.

## Dine-in table availability

The order picker reads active floors and tables from the local store database
instead of displaying a fixed floor plan. Booked tables are greyed out and cannot
be selected. Availability is checked again before opening an order; use Refresh
to reload it after another order closes. Sync/configure floors and tables if the
picker is empty. Load failures disable selection and provide Retry.

Checkout and saved drafts keep the stable table ID separately from its display
name, so identically named tables on different floors are not confused. Existing
orders can continue using their own tables. Table occupancy reflects open orders
stored on this device: independently offline devices cannot see one another's
unsynced bookings.

## Billing after KOT

Sending KOT keeps the open order's basket, discounts, tax and tips available for
billing. The history tab shows the kitchen batch, but BILL remains available
and completes the same order rather than creating another one. KOT is disabled
until more items/quantities are added. Saved KOT drafts can also be reopened from
the home screen to continue billing after leaving the order screen.

## Credit payment summaries

A credit tender finalizes the sale but is not money received. Full-credit sales
show Unpaid with zero paid; split cash/card/online and credit sales show Partial
with only the received amount in paid totals. The remaining balance is shown on
the invoice, order summary and payments screen. The order can remain Closed
while its credit is outstanding.

Collect debt through Credits. Allocated repayments increase the order's paid
total, and reversed repayments restore its outstanding balance. Existing orders
previously marked Paid on credit are corrected when read from the local database.

## Deleting orders and freeing tables

Starting a new order does not create an order ID. One is created only when a
product is persisted: KOT, checkout, or saving a SQLite draft from billing.
Saving a draft from billing for an order that already has a KOT updates that
order's saved cart draft instead of creating a duplicate order.

The order page Delete button removes the whole order: the cart, its saved draft
and any open KOT order, then frees the table. An untouched new order is simply
closed. The orders table and order details offer Delete for unpaid open orders
without products, and for drafts. Home → Saved drafts can delete a draft and
its open order too. Orders already sent to the kitchen or synced are kept as
Cancelled, with kitchen cancellations logged. Other orders are deleted. Orders
with payments must be refunded and cancelled instead. Cancelled and completed
orders no longer occupy tables.

## Product and variant offers

Offers come from the backend offers sync and
are applied offline in the cart preview, at checkout and in order details. The
gateway sends offers linked to a specific variant, and expands offers linked to
a whole product (store product or org master product) to all of the store's
variants. It skips variants marked as excluded. Supported benefits are
percentage, flat, buy M get N, buy M get N at a percentage off, and fixed
price (for example "3 for ₹80"). Offers that expire or are removed upstream
disappear from the device on the next offers sync. An offer applies only while
it is published, active and within its effective dates.

## Material form and table styling

The application uses `PosTheme.light()` for shared Material 3 form fields,
dialogs, sheets, buttons and table defaults. Fields have rounded outlines,
floating labels, visible focus/error states and consistent spacing. Customer
and order-entry sheets inherit these defaults rather than drawing heavy custom
borders. Keep input behavior and validation in the individual forms.

Credit dialogs scroll when the keyboard reduces available height. Billing,
order-list and dashboard table surfaces use the theme's surface/outline colors;
billing and dashboard rows have subtle alternating backgrounds. Keep numeric
columns right-aligned and let long item descriptions wrap.

When adding forms, prefer `InputDecoration(labelText: ...)` without specifying
plain borders. Use the component themes rather than recreating per-dialog
button or field styles. Specialized layouts (for example the large tender amount
entry) may retain their sizing while inheriting focus/error styling.

## Phone and tablet layouts

Android and iOS support portrait and landscape. Checkout uses full-width
Item/Order or Item/Payments tabs below 900 logical pixels and side-by-side
panels on wider displays. Short layouts can scroll the checkout panels,
including when the keyboard is open. Product grids adapt their column count
to the available width.

Category boxes use bold labels and stable accent colors, with a filled color
and checkmark for the selection. Tap anywhere on a product tile to add it;
tiles keep the price, offers and quantity badge without a separate plus button.
Product tiles show the parent product in bold with the variant on a separate
line underneath. Cart labels retain the full name (for example, `Tea (Regular)`)
so products with the same variant name remain identifiable.

Compact home screens use a scrollable menu. Order history switches from table
rows to cards with the same payment, edit, print and eligible-delete actions;
Sales and Purchases expose a New Order floating action button. Filters wrap
into multiple rows below 1100 logical pixels. Company logo controls and trade
choices stack when their container cannot fit both controls.

Use `AdaptiveFormRow` for grouped controls and shared Material touch targets.
Choose layouts by available space, not by platform or physical device type.

## Syncing catalogue edits and variant add-ons

The products sync sends every new or changed variant, including variants whose
add-on groups changed. After the first sync the device stores the server ids,
and later syncs send those ids. The backend reuses the variant's existing
product and category, or matches by server id. It creates a master category and
product, plus the store copies, only for items that have never synced. This
means re-syncing an item, adding a product to a synced category, or linking
add-ons to a variant does not duplicate categories or products in the admin
panel. Add-on groups are matched by name on the variant.

Deleting a package (or a category) on Store setup marks it as deleted on the
device until the next sync exports it. Each sync downloads the catalogue before
uploading local changes, so the download leaves any catalogue item with local
changes not yet uploaded (deletes or edits) as it is on the device. Once the
backend gets the delete it marks the variant, and its product and category when
no other active items are left, as deleted and inactive. They then disappear
from the admin panel and from later catalogue downloads.

Use the switch on each package in Store setup → Products to make it active or
inactive. Inactive packages stay on the device, labelled "Inactive", and are
hidden from billing. The change is sent at the next sync, like any other edit.
The backend sets the variant's `active` flag. It marks the store product
inactive when none of its variants are active, and active again as soon as one
is. Toggling a variant or product in the admin panel reaches the device on the
next sync. The device downloads the catalogue with `includeInactive=1` and
receives each variant's `active` value, which is 0 when either the variant or
its product is inactive. Older app builds don't send `includeInactive`, so they
still get only active items. The `product_variants.active` column was added in
schema v54.

## Editing company details offline

Settings → Company saves name, contact, address, registration, tax and
identifier on the device first, marked as pending sync (`profile_pending_sync`).
If the gateway is reachable and you are signed in, the change is pushed to
`/api/pos/store/profile` straight away. Otherwise the screen shows "Not synced
yet" and the next Sync (manual or auto) pushes it. Store directory refreshes
at login or reopen keep pending edits and a pending logo instead of
overwriting them. If the server rejects the update, its message is shown and
the edit stays on the device until it is corrected and saved again.

## Adding customers offline

The customer sheet (used for credit checkout and order start) creates customers
through the gateway. If the gateway can't be reached (no network, timeout, or
a non-JSON proxy page), `UiStoreController.createDirectoryCustomer` saves the
retail/business customer locally under a provisional `local_cust_…` id, so a
credit sale can be completed offline. Suppliers still require a connection.
The next customer sync replaces the provisional id with the backend
`user_{id}` before credits are exported.

## Order times and the organisation timezone

Order times are shown in the store's configured IANA timezone
(`DeviceSetupStore.timezoneForStore`, exposed as
`UiStoreController.orgTimezoneName`), not the device clock. The order list,
"Last 24 hours" filter, KOT history, credit account dates and printed
receipts (`Store.receiptTimestampFormatter`, set in `initServiceLocator`) all
go through `OrgTimezone`. UTC (`…Z`) and naive device-local values are both
handled; date-only values such as due dates are kept as calendar days.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
