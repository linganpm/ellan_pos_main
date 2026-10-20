import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

import '../lib/offers_repository.dart';
import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

Map<String, dynamic> _variant(int categoryId, int variantId, int productId, String name, double price) => {
      'id': variantId,
      'unique_id': '$variantId',
      'product_variant_name': name,
      'product_name': name,
      'sell_price': price,
      'product_addon_group_data': const [],
      'product_variant_addon_group_data': const [],
      'product_data': {'id': productId, 'unique_id': '$productId', 'name': name, 'type': 1},
      'category_data': {'id': categoryId, 'unique_id': '$categoryId', 'name': 'Category $categoryId'},
    };

Future<Store> _openStore() async {
  final tempDir = await Directory.systemTemp.createTemp('offer_types_store_');
  final productFile = File('${tempDir.path}/products.json');
  await productFile.writeAsString(jsonEncode({
    'data': [
      {
        'id': 20,
        'unique_id': '20',
        'name': 'Category 20',
        'slug': 'category-20',
        'product_variants': [
          _variant(20, 1003, 2003, 'Gamma', 20),
          _variant(20, 1004, 2004, 'Delta', 10),
          _variant(20, 1005, 2005, 'Epsilon', 5),
          _variant(20, 1006, 2006, 'Zeta', 50),
        ],
      },
    ],
  }));
  final store = await openAdminLoggedInTestStore(productJson: productFile.path);
  addTearDown(() async {
    await store.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });
  return store;
}

Future<int> _order(Store store, Map<int, int> qtyByVariant) async {
  final createdOn = DateTime.now().toIso8601String();
  final orderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: 'R',
      customerName: 'C',
      mobile: '9000000099',
      statusName: 'Pending',
      total: 0,
      serviceInstance: 1,
      createdBy: 'offer-types-test',
      createdOn: createdOn,
      paymentStatus: 'Unpaid',
      orderType: StoreOrderType.pickUp,
    ),
  );
  for (final entry in qtyByVariant.entries) {
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_${entry.key}',
        productId: 'prod_${entry.key + 1000}',
        quantity: entry.value,
        createdBy: 'offer-types-test',
        createdOn: createdOn,
      ),
    );
  }
  return orderId;
}

Future<Database> _openOffersDb() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('''
    CREATE TABLE offers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, orgId TEXT NOT NULL, storeId TEXT NOT NULL,
      unique_id TEXT, local_id TEXT NOT NULL, name TEXT NOT NULL, target_type TEXT NOT NULL,
      offer_type TEXT NOT NULL, percentage_value REAL, flat_value REAL, minimum_bill_amount REAL,
      buy_quantity INTEGER, get_quantity INTEGER, active INTEGER NOT NULL DEFAULT 1,
      created_on TEXT NOT NULL, updated_on TEXT NOT NULL, exported INTEGER NOT NULL DEFAULT 1,
      description TEXT, deleted INTEGER NOT NULL DEFAULT 0)
  ''');
  await db.execute('''
    CREATE TABLE offer_targets (
      id INTEGER PRIMARY KEY AUTOINCREMENT, orgId TEXT NOT NULL, storeId TEXT NOT NULL,
      offer_local_id TEXT NOT NULL, target_value TEXT NOT NULL)
  ''');
  addTearDown(db.close);
  return db;
}

Map<String, dynamic> _serverOffer(int id, {String type = 'percentage', double? pct = 10, double? flat}) => {
      'local_id': 'offer-$id',
      'unique_id': '$id',
      'name': 'Offer $id',
      'target_type': 'product',
      'offer_type': type,
      'target_ids': ['1004'],
      'percentage_value': pct,
      'flat_value': flat,
      'active': true,
    };

