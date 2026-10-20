import 'dart:io';

import 'package:test/test.dart';

import '../lib/backend_setup.dart';
import '../lib/product_data_importer.dart';
import '../lib/product_repository.dart';
import '../lib/sqflite_ffi_io.dart';
import '../lib/store_models.dart';

void main() {
  const scope = StoreScope(orgId: 'org', storeId: 'store');
  late Directory temp;
  late Database db;
  late ProductRepository repo;

  Map<String, dynamic> feed({
    String price = '10',
    String categoryName = 'Food',
    int? active,
  }) => {
        'data': [
          {
            'id': 1,
            'name': categoryName,
            'product_variants': [
              {
                'id': 2,
                'product_name': 'Rice',
                'product_variant_name': '1 kg',
                'sell_price': price,
                if (active != null) 'active': active,
                'product_data': {'id': 3, 'name': 'Rice'},
              },
            ],
          },
        ],
      };

  Future<void> importFeed([Map<String, dynamic>? data]) =>
      ProductDataImporter(db).importFromJsonData(data ?? feed(), scope: scope);

  Future<Map<String, Object?>> variant() async =>
      (await db.query('product_variants', where: 'variantId = 2')).single;

  Future<Map<String, Object?>> product() async =>
      (await db.query('products', where: 'productId = 3')).single;

  Future<Map<String, Object?>> category() async =>
      (await db.query('categories', where: 'categoryId = 1')).single;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('pos-catalog-delete-');
    db = await databaseFactoryFfi.openDatabase('${temp.path}/catalogue.db');
    await BackendSetup.createTablesForTest(db);
    repo = ProductRepository(db);
    await importFeed();
  });

  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  test('import keeps a pending local delete so Sync can export it', () async {
    await repo.softDeleteVariant(scope, '${(await variant())['localId']}');

    await importFeed();

    expect((await variant())['deleted'], 1);
    expect((await variant())['exported'], 0);
    expect((await product())['deleted'], 1);
    final pending = await repo.listPendingExportCatalogRows(scope);
    expect(pending.single['deleted'], 1);
    expect(pending.single['unique_id'], '2');
  });

  test('deleted variant stays gone once the server drops it', () async {
    final localId = '${(await variant())['localId']}';
    await repo.softDeleteVariant(scope, localId);
    await repo.markProductVariantsExported(scope, [localId], exported: true);

    await importFeed({'data': []});

    expect((await variant())['deleted'], 1);
    expect(await repo.listPendingExportCatalogRows(scope), isEmpty);
  });

  test('pending local category delete survives import', () async {
    await repo.softDeleteCategory(scope, '${(await category())['localId']}');

    await importFeed();

    expect((await category())['deleted'], 1);
    expect((await variant())['deleted'], 1);
  });

  test('synced rows still take server updates', () async {
    await importFeed(feed(price: '12', categoryName: 'Meals'));

    expect((await variant())['sell_price'], '12');
    expect((await variant())['deleted'], 0);
    expect((await category())['name'], 'Meals');
  });

  test('feed active flag is stored and hides the variant from billing', () async {
    expect((await variant())['active'], 1);

    await importFeed(feed(active: 0));

    expect((await variant())['active'], 0);
    expect((await variant())['deleted'], 0);
    expect(await repo.searchProductVariants(scope), hasLength(1));
    expect(await repo.searchProductVariants(scope, activeOnly: true), isEmpty);
    expect(await repo.getProductVariantsByCategory(scope, 1, activeOnly: true), isEmpty);

    await importFeed(feed(active: 1));
    expect(await repo.searchProductVariants(scope, activeOnly: true), hasLength(1));
  });

  test('pending local inactive toggle survives import and is exported', () async {
    await repo.markProductVariantsExported(
      scope,
      ['${(await variant())['localId']}'],
      exported: true,
    );
    await repo.setVariantActive(scope, '${(await variant())['localId']}', active: false);

    await importFeed(feed(active: 1));

    expect((await variant())['active'], 0);
    expect((await variant())['exported'], 0);
    final pending = await repo.listPendingExportCatalogRows(scope);
    expect(pending.single['active'], 0);
    expect(pending.single['deleted'], 0);

    await repo.setVariantActive(scope, '${(await variant())['localId']}', active: true);
    expect((await repo.listPendingExportCatalogRows(scope)).single['active'], 1);
  });

  test('schema repair adds the active column to older databases', () async {
    await db.execute('ALTER TABLE product_variants DROP COLUMN active');
    await BackendSetup.ensureSchemaRepairs(db);

    final cols = await db.rawQuery('PRAGMA table_info(product_variants)');
    expect(cols.map((c) => c['name']), contains('active'));
    expect((await variant())['active'], 1);
  });
}
