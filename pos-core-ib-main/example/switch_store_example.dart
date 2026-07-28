import 'package:pos_orders_offline/pos_orders_offline.dart';

Future<Store> _switchStoreSafely({
  required Store currentStore,
  required StoreOrganisationLoginResult login,
  required String targetStoreId,
  required StoreDeviceRegistrationRequest deviceRegistration,
}) async {
  try {
    final nextStore = await currentStore.switchAccessibleStore(
      login: login,
      storeId: targetStoreId,
      deviceRegistration: deviceRegistration,
    );
    print('Switched to store: ${nextStore.storeName} [${nextStore.storeId}]');
    return nextStore;
  } on StoreDeviceAccessException catch (error) {
    print('Switch blocked by device access: $error');
  } on StoreAuthorizationException catch (error) {
    print('Switch blocked by store authorization: $error');
  } on StoreAuthException catch (error) {
    print('Switch blocked by auth state: $error');
  } catch (error) {
    print('Switch failed unexpectedly: $error');
  }

  print('Continuing on current store: ${currentStore.storeName} [${currentStore.storeId}]');
  return currentStore;
}

Future<void> main() async {
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';
  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'switch-example-device-001',
    make: 'Linux',
    model: 'Switch Store Example',
    lat: 0,
    lan: 0,
  );

  final organisation = await Store.resolveOrganisationByCodeFromUrl(
    orgCode,
    lookupUrl: discoveryUrl,
  );
  if (organisation == null) {
    throw StateError('Organisation lookup failed');
  }

  final config = await StoreConfig.loadRemoteForOrganisation(
    orgCode: organisation.orgCode,
    lookupUrl: discoveryUrl,
  );
  final login = await Store.loginToOrganisation(
    orgCode: organisation.orgCode,
    email: config.defaultLogin.email,
    password: config.defaultLogin.password,
    config: config,
  );
  if (login == null) {
    throw StateError('Login failed');
  }
  if (login.accessibleStores.length < 2) {
    throw StateError('Switch store example requires at least two accessible stores.');
  }

  await Store.registerDeviceForOrganisation(
    orgId: organisation.orgId,
    request: deviceRegistration,
    config: config,
  );

  final firstStoreId = login.accessibleStores.first.store.storeId;
  final secondStoreId = login.accessibleStores[1].store.storeId;

  var store = await Store.openAccessibleStore(
    login: login,
    storeId: firstStoreId,
    deviceRegistration: deviceRegistration,
    config: config,
  );

  print('Opened first store: ${store.storeName} [${store.storeId}]');

  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );

  final firstStoreOrderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: store.storeName,
      customerName: 'Switch Example Customer',
      mobile: '+1000000002',
      statusName: 'Pending',
      total: 18.5,
      serviceInstance: store.serviceInstanceId,
      createdBy: 'switch-example',
      createdOn: DateTime.now().toIso8601String(),
      paymentStatus: 'Unpaid',
      orderType: StoreOrderType.dineIn,
    ),
  );

  final firstStoreOrders = await store.orders.listSummaries(store.scope);
  print('First store orders after create: ${firstStoreOrders.length}');

  final switchedStore = await _switchStoreSafely(
    currentStore: store,
    login: login,
    targetStoreId: secondStoreId,
    deviceRegistration: deviceRegistration,
  );
  final switchedToSecondStore = switchedStore.storeId == secondStoreId;
  store = switchedStore;

  final secondStoreOrders = await store.orders.listSummaries(store.scope);
  final carriedOrder = await store.orders.getById(store.scope, firstStoreOrderId);
  print('Second store orders: ${secondStoreOrders.length}');
  print('Order $firstStoreOrderId visible in second store: ${carriedOrder != null}');

  if (!switchedToSecondStore) {
    print('Skipping switch-back because the switch to $secondStoreId did not succeed.');
  } else {
    store = await _switchStoreSafely(
      currentStore: store,
      login: login,
      targetStoreId: firstStoreId,
      deviceRegistration: deviceRegistration,
    );
  }

  final reopenedOrder = await store.orders.getById(store.scope, firstStoreOrderId);
  print('Current store after switch handling: ${store.storeName} [${store.storeId}]');
  print('Order restored in original store: ${reopenedOrder != null}');

  await store.auth.logout();
  await store.close();
}