import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_exceptions.dart';
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
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  } finally {
    client.close(force: true);
  }
  throw StateError('Mock remote server did not become healthy at $healthUri');
}

Future<void> _resetMockServer(int port) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:$port/api/reset'),
    );
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Mock remote server reset failed with status ${response.statusCode}.',
      );
    }
  } finally {
    client.close(force: true);
  }
  await _setRuntimeStoreStatus('store_001', 'active');
  await _setRuntimeStoreStatus('store_002', 'active');
  await _setRuntimeDeviceStatus('active-device-001', 'active');
  await _setRuntimeDeviceStatus('pending-device-001', 'pending');
  await _setRuntimeDeviceStatus('inactive-device-001', 'inactive');
}

String _mockLookupUrl(int port) => 'http://127.0.0.1:$port/api/bootstrap';

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

Future<void> _setRuntimeDeviceStatus(String deviceId, String status) {
  return _updateRuntimeSeedRows('devices', (rows) {
    for (final row in rows) {
      if (row['deviceId'] == deviceId) {
        row['status'] = status;
        row['message'] = 'Device is $status.';
      }
    }
  });
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
  await _resetMockServer(port);
  return process;
}

StoreConfig _mockBootstrapConfig(int port) {
  return _mockBootstrapConfigWithDevicePath(port, '/api/devices/register');
}

