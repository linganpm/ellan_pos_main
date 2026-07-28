import 'dart:io';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final tempDir = await Directory.systemTemp.createTemp('table_seed_example_');
  final seedFile = File('${tempDir.path}/tables_seed.json');

  Store? sourceStore;
  Store? targetStore;

  try {
    sourceStore = await Store.createForTest(config: config);
    final sourceSession = await sourceStore.auth.login(
      sourceStore.scope,
      const StoreLoginRequest(
        email: 'charlie@example.com',
        password: 'charliepass',
      ),
    );
    if (sourceSession == null) {
      throw StateError('Admin login failed for source seed example store.');
    }

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
        floorId: 'floor_rooftop',
        name: 'Roof Top',
        sortingOrder: 2,
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
        tableId: 'table_g2',
        floorId: 'floor_ground',
        name: 'G2',
        capacity: 2,
        sortingOrder: 2,
      ),
    );
    await sourceStore.tables.saveTable(
      sourceStore.scope,
      const StoreSaveTableRequest(
        tableId: 'table_r1',
        floorId: 'floor_rooftop',
        name: 'R1',
        capacity: 8,
        sortingOrder: 1,
        active: false,
      ),
    );

    final exportedData = await sourceStore.tables.exportToJsonData(
      sourceStore.scope,
    );
    print('Exported table seed payload:');
    print(exportedData);

    await sourceStore.tables.exportToJsonFile(sourceStore.scope, seedFile.path);
    print('Seed file written to ${seedFile.path}');

    await sourceStore.auth.logout();
    await sourceStore.close();
    sourceStore = null;

    targetStore = await Store.createForTest(
      config: config,
      // tableJson removed: use only API sync
    );
    final targetSession = await targetStore.auth.login(
      targetStore.scope,
      StoreLoginRequest(
        email: config.defaultLogin.email,
        password: config.defaultLogin.password,
      ),
    );
    if (targetSession == null) {
      throw StateError('Default login failed for target seed example store.');
    }

    final importedFloors = await targetStore.tables.listFloors(
      targetStore.scope,
    );
    final importedTables = await targetStore.tables.listTables(
      targetStore.scope,
      includeInactive: true,
      includeOccupied: true,
    );

    print('Imported floors:');
    for (final floor in importedFloors) {
      print(
        '  ${floor.floorId}: name=${floor.name} sorting=${floor.sortingOrder} active=${floor.active}',
      );
    }

    print('Imported tables:');
    for (final table in importedTables) {
      print(
        '  ${table.tableId}: label=${table.displayLabel} capacity=${table.capacity} active=${table.active} occupied=${table.occupied}',
      );
    }
  } finally {
    await sourceStore?.auth.logout();
    await sourceStore?.close();
    await targetStore?.auth.logout();
    await targetStore?.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}
