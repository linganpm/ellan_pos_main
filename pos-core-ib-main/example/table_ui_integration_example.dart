import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

class TablePickerTableViewModel {
  final String tableId;
  final String tableName;
  final String displayLabel;
  final int capacity;
  final bool occupied;
  final int? occupiedOrderId;
  final String? occupiedOrderStatus;

  const TablePickerTableViewModel({
    required this.tableId,
    required this.tableName,
    required this.displayLabel,
    required this.capacity,
    required this.occupied,
    required this.occupiedOrderId,
    required this.occupiedOrderStatus,
  });

  factory TablePickerTableViewModel.fromRecord(StoreTableRecord record) {
    return TablePickerTableViewModel(
      tableId: record.tableId,
      tableName: record.name,
      displayLabel: record.displayLabel,
      capacity: record.capacity ?? 0,
      occupied: record.occupied,
      occupiedOrderId: record.occupiedOrderId,
      occupiedOrderStatus: record.occupiedOrderStatus,
    );
  }
}

class TablePickerFloorSectionViewModel {
  final String floorId;
  final String floorName;
  final List<TablePickerTableViewModel> tables;

  const TablePickerFloorSectionViewModel({
    required this.floorId,
    required this.floorName,
    required this.tables,
  });
}

class TablePickerController {
  final Store store;

  const TablePickerController(this.store);

  Future<List<TablePickerFloorSectionViewModel>> loadAvailableTablesByFloor() {
    return _loadTablesByFloor(availableOnly: true);
  }

  Future<List<TablePickerFloorSectionViewModel>> loadAllTablesByFloor() {
    return _loadTablesByFloor(availableOnly: false);
  }

  Future<List<TablePickerFloorSectionViewModel>> _loadTablesByFloor({
    required bool availableOnly,
  }) async {
    final floors = await store.tables.listFloors(store.scope);
    final tables = availableOnly
        ? await store.tables.listAvailableTables(store.scope)
        : await store.tables.listTables(store.scope, includeOccupied: true);

    final groupedTables = <String, List<StoreTableRecord>>{};
    for (final table in tables) {
      groupedTables
          .putIfAbsent(table.floorId, () => <StoreTableRecord>[])
          .add(table);
    }

    final sections = <TablePickerFloorSectionViewModel>[];
    for (final floor in floors) {
      final floorTables =
          groupedTables[floor.floorId] ?? const <StoreTableRecord>[];
      sections.add(
        TablePickerFloorSectionViewModel(
          floorId: floor.floorId,
          floorName: floor.name,
          tables: floorTables
              .map(TablePickerTableViewModel.fromRecord)
              .toList(growable: false),
        ),
      );
    }
    return sections;
  }
}

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
      throw StateError('Admin login failed for table UI integration example.');
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

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'UI Table Customer',
        mobile: '+1000005001',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'table-ui-example',
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
        createdBy: 'table-ui-example',
        createdOn: createdOn,
      ),
    );

    final controller = TablePickerController(store);
    final allSections = await controller.loadAllTablesByFloor();
    final availableSections = await controller.loadAvailableTablesByFloor();

    print('All tables grouped by floor:');
    for (final section in allSections) {
      print('${section.floorName}:');
      for (final table in section.tables) {
        print(
          '  ${table.displayLabel} capacity=${table.capacity} occupied=${table.occupied} occupiedOrderId=${table.occupiedOrderId}',
        );
      }
    }

    print('');
    print('Available tables grouped by floor:');
    for (final section in availableSections) {
      print('${section.floorName}:');
      if (section.tables.isEmpty) {
        print('  No tables available');
        continue;
      }
      for (final table in section.tables) {
        print('  ${table.displayLabel} capacity=${table.capacity}');
      }
    }
  } finally {
    await store.auth.logout();
    await store.close();
  }
}
