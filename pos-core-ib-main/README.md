# pos_orders_offline

Dart package for offline orders management with API and SQLite integration.

## Features
- Orders list API client (interface only, implementation hidden)
- Order model with JSON serialization
- SQLite integration for offline storage
- Repository pattern for fetching and caching orders
- Example usage

## Usage
```dart
import 'package:pos_orders_offline/pos_orders_offline.dart';

void main() async {
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';

  final organisation = await Store.resolveOrganisationByCodeFromUrl(
    orgCode,
    lookupUrl: discoveryUrl,
  );
  final config = await StoreConfig.loadRemoteForOrganisation(
    orgCode: orgCode,
    lookupUrl: discoveryUrl,
  );
  final bootstrap = await Store.syncOrganisationBootstrap(
    orgCode: orgCode,
    config: config,
  );
  final login = await Store.loginToOrganisation(
    orgCode: organisation!.orgCode,
    email: config.defaultLogin.email,
    password: config.defaultLogin.password,
    config: config,
  );
  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'readme-device-001',
    make: 'Linux',
    model: 'README Example',
    lat: 0,
    lan: 0,
  );
  final store = await Store.openAccessibleStore(
    login: login!,
    storeId: bootstrap!.stores.first.storeId,
    deviceRegistration: deviceRegistration,
    config: config,
  );

  // When connectivity comes back, refresh device/store access before sync.
  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );

  final orders = await store.orders.listSummaries(store.scope);
  print(orders);

  await store.close();
}
```

This package now supports a discovery-first startup flow: the app only needs a single bootstrap lookup URL at install time. From that URL it can resolve the organisation by `orgCode`, fetch the remote `config.json`, and then continue with login, device registration, and sync using the returned backend URLs.

For UI handoff examples, see [UI_INTEGRATION.md](UI_INTEGRATION.md), [UI_CUBIT_INTEGRATION.md](UI_CUBIT_INTEGRATION.md), [example/ui_integration_example.dart](example/ui_integration_example.dart), and [example/sync_frontend_integration_example.dart](example/sync_frontend_integration_example.dart). The sync frontend example now demonstrates a restore-aware flow that exports an order with nested items plus a credit repayment allocation graph before showing what a fresh-device restore should rebuild.

For order pricing mode examples, see [example/order_pricing_mode_example.dart](example/order_pricing_mode_example.dart). It demonstrates that `selling` is the default ordering mode when `pricingMode` is omitted, and shows how the same product and add-on resolve to `buy_price` when an order is created with `StoreOrderPricingMode.buying`.

For dashboard reporting, use `store.dashboard.orderStatisticsGraph(...)` when you want the backend-style daily totals payload and `store.dashboard.snapshot(...)` when you also need top products, top categories, payment split, and credit summary for a dashboard screen.

Example:

```dart
final statistics = await store.dashboard.orderStatisticsGraph(
  store.scope,
  segment: StoreDashboardSegment.month,
  referenceDate: DateTime.now(),
);

print(statistics.data.totalCount);
print(statistics.data.totalAmount);

final snapshot = await store.dashboard.snapshot(
  store.scope,
  segment: StoreDashboardSegment.month,
  referenceDate: DateTime.now(),
  topLimit: 5,
);

print(snapshot.topCategories.map((row) => row.categoryName));
print(snapshot.topProducts.map((row) => row.displayName));
print(snapshot.creditSummary.outstandingAmount);
```

For a runnable end-to-end sample that seeds local orders and prints dashboard output, see [example/dashboard_service_example.dart](example/dashboard_service_example.dart).

For offers, see [example/order_offers_example.dart](example/order_offers_example.dart) for a seeded-offer flow and [example/offers_feature_example.dart](example/offers_feature_example.dart) for a broader demonstration of percentage, flat, and buy-N-get-M offers. The offer engine now also supports a bill-level `total_offer` type with `targetType: bill`: when the gross bill reaches `minimumBillAmount`, the configured percentage is applied to the current bill total. Orders persist three amount fields in SQLite for this flow: gross `total_value`, applied offer discount `offer_applied_value`, and payable `final_value`.

