import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

Future<int> _reservePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitForHealth(Uri healthUri) async {
  final client = HttpClient();
  try {
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        final request = await client.getUrl(healthUri);
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          await response.drain<void>();
          return;
        }
      } catch (_) {
        // Keep retrying until the server is ready.
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  } finally {
    client.close(force: true);
  }
  throw StateError('Mock remote server did not become healthy at $healthUri');
}

Future<Process> _startMockServer(int port) async {
  final process = await Process.start(
    '/home/linga/work/ellan/pos-dart-packages/.venv/bin/python',
    [
      '-m',
      'mock_remote_server.mock_remote_server',
      '--host',
      '127.0.0.1',
      '--port',
      '$port',
    ],
    environment: {
      ...Platform.environment,
      'PYTHONPATH': Directory.current.path,
      'MOCK_SERVER_ORDERS_EXPORT_TOKEN': 'orders-token',
      'MOCK_SERVER_PRODUCTS_EXPORT_TOKEN': 'products-token',
      'MOCK_SERVER_CUSTOMERS_EXPORT_TOKEN': 'customers-token',
      'MOCK_SERVER_CREDITS_EXPORT_TOKEN': 'credits-token',
      'MOCK_SERVER_TABLES_EXPORT_TOKEN': 'tables-token',
    },
  );
  unawaited(process.stdout.drain<void>());
  unawaited(process.stderr.drain<void>());
  await _waitForHealth(Uri.parse('http://127.0.0.1:$port/health'));
  return process;
}

StoreConfig _mockSyncConfig(int port) {
  return StoreConfig.fromJson({
    'db_name_id': 'store_mock_sync',
    'bootstrap': {'lookup_path': '/api/bootstrap'},
    'sync': {
      'base_url': 'http://127.0.0.1:$port',
      'auto_sync_enabled': false,
      'periodic_duration_seconds': 1,
      'orders': {
        'import_path': '/api/orders/import',
        'export_path': '/api/orders/export',
        'export_token': 'orders-token',
      },
      'products': {
        'import_path': '/api/products/import',
        'export_path': '/api/products/export',
        'export_token': 'products-token',
      },
      'customers': {
        'import_path': '/api/customers/import',
        'export_path': '/api/customers/export',
        'export_token': 'customers-token',
      },
      'credits': {
        'import_path': '/api/credits/import',
        'export_path': '/api/credits/export',
        'export_token': 'credits-token',
      },
      'tables': {
        'import_path': '/api/tables/import',
        'export_path': '/api/tables/export',
        'export_token': 'tables-token',
      },
    },
    'session_duration_hours': 12,
    'asset_paths': {
      'orders': 'fixtures/order_list.json',
      'products': 'fixtures/product_data.json',
      'customers': 'fixtures/customer_data.json',
    },
    'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
  });
}