StoreConfig _mockBootstrapConfigWithDevicePath(
  int port,
  String deviceRegistrationPath,
) {
  return StoreConfig.fromJson({
    'db_name_id': 'store_test',
    'bootstrap': {
      'lookup_path': '/api/bootstrap',
      'device_registration_path': deviceRegistrationPath,
    },
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

StoreConfig _mockBootstrapRecoveryConfig(int port) {
  return StoreConfig.fromJson({
    'db_name_id': 'store_test_recovery',
    'bootstrap': {
      'lookup_path': '/api/bootstrap',
      'device_registration_path': '/api/devices/register',
    },
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
      'orders': 'fixtures/does-not-exist-orders.json',
      'products': 'fixtures/does-not-exist-products.json',
      'customers': 'fixtures/does-not-exist-customers.json',
    },
    'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
  });
}

void main() {
  test(
    'Organisation flow can start from discovery URL only and load remote config',
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

      final lookupUrl = _mockLookupUrl(port);
      final organisation = await Store.resolveOrganisationByCodeFromUrl(
        '100001',
        lookupUrl: lookupUrl,
      );
      expect(organisation != null, true);
      expect(organisation!.orgId, 'org_001');

      final config = await StoreConfig.loadRemoteForOrganisation(
        orgCode: organisation.orgCode,
        lookupUrl: lookupUrl,
      );
      expect(config.bootstrap.lookupUrl, lookupUrl);
      expect(config.sync.baseUrl, 'http://127.0.0.1:$port');
      expect(
        config.sync.orders.importUrl,
        'http://127.0.0.1:$port/api/orders/import',
      );

      final login = await Store.loginToOrganisation(
        orgCode: organisation.orgCode,
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      const deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'discovery-device-001',
        make: 'Linux',
        model: 'Discovery Runner',
        lat: 6.9271,
        lan: 79.8612,
      );
      await Store.registerDeviceForOrganisation(
        orgId: organisation.orgId,
        request: deviceRegistration,
        config: config,
      );

      final openedStore = await Store.openAccessibleStore(
        login: login!,
        storeId: 'store_001',
        deviceRegistration: deviceRegistration,
        config: config,
      );
      addTearDown(openedStore.close);

      expect(await openedStore.auth.isLoggedIn(), true);
      expect(openedStore.orgId, 'org_001');
    },
  );

  test(
    'Organisation discovery preserves existing lookup query parameters',
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

      final lookupUrl = '${_mockLookupUrl(port)}?environment=test';
      final organisation = await Store.resolveOrganisationByCodeFromUrl(
        '100001',
        lookupUrl: lookupUrl,
      );
      expect(organisation != null, true);

      final config = await StoreConfig.loadRemoteForOrganisation(
        orgCode: '100001',
        lookupUrl: lookupUrl,
      );
      expect(config.dbNameId, 'store_test');
    },
  );

  test(
    'Organisation flow resolves org, logs in, lists accessible stores, and opens a store',
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
      final config = _mockBootstrapConfig(port);

      final organisation = await Store.resolveOrganisationByCode(
        '100001',
        config: config,
      );
      expect(organisation != null, true);
      expect(organisation!.orgId, 'org_001');
      expect(organisation.remoteId, 'org_001');

      final login = await Store.loginToOrganisation(
        orgCode: organisation.orgCode,
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);
      expect(login!.customerId, 'cust_001');
      expect(login.organisationRole, 'member');
      expect(login.accessibleStores.isNotEmpty, true);
      expect(
        login.accessibleStores.any(
          (entry) => entry.store.storeId == 'store_001',
        ),
        true,
      );
      expect(
        login.accessibleStores.every(
          (entry) => entry.store.remoteId?.isNotEmpty == true,
        ),
        true,
      );
      expect(
        login.accessibleStores.every(
          (entry) => entry.access.remoteId?.isNotEmpty == true,
        ),
        true,
      );

      const deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'test-device-001',
        make: 'Linux',
        model: 'CI runner',
        lat: 6.9271,
        lan: 79.8612,
      );
      final deviceAccess = await Store.registerDeviceForOrganisation(
        orgId: organisation.orgId,
        request: deviceRegistration,
        config: config,
      );
      expect(deviceAccess != null, true);
      expect(deviceAccess!.isActive, true);

      final openedStore = await Store.openAccessibleStore(
        login: login,
        storeId: 'store_001',
        deviceRegistration: deviceRegistration,
        config: config,
      );
      addTearDown(openedStore.close);

      expect(await openedStore.auth.isLoggedIn(), true);
      final session = await openedStore.auth.currentSession();
      expect(session != null, true);
      expect(session!.organisationRole, 'member');
      expect(session.storeRole, 'member');
      final access = await openedStore.auth.currentStoreAccess(
        openedStore.scope,
      );
      expect(access != null, true);
      expect(access!.storeRole, 'member');
      expect(access.remoteId?.isNotEmpty, true);
      expect(await openedStore.auth.canAccessStore(openedStore.scope), true);
      expect(openedStore.organisationRemoteId, 'org_001');
      expect(openedStore.storeRemoteId, 'store_001');

      final orders = await openedStore.orders.listSummaries(openedStore.scope);
      expect(orders.isNotEmpty, true);
    },
  );

  test(
    'Organisation flow rejects invalid organisation code or inaccessible store',
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
      final config = _mockBootstrapConfig(port);

      final missingOrg = await Store.loginToOrganisation(
        orgCode: '999999',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(missingOrg, isNull);

      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      const deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'test-device-002',
        make: 'Linux',
        model: 'CI runner',
        lat: 6.9271,
        lan: 79.8612,
      );

      expect(
        () => Store.openAccessibleStore(
          login: login!,
          storeId: 'store_999',
          deviceRegistration: deviceRegistration,
          config: config,
        ),
        throwsA(isA<StoreAuthorizationException>()),
      );
    },
  );

  test(
    'Organisation flow restores remote data for a fresh device without local asset seeds',
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
      final config = _mockBootstrapRecoveryConfig(port);

      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      const deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'test-device-003',
        make: 'Linux',
        model: 'Recovery runner',
        lat: 6.9271,
        lan: 79.8612,
      );

      final openedStore = await Store.openAccessibleStore(
        login: login!,
        storeId: 'store_001',
        deviceRegistration: deviceRegistration,
        config: config,
      );
      addTearDown(openedStore.close);

      final customers = await openedStore.customers.listDetails(
        scope: openedStore.scope,
      );
      final orders = await openedStore.orders.listSummaries(openedStore.scope);
      final categoryIds = await openedStore.products
          .listCategoryIdsWithVariants(openedStore.scope);
      final credits = await openedStore.credits.listRecords(openedStore.scope);

      expect(customers.isNotEmpty, true);
      expect(
        customers.every((customer) => customer.remoteId?.isNotEmpty == true),
        true,
      );
      expect(orders.isNotEmpty, true);
      expect(categoryIds.isNotEmpty, true);
      expect(credits.isNotEmpty, true);
      expect(credits.any((credit) => credit.remoteId != null), true);
    },
  );

  test(
    'Organisation flow blocks inactive registered devices before opening the store',
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
      final config = _mockBootstrapConfig(port);

      final organisation = await Store.resolveOrganisationByCode(
        '100001',
        config: config,
      );
      expect(organisation != null, true);

      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      const blockedDevice = StoreDeviceRegistrationRequest(
        deviceId: 'inactive-device-001',
        make: 'Linux',
        model: 'Blocked Unit',
        lat: 0,
        lan: 0,
      );
      await expectLater(
        () => Store.registerDeviceForOrganisation(
          orgId: organisation!.orgId,
          request: blockedDevice,
          config: config,
        ),
        throwsA(isA<StoreDeviceAccessException>()),
      );

      expect(
        () => Store.openAccessibleStore(
          login: login!,
          storeId: 'store_001',
          deviceRegistration: blockedDevice,
          config: config,
        ),
        throwsA(isA<StoreDeviceAccessException>()),
      );
    },
  );

  test(
    'Organisation flow stops when device registration endpoint fails',
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
      final config = _mockBootstrapConfigWithDevicePath(
        port,
        '/api/devices/missing',
      );

      final organisation = await Store.resolveOrganisationByCode(
        '100001',
        config: config,
      );
      expect(organisation != null, true);

      const deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'missing-device-endpoint-001',
        make: 'Linux',
        model: 'Broken Registration Endpoint',
        lat: 0,
        lan: 0,
      );

      await expectLater(
        () => Store.registerDeviceForOrganisation(
          orgId: organisation!.orgId,
          request: deviceRegistration,
          config: config,
        ),
        throwsA(isA<StoreDeviceAccessException>()),
      );
    },
  );

  test('Approved devices can reopen and work offline after setup', () async {
    final port = await _reservePort();
    final process = await _startMockServer(port);
    final tempDir = await Directory.systemTemp.createTemp(
      'store_offline_reopen_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
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

    final config = _mockBootstrapConfig(port);
    final login = await Store.loginToOrganisation(
      orgCode: '100001',
      email: 'alice@example.com',
      password: 'alicepass',
      config: config,
    );
    expect(login != null, true);

    final deviceRegistration = StoreDeviceRegistrationRequest(
      deviceId: 'offline-cache-device-$port',
      make: 'Linux',
      model: 'Offline Cache Runner',
      lat: 6.9271,
      lan: 79.8612,
    );
    final uniqueId = login!.accessibleStores
        .firstWhere((entry) => entry.store.storeId == 'store_001')
        .store
        .uniqueId;

    final openedStore = await Store.openAccessibleStore(
      login: login,
      storeId: 'store_001',
      deviceRegistration: deviceRegistration,
      databasePath: tempDir.path,
      config: config,
    );
    await openedStore.close();

    process.kill(ProcessSignal.sigterm);
    await process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return 0;
      },
    );

    final reopenedStore = await Store.reopenPersistent(
      orgId: 'org_001',
      storeId: 'store_001',
      uniqueId: uniqueId,
      databasePath: tempDir.path,
      config: config,
    );
    addTearDown(reopenedStore.close);

    expect(await reopenedStore.auth.isLoggedIn(), true);
    final orders = await reopenedStore.orders.listSummaries(
      reopenedStore.scope,
    );
    expect(orders.isNotEmpty, true);
  });

  test(
    'Store can switch between accessible stores inside the same organisation database',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      final tempDir = await Directory.systemTemp.createTemp('store_switch_');
      Store? activeStore;
      addTearDown(() async {
        await activeStore?.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return 0;
          },
        );
      });

      final config = _mockBootstrapConfig(port);
      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);
      expect(login!.accessibleStores.length, greaterThanOrEqualTo(2));
      final firstAccessibleStoreId = login.accessibleStores.first.store.storeId;
      final secondAccessibleStoreId = login.accessibleStores[1].store.storeId;

      final deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'switch-store-device-$port',
        make: 'Linux',
        model: 'Switch Store Runner',
        lat: 0,
        lan: 0,
      );

      activeStore = await Store.openAccessibleStore(
        login: login,
        storeId: firstAccessibleStoreId,
        deviceRegistration: deviceRegistration,
        databasePath: tempDir.path,
        config: config,
      );

      const orderId = 5500081001;
      await activeStore!.orders.create(
        activeStore!.scope,
        StoreCreateOrderRequest(
          id: orderId,
          orderId: orderId,
          restaurantName: activeStore!.storeName,
          customerName: 'Switch Flow Customer',
          mobile: '+1000000001',
          statusName: 'Pending',
          total: 15.0,
          serviceInstance: activeStore!.serviceInstanceId,
          createdBy: 'switch-test',
          createdOn: DateTime.now().toIso8601String(),
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.dineIn,
        ),
      );

      activeStore = await activeStore!.switchAccessibleStore(
        login: login,
        storeId: secondAccessibleStoreId,
        deviceRegistration: deviceRegistration,
      );

      expect(activeStore!.orgId, 'org_001');
      expect(activeStore!.storeId, secondAccessibleStoreId);
      expect(await activeStore!.auth.isLoggedIn(), true);
      expect(
        await activeStore!.orders.getById(activeStore!.scope, orderId),
        isNull,
      );

      activeStore = await activeStore!.switchAccessibleStore(
        login: login,
        storeId: firstAccessibleStoreId,
        deviceRegistration: deviceRegistration,
      );

      expect(activeStore!.storeId, firstAccessibleStoreId);
      final switchedBackOrder = await activeStore!.orders.getById(
        activeStore!.scope,
        orderId,
      );
      expect(switchedBackOrder != null, true);
      expect(switchedBackOrder!.orderId, orderId);
    },
  );

  test(
    'Online access refresh updates cached device status and blocks a suspended device',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      final tempDir = await Directory.systemTemp.createTemp(
        'store_device_revoke_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
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

      final config = _mockBootstrapConfig(port);
      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      final deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'revoked-device-$port',
        make: 'Linux',
        model: 'Revocation Runner',
        lat: 0,
        lan: 0,
      );
      final uniqueId = login!.accessibleStores
          .firstWhere((entry) => entry.store.storeId == 'store_001')
          .store
          .uniqueId;

      final openedStore = await Store.openAccessibleStore(
        login: login,
        storeId: 'store_001',
        deviceRegistration: deviceRegistration,
        databasePath: tempDir.path,
        config: config,
      );
      addTearDown(openedStore.close);

      await _setRuntimeDeviceStatus(deviceRegistration.deviceId, 'inactive');

      await expectLater(
        () => openedStore.sync.refreshAccessControl(openedStore.scope),
        throwsA(isA<StoreDeviceAccessException>()),
      );
      expect(await openedStore.auth.isLoggedIn(), false);

      final reopenedStore = await Store.reopenPersistent(
        orgId: 'org_001',
        storeId: 'store_001',
        uniqueId: uniqueId,
        databasePath: tempDir.path,
        config: config,
      );
      addTearDown(reopenedStore.close);

      expect(await reopenedStore.auth.isLoggedIn(), false);
      await expectLater(
        () => reopenedStore.orders.listSummaries(reopenedStore.scope),
        throwsA(
          anyOf(isA<StoreAuthException>(), isA<StoreDeviceAccessException>()),
        ),
      );
    },
  );

  test(
    'Online access refresh updates cached store status and blocks a disabled store',
    () async {
      final port = await _reservePort();
      final process = await _startMockServer(port);
      final tempDir = await Directory.systemTemp.createTemp(
        'store_disable_refresh_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
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

      final config = _mockBootstrapConfig(port);
      final login = await Store.loginToOrganisation(
        orgCode: '100001',
        email: 'alice@example.com',
        password: 'alicepass',
        config: config,
      );
      expect(login != null, true);

      final deviceRegistration = StoreDeviceRegistrationRequest(
        deviceId: 'store-disabled-device-$port',
        make: 'Linux',
        model: 'Store Disable Runner',
        lat: 0,
        lan: 0,
      );
      final uniqueId = login!.accessibleStores
          .firstWhere((entry) => entry.store.storeId == 'store_001')
          .store
          .uniqueId;

      final openedStore = await Store.openAccessibleStore(
        login: login,
        storeId: 'store_001',
        deviceRegistration: deviceRegistration,
        databasePath: tempDir.path,
        config: config,
      );
      addTearDown(openedStore.close);

      await _setRuntimeStoreStatus('store_001', 'inactive');

      await expectLater(
        () => openedStore.sync.refreshAccessControl(openedStore.scope),
        throwsA(isA<StoreAuthorizationException>()),
      );
      expect(await openedStore.auth.isLoggedIn(), false);

      final reopenedStore = await Store.reopenPersistent(
        orgId: 'org_001',
        storeId: 'store_001',
        uniqueId: uniqueId,
        databasePath: tempDir.path,
        config: config,
      );
      addTearDown(reopenedStore.close);

      expect(await reopenedStore.auth.isLoggedIn(), false);
      await expectLater(
        () => reopenedStore.orders.listSummaries(reopenedStore.scope),
        throwsA(
          anyOf(isA<StoreAuthException>(), isA<StoreAuthorizationException>()),
        ),
      );
    },
  );
}