For receipt printing, see [example/order_receipt_print_example.dart](example/order_receipt_print_example.dart). A store instance can now discover printers with `store.listAvailablePrinters()`, send incremental kitchen tickets with `store.sendToKitchen(printerId, orderId, ...)`, inspect separate KOT cancellations with `store.orders.listKitchenCancellations(store.scope, orderId)`, and print a customer receipt with `store.print(printerId, orderId, templateType: ..., copies: ...)`. The built-in template types are `customer` and `kitchen`. Kitchen sends are quantity-aware and incremental: after each successful kitchen print, the sent quantity is tracked per order item, so the next kitchen send prints only the unsent quantity delta. If a previously sent quantity is reduced or removed, the cancellation is tracked separately in the KOT cancellation list. Orders can also assign tables per order item through `StoreAddOrderItemRequest(tableId: ...)`: define floors and tables with `store.tables.saveFloor(...)` and `store.tables.saveTable(...)`, list availability with `store.tables.listTables(...)` or `store.tables.listAvailableTables(...)`, and rely on open-order occupancy checks to block the same table from being attached to another order until the original order is closed. Kitchen receipts automatically include the assigned table labels for the printed items. The default adapter is simulated, so the same call returns a successful print result and the rendered receipt text without requiring hardware. During development, the simulated adapter also exposes a built-in `console-printer-01` printer that writes the rendered receipt directly to stdout for quick testing. If you want to send the same receipt to a real Linux printer queue, pass `StoreSystemPrinterAdapter()` and the package will spool it through `lp -d <printerId>`.

Floors and tables now also support local seed import/export. Use `store.tables.importFromJsonFile(...)`, `store.tables.importFromData(...)`, `store.tables.exportToJsonFile(...)`, or `store.tables.exportToJsonData(...)` with a payload shaped like `{ "floors": [...], "tables": [...] }`. For local test/example bootstrapping, `Store.createForTest(...)`, `Store.createInMemory(...)`, `Store.openPersistent(...)`, and `Store.openAccessibleStore(...)` also accept an optional `tableJson` path that seeds floors and tables during store initialization.
For end-to-end examples, see [example/table_management_example.dart](example/table_management_example.dart) for occupancy and KOT behavior, [example/table_ui_integration_example.dart](example/table_ui_integration_example.dart) for a frontend-friendly grouped-by-floor table picker payload, and [example/table_seed_example.dart](example/table_seed_example.dart) for exporting floors/tables to a seed file and importing them into a fresh store.

Local fixture environment configs, still used by tests and local tooling, are stored in:

- `fixtures/config/store_config.dev.json`
- `fixtures/config/store_config.test.json`
- `fixtures/config/store_config.production.json`

Offer seed data can also be kept in its own file, for example `fixtures/offers_data.json`, and referenced through `asset_paths.offers`.

Load them with `StoreConfig.loadForEnvironment(...)` only when you explicitly want fixture-backed local config instead of the discovery-first remote flow.

`Store.createAndInit()` now opens a persistent per-organisation SQLite database keyed by `orgId` using the configured `db_name_id` prefix, while store selection and sync remain scoped to the selected store.

When `bootstrap.device_registration_path` or `bootstrap.device_registration_url` is configured, call `Store.registerDeviceForOrganisation(...)` during the splash/bootstrap flow and pass the same device payload into `Store.openAccessibleStore(...)`. After the first successful setup, the approved device state is cached in the organisation database so the store can reopen and continue working offline.

When the app later regains connectivity, call `store.sync.refreshAccessControl(store.scope, deviceRegistration: ...)` before sync or from a connectivity-resumed callback. That refresh updates the locally cached device status and store status. If the backend has suspended the device or disabled the store, the local cache is updated immediately and further access is blocked, including offline reopen.

