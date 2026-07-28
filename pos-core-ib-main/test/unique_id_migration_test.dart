import '../lib/sqflite_ffi_io.dart';
import 'package:test/test.dart';

import '../lib/backend_setup.dart';
import '../lib/orders_repository.dart';
import '../lib/store_models.dart';

void main() {
  test('schema migration keeps legacy sync rows without generated unique ids', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(() async => db.close());

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER,
        order_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        order_id INTEGER NOT NULL,
        product_variant_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        qty INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        final_price REAL NOT NULL,
        created_by TEXT NOT NULL,
        created_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE offers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        name TEXT NOT NULL,
        target_type TEXT NOT NULL,
        offer_type TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_on TEXT NOT NULL,
        updated_on TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        categoryId INTEGER,
        id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE product_variants (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        variantId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        localId TEXT PRIMARY KEY,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        productId INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE order_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE credits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE credit_repayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orgId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id INTEGER
      )
    ''');

    await db.insert('orders', {
      'orgId': 'org-1',
      'storeId': 'store-1',
      'local_id': 'order-local-1',
      'remote_id': 101,
      'order_id': 5500000001,
    });
    await db.insert('order_items', {
      'orgId': 'org-1',
      'storeId': 'store-1',
      'order_id': 5500000001,
      'product_variant_id': 'var_1001',
      'product_id': 'prod_2001',
      'qty': 1,
      'unit_price': 100,
      'final_price': 100,
      'created_by': 'test',
      'created_on': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('offers', {
      'orgId': 'org-1',
      'storeId': 'store-1',
      'local_id': 'offer-local-1',
      'name': 'Legacy Offer',
      'target_type': 'product',
      'offer_type': 'percentage',
      'active': 1,
      'created_on': '2024-01-01T00:00:00.000Z',
      'updated_on': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('categories', {
      'localId': 'cat_10',
      'orgId': 'org-1',
      'storeId': 'store-1',
      'categoryId': 10,
      'id': 10,
    });
    await db.insert('products', {
      'localId': 'prod_2001',
      'orgId': 'org-1',
      'storeId': 'store-1',
      'productId': 2001,
    });

    await BackendSetup.upgradeTablesForTest(db, 19, BackendSetup.schemaVersion);

    final order = (await db.query('orders', limit: 1)).single;
    final item = (await db.query('order_items', limit: 1)).single;
    final offer = (await db.query('offers', limit: 1)).single;
    final category = (await db.query('categories', limit: 1)).single;
    final product = (await db.query('products', limit: 1)).single;

    expect(order['unique_id'], isNull);
    expect(item['unique_id'], isNull);
    expect(offer['unique_id'], isNull);
    expect(category['unique_id'], isNull);
    expect(product['unique_id'], isNull);
  });

  test('locally created order rows keep unique_id empty until remote assigns one', () async {
    sqfliteFfiInit();
    final repo = await OrdersRepository.createInMemory();
    addTearDown(() async => repo.close());

    const scope = StoreScope(orgId: 'org-1', storeId: 'store-1');
    await repo.addOrder(scope, {
      'order_id': 5500000001,
      'restaurant_name': 'Local Only',
      'name': 'Customer',
      'mobile': '9000000000',
      'status_name': 'Pending',
      'total': 0,
      'service_instance': 1,
      'created_by': 'test',
      'created_on': '2024-01-01T00:00:00.000Z',
      'payment_status': 'Unpaid',
      'order_type': 'dinein',
      'pricing_mode': 'selling',
    });

    final rows = await repo.getAllOrders(scope);
    expect(rows.single['unique_id'], isNull);
  });
}