# UI Integration Examples

This package is designed to be consumed through a single `Store` instance.

Use the Store instance as the only entry point for:

- login and logout
- session restore
- orders
- products
- customers
- sync

## 1. Bootstrap Store

```dart
import 'package:pos_orders_offline/pos_orders_offline.dart';

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
  deviceId: 'ui-device-001',
  make: 'Linux',
  model: 'UI Bootstrap',
  lat: 0,
  lan: 0,
);
final deviceAccess = await Store.registerDeviceForOrganisation(
  orgId: bootstrap!.organisation.orgId,
  request: deviceRegistration,
  config: config,
);
if (deviceAccess != null && !deviceAccess.isActive) {
  throw StateError(deviceAccess.message ?? 'Device is not active.');
}
final store = await Store.openAccessibleStore(
  login: login!,
  storeId: bootstrap!.stores.first.storeId,
  deviceRegistration: deviceRegistration,
  config: config,
);

// After setup succeeds once, the approved device state is cached locally.
// The store can reopen offline, but when connectivity returns you should
// refresh remote access control before sync-sensitive operations.
await store.sync.refreshAccessControl(
  store.scope,
  deviceRegistration: deviceRegistration,
);
```

At install time the app only needs the discovery URL. The real backend config, including import/export endpoints and device-registration URL, is fetched after the org code is resolved.

Recommended lifecycle:

- During splash/setup: resolve org, fetch remote config, register device, open store.
- Offline after approved setup: reopen the same org/store from the local DB and continue working.
- When internet returns: call `store.sync.refreshAccessControl(...)` before sync or other privileged activity.
- If the backend has suspended the device or disabled the store, the local cache is updated and the app should stop allowing store operations.

final scope = store.scope;

## 2. Login

```dart
final session = await store.auth.login(
  scope,
  const StoreLoginRequest(
    email: 'alice@example.com',
    password: 'alicepass',
  ),
);

if (session == null) {
  // show invalid credentials message
}
```

## 3. Restore Existing Session

```dart
final isLoggedIn = await store.auth.isLoggedIn();

if (isLoggedIn) {
  final currentSession = await store.auth.currentSession();
  final currentCustomer = await store.auth.currentCustomer();
}
```

## 4. Load Orders

```dart
final orders = await store.orders.listSummaries(scope);

for (final order in orders) {
  print(order.orderId);
  print(order.restaurantName);
  print(order.exported);
  print(order.lastExportedAt);
}
```

## 5. Create Order

```dart
await store.orders.create(
  scope,
  StoreCreateOrderRequest(
    restaurantName: store.storeName,
    customerName: 'Walk-in Customer',
    mobile: '+1000000000',
    statusName: 'Pending',
    total: 55.0,
    serviceInstance: store.serviceInstanceId,
    createdBy: 'ui-app',
    createdOn: DateTime.now().toIso8601String(),
    paymentStatus: 'Unpaid',
    orderType: 'Takeaway',
  ),
);
```

## 6. Load Products

```dart
final names = await store.products.listNames(scope);
final categoryIds = await store.products.listCategoryIdsWithVariants(scope);

if (categoryIds.isNotEmpty) {
  final variants = await store.products.listVariantsByCategory(scope, categoryIds.first);
}
```

## 7. Search Customers

```dart
final customers = await store.customers.searchDetails(
  scope: scope,
  nameQuery: 'Ali',
  limit: 20,
);
```

## 8. Sync

```dart
final tableProgress = <String, StoreSyncProgressUpdate>{};

final syncResult = await store.sync.runAll(
  scope,
  exportBatchSize: 500,
  onProgress: (update) {
    tableProgress['${update.entity}:${update.direction}'] = update;
    // Trigger setState, notifier update, reducer dispatch, etc.
  },
);

final history = await store.sync.history(scope, limit: 20);
```

Useful fields for UI:

- `StoreOrderDetails.exported`
- `StoreOrderDetails.lastImportedAt`
- `StoreOrderDetails.lastExportedAt`
- `StoreProductVariantRecord.exported`
- `StoreProductVariantRecord.lastImportedAt`
- `StoreProductVariantRecord.lastExportedAt`
- `StoreSyncAttemptRecord.successCount`
- `StoreSyncAttemptRecord.failureCount`
- `StoreSyncAttemptRecord.startedAt`
- `StoreSyncAttemptRecord.completedAt`
- `StoreSyncProgressUpdate.entity`
- `StoreSyncProgressUpdate.direction`
- `StoreSyncProgressUpdate.stage`
- `StoreSyncProgressUpdate.processedCount`
- `StoreSyncProgressUpdate.totalCount`
- `StoreSyncProgressUpdate.batchIndex`
- `StoreSyncProgressUpdate.totalBatches`
- `StoreSyncProgressUpdate.progressFraction`

## 9. Logout

```dart
await store.auth.logout();
```

## 10. Error Handling

```dart
try {
  final orders = await store.orders.listSummaries(scope);
  print(orders.length);
} on StoreSessionExpiredException {
  // force user to login again
} on StoreAuthException {
  // missing or invalid session
} on StoreAuthorizationException {
  // logged in but does not have required role
}
```

## Runnable Example

See [example/ui_integration_example.dart](example/ui_integration_example.dart) for a controller-style sample and [example/sync_frontend_integration_example.dart](example/sync_frontend_integration_example.dart) for callback-driven sync screen state. The sync frontend example now covers a restore-aware scenario with order items, credits, repayments, and repayment allocations so frontend teams can model full replacement-device recovery instead of only top-level order sync.

For Flutter `Cubit` integration, see [UI_CUBIT_INTEGRATION.md](UI_CUBIT_INTEGRATION.md).