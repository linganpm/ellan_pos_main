import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final store = await Store.createForTest(config: config);

  try {
    final session = await store.auth.login(
      store.scope,
      const StoreLoginRequest(
        email: 'charlie@example.com',
        password: 'charliepass',
      ),
    );
    if (session == null) {
      throw StateError('Admin login failed for table management example.');
    }

    await store.tables.saveFloor(
      store.scope,
      const StoreSaveFloorRequest(
        floorId: 'floor_ground',
        name: 'Ground Floor',
        sortingOrder: 1,
      ),
    );
    await store.tables.saveFloor(
      store.scope,
      const StoreSaveFloorRequest(
        floorId: 'floor_first',
        name: 'First Floor',
        sortingOrder: 2,
      ),
    );

    await store.tables.saveTable(
      store.scope,
      const StoreSaveTableRequest(
        tableId: 'table_g1',
        floorId: 'floor_ground',
        name: 'G1',
        capacity: 4,
        sortingOrder: 1,
      ),
    );
    await store.tables.saveTable(
      store.scope,
      const StoreSaveTableRequest(
        tableId: 'table_g2',
        floorId: 'floor_ground',
        name: 'G2',
        capacity: 2,
        sortingOrder: 2,
      ),
    );
    await store.tables.saveTable(
      store.scope,
      const StoreSaveTableRequest(
        tableId: 'table_f1',
        floorId: 'floor_first',
        name: 'F1',
        capacity: 6,
        sortingOrder: 1,
      ),
    );

    final floors = await store.tables.listFloors(store.scope);
    print('Floors: ${floors.map((floor) => floor.name).join(', ')}');

    final tables = await store.tables.listTables(store.scope);
    print('Tables:');
    for (final table in tables) {
      print(
        '  ${table.displayLabel} capacity=${table.capacity} occupied=${table.occupied}',
      );
    }

    final createdOn = DateTime.now().toIso8601String();
    final orderOneId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Table Demo Customer 1',
        mobile: '+1000004001',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'table-management-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );
    final orderTwoId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Table Demo Customer 2',
        mobile: '+1000004002',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'table-management-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderOneId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        tableId: 'table_g1',
        quantity: 1,
        createdBy: 'table-management-example',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderOneId,
        productVariantId: 'var_40',
        productId: 'prod_40',
        tableId: 'table_f1',
        quantity: 1,
        createdBy: 'table-management-example',
        createdOn: createdOn,
      ),
    );

    final orderOneDetails = await store.orders.details(store.scope, orderOneId);
    print(
      'Order $orderOneId tables: ${orderOneDetails?.tables.map((table) => table.displayLabel).join(', ')}',
    );

    final availableAfterAssign = await store.tables.listAvailableTables(
      store.scope,
    );
    print(
      'Available tables after assigning order $orderOneId: ${availableAfterAssign.map((table) => table.displayLabel).join(', ')}',
    );

    try {
      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderTwoId,
          productVariantId: 'var_39',
          productId: 'prod_39',
          tableId: 'table_g1',
          quantity: 1,
          createdBy: 'table-management-example',
          createdOn: createdOn,
        ),
      );
    } on StoreOrderStateException catch (error) {
      print('Blocked reuse of occupied table: ${error.message}');
    }

    final kitchenResult = await store.sendToKitchen(
      'console-printer-01',
      orderOneId,
    );
    print('Kitchen print success: ${kitchenResult.success}');
    print(kitchenResult.receiptContent);

    final orderOneTotal = orderOneDetails?.total ?? 0;
    await store.orders.addPayment(
      store.scope,
      orderOneId,
      StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: orderOneTotal,
        referenceId: 'TABLE-EXAMPLE-CLOSE',
      ),
    );
    await store.orders.close(store.scope, orderOneId);

    final availableAfterClose = await store.tables.listAvailableTables(
      store.scope,
    );
    print(
      'Available tables after closing order $orderOneId: ${availableAfterClose.map((table) => table.displayLabel).join(', ')}',
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderTwoId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        tableId: 'table_g1',
        quantity: 1,
        createdBy: 'table-management-example',
        createdOn: createdOn,
      ),
    );
    print(
      'Order $orderTwoId successfully reused table_g1 after order $orderOneId closed.',
    );
  } finally {
    await store.auth.logout();
    await store.close();
  }
}