## Sync Configuration

Each environment config also drives sync behavior:

- `sync.base_url`: shared base URL for all remote sync endpoints.
- `sync.auto_sync_enabled`: enables or disables `store.sync.startAutoSync(store.scope)`.
- `sync.periodic_duration_seconds`: periodic interval for auto-sync.
- `sync.orders.import_path` / `sync.orders.export_path`
- `sync.products.import_path` / `sync.products.export_path`
- `sync.customers.import_path` / `sync.customers.export_path`
- `sync.credits.import_path` / `sync.credits.export_path`
- `sync.*.export_token`: bearer token used for export requests.
- `sync.*.import_batch_size`: optional page size for remote imports. Defaults to `500`.

You can still provide absolute `import_url` / `export_url` values when needed, but the default config format uses one `base_url` plus per-entity relative paths.

Orders and product variants persist an `exported` flag in SQLite. Imported records are marked exported, and locally created orders remain pending until `store.sync.exportOrders()` succeeds.

Customers and credits currently export as full snapshots for the active store scope. Credit exports include repayment rows and repayment allocation rows so the remote dataset stays restorable for replacement devices.

Orders now export nested `items` and `payments` arrays, so replacement-device restore can rebuild both the order header and its line items from remote sync data.

For large datasets, sync entry points also accept `exportBatchSize` and `onProgress`, and remote imports honor `sync.*.import_batch_size`, so the app can render live table-wise progress while exports and imports run in chunks instead of a single oversized request.

Orders can also persist multiple payment entries in SQLite. Each payment row is tied to an order and supports `cash`, `card`, `online`, and `credit` modes. Credit payments must carry a `customerId`.

When orders are imported or exported through sync, each order includes a nested `payments` array in the sync payload.

Orders and product variants also persist:

- `lastImportedAt`
- `lastExportedAt`

Each sync call is recorded in the `sync_attempts` table with:

- entity and direction
- started/completed timestamps
- processed, success, and failure counts
- skipped/success state
- message

Every Store data/sync call now requires an explicit `StoreScope` and the simplest option is `store.scope`.

Available sync entry points:

- `Store.syncOrganisationBootstrap(orgCode: ...)`
- `store.sync.importOrders(store.scope)`
- `store.sync.exportOrders(store.scope)`
- `store.sync.importProducts(store.scope)`
- `store.sync.exportProducts(store.scope)`
- `store.sync.importCustomers(store.scope)`
- `store.sync.exportCustomers(store.scope)`
- `store.sync.importCredits(store.scope)`
- `store.sync.exportCredits(store.scope)`
- `store.sync.restoreFromRemote(store.scope)`
- `store.sync.syncOrdersProductsCredits(store.scope)`
- `store.sync.runAll(store.scope)`
- `store.sync.history(store.scope)`
- `store.sync.startAutoSync(store.scope)` / `store.sync.stopAutoSync()`

Example:

```dart
final progressRows = <String, StoreSyncProgressUpdate>{};

await store.sync.runConfigured(
  store.scope,
  exportBatchSize: 500,
  onProgress: (update) {
    progressRows['${update.entity}:${update.direction}'] = update;
  },
);
```

For the splash flow, call `Store.syncOrganisationBootstrap(orgCode: ...)` after the user enters the organisation code. That returns the organisation, stores, customers, store roles, and derived organisation roles needed before login/store selection.

When remote import endpoints are configured, `Store.openAccessibleStore(...)` now restores the local store database from the remote server before finishing login, so a replacement device can recover customers, products, orders, order items, credits, repayments, and repayment allocations without relying on local asset seed files.

Use `Store.createForTest()` for isolated in-memory test stores.

## Build
Run `flutter pub run build_runner build` to generate model code.

## Notes
- Only public interfaces are exported. Implementation details are hidden.
- Update API logic in the private implementation as needed.