Future<Map<String, dynamic>> _getJson(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _postJson(
  Uri uri, {
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    if (body != null) {
      final encoded = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = encoded.length;
      request.add(encoded);
    }
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    return jsonDecode(responseBody) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

Future<void> _resetMockServer(int port) async {
  await _postJson(Uri.parse('http://127.0.0.1:$port/api/reset'));
  await _setRuntimeStoreStatus('store_001', 'active');
  await _setRuntimeStoreStatus('store_002', 'active');
}

Future<({int statusCode, Map<String, dynamic> body})> _postJsonWithStatus(
  Uri uri, {
  Map<String, dynamic>? body,
}) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    if (body != null) {
      final encoded = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = encoded.length;
      request.add(encoded);
    }
    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    return (
      statusCode: response.statusCode,
      body: jsonDecode(responseBody) as Map<String, dynamic>,
    );
  } finally {
    client.close(force: true);
  }
}

Future<Store> _openEmptyInMemoryStore(
  StoreConfig config, {
  String? customerJson,
}) {
  final metadata = config.testStore ?? StoreConfig.defaultTestStoreMetadata;
  return Store.createInMemory(
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
    customerJson: customerJson,
    config: config,
  );
}

File _runtimeSeedFile(String fileName) {
  return File(
    '${Directory.current.path}/mock_remote_server/runtime/seeds/$fileName.json',
  );
}

Future<void> _updateRuntimeSeedRows(
  String fileName,
  void Function(List<Map<String, dynamic>> rows) update,
) async {
  final file = _runtimeSeedFile(fileName);
  final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final rows = (payload['data'] as List<dynamic>? ?? const [])
      .whereType<Map>()
      .map((row) => row.cast<String, dynamic>())
      .toList(growable: true);
  update(rows);
  payload['data'] = rows;
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
}

Future<void> _setRuntimeStoreStatus(String storeId, String status) {
  return _updateRuntimeSeedRows('stores', (rows) {
    for (final row in rows) {
      if (row['storeId'] == storeId || row['store_id'] == storeId) {
        row['status'] = status;
      }
    }
  });
}

void main() {
  test('Mock remote server serves environment-specific config payloads', () async {
    final port = await _reservePort();
    final process = await _startMockServer(port);
    addTearDown(() async {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return 0;
        },
      );
    });

    final productionBootstrap = await _getJson(
      Uri.parse(
        'http://127.0.0.1:$port/api/bootstrap?orgCode=100001&environment=production',
      ),
    );
    expect(
      (productionBootstrap['config_url'] as String),
      contains('environment=production'),
    );

    final productionConfig = await _getJson(
      Uri.parse(
        'http://127.0.0.1:$port/api/config?orgId=org_001&environment=production',
      ),
    );
    expect(productionConfig['environment'], 'production');
    expect(productionConfig['db_name_id'], 'store_prod');
    expect(
      (productionConfig['sync'] as Map<String, dynamic>)['auto_sync_enabled'],
      true,
    );
    expect(
      (productionConfig['sync']
          as Map<String, dynamic>)['periodic_duration_seconds'],
      900,
    );

    final testConfig = await _getJson(
      Uri.parse(
        'http://127.0.0.1:$port/api/config?orgId=org_001&environment=test',
      ),
    );
    expect(testConfig['environment'], 'test');
    expect(testConfig['db_name_id'], 'store_test');
    expect(
      (testConfig['sync'] as Map<String, dynamic>)['auto_sync_enabled'],
      false,
    );
    expect(
      (testConfig['sync'] as Map<String, dynamic>)['periodic_duration_seconds'],
      1,
    );
  });

  test(
    'Mock remote server persists device registrations and preserves inactive status',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final created = await _postJson(
        Uri.parse('http://127.0.0.1:$port/api/devices/register'),
        body: {
          'orgId': 'org_001',
          'deviceId': 'mock-device-001',
          'make': 'Acme',
          'model': 'Runner',
          'lat': 6.9271,
          'lan': 79.8612,
        },
      );
      expect(created['ok'], true);
      expect(created['status'], 'active');
      expect(created['deviceId'], 'mock-device-001');

      final listed = await _getJson(
        Uri.parse(
          'http://127.0.0.1:$port/api/devices/registrations?orgId=org_001&deviceId=mock-device-001',
        ),
      );
      expect(listed['ok'], true);
      expect(listed['total_count'], 1);
      final listedRows = listed['data'] as List<dynamic>;
      expect((listedRows.first as Map<String, dynamic>)['status'], 'active');

      final seededStates = await _getJson(
        Uri.parse(
          'http://127.0.0.1:$port/api/devices/registrations?orgId=org_001',
        ),
      );
      expect(seededStates['ok'], true);
      final seededRows = (seededStates['data'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        seededRows.any(
          (row) =>
              row['deviceId'] == 'active-device-001' &&
              row['status'] == 'active',
        ),
        true,
      );
      expect(
        seededRows.any(
          (row) =>
              row['deviceId'] == 'pending-device-001' &&
              row['status'] == 'pending',
        ),
        true,
      );
      expect(
        seededRows.any(
          (row) =>
              row['deviceId'] == 'inactive-device-001' &&
              row['status'] == 'inactive',
        ),
        true,
      );

      final inactive = await _postJson(
        Uri.parse('http://127.0.0.1:$port/api/devices/register'),
        body: {
          'orgId': 'org_001',
          'deviceId': 'inactive-device-001',
          'make': 'Seeder',
          'model': 'Blocked Unit',
          'lat': 0,
          'lan': 0,
        },
      );
      expect(inactive['ok'], true);
      expect(inactive['status'], 'inactive');
      expect(inactive['message'], contains('inactive'));

      final pending = await _postJson(
        Uri.parse('http://127.0.0.1:$port/api/devices/register'),
        body: {
          'orgId': 'org_001',
          'deviceId': 'pending-device-001',
          'make': 'Seeder',
          'model': 'Review Unit',
          'lat': 1.3521,
          'lan': 103.8198,
        },
      );
      expect(pending['ok'], true);
      expect(pending['status'], 'pending');
      expect(pending['message'], contains('pending'));
    },
  );

  test(
    'Mock remote server requires full device registration payload',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final response = await _postJsonWithStatus(
        Uri.parse('http://127.0.0.1:$port/api/devices/register'),
        body: {
          'orgId': 'org_001',
          'deviceId': 'missing-fields-001',
          'make': 'Acme',
        },
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(response.body['ok'], false);
      expect(response.body['message'], contains('model is required'));
    },
  );

  test(
    'Store sync uses the Python mock remote server for orders, products, credits, and tables',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final config = _mockSyncConfig(port);
      final store = await Store.createForTest(
        productJson: null,
        config: config,
      );
      addTearDown(store.close);
      await loginAsAdmin(store);

      await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          id: 5570000001,
          orderId: 5570000001,
          restaurantName: 'Mock Sync Store',
          customerName: 'Remote Export Customer',
          mobile: '+15555555555',
          statusName: 'Pending',
          total: 50.0,
          serviceInstance: 1,
          createdBy: 'mock-sync-test',
          createdOn: DateTime.now().toIso8601String(),
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.pickUp,
        ),
      );
      final creditId = await store.credits.create(
        store.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: 'cust_001',
          orderId: 5570000001,
          amount: 50.0,
          createdOn: '2026-03-29T12:30:00.000Z',
        ),
      );
      await store.credits.recordRepayment(
        store.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: 'cust_001',
          paymentMode: StoreCreditRepaymentMode.cash,
          totalAmount: 20.0,
          paidOn: '2026-03-29T12:45:00.000Z',
          referenceId: 'mock-sync-repayment',
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: creditId,
              allocatedAmount: 20.0,
            ),
          ],
        ),
      );
      await store.tables.saveFloor(
        store.scope,
        const StoreSaveFloorRequest(
          floorId: 'patio',
          name: 'Patio',
          sortingOrder: 1,
        ),
      );
      await store.tables.saveTable(
        store.scope,
        const StoreSaveTableRequest(
          tableId: 'p1',
          floorId: 'patio',
          name: 'Patio 1',
          capacity: 6,
          sortingOrder: 1,
        ),
      );

      final orderExportResult = await store.sync.exportOrders(store.scope);
      final productImportResult = await store.sync.importProducts(store.scope);
      final creditImportResult = await store.sync.importCredits(store.scope);
      final creditExportResult = await store.sync.exportCredits(store.scope);
      final tableImportResult = await store.sync.importTables(store.scope);
      final tableExportResult = await store.sync.exportTables(store.scope);
      expect(orderExportResult.success, true);
      expect(productImportResult.success, true);
      expect(creditImportResult.success, true);
      expect(creditExportResult.success, true);
      expect(tableImportResult.success, true);
      expect(tableExportResult.success, true);

      final exportedOrders = await _getJson(
        Uri.parse('http://127.0.0.1:$port/api/orders/exports'),
      );
      expect(exportedOrders['request_count'], 1);
      final requests = exportedOrders['requests'] as List<dynamic>;
      expect(requests.isNotEmpty, true);
      final exportedBody =
          (requests.first as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final exportedRows = exportedBody['data'] as List<dynamic>;
      expect(exportedRows.length, 1);
      expect(
        (((exportedRows.first as Map<String, dynamic>)['local_id']) as String)
            .isNotEmpty,
        true,
      );

      final exportedCredits = await _getJson(
        Uri.parse('http://127.0.0.1:$port/api/credits/exports'),
      );
      expect(exportedCredits['request_count'], 1);
      final creditRequests = exportedCredits['requests'] as List<dynamic>;
      expect(creditRequests.isNotEmpty, true);
      final creditPayload =
          (creditRequests.first as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final creditRows = creditPayload['data'] as List<dynamic>;
      final repaymentRows = creditPayload['repayments'] as List<dynamic>;
      final allocationRows = creditPayload['allocations'] as List<dynamic>;
      expect(
        creditRows.any(
          (row) =>
              ((row as Map<String, dynamic>)['local_id'] as String).isNotEmpty,
        ),
        true,
      );
      expect(
        repaymentRows.any(
          (row) =>
              (row as Map<String, dynamic>)['reference_id'] ==
              'mock-sync-repayment',
        ),
        true,
      );
      expect(
        allocationRows.any(
          (row) => (row as Map<String, dynamic>)['credit_id'] == creditId,
        ),
        true,
      );

      final categoryIds = await store.products.listCategoryIdsWithVariants(
        store.scope,
      );
      expect(categoryIds.isNotEmpty, true);

      final credits = await store.credits.listRecords(store.scope);
      expect(credits.isNotEmpty, true);
      expect(credits.every((credit) => credit.storeId == store.storeId), true);
      expect(credits.every((credit) => credit.localId.isNotEmpty), true);
      expect(credits.any((credit) => credit.remoteId != null), true);
    },
  );

  test(
    'Store sync exports customers with store and organisation roles',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final config = _mockSyncConfig(port);
      final store = await Store.createForTest(
        productJson: null,
        config: config,
      );
      addTearDown(store.close);
      await loginAsAdmin(store);

      final result = await store.sync.exportCustomers(store.scope);

      expect(result.success, true);
      expect(result.processedCount, greaterThan(0));

      final exportedCustomers = await _getJson(
        Uri.parse('http://127.0.0.1:$port/api/customers/exports'),
      );
      expect(exportedCustomers['request_count'], 1);
      final requests = exportedCustomers['requests'] as List<dynamic>;
      final payload =
          (requests.first as Map<String, dynamic>)['payload']
              as Map<String, dynamic>;
      final customers = payload['data'] as List<dynamic>;
      final storeRoles = payload['store_roles'] as List<dynamic>;
      final orgRoles = payload['org_roles'] as List<dynamic>;
      expect(customers.isNotEmpty, true);
      expect(storeRoles.isNotEmpty, true);
      expect(orgRoles.isNotEmpty, true);
      expect(
        customers.any(
          (row) => (row as Map<String, dynamic>)['customerId'] == 'cust_001',
        ),
        true,
      );
    },
  );

  test(
    'Mock remote export payload can restore order items and credit repayment allocations on a fresh device',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final config = _mockSyncConfig(port);
      final sourceStore = await Store.createForTest(
        productJson: null,
        config: config,
      );
      addTearDown(sourceStore.close);
      await loginAsAdmin(sourceStore);

      await sourceStore.orders.create(
        sourceStore.scope,
        StoreCreateOrderRequest(
          id: 5570000002,
          orderId: 5570000002,
          restaurantName: 'Recovery Store',
          customerName: 'Recovery Customer',
          mobile: '+15550001111',
          statusName: 'Pending',
          total: 0,
          serviceInstance: 1,
          createdBy: 'recovery-test',
          createdOn: '2026-03-29T14:00:00.000Z',
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.delivery,
        ),
      );
      await sourceStore.orders.addItem(
        sourceStore.scope,
        const StoreAddOrderItemRequest(
          orderId: 5570000002,
          productVariantId: 'variant-restore-1',
          productId: 'product-restore-1',
          quantity: 2,
          unitPrice: 12.5,
          finalPrice: 25.0,
          createdBy: 'recovery-test',
          createdOn: '2026-03-29T14:01:00.000Z',
        ),
      );

      final creditId = await sourceStore.credits.create(
        sourceStore.scope,
        const StoreCreateCreditRequest(
          orgId: 'org_001',
          customerId: 'cust_001',
          orderId: 5570000002,
          amount: 25.0,
          createdOn: '2026-03-29T14:05:00.000Z',
        ),
      );
      await sourceStore.credits.recordRepayment(
        sourceStore.scope,
        StoreCreateCreditRepaymentRequest(
          customerId: 'cust_001',
          paymentMode: StoreCreditRepaymentMode.card,
          totalAmount: 10.0,
          paidOn: '2026-03-29T14:10:00.000Z',
          referenceId: 'restore-roundtrip',
          allocations: [
            StoreCreateCreditRepaymentAllocationRequest(
              creditId: creditId,
              allocatedAmount: 10.0,
            ),
          ],
        ),
      );

      final orderExportResult = await sourceStore.sync.exportOrders(
        sourceStore.scope,
      );
      final creditExportResult = await sourceStore.sync.exportCredits(
        sourceStore.scope,
      );
      expect(orderExportResult.success, true);
      expect(creditExportResult.success, true);

      final restoredStore = await _openEmptyInMemoryStore(
        config,
        customerJson: config.assetPaths.customers,
      );
      addTearDown(restoredStore.close);

      await loginAsAdmin(restoredStore);

      final restoreResult = await restoredStore.sync.restoreFromRemote(
        restoredStore.scope,
      );
      expect(
        restoreResult.operations.every((operation) => operation.success),
        true,
      );

      final restoredOrderItems = await restoredStore.orders.listItems(
        restoredStore.scope,
        5570000002,
      );
      expect(restoredOrderItems.length, 1);
      expect(restoredOrderItems.first.quantity, 2);
      expect(restoredOrderItems.first.finalPrice, 25.0);

      final restoredCredits = await restoredStore.credits.listRecords(
        restoredStore.scope,
      );
      final restoredCredit = restoredCredits.firstWhere(
        (credit) => credit.orderId == 5570000002,
      );
      expect(restoredCredit.amount, 25.0);
      expect(restoredCredit.paidAmount, 10.0);
      expect(restoredCredit.outstandingAmount, 15.0);

      final restoredRepayments = await restoredStore.credits.listRepayments(
        restoredStore.scope,
        customerId: 'cust_001',
        includeDeleted: true,
      );
      final restoredRepayment = restoredRepayments.firstWhere(
        (repayment) => repayment.referenceId == 'restore-roundtrip',
      );
      final restoredAllocations = await restoredStore.credits
          .listRepaymentAllocations(restoredStore.scope, restoredRepayment.id);
      expect(restoredAllocations.length, 1);
      expect(restoredAllocations.first.creditId, restoredCredit.id);
      expect(restoredAllocations.first.allocatedAmount, 10.0);
    },
  );

  test('Python mock remote server exposes customer import payloads', () async {
    final port = await _reservePort();
    final process = await _startMockServer(port);
    addTearDown(() async {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return 0;
        },
      );
    });
    await _resetMockServer(port);

    final customerPayload = await _getJson(
      Uri.parse(
        'http://127.0.0.1:$port/api/customers/import?orgId=org_001&storeId=store_001',
      ),
    );

    final customers = customerPayload['data'] as List<dynamic>;
    final storeRoles = customerPayload['store_roles'] as List<dynamic>;
    final orgRoles = customerPayload['org_roles'] as List<dynamic>;
    expect(customers.isNotEmpty, true);
    expect(storeRoles.isNotEmpty, true);
    expect(orgRoles.isNotEmpty, true);
    expect(
      customers.every(
        (row) => (row as Map<String, dynamic>)['storeId'] == 'store_001',
      ),
      true,
    );
    expect(
      customers.every(
        (row) =>
            ((row as Map<String, dynamic>)['remote_id'] as String).isNotEmpty,
      ),
      true,
    );
    expect(
      storeRoles.every(
        (row) =>
            ((row as Map<String, dynamic>)['remote_id'] as String).isNotEmpty,
      ),
      true,
    );
    expect(
      orgRoles.every(
        (row) =>
            ((row as Map<String, dynamic>)['remote_id'] as String).isNotEmpty,
      ),
      true,
    );
  });

  test(
    'Python mock remote server paginates customer imports with cursor metadata',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });
      await _resetMockServer(port);

      final firstPage = await _getJson(
        Uri.parse(
          'http://127.0.0.1:$port/api/customers/import?orgId=org_001&storeId=store_001&limit=1',
        ),
      );

      expect(firstPage['total_count'], greaterThanOrEqualTo(1));
      expect(firstPage['batch_count'], 1);
      expect(firstPage['has_more'], true);
      expect(firstPage['next_cursor'], isNotNull);

      final firstCustomers = firstPage['data'] as List<dynamic>;
      final firstCustomerIds = firstCustomers
          .map((row) => (row as Map<String, dynamic>)['customerId'] as String)
          .toSet();
      final firstStoreRoles = firstPage['store_roles'] as List<dynamic>;
      expect(
        firstStoreRoles.every(
          (row) => firstCustomerIds.contains(
            (row as Map<String, dynamic>)['customerId'],
          ),
        ),
        true,
      );

      final secondPage = await _getJson(
        Uri.parse(
          'http://127.0.0.1:$port/api/customers/import?orgId=org_001&storeId=store_001&limit=1&cursor=${firstPage['next_cursor']}',
        ),
      );

      expect(secondPage['batch_count'], greaterThanOrEqualTo(0));
      expect(secondPage['total_count'], firstPage['total_count']);
    },
  );

  test(
    'Organisation bootstrap sync returns stores, customers, store roles, and organisation roles',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });

      final bootstrap = await Store.syncOrganisationBootstrap(
        orgCode: '100001',
        config: _mockSyncConfig(port),
      );

      expect(bootstrap != null, true);
      expect(bootstrap!.organisation.orgId, 'org_001');
      expect(bootstrap.organisation.orgName, 'Ellan Test Organisation');
      expect(bootstrap.stores.length, 2);
      expect(
        bootstrap.stores.any((store) => store.storeId == 'store_001'),
        true,
      );
      expect(
        bootstrap.stores.any((store) => store.storeId == 'store_002'),
        true,
      );
      expect(bootstrap.customers.isNotEmpty, true);
      expect(bootstrap.storeRoles.isNotEmpty, true);
      expect(bootstrap.organisationRoles.isNotEmpty, true);
      expect(
        bootstrap.organisationRoles.any(
          (role) => role.organisationRole == 'admin',
        ),
        true,
      );
    },
  );

  test(
    'Python mock bootstrap payload includes remote ids for organisation directory records',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });

      final bootstrapPayload = await _getJson(
        Uri.parse('http://127.0.0.1:$port/api/bootstrap?orgCode=100001'),
      );

      final organisation =
          bootstrapPayload['organisation'] as Map<String, dynamic>;
      final stores = bootstrapPayload['stores'] as List<dynamic>;
      final orgRoles = bootstrapPayload['org_roles'] as List<dynamic>;
      expect(organisation['org_name'], 'Ellan Test Organisation');
      expect((organisation['remote_id'] as String).isNotEmpty, true);
      expect(
        stores.every(
          (row) =>
              ((row as Map<String, dynamic>)['remote_id'] as String).isNotEmpty,
        ),
        true,
      );
      expect(
        orgRoles.every(
          (row) =>
              ((row as Map<String, dynamic>)['remote_id'] as String).isNotEmpty,
        ),
        true,
      );
    },
  );
}
