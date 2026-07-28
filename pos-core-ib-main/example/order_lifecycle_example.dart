import 'package:pos_orders_offline/pos_orders_offline.dart';

Future<void> main() async {
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
    orgCode: bootstrap.organisation.orgCode,
    email: config.defaultLogin.email,
    password: config.defaultLogin.password,
    config: config,
  );
  if (login == null) {
    throw StateError('Login failed');
  }
  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'example-device-002',
    make: 'Linux',
    model: 'Order Lifecycle Example',
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

  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );

  try {
    final timestamp = DateTime.now().toIso8601String();

    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Walk-in Customer',
        mobile: '+1000000000',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'order-lifecycle-example',
        createdOn: timestamp,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );
    print('Created order $orderId');

    final firstItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'variant-dosai',
        productId: 'product-dosai',
        quantity: 2,
        unitPrice: 12.5,
        finalPrice: 25,
        createdBy: 'order-lifecycle-example',
        createdOn: timestamp,
      ),
    );
    print('Added first variant, order total is now ${(await store.orders.getById(store.scope, orderId))?.total}');

    final secondItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'variant-biryani',
        productId: 'product-biryani',
        quantity: 1,
        unitPrice: 18,
        finalPrice: 18,
        createdBy: 'order-lifecycle-example',
        createdOn: timestamp,
      ),
    );
    print('Added second variant, order total is now ${(await store.orders.getById(store.scope, orderId))?.total}');

    await store.orders.updateItemQuantity(store.scope, firstItemId, 3);
    print('Increased first item quantity, order total is now ${(await store.orders.getById(store.scope, orderId))?.total}');

    await store.orders.updateItemQuantity(store.scope, firstItemId, 1);
    print('Decreased first item quantity, order total is now ${(await store.orders.getById(store.scope, orderId))?.total}');

    await store.orders.deleteItem(store.scope, secondItemId);
    final currentOrder = await store.orders.getById(store.scope, orderId);
    print('Deleted second item, order total is now ${currentOrder?.total}');

    await store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: 5,
        referenceId: 'cash-81001',
      ),
    );
    await store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.card,
        amount: 7.5,
        referenceId: 'card-81001',
      ),
    );

    try {
      await store.orders.close(store.scope, orderId);
      print('Order closed unexpectedly.');
    } on StoreOrderStateException catch (error) {
      print('Close blocked as expected: $error');
    }

    final orderBeforeFinalPayment = await store.orders.getById(store.scope, orderId);
    final currentPaid = orderBeforeFinalPayment?.payments.fold<double>(0, (sum, payment) => sum + payment.amount) ?? 0;
    final remainingAmount = (orderBeforeFinalPayment?.total ?? 0) - currentPaid;

    await store.orders.addPayment(
      store.scope,
      orderId,
      StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.online,
        amount: remainingAmount,
        referenceId: 'online-81001',
      ),
    );

    await store.orders.close(store.scope, orderId);

    final closedOrder = await store.orders.getById(store.scope, orderId);
    print('Closed order ${closedOrder?.orderId} status=${closedOrder?.statusName} total=${closedOrder?.total}');
    for (final item in await store.orders.listItems(store.scope, orderId)) {
      print('Item ${item.id}: variant=${item.productVariantId} qty=${item.quantity} finalPrice=${item.finalPrice}');
    }
    for (final payment in await store.orders.listPayments(store.scope, orderId)) {
      print('Payment: mode=${payment.paymentMode} amount=${payment.amount} ref=${payment.referenceId}');
    }
  } finally {
    await store.auth.logout();
    await store.close();
  }
}