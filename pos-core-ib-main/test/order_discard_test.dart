import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  const tableId = 'table_d1';

  Future<Store> openStoreWithTable() async {
    final store = await openAdminLoggedInTestStore();
    await store.tables.saveFloor(
      store.scope,
      const StoreSaveFloorRequest(floorId: 'floor_d', name: 'Ground'),
    );
    await store.tables.saveTable(
      store.scope,
      const StoreSaveTableRequest(
        tableId: tableId,
        floorId: 'floor_d',
        name: 'D1',
      ),
    );
    return store;
  }

  Future<int> createOrder(Store store, {String status = 'Pending'}) {
    return store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Walk-in Customer',
        mobile: '+1000000000',
        statusName: status,
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'discard-test',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );
  }

  Future<void> addItem(Store store, int orderId) {
    return store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_39',
        productId: 'prod_39',
        tableId: tableId,
        quantity: 2,
        createdBy: 'discard-test',
        createdOn: DateTime.now().toIso8601String(),
      ),
    );
  }

  Future<bool> tableOccupied(Store store) async {
    final tables = await store.tables.listTables(
      store.scope,
      includeOccupied: true,
    );
    return tables.firstWhere((t) => t.tableId == tableId).occupied;
  }

  test('local order that never reached the kitchen is hard-deleted', () async {
    final store = await openStoreWithTable();
    addTearDown(store.close);
    final orderId = await createOrder(store);
    await addItem(store, orderId);
    expect(await tableOccupied(store), isTrue);

    expect(await store.orders.discard(store.scope, orderId), isTrue);

    expect(await store.orders.getById(store.scope, orderId), isNull);
    expect(await store.orders.listItems(store.scope, orderId), isEmpty);
    expect(await tableOccupied(store), isFalse);
  });

  test('empty pending order is deleted', () async {
    final store = await openStoreWithTable();
    addTearDown(store.close);
    final orderId = await createOrder(store);

    expect(await store.orders.discard(store.scope, orderId), isTrue);
    expect(await store.orders.getById(store.scope, orderId), isNull);
  });

  test('KOT-sent order is cancelled, logs kitchen cancellation and frees '
      'the table', () async {
    final store = await openStoreWithTable();
    addTearDown(store.close);
    final orderId = await createOrder(store);
    await addItem(store, orderId);
    await store.sendToKitchen('kitchen-printer-01', orderId);
    expect(await tableOccupied(store), isTrue);

    expect(await store.orders.discard(store.scope, orderId), isFalse);

    final order = await store.orders.getById(store.scope, orderId);
    expect(order, isNotNull);
    expect(StoreOrderStatus.isCancelled(order!.statusName), isTrue);
    final cancellations = await store.orders.listKitchenCancellations(
      store.scope,
      orderId,
    );
    expect(cancellations, hasLength(1));
    expect(cancellations.single.cancelledQuantity, 2);
    expect(await tableOccupied(store), isFalse);
  });

  test('orders with payments or closed orders cannot be discarded', () async {
    final store = await openStoreWithTable();
    addTearDown(store.close);
    final paidId = await createOrder(store);
    await addItem(store, paidId);
    await store.orders.addPayment(
      store.scope,
      paidId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: 5,
        referenceId: 'discard-cash',
      ),
    );
    await expectLater(
      () => store.orders.discard(store.scope, paidId),
      throwsA(isA<StoreOrderStateException>()),
    );
    expect(await store.orders.listItems(store.scope, paidId), isNotEmpty);

    final closedId = await createOrder(store, status: 'Closed');
    await expectLater(
      () => store.orders.discard(store.scope, closedId),
      throwsA(isA<StoreOrderStateException>()),
    );
  });

  test('cancelled orders with items no longer occupy their table', () async {
    final store = await openStoreWithTable();
    addTearDown(store.close);
    final orderId = await createOrder(store);
    await addItem(store, orderId);
    expect(await tableOccupied(store), isTrue);

    await store.orders.updateStatus(
      store.scope,
      orderId,
      StoreOrderStatus.cancelled,
    );
    expect(await tableOccupied(store), isFalse);
  });
}
