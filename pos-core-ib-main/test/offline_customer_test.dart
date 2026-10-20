import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/customer_repository.dart';
import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  Future<({Store store, List<Map<String, dynamic>> exported})> openStore() async {
    final exported = <Map<String, dynamic>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      if (request.uri.path == '/customers/export') {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final rows = (body['data'] as List).cast<Map<String, dynamic>>();
        exported.addAll(rows);
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            jsonEncode({
              'ok': true,
              'results': [
                for (final row in rows)
                  {
                    'localCustomerId': row['customerId'],
                    'customerId':
                        CustomerRepository.isProvisionalCustomerId(
                          '${row['customerId']}',
                        )
                        ? 'user_501'
                        : row['customerId'],
                  },
              ],
            }),
          );
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    });

    const meta = {
      'org_id': 'org_001',
      'org_name': 'Offline Customer Org',
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
    };
    const off = {'import_path': '', 'export_path': '', 'export_token': ''};
    final config = StoreConfig.fromJson({
      'db_name_id': 'store',
      'sync': {
        'base_url': 'http://${server.address.host}:${server.port}',
        'auto_sync_enabled': false,
        'periodic_duration_seconds': 1,
        'orders': off,
        'products': off,
        'customers': {
          'import_path': '',
          'export_path': '/customers/export',
          'export_token': 'token',
        },
        'credits': off,
        'tables': off,
      },
      'session_duration_hours': 12,
      'default_store': meta,
      'test_store': meta,
      'asset_paths': {
        'orders': 'fixtures/order_list.json',
        'products': 'fixtures/product_data.json',
        'customers': 'fixtures/customer_data.json',
      },
      'default_login': {'email': 'alice@example.com', 'password': 'alicepass'},
    });
    final m = config.testStore!;
    final store = await Store.createInMemory(
      orgId: m.orgId,
      orgName: m.orgName,
      orgCode: m.orgCode,
      storeId: m.storeId,
      serviceInstanceId: m.serviceInstanceId,
      storeName: m.storeName,
      logo: m.logo,
      uniqueId: m.uniqueId,
      contactEmail: m.contactEmail,
      phone: m.phone,
      contactPerson: m.contactPerson,
      status: m.status,
      serviceVariantType: m.serviceVariantType,
      orderJson: null,
      productJson: null,
      customerJson: config.assetPaths.customers,
      config: config,
    );
    addTearDown(store.close);
    await loginAsAdmin(store);
    return (store: store, exported: exported);
  }

  test('offline customer gets a provisional id and is searchable', () async {
    final (:store, exported: _) = await openStore();
    final id = await store.customers.recordOfflineDirectoryCustomer(
      scope: store.scope,
      name: 'Ravi Offline',
      phone: '9876500001',
    );
    expect(CustomerRepository.isProvisionalCustomerId(id), isTrue);

    final again = await store.customers.recordOfflineDirectoryCustomer(
      scope: store.scope,
      name: 'Ravi',
      phone: '9876500001',
    );
    expect(again, id, reason: 'same phone reuses the offline customer');

    final hits = await store.customers.searchDirectoryDetails(
      scope: store.scope,
      nameQuery: 'Ravi',
    );
    expect(hits.map((c) => c.customerId), contains(id));
  });

  test('customer export swaps provisional id for backend user id', () async {
    final (:store, :exported) = await openStore();
    final localId = (await store.customers.recordOfflineDirectoryCustomer(
      scope: store.scope,
      name: 'Credit Buyer',
      phone: '9876500002',
    ))!;
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Credit Buyer',
        mobile: '9876500002',
        customerUniqueId: localId,
        statusName: 'Completed',
        total: 250,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'offline-test',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Credit',
        orderType: StoreOrderType.dineIn,
      ),
    );
    await store.credits.create(
      store.scope,
      StoreCreateCreditRequest(
        orgId: store.orgId,
        customerId: localId,
        orderId: orderId,
        amount: 250,
        createdOn: DateTime.now().toIso8601String(),
      ),
    );

    final result = await store.sync.exportCustomers(store.scope);
    expect(result.success, isTrue, reason: result.message);
    expect(exported.map((r) => r['customerId']), contains(localId));

    expect(await store.customers.getById(localId), isNull);
    final adopted = await store.customers.getById('user_501');
    expect(adopted?.name, 'Credit Buyer');

    final credits = await store.credits.listRecords(
      store.scope,
      customerId: 'user_501',
    );
    expect(credits.single.amount, 250);
    final order = await store.orders.details(store.scope, orderId);
    expect(order?.customerUniqueId, 'user_501');
    final hits = await store.customers.searchDirectoryDetails(
      scope: store.scope,
      nameQuery: 'Credit Buyer',
    );
    expect(hits.single.customerId, 'user_501');
  });
}
