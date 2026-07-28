import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test(
    'store manages floors and tables with occupancy-aware availability',
    () async {
      final store = await openAdminLoggedInTestStore();
      addTearDown(store.close);

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
      expect(floors.map((floor) => floor.name).toList(), [
        'Ground Floor',
        'First Floor',
      ]);

      final allTables = await store.tables.listTables(store.scope);
      expect(allTables.map((table) => table.displayLabel).toList(), [
        'Ground Floor / G1',
        'Ground Floor / G2',
        'First Floor / F1',
      ]);
      expect(allTables.every((table) => table.occupied == false), isTrue);

      final availableGroundTables = await store.tables.listAvailableTables(
        store.scope,
        floorId: 'floor_ground',
      );
      expect(availableGroundTables.map((table) => table.tableId).toList(), [
        'table_g1',
        'table_g2',
      ]);
    },
  );

  test(
    'table occupancy blocks other open orders and releases when order closes',
    () async {
      final store = await openAdminLoggedInTestStore();
      addTearDown(store.close);

      await store.tables.saveFloor(
        store.scope,
        const StoreSaveFloorRequest(
          floorId: 'floor_ground',
          name: 'Ground Floor',
        ),
      );
      await store.tables.saveTable(
        store.scope,
        const StoreSaveTableRequest(
          tableId: 'table_g1',
          floorId: 'floor_ground',
          name: 'G1',
          capacity: 4,
        ),
      );

      const createdOn = '2026-03-30T10:00:00.000Z';
      final orderOneId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: 'Table Customer 1',
          mobile: '9000000111',
          statusName: 'Pending',
          total: 0,
          serviceInstance: store.serviceInstanceId,
          createdBy: 'table-test',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.dineIn,
        ),
      );
      final orderTwoId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: 'Table Customer 2',
          mobile: '9000000222',
          statusName: 'Pending',
          total: 0,
          serviceInstance: store.serviceInstanceId,
          createdBy: 'table-test',
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
          createdBy: 'table-test',
          createdOn: createdOn,
        ),
      );
      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderOneId,
          productVariantId: 'var_40',
          productId: 'prod_40',
          tableId: 'table_g1',
          quantity: 1,
          createdBy: 'table-test',
          createdOn: createdOn,
        ),
      );

      final orderOneItems = await store.orders.listItems(
        store.scope,
        orderOneId,
      );
      expect(orderOneItems.every((item) => item.tableId == 'table_g1'), isTrue);
      expect(orderOneItems.every((item) => item.tableName == 'G1'), isTrue);
      expect(
        orderOneItems.every((item) => item.floorName == 'Ground Floor'),
        isTrue,
      );

      final occupiedTables = await store.tables.listTables(
        store.scope,
        includeOccupied: true,
      );
      final occupiedTable = occupiedTables.firstWhere(
        (table) => table.tableId == 'table_g1',
      );
      expect(occupiedTable.occupied, isTrue);
      expect(occupiedTable.occupiedOrderId, orderOneId);

      await expectLater(
        () => store.orders.addItem(
          store.scope,
          StoreAddOrderItemRequest(
            orderId: orderTwoId,
            productVariantId: 'var_39',
            productId: 'prod_39',
            tableId: 'table_g1',
            quantity: 1,
            createdBy: 'table-test',
            createdOn: createdOn,
          ),
        ),
        throwsA(isA<StoreOrderStateException>()),
      );

      final availableBeforeClose = await store.tables.listAvailableTables(
        store.scope,
      );
      expect(
        availableBeforeClose.any((table) => table.tableId == 'table_g1'),
        isFalse,
      );

      final orderOneDetails = await store.orders.details(
        store.scope,
        orderOneId,
      );
      expect(orderOneDetails, isNotNull);
      expect(
        orderOneDetails!.tables.map((table) => table.displayLabel).toList(),
        ['Ground Floor / G1'],
      );

      await store.orders.addPayment(
        store.scope,
        orderOneId,
        StoreCreateOrderPaymentRequest(
          paymentMode: StoreOrderPaymentMode.cash,
          amount: orderOneDetails.total,
          referenceId: 'TABLE-CLOSE-1',
        ),
      );
      await store.orders.close(store.scope, orderOneId);

      final availableAfterClose = await store.tables.listAvailableTables(
        store.scope,
      );
      expect(
        availableAfterClose.any((table) => table.tableId == 'table_g1'),
        isTrue,
      );

      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderTwoId,
          productVariantId: 'var_39',
          productId: 'prod_39',
          tableId: 'table_g1',
          quantity: 1,
          createdBy: 'table-test',
          createdOn: createdOn,
        ),
      );
      final orderTwoItems = await store.orders.listItems(
        store.scope,
        orderTwoId,
      );
      expect(orderTwoItems.single.tableId, 'table_g1');
    },
  );

  test(
    'kitchen receipt mentions assigned tables for each order item',
    () async {
      final printerAdapter = StoreSimulatedPrinterAdapter();
      final store = await openAdminLoggedInTestStore(
        printerAdapter: printerAdapter,
      );
      addTearDown(store.close);

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
        ),
      );
      await store.tables.saveTable(
        store.scope,
        const StoreSaveTableRequest(
          tableId: 'table_f1',
          floorId: 'floor_first',
          name: 'F1',
        ),
      );

      const createdOn = '2026-03-30T11:00:00.000Z';
      final orderId = await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          restaurantName: store.storeName,
          customerName: 'Kitchen Table Customer',
          mobile: '9000000333',
          statusName: 'Pending',
          total: 0,
          serviceInstance: store.serviceInstanceId,
          createdBy: 'table-kitchen-test',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.dineIn,
        ),
      );

      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: 'var_39',
          productId: 'prod_39',
          tableId: 'table_g1',
          quantity: 1,
          createdBy: 'table-kitchen-test',
          createdOn: createdOn,
        ),
      );
      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: 'var_40',
          productId: 'prod_40',
          tableId: 'table_f1',
          quantity: 1,
          createdBy: 'table-kitchen-test',
          createdOn: createdOn,
        ),
      );

      final result = await store.sendToKitchen('kitchen-printer-01', orderId);

      expect(result.success, isTrue);
      expect(result.receiptContent, contains('Table'));
      expect(result.receiptContent, contains('Ground Floor / G1'));
      expect(result.receiptContent, contains('First Floor / F1'));
      expect(
        result.receiptContent,
        contains('1. Plain Dosai x1 [Ground Floor / G1]'),
      );
      expect(
        result.receiptContent,
        contains('2. Egg Dosai x1 [First Floor / F1]'),
      );
    },
  );

  test('table seeds can be exported and imported into a fresh store', () async {
    final sourceStore = await openAdminLoggedInTestStore();
    addTearDown(sourceStore.close);

    await sourceStore.tables.saveFloor(
      sourceStore.scope,
      const StoreSaveFloorRequest(
        floorId: 'floor_ground',
        name: 'Ground Floor',
        sortingOrder: 1,
      ),
    );
    await sourceStore.tables.saveFloor(
      sourceStore.scope,
      const StoreSaveFloorRequest(
        floorId: 'floor_roof',
        name: 'Roof Top',
        sortingOrder: 3,
        active: false,
      ),
    );
    await sourceStore.tables.saveTable(
      sourceStore.scope,
      const StoreSaveTableRequest(
        tableId: 'table_g1',
        floorId: 'floor_ground',
        name: 'G1',
        capacity: 4,
        sortingOrder: 1,
      ),
    );
    await sourceStore.tables.saveTable(
      sourceStore.scope,
      const StoreSaveTableRequest(
        tableId: 'table_roof_1',
        floorId: 'floor_roof',
        name: 'R1',
        capacity: 8,
        sortingOrder: 2,
        active: false,
      ),
    );

    final tempDir = await Directory.systemTemp.createTemp('table_seed_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final seedFile = File('${tempDir.path}/tables_seed.json');

    final exportedData = await sourceStore.tables.exportToJsonData(
      sourceStore.scope,
    );
    expect(exportedData['floors'], isA<List<dynamic>>());
    expect(exportedData['tables'], isA<List<dynamic>>());
    await sourceStore.tables.exportToJsonFile(sourceStore.scope, seedFile.path);

    final importedStore = await openAdminLoggedInTestStore(
      tableJson: seedFile.path,
    );
    addTearDown(importedStore.close);

    final importedFloors = await importedStore.tables.listFloors(
      importedStore.scope,
    );
    expect(importedFloors.map((floor) => floor.floorId).toList(), [
      'floor_ground',
      'floor_roof',
    ]);
    expect(importedFloors.map((floor) => floor.active).toList(), [true, false]);

    final importedTables = await importedStore.tables.listTables(
      importedStore.scope,
      includeInactive: true,
      includeOccupied: true,
    );
    expect(importedTables.map((table) => table.tableId).toList(), [
      'table_g1',
      'table_roof_1',
    ]);
    expect(importedTables.map((table) => table.displayLabel).toList(), [
      'Ground Floor / G1',
      'Roof Top / R1',
    ]);
    expect(importedTables.map((table) => table.active).toList(), [true, false]);
    expect(importedTables.map((table) => table.capacity).toList(), [4, 8]);
    expect(importedTables.every((table) => table.occupied == false), isTrue);
  });
}
