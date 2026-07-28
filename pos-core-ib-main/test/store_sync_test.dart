import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test('Store sync runConfigured uses configured endpoints only', () async {
    final requestCounts = <String, int>{
      '/orders/import': 0,
      '/orders/export': 0,
      '/customers/import': 0,
      '/customers/export': 0,
      '/credits/import': 0,
      '/credits/export': 0,
      '/tables/import': 0,
      '/tables/export': 0,
    };
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      requestCounts.update(
        request.uri.path,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (request.uri.path == '/orders/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"data": []}');
      } else if (request.uri.path == '/orders/export') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"ok":true}');
      } else if (request.uri.path == '/customers/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"data": [], "store_roles": []}');
      } else if (request.uri.path == '/customers/export') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"ok":true}');
      } else if (request.uri.path == '/credits/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"data": []}');
      } else if (request.uri.path == '/credits/export') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"ok":true}');
      } else if (request.uri.path == '/tables/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"floors": [], "tables": []}');
      } else if (request.uri.path == '/tables/export') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"ok":true}');
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final config = StoreConfig.fromJson({
      'db_name_id': 'store',
      'sync': {
        'base_url': 'http://${server.address.host}:${server.port}',
        'auto_sync_enabled': true,
        'periodic_duration_seconds': 1,
        'orders': {
          'import_path': '/orders/import',
          'export_path': '/orders/export',
          'export_token': 'orders-token',
        },
        'products': {'import_path': '', 'export_path': '', 'export_token': ''},
        'customers': {
          'import_path': '/customers/import',
          'export_path': '/customers/export',
          'export_token': 'customers-token',
        },
        'credits': {
          'import_path': '/credits/import',
          'export_path': '/credits/export',
          'export_token': 'credits-token',
        },
        'tables': {
          'import_path': '/tables/import',
          'export_path': '/tables/export',
          'export_token': 'tables-token',
        },
      },
      'session_duration_hours': 12,
      'default_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Main Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'store@example.com',
        'phone': '+1234567890',
        'contact_person': 'Manager',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'test_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Test Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'test@store.com',
        'phone': '+1234567890',
        'contact_person': 'Test Person',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'asset_paths': {
        'orders': 'fixtures/order_list.json',
        'products': 'fixtures/product_data.json',
        'customers': 'fixtures/customer_data.json',
      },
      'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
    });

    final metadata = config.testStore ?? StoreConfig.defaultTestStoreMetadata;
    final store = await Store.createInMemory(
      orgId: metadata.orgId,
      orgName: metadata.orgName,
      orgCode: metadata.orgCode,
      storeId: metadata.storeId,
      serviceInstanceId: metadata.serviceInstanceId,
      storeName: metadata.storeName,
      logo: metadata.logo,
      uniqueId: metadata.uniqueId,
      contactEmail: metadata.contactEmail,
      phone: metadata.phone,
      contactPerson: metadata.contactPerson,
      status: metadata.status,
      serviceVariantType: metadata.serviceVariantType,
      orderJson: null,
      productJson: null,
      customerJson: config.assetPaths.customers,
      config: config,
    );
    addTearDown(store.close);

    await loginAsAdmin(store);
    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: 5500009902,
        orderId: 5500009902,
        restaurantName: 'Sync Store',
        customerName: 'Sync Customer',
        mobile: '+1111111111',
        statusName: 'Pending',
        total: 12.0,
        serviceInstance: 1,
        createdBy: 'test',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );
    await store.credits.create(
      store.scope,
      StoreCreateCreditRequest(
        orgId: 'org_001',
        customerId: 'cust_001',
        orderId: 5500009902,
        amount: 12.0,
        createdOn: DateTime.now().toIso8601String(),
      ),
    );
    await store.tables.saveFloor(
      store.scope,
      const StoreSaveFloorRequest(
        floorId: 'ground',
        name: 'Ground Floor',
        sortingOrder: 1,
      ),
    );
    await store.tables.saveTable(
      store.scope,
      const StoreSaveTableRequest(
        tableId: 't1',
        floorId: 'ground',
        name: 'T1',
        capacity: 4,
        sortingOrder: 1,
      ),
    );

    final batch = await store.sync.runConfigured(store.scope);

    expect(requestCounts['/orders/import'], 1);
    expect(requestCounts['/orders/export'], 1);
    expect(requestCounts['/customers/import'], 1);
    expect(requestCounts['/customers/export'], 1);
    expect(requestCounts['/credits/import'], 1);
    expect(requestCounts['/credits/export'], 1);
    expect(requestCounts['/tables/import'], 1);
    expect(requestCounts['/tables/export'], 1);
    expect(
      batch.operations.any(
        (op) =>
            op.entity == 'customers' && op.direction == 'export' && !op.skipped,
      ),
      true,
    );
    expect(
      batch.operations.any(
        (op) =>
            op.entity == 'credits' && op.direction == 'export' && !op.skipped,
      ),
      true,
    );
    expect(
      batch.operations.any(
        (op) =>
            op.entity == 'tables' && op.direction == 'export' && !op.skipped,
      ),
      true,
    );
  });

  test(
    'Store sync kickStartAutoSync respects config enable flag and interval',
    () async {
      final disabledConfig = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://127.0.0.1:65535',
          'auto_sync_enabled': false,
          'periodic_duration_seconds': 1,
          'orders': {
            'import_path': '/orders/import',
            'export_path': '',
            'export_token': '',
          },
          'products': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final disabledStore = await Store.createForTest(config: disabledConfig);
      addTearDown(disabledStore.close);
      await loginAsAdmin(disabledStore);

      expect(disabledStore.sync.kickStartAutoSync(disabledStore.scope), false);
      expect(disabledStore.sync.isAutoSyncRunning, false);

      final requestCount = <String, int>{'/orders/import': 0};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        requestCount.update(
          request.uri.path,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        if (request.uri.path == '/orders/import') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('{"data": []}');
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final enabledConfig = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': true,
          'periodic_duration_seconds': 1,
          'orders': {
            'import_path': '/orders/import',
            'export_path': '',
            'export_token': '',
          },
          'products': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final enabledStore = await Store.createForTest(config: enabledConfig);
      addTearDown(enabledStore.close);
      await loginAsAdmin(enabledStore);

      expect(enabledStore.sync.kickStartAutoSync(enabledStore.scope), true);
      expect(enabledStore.sync.isAutoSyncRunning, true);

      for (
        var attempt = 0;
        attempt < 25 && (requestCount['/orders/import'] ?? 0) < 2;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      enabledStore.sync.stopAutoSync();

      expect(requestCount['/orders/import'], greaterThanOrEqualTo(2));
      expect(enabledStore.sync.isAutoSyncRunning, false);
    },
  );

  test(
    'Store sync emits table-wise progress updates for chunked order export',
    () async {
      final requestCounts = <String, int>{'/orders/export': 0};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        requestCounts.update(
          request.uri.path,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        if (request.uri.path == '/orders/export') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('{"ok":true}');
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final config = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': false,
          'periodic_duration_seconds': 1,
          'orders': {
            'import_path': '',
            'export_path': '/orders/export',
            'export_token': 'orders-token',
          },
          'products': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'credits': {'import_path': '', 'export_path': '', 'export_token': ''},
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final metadata = config.testStore ?? StoreConfig.defaultTestStoreMetadata;
      final store = await Store.createInMemory(
        orgId: metadata.orgId,
        orgName: metadata.orgName,
        orgCode: metadata.orgCode,
        storeId: metadata.storeId,
        serviceInstanceId: metadata.serviceInstanceId,
        storeName: metadata.storeName,
        logo: metadata.logo,
        uniqueId: metadata.uniqueId,
        contactEmail: metadata.contactEmail,
        phone: metadata.phone,
        contactPerson: metadata.contactPerson,
        status: metadata.status,
        serviceVariantType: metadata.serviceVariantType,
        orderJson: null,
        productJson: null,
        customerJson: config.assetPaths.customers,
        config: config,
      );
      addTearDown(store.close);
      await loginAsAdmin(store);

      for (final orderId in [5500009951, 5500009952]) {
        await store.orders.create(
          store.scope,
          StoreCreateOrderRequest(
            id: orderId,
            orderId: orderId,
            restaurantName: 'Chunk Sync Store',
            customerName: 'Chunk Customer',
            mobile: '+1111111111',
            statusName: 'Pending',
            total: 10.0,
            serviceInstance: 1,
            createdBy: 'test',
            createdOn: DateTime.now().toIso8601String(),
            paymentStatus: 'Unpaid',
            orderType: StoreOrderType.pickUp,
          ),
        );
      }

      final updates = <StoreSyncProgressUpdate>[];
      final result = await store.sync.runConfigured(
        store.scope,
        exportBatchSize: 1,
        onProgress: updates.add,
      );

      expect(result.operations.single.entity, 'orders');
      expect(result.operations.single.direction, 'export');
      expect(result.operations.single.successCount, 2);
      expect(requestCounts['/orders/export'], 2);

      final orderExportUpdates = updates
          .where(
            (update) =>
                update.entity == 'orders' && update.direction == 'export',
          )
          .toList();
      expect(orderExportUpdates.isNotEmpty, true);
      expect(orderExportUpdates.first.stage, StoreSyncProgressStage.running);
      expect(orderExportUpdates.first.totalCount, 2);
      expect(
        orderExportUpdates.any(
          (update) => update.batchIndex == 1 && update.processedCount == 1,
        ),
        true,
      );
      expect(
        orderExportUpdates.any(
          (update) => update.batchIndex == 2 && update.processedCount == 2,
        ),
        true,
      );
      expect(orderExportUpdates.last.stage, StoreSyncProgressStage.completed);
      expect(orderExportUpdates.last.progressFraction, 1);
    },
  );

  test(
    'Store sync exports pending orders with token and marks them exported',
    () async {
      final exportRequests = <Map<String, dynamic>>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        if (request.uri.path == '/orders/export') {
          final body = await utf8.decoder.bind(request).join();
          exportRequests.add({
            'authorization': request.headers.value(
              HttpHeaders.authorizationHeader,
            ),
            'body': jsonDecode(body) as Map<String, dynamic>,
          });
          request.response
            ..statusCode = HttpStatus.ok
            ..write('{"ok":true}');
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final config = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': false,
          'periodic_duration_seconds': 1,
          'orders': {
            'import_path': '',
            'export_path': '/orders/export',
            'export_token': 'export-token-123',
          },
          'products': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final store = await Store.createForTest(config: config);
      addTearDown(store.close);

      await loginAsAdmin(store);

      await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          id: 5500009901,
          orderId: 5500009901,
          restaurantName: 'Sync Store',
          customerName: 'Sync Customer',
          mobile: '+1111111111',
          statusName: 'Pending',
          total: 25.5,
          serviceInstance: 1,
          createdBy: 'test',
          createdOn: DateTime.now().toIso8601String(),
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
          payments: const [
            StoreCreateOrderPaymentRequest(
              paymentMode: StoreOrderPaymentMode.cash,
              amount: 10.5,
              referenceId: 'cash-sync-1',
            ),
            StoreCreateOrderPaymentRequest(
              paymentMode: StoreOrderPaymentMode.credit,
              amount: 15.0,
              customerId: 'cust_001',
              referenceId: 'credit-sync-1',
            ),
          ],
        ),
      );

      final beforeExport = await store.orders.getById(store.scope, 5500009901);
      expect(beforeExport != null, true);
      expect(beforeExport!.exported, false);
      expect(beforeExport.lastImportedAt, isNull);
      expect(beforeExport.lastExportedAt, isNull);

      final result = await store.sync.exportOrders(store.scope);
      expect(result.processedCount, 1);
      expect(result.successCount, 1);
      expect(result.failureCount, 0);
      expect(exportRequests.length, 1);
      expect(exportRequests.single['authorization'], 'Bearer export-token-123');
      final exportedOrders =
          exportRequests.single['body']['data'] as List<dynamic>;
      expect(exportedOrders.length, 1);
      final exportedOrder = exportedOrders.single as Map<String, dynamic>;
      expect((exportedOrder['local_id'] as String).isNotEmpty, true);
      expect(exportedOrder['remote_id'], isNull);
      final exportedPayments = exportedOrder['payments'] as List<dynamic>;
      expect(exportedPayments.length, 2);
      expect(
        exportedPayments.every(
          (payment) => ((payment as Map<String, dynamic>)['local_id'] as String)
              .isNotEmpty,
        ),
        true,
      );
      expect(
        exportedPayments.any(
          (payment) =>
              (payment as Map<String, dynamic>)['payment_mode'] ==
              StoreOrderPaymentMode.credit,
        ),
        true,
      );

      final afterExport = await store.orders.getById(store.scope, 5500009901);
      expect(afterExport != null, true);
      expect(afterExport!.exported, true);
      expect(afterExport.lastExportedAt, isNotNull);

      final history = await store.sync.history(store.scope);
      expect(history.isNotEmpty, true);
      expect(history.first.entity, 'orders');
      expect(history.first.direction, 'export');
      expect(history.first.successCount, 1);
      expect(history.first.failureCount, 0);
    },
  );

  test('Store sync imports orders with nested payments', () async {
    final orderJson = jsonEncode({
      'data': [
        {
          'id': 6101,
          'order_id': 6101,
          'restaurant_name': 'Sync Import Store',
          'name': 'Import Customer',
          'mobile': '+12223334444',
          'status': {'status_name': 'Paid'},
          'total': 42.75,
          'service_instance': 1,
          'created_by': 'remote',
          'created_on': '2026-03-29T10:00:00.000Z',
          'payment_status': 'Paid',
          'type_str': 'DINE-IN',
          'payments': [
            {
              'payment_mode': 'card',
              'amount': 30.25,
              'reference_id': 'card-import-1',
              'created_on': '2026-03-29T10:00:00.000Z',
              'updated_on': '2026-03-29T10:00:00.000Z',
            },
            {
              'id': 'credit-6101',
              'payment_mode': 'credit',
              'amount': 12.5,
              'customerId': 'cust_001',
              'reference_id': 'credit-import-1',
              'created_on': '2026-03-29T10:01:00.000Z',
              'updated_on': '2026-03-29T10:01:00.000Z',
            },
          ],
        },
      ],
    });
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      if (request.uri.path == '/orders/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(orderJson);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final config = StoreConfig.fromJson({
      'db_name_id': 'store',
      'sync': {
        'base_url': 'http://${server.address.host}:${server.port}',
        'auto_sync_enabled': false,
        'periodic_duration_seconds': 1,
        'orders': {
          'import_path': '/orders/import',
          'export_path': '',
          'export_token': '',
        },
        'products': {'import_path': '', 'export_path': '', 'export_token': ''},
        'customers': {'import_path': '', 'export_path': '', 'export_token': ''},
      },
      'session_duration_hours': 12,
      'default_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Main Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'store@example.com',
        'phone': '+1234567890',
        'contact_person': 'Manager',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'test_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Test Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'test@store.com',
        'phone': '+1234567890',
        'contact_person': 'Test Person',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'asset_paths': {
        'orders': 'fixtures/order_list.json',
        'products': 'fixtures/product_data.json',
        'customers': 'fixtures/customer_data.json',
      },
      'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
    });

    final store = await Store.createForTest(config: config);
    addTearDown(store.close);

    await loginAsAdmin(store);
    final result = await store.sync.importOrders(store.scope);
    expect(result.successCount, 1);

    final importedOrder = await store.orders.getById(store.scope, 6101);
    expect(importedOrder != null, true);
    expect(importedOrder!.payments.length, 2);
    expect(importedOrder.localId.isNotEmpty, true);
    expect(importedOrder.remoteId, 6101);
    expect(
      importedOrder.payments.every((payment) => payment.localId.isNotEmpty),
      true,
    );
    expect(importedOrder.orderType, StoreOrderType.dineIn);
    expect(
      importedOrder.payments.first.paymentMode,
      StoreOrderPaymentMode.card,
    );
    expect(importedOrder.payments.last.customerId, 'cust_001');
  });

  test(
    'Store sync imports orders across multiple pages and emits progress',
    () async {
      final requestUris = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        requestUris.add(request.uri);
        if (request.uri.path != '/orders/import') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final cursor = request.uri.queryParameters['cursor'];
        if (cursor == '1') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'data': [
                  {
                    'id': 6202,
                    'order_id': 6202,
                    'restaurant_name': 'Paged Import Store',
                    'name': 'Paged Customer 2',
                    'mobile': '+12223330002',
                    'status': {'status_name': 'Pending'},
                    'total': 9.5,
                    'service_instance': 1,
                    'created_by': 'remote',
                    'created_on': '2026-03-29T11:05:00.000Z',
                    'payment_status': 'Unpaid',
                    'type_str': 'PICK-UP',
                    'payments': [],
                  },
                ],
                'batch_count': 1,
                'total_count': 2,
                'next_cursor': null,
                'has_more': false,
              }),
            );
        } else {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'data': [
                  {
                    'id': 6201,
                    'order_id': 6201,
                    'restaurant_name': 'Paged Import Store',
                    'name': 'Paged Customer 1',
                    'mobile': '+12223330001',
                    'status': {'status_name': 'Paid'},
                    'total': 13.25,
                    'service_instance': 1,
                    'created_by': 'remote',
                    'created_on': '2026-03-29T11:00:00.000Z',
                    'payment_status': 'Paid',
                    'type_str': 'DINE-IN',
                    'payments': [],
                  },
                ],
                'batch_count': 1,
                'total_count': 2,
                'next_cursor': '1',
                'has_more': true,
              }),
            );
        }
        await request.response.close();
      });

      final config = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': false,
          'periodic_duration_seconds': 1,
          'orders': {
            'import_path': '/orders/import',
            'import_batch_size': 1,
            'export_path': '',
            'export_token': '',
          },
          'products': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'credits': {'import_path': '', 'export_path': '', 'export_token': ''},
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final store = await Store.createForTest(config: config);
      addTearDown(store.close);
      await loginAsAdmin(store);

      final updates = <StoreSyncProgressUpdate>[];
      final result = await store.sync.importOrders(
        store.scope,
        onProgress: updates.add,
      );

      expect(result.successCount, 2);
      expect(requestUris.length, 2);
      expect(requestUris.first.queryParameters['limit'], '1');
      expect(requestUris.last.queryParameters['cursor'], '1');
      expect((await store.orders.getById(store.scope, 6201)) != null, true);
      expect((await store.orders.getById(store.scope, 6202)) != null, true);

      final importUpdates = updates
          .where(
            (update) =>
                update.entity == 'orders' && update.direction == 'import',
          )
          .toList();
      expect(
        importUpdates.any(
          (update) =>
              update.stage == StoreSyncProgressStage.running &&
              update.processedCount == 1 &&
              update.totalCount == 2,
        ),
        true,
      );
      expect(importUpdates.last.stage, StoreSyncProgressStage.completed);
      expect(importUpdates.last.processedCount, 2);
      expect(importUpdates.last.totalCount, 2);
    },
  );

  test('Store sync ignores imported orders from other stores', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);

    server.listen((request) async {
      if (request.uri.path == '/orders/import') {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            jsonEncode({
              'data': [
                {
                  'id': 6301,
                  'orgId': 'org_001',
                  'storeId': 'store_001',
                  'order_id': 6301,
                  'restaurant_name': 'Scoped Store',
                  'name': 'Scoped Customer',
                  'mobile': '+12223330011',
                  'status': {'status_name': 'Pending'},
                  'total': 10.0,
                  'service_instance': 1,
                  'created_by': 'remote',
                  'created_on': '2026-03-29T11:00:00.000Z',
                  'payment_status': 'Unpaid',
                  'type_str': 'PICK-UP',
                  'payments': [],
                },
                {
                  'id': 6399,
                  'orgId': 'org_001',
                  'storeId': 'store_999',
                  'order_id': 6399,
                  'restaurant_name': 'Other Store',
                  'name': 'Other Customer',
                  'mobile': '+12223339999',
                  'status': {'status_name': 'Pending'},
                  'total': 99.0,
                  'service_instance': 1,
                  'created_by': 'remote',
                  'created_on': '2026-03-29T11:00:00.000Z',
                  'payment_status': 'Unpaid',
                  'type_str': 'PICK-UP',
                  'payments': [],
                },
              ],
              'batch_count': 2,
              'total_count': 2,
              'next_cursor': null,
              'has_more': false,
            }),
          );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    final config = StoreConfig.fromJson({
      'db_name_id': 'store',
      'sync': {
        'base_url': 'http://${server.address.host}:${server.port}',
        'auto_sync_enabled': false,
        'periodic_duration_seconds': 1,
        'orders': {
          'import_path': '/orders/import',
          'export_path': '',
          'export_token': '',
        },
        'products': {'import_path': '', 'export_path': '', 'export_token': ''},
        'customers': {'import_path': '', 'export_path': '', 'export_token': ''},
        'credits': {'import_path': '', 'export_path': '', 'export_token': ''},
      },
      'session_duration_hours': 12,
      'default_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Main Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'store@example.com',
        'phone': '+1234567890',
        'contact_person': 'Manager',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'test_store': {
        'org_id': 'org_001',
        'org_name': 'Sync Test Organisation',
        'org_code': '200001',
        'store_id': 'store_001',
        'service_instance_id': 1,
        'store_name': 'Test Store',
        'logo': 'logo.png',
        'unique_id': '12345678',
        'contact_email': 'test@store.com',
        'phone': '+1234567890',
        'contact_person': 'Test Person',
        'status': 'active',
        'service_variant_type': 'standard',
      },
      'asset_paths': {
        'orders': 'fixtures/order_list.json',
        'products': 'fixtures/product_data.json',
        'customers': 'fixtures/customer_data.json',
      },
      'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
    });

    final store = await Store.createForTest(config: config);
    addTearDown(store.close);
    await loginAsAdmin(store);

    final result = await store.sync.importOrders(store.scope);

    expect(result.successCount, 2);
    expect((await store.orders.getById(store.scope, 6301)) != null, true);
    expect((await store.orders.getById(store.scope, 6399)) == null, true);
  });

  test(
    'Store sync imports products and keeps imported variants exported',
    () async {
      final productJson = await File(
        'fixtures/product_data.json',
      ).readAsString();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        if (request.uri.path == '/products/import') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(productJson);
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final config = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': true,
          'periodic_duration_seconds': 1,
          'orders': {'import_path': '', 'export_path': '', 'export_token': ''},
          'products': {
            'import_path': '/products/import',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final store = await Store.createForTest(
        productJson: null,
        config: config,
      );
      addTearDown(store.close);

      await loginAsAdmin(store);

      final importResult = await store.sync.importProducts(store.scope);
      expect(importResult.processedCount, greaterThan(0));
      expect(importResult.successCount, greaterThan(0));
      expect(importResult.failureCount, 0);

      final categoryIds = await store.products.listCategoryIdsWithVariants(
        store.scope,
      );
      expect(categoryIds.isNotEmpty, true);
      final variants = await store.products.listVariantsByCategory(
        store.scope,
        categoryIds.first,
      );
      expect(variants.isNotEmpty, true);
      expect(variants.first.exported, true);
      expect(variants.first.lastImportedAt, isNotNull);
      expect(variants.first.lastExportedAt, isNull);

      final history = await store.sync.history(store.scope);
      expect(history.isNotEmpty, true);
      expect(history.first.entity, 'products');
      expect(history.first.direction, 'import');
      expect(history.first.successCount, greaterThan(0));
      expect(history.first.failureCount, 0);

      expect(store.sync.autoSyncEnabled, true);
      expect(store.sync.startAutoSync(store.scope), true);
      expect(store.sync.isAutoSyncRunning, true);
      store.sync.stopAutoSync();
      expect(store.sync.isAutoSyncRunning, false);
    },
  );

  test(
    'Store sync ignores imported products from other stores when payload includes scope metadata',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      server.listen((request) async {
        if (request.uri.path == '/products/import') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write(
              jsonEncode({
                'data': [
                  {
                    'id': 7001,
                    'orgId': 'org_001',
                    'storeId': 'store_001',
                    'name': 'Scoped Category',
                    'product_variants': [
                      {
                        'id': 7101,
                        'orgId': 'org_001',
                        'storeId': 'store_001',
                        'product_variant_name': 'Scoped Variant',
                        'product_name': 'Scoped Product',
                        'product_data': {
                          'id': 7201,
                          'orgId': 'org_001',
                          'storeId': 'store_001',
                          'name': 'Scoped Product',
                        },
                      },
                    ],
                  },
                  {
                    'id': 7002,
                    'orgId': 'org_001',
                    'storeId': 'store_999',
                    'name': 'Other Category',
                    'product_variants': [
                      {
                        'id': 7199,
                        'orgId': 'org_001',
                        'storeId': 'store_999',
                        'product_variant_name': 'Other Variant',
                        'product_name': 'Other Product',
                        'product_data': {
                          'id': 7299,
                          'orgId': 'org_001',
                          'storeId': 'store_999',
                          'name': 'Other Product',
                        },
                      },
                    ],
                  },
                ],
              }),
            );
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final config = StoreConfig.fromJson({
        'db_name_id': 'store',
        'sync': {
          'base_url': 'http://${server.address.host}:${server.port}',
          'auto_sync_enabled': false,
          'periodic_duration_seconds': 1,
          'orders': {'import_path': '', 'export_path': '', 'export_token': ''},
          'products': {
            'import_path': '/products/import',
            'export_path': '',
            'export_token': '',
          },
          'customers': {
            'import_path': '',
            'export_path': '',
            'export_token': '',
          },
          'credits': {'import_path': '', 'export_path': '', 'export_token': ''},
        },
        'session_duration_hours': 12,
        'default_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Main Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'store@example.com',
          'phone': '+1234567890',
          'contact_person': 'Manager',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'test_store': {
          'org_id': 'org_001',
          'org_name': 'Sync Test Organisation',
          'org_code': '200001',
          'store_id': 'store_001',
          'service_instance_id': 1,
          'store_name': 'Test Store',
          'logo': 'logo.png',
          'unique_id': '12345678',
          'contact_email': 'test@store.com',
          'phone': '+1234567890',
          'contact_person': 'Test Person',
          'status': 'active',
          'service_variant_type': 'standard',
        },
        'asset_paths': {
          'orders': 'fixtures/order_list.json',
          'products': 'fixtures/product_data.json',
          'customers': 'fixtures/customer_data.json',
        },
        'default_login': {
          'email': 'alice@example.com',
          'password': 'alicepass',
        },
      });

      final metadata = config.testStore ?? StoreConfig.defaultTestStoreMetadata;
      final store = await Store.createInMemory(
        orgId: metadata.orgId,
        orgName: metadata.orgName,
        orgCode: metadata.orgCode,
        storeId: metadata.storeId,
        serviceInstanceId: metadata.serviceInstanceId,
        storeName: metadata.storeName,
        logo: metadata.logo,
        uniqueId: metadata.uniqueId,
        contactEmail: metadata.contactEmail,
        phone: metadata.phone,
        contactPerson: metadata.contactPerson,
        status: metadata.status,
        serviceVariantType: metadata.serviceVariantType,
        orderJson: null,
        productJson: null,
        customerJson: config.assetPaths.customers,
        config: config,
      );
      addTearDown(store.close);
      await loginAsAdmin(store);

      final importResult = await store.sync.importProducts(store.scope);
      expect(importResult.successCount, 2);

      final categoryIds = await store.products.listCategoryIdsWithVariants(
        store.scope,
      );
      expect(categoryIds.length, 1);
      final variants = await store.products.listVariantsByCategory(
        store.scope,
        categoryIds.first,
      );
      expect(variants.length, 1);
      expect(variants.first.productVariantName, 'Scoped Variant');
    },
  );
}
