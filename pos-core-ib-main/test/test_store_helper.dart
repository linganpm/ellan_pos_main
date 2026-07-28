import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<StoreConfig> loadTestConfig() {
  return StoreConfig.loadForEnvironment(StoreEnvironment.test);
}

Future<Store> openTestStore({
  String? orderJson,
  String? productJson,
  String? customerJson,
  String? offerJson,
  String? tableJson,
  StoreConfig? config,
  StorePrinterAdapter? printerAdapter,
}) async {
  final resolvedConfig = config ?? await loadTestConfig();
  return Store.createForTest(
    orderJson: orderJson ?? resolvedConfig.assetPaths.orders,
    productJson: productJson ?? resolvedConfig.assetPaths.products,
    customerJson: customerJson ?? resolvedConfig.assetPaths.customers,
    offerJson: offerJson ?? resolvedConfig.assetPaths.offers,
    tableJson: tableJson,
    config: resolvedConfig,
    printerAdapter: printerAdapter,
  );
}

Future<StoreSession?> loginWithCredentials(
  Store store, {
  required String email,
  required String password,
}) {
  return store.auth.login(
    store.scope,
    StoreLoginRequest(email: email, password: password),
  );
}

Future<StoreSession> loginAsDefaultTestUser(
  Store store, {
  StoreConfig? config,
}) async {
  final resolvedConfig = config ?? await loadTestConfig();
  final session = await loginWithCredentials(
    store,
    email: resolvedConfig.defaultLogin.email,
    password: resolvedConfig.defaultLogin.password,
  );
  expect(
    session != null,
    true,
    reason: 'Expected default test user login to succeed',
  );
  return session!;
}

Future<StoreSession> loginAsAdmin(Store store) async {
  final session = await loginWithCredentials(
    store,
    email: 'charlie@example.com',
    password: 'charliepass',
  );
  expect(session != null, true, reason: 'Expected admin test login to succeed');
  return session!;
}

Future<Store> openLoggedInTestStore({
  String? orderJson,
  String? productJson,
  String? customerJson,
  String? offerJson,
  String? tableJson,
  StorePrinterAdapter? printerAdapter,
}) async {
  final config = await loadTestConfig();
  final store = await openTestStore(
    orderJson: orderJson,
    productJson: productJson,
    customerJson: customerJson,
    offerJson: offerJson,
    tableJson: tableJson,
    config: config,
    printerAdapter: printerAdapter,
  );
  await loginAsDefaultTestUser(store, config: config);
  return store;
}

Future<Store> openAdminLoggedInTestStore({
  String? orderJson,
  String? productJson,
  String? customerJson,
  String? offerJson,
  String? tableJson,
  StoreConfig? config,
  StorePrinterAdapter? printerAdapter,
}) async {
  final resolvedConfig = config ?? await loadTestConfig();
  final store = await openTestStore(
    orderJson: orderJson,
    productJson: productJson,
    customerJson: customerJson,
    offerJson: offerJson,
    tableJson: tableJson,
    config: resolvedConfig,
    printerAdapter: printerAdapter,
  );
  await loginAsAdmin(store);
  return store;
}
