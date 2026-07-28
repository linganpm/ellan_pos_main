import 'store.dart';
import 'store_config.dart';
import 'store_models.dart';

void main() async {
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';

  final organisation = await Store.resolveOrganisationByCodeFromUrl(
    orgCode,
    lookupUrl: discoveryUrl,
  );
  if (organisation == null) {
    throw StateError('Organisation lookup failed');
  }

  final config = await StoreConfig.loadRemoteForOrganisation(
    orgCode: orgCode,
    lookupUrl: discoveryUrl,
  );
  final bootstrap = await Store.syncOrganisationBootstrap(
    orgCode: orgCode,
    config: config,
  );
  if (bootstrap == null || bootstrap.stores.isEmpty) {
    throw StateError('Bootstrap failed');
  }
  final login = await Store.loginToOrganisation(
    orgCode: organisation.orgCode,
    email: config.defaultLogin.email,
    password: config.defaultLogin.password,
    config: config,
  );
  if (login == null) {
    throw StateError('Login failed');
  }
  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'example-device-001',
    make: 'Linux',
    model: 'Library Example',
    lat: 0,
    lan: 0,
  );
  await Store.registerDeviceForOrganisation(
    orgId: bootstrap.organisation.orgId,
    request: deviceRegistration,
    config: config,
  );
  final store = await Store.openAccessibleStore(
    login: login,
    storeId: bootstrap.stores.first.storeId,
    deviceRegistration: deviceRegistration,
    config: config,
  );

  // Call this when connectivity returns to refresh locally cached device/store access.
  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );

  final orders = await store.orders.listSummaries(store.scope);
  print('Offline orders:');
  for (final order in orders) {
    print('${order.orderId}: ${order.restaurantName} [${order.statusName}] total=${order.total}');
  }

  final now = DateTime.now().toIso8601String();
  final orderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: store.storeName,
      customerName: 'Walk-in Customer',
      mobile: '+1000000000',
      statusName: 'Pending',
      total: 42.0,
      serviceInstance: store.serviceInstanceId,
      createdBy: 'example',
      createdOn: now,
      paymentStatus: 'Unpaid',
      orderType: StoreOrderType.dineIn,
      payments: const [
        StoreCreateOrderPaymentRequest(
          paymentMode: StoreOrderPaymentMode.cash,
          amount: 20.0,
          referenceId: 'cash-auto-order',
        ),
      ],
    ),
  );

  await store.orders.addPayment(
    store.scope,
    orderId,
    const StoreCreateOrderPaymentRequest(
      paymentMode: StoreOrderPaymentMode.card,
      amount: 22.0,
      referenceId: 'card-auto-order',
    ),
  );

  final createdOrder = await store.orders.getById(store.scope, orderId);
  print('Created order ${createdOrder?.orderId} localId=${createdOrder?.localId} remoteId=${createdOrder?.remoteId} with ${createdOrder?.payments.length ?? 0} payments.');
  if (createdOrder != null) {
    for (final payment in createdOrder.payments) {
      print('Payment: localId=${payment.localId} remoteId=${payment.remoteId} mode=${payment.paymentMode} amount=${payment.amount} ref=${payment.referenceId}');
    }
  }

  await store.orders.updateStatus(store.scope, orderId, 'Closed');

  final closedOrder = await store.orders.getById(store.scope, orderId);
  print('Closed order ${closedOrder?.orderId} status=${closedOrder?.statusName}');

  await store.auth.logout();
  await store.close();
}
