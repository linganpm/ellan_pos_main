import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import 'package:pos_orders_offline/backend_setup.dart';
import 'package:pos_orders_offline/product_repository.dart';
import 'package:pos_orders_offline/store_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('export mappings write productId, not nonexistent products.id', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await BackendSetup.createTablesForTest(db);
    await BackendSetup.ensureSchemaRepairs(db);

    const scope = StoreScope(orgId: 'org1', storeId: 'store1');
    await db.insert('categories', {
      'localId': 'cat1',
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'name': 'Drinks',
    });
    await db.insert('product_variants', {
      'localId': 'var1',
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'categoryLocalId': 'cat1',
      'product_name': 'Juice',
      'product_variant_name': 'Regular',
      'exported': 0,
    });
    await db.insert('products', {
      'localId': 'prod1',
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'variantLocalId': 'var1',
      'categoryLocalId': 'cat1',
      'name': 'Juice',
    });

    final repo = ProductRepository(db);
    await repo.applyProductExportMappings(scope, [
      {
        'localId': 'var1',
        'unique_id': 'var_server',
        'variant_id': 101,
        'category_local_id': 'cat1',
        'category_unique_id': 'cat_server',
        'category_id': 11,
        'product_local_id': 'prod1',
        'product_unique_id': 'prod_server',
        'product_id': 55,
        'master_product_unique_id': 'mprod1',
        'master_category_unique_id': 'mcat1',
      },
    ]);

    final products = await db.query('products', where: 'localId = ?', whereArgs: ['prod1']);
    expect(products.single['productId'], 55);
    expect(products.single['unique_id'], 'prod_server');

    final cols = await db.rawQuery('PRAGMA table_info(products)');
    final names = cols.map((r) => '${r['name']}').toSet();
    expect(names.contains('productId'), isTrue);
    expect(names.contains('id'), isFalse);

    final variants = await db.query(
      'product_variants',
      where: 'localId = ?',
      whereArgs: ['var1'],
    );
    expect(variants.single['variantId'], 101);
    expect(variants.single['unique_id'], 'var_server');
  });
}
