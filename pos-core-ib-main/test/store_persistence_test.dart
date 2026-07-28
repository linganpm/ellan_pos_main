import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test('Store persists metadata and orders across reopen', () async {
    final config = await loadTestConfig();
    final tempDir = await Directory.systemTemp.createTemp('store_persistence_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final createdStore = await Store.openPersistent(
      orgId: 'org_001',
      orgName: 'Persistent Organisation',
      orgCode: '900001',
      storeId: 'store_001',
      serviceInstanceId: 99,
      storeName: 'Persistent Store',
      logo: 'persistent.png',
      uniqueId: '87654321',
      contactEmail: 'persistent@store.com',
      phone: '+1999999999',
      contactPerson: 'Persistent Person',
      status: 'active',
      serviceVariantType: 'premium',
      customerJson: config.assetPaths.customers,
      databasePath: tempDir.path,
      config: config,
    );

    await loginAsDefaultTestUser(createdStore, config: config);

    await createdStore.orders.create(
      createdStore.scope,
      StoreCreateOrderRequest(
        id: 5500007001,
        orderId: 5500007001,
        restaurantName: 'Persistent Store',
        customerName: 'Persistent Customer',
        mobile: '+12223334444',
        statusName: 'Pending',
        total: 77.5,
        serviceInstance: 99,
        createdBy: 'test',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );
    await createdStore.close();

    final reopenedStore = await Store.reopenPersistent(
      orgId: 'org_001',
      storeId: 'store_001',
      uniqueId: '87654321',
      databasePath: tempDir.path,
      config: config,
    );

    expect(reopenedStore.storeName, 'Persistent Store');
    expect(reopenedStore.orgId, 'org_001');
    expect(reopenedStore.storeId, 'store_001');
    expect(reopenedStore.serviceInstanceId, 99);
    expect(await reopenedStore.auth.isLoggedIn(), true);

    final currentCustomer = await reopenedStore.auth.currentCustomer();
    expect(currentCustomer != null, true);
    expect(currentCustomer!.email, 'alice@example.com');

    final order = await reopenedStore.orders.getById(reopenedStore.scope, 5500007001);
    expect(order != null, true);
    expect(order!.restaurantName, 'Persistent Store');
    expect(order.orderType, StoreOrderType.pickUp);
    expect(order.localId.isNotEmpty, true);
    expect(order.remoteId, isNull);

    await reopenedStore.auth.logout();
    expect(await reopenedStore.auth.isLoggedIn(), false);

    await reopenedStore.close();
  });

  test('Stores in the same organisation share one physical database file', () async {
    final config = await loadTestConfig();
    final tempDir = await Directory.systemTemp.createTemp('store_org_db_test_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final firstStore = await Store.openPersistent(
      orgId: 'org_001',
      orgName: 'Persistent Organisation',
      orgCode: '900001',
      storeId: 'store_001',
      serviceInstanceId: 99,
      storeName: 'Persistent Store One',
      logo: 'persistent.png',
      uniqueId: '87654321',
      contactEmail: 'persistent1@store.com',
      phone: '+1999999999',
      contactPerson: 'Persistent Person One',
      status: 'active',
      serviceVariantType: 'premium',
      customerJson: config.assetPaths.customers,
      databasePath: tempDir.path,
      config: config,
    );
    await firstStore.close();

    final secondStore = await Store.openPersistent(
      orgId: 'org_001',
      orgName: 'Persistent Organisation',
      orgCode: '900001',
      storeId: 'store_002',
      serviceInstanceId: 100,
      storeName: 'Persistent Store Two',
      logo: 'persistent.png',
      uniqueId: '99998888',
      contactEmail: 'persistent2@store.com',
      phone: '+1888888888',
      contactPerson: 'Persistent Person Two',
      status: 'active',
      serviceVariantType: 'premium',
      databasePath: tempDir.path,
      config: config,
    );
    await secondStore.close();

    final dbFiles = await tempDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.db'))
        .cast<File>()
        .toList();

    expect(dbFiles.length, 1);
    expect(dbFiles.single.path.endsWith('${config.dbNameId}_org_001.db'), true);
  });
}