void main() {
  const scope = StoreScope(orgId: 'org', storeId: 'store');

  test('variant-targeted percentage offer from the server applies to the order', () async {
    final store = await _openStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        uniqueId: '77',
        name: 'Variant 10%',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.percentage,
        targetIds: ['1004'],
        percentageValue: 10,
      ),
    );
    final details = (await store.orders.details(store.scope, await _order(store, {1004: 2})))!;
    expect(details.subtotal, 20);
    expect(details.totalDiscount, closeTo(2, 1e-9));
  });

  test('fixed price offer sells bundles of M units for the fixed price', () async {
    final store = await _openStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: '3 for 25',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.fixedPrice,
        targetIds: ['1004'],
        flatValue: 25,
        buyQuantity: 3,
      ),
    );
    final details = (await store.orders.details(store.scope, await _order(store, {1004: 4})))!;
    expect(details.subtotal, 40);
    expect(details.totalDiscount, closeTo(5, 1e-9));
    expect(details.total, closeTo(35, 1e-9));
    expect(details.appliedOffers.single.offerType, StoreOfferType.fixedPrice);
  });

  test('fixed unit price offer discounts every unit down to the price', () async {
    final store = await _openStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Zeta now 45',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.fixedPrice,
        targetIds: ['1006'],
        flatValue: 45,
      ),
    );
    final details = (await store.orders.details(store.scope, await _order(store, {1006: 2})))!;
    expect(details.totalDiscount, closeTo(10, 1e-9));
    expect(details.total, closeTo(90, 1e-9));
  });

  test('buy N get M at discount takes the percentage off the cheapest units', () async {
    final store = await _openStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Buy 2 get 1 half price',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.buyNGetMDiscount,
        targetIds: ['20'],
        buyQuantity: 2,
        getQuantity: 1,
        percentageValue: 50,
      ),
    );
    final details = (await store.orders.details(store.scope, await _order(store, {1003: 1, 1004: 1, 1005: 1})))!;
    expect(details.subtotal, 35);
    expect(details.totalDiscount, closeTo(2.5, 1e-9));
    expect(
      details.items.firstWhere((item) => item.item.productId == 'prod_2005').discountAmount,
      closeTo(2.5, 1e-9),
    );
  });

  test('import skips invalid offers instead of aborting the batch', () async {
    final repo = OffersRepository(await _openOffersDb());
    final ids = await repo.importOffersFromJsonData({
      'data': [
        _serverOffer(1),
        _serverOffer(2, type: 'buy_n_get_m'), // missing quantities -> invalid
        _serverOffer(3, type: 'fixed_price', pct: null, flat: 25),
      ],
    }, scope: scope);
    expect(ids, ['1', '2', '3']);
    final offers = await repo.listOffers(scope);
    expect(offers.map((offer) => offer.uniqueId).toSet(), {'1', '3'});
  });

  test('prune retires server offers missing from the snapshot and revives returning ones', () async {
    final db = await _openOffersDb();
    final repo = OffersRepository(db);
    await repo.importOffersFromJsonData({'data': [_serverOffer(1), _serverOffer(2), _serverOffer(3)]}, scope: scope);
    await repo.saveOffer(
      scope,
      const StoreSaveOfferRequest(
        name: 'Local only',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.percentage,
        targetIds: ['1004'],
        percentageValue: 5,
      ),
    );
    await repo.deleteOffer(scope, 'offer-3'); // pending local delete

    final pruned = await repo.pruneServerOffersNotIn(scope, ['1']);
    expect(pruned, 1);
    expect((await repo.listOffers(scope)).map((offer) => offer.name).toSet(), {'Offer 1', 'Local only'});
    final offer2 = (await db.query('offers', where: 'unique_id = ?', whereArgs: ['2'])).single;
    expect(offer2['exported'], 1, reason: 'a server prune must not be exported back');

    await repo.importOffersFromJsonData({'data': [_serverOffer(1), _serverOffer(2), _serverOffer(3)]}, scope: scope);
    expect((await repo.listOffers(scope)).map((offer) => offer.name).toSet(), {'Offer 1', 'Offer 2', 'Local only'});
  });
}
