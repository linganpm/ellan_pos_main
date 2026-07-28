import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

Map<String, dynamic> _offerProductData() {
  Map<String, dynamic> variant({
    required int categoryId,
    required int variantId,
    required int productId,
    required String name,
    required double sellPrice,
  }) {
    return {
      'id': variantId,
      'unique_id': 'variant-uuid-$variantId',
      'product_variant_name': name,
      'product_name': name,
      'sell_price': sellPrice,
      'buy_price': sellPrice / 2,
      'mrp_price': sellPrice + 10,
      'product_addon_group_data': const [],
      'product_variant_addon_group_data': const [],
      'product_data': {
        'id': productId,
        'unique_id': 'product-uuid-$productId',
        'name': name,
        'type': 1,
        'description': '$name description',
        'is_preorder': 0,
        'is_allergens': 0,
      },
      'category_data': {
        'id': categoryId,
        'unique_id': 'category-uuid-$categoryId',
        'name': 'Category $categoryId',
      },
    };
  }

  return {
    'data': [
      {
        'id': 10,
        'unique_id': 'category-uuid-10',
        'name': 'Category 10',
        'slug': 'category-10',
        'product_variants': [
          variant(categoryId: 10, variantId: 1001, productId: 2001, name: 'Alpha', sellPrice: 100),
          variant(categoryId: 10, variantId: 1002, productId: 2002, name: 'Beta', sellPrice: 50),
        ],
      },
      {
        'id': 20,
        'unique_id': 'category-uuid-20',
        'name': 'Category 20',
        'slug': 'category-20',
        'product_variants': [
          variant(categoryId: 20, variantId: 1003, productId: 2003, name: 'Gamma', sellPrice: 20),
          variant(categoryId: 20, variantId: 1004, productId: 2004, name: 'Delta', sellPrice: 10),
          variant(categoryId: 20, variantId: 1005, productId: 2005, name: 'Epsilon', sellPrice: 5),
        ],
      },
    ],
  };
}

Future<Store> _openOfferTestStore() async {
  final tempDir = await Directory.systemTemp.createTemp('order_offer_test_store_');
  final productFile = File('${tempDir.path}/offers_product_data.json');
  await productFile.writeAsString(jsonEncode(_offerProductData()));
  final store = await openAdminLoggedInTestStore(productJson: productFile.path);
  addTearDown(() async {
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  return store;
}

Future<Store> _openOfferSeededStore() async {
  final tempDir = await Directory.systemTemp.createTemp('order_offer_seed_store_');
  final productFile = File('${tempDir.path}/offers_product_data.json');
  final offerFile = File('${tempDir.path}/offers_data.json');
  await productFile.writeAsString(jsonEncode(_offerProductData()));
  await offerFile.writeAsString(jsonEncode({
    'data': [
      {
        'local_id': 'seed-offer-1',
        'name': 'Seeded Product Offer',
        'target_type': 'product',
        'offer_type': 'percentage',
        'target_ids': ['prod_2001', 'prod_2002'],
        'percentage_value': 10,
        'active': true,
      },
    ],
  }));
  final store = await openAdminLoggedInTestStore(productJson: productFile.path, offerJson: offerFile.path);
  addTearDown(() async {
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
  return store;
}

Future<int> _createOfferOrder(
  Store store,
  List<StoreAddOrderItemRequest> items,
) async {
  final createdOn = DateTime.now().toIso8601String();
  final orderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: 'Offer Demo Restaurant',
      customerName: 'Offer Demo Customer',
      mobile: '9000000010',
      statusName: 'Pending',
      total: 0,
      serviceInstance: 1,
      createdBy: 'order-offer-test',
      createdOn: createdOn,
      paymentStatus: 'Unpaid',
      orderType: StoreOrderType.dineIn,
    ),
  );
  for (final item in items) {
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: item.productVariantId,
        productId: item.productId,
        quantity: item.quantity,
        createdBy: item.createdBy,
        createdOn: item.createdOn,
      ),
    );
  }
  return orderId;
}

void main() {
  test('offers can be seeded from a separate offers file', () async {
    final store = await _openOfferSeededStore();
    final offers = await store.offers.list(store.scope);
    expect(offers.length, 1);
    expect(offers.single.localId, 'seed-offer-1');
    expect(offers.single.targetIds, ['prod_2001', 'prod_2002']);
    expect(offers.single.offerType, StoreOfferType.percentage);
  });

  test('backend style remote ids can be used in offer targets', () async {
    final store = await _openOfferTestStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Backend Remote Product Offer',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.percentage,
        targetIds: ['2001'],
        percentageValue: 25,
      ),
    );

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Remote Id Offer Restaurant',
        customerName: 'Remote Id Customer',
        mobile: '9000000000',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1001',
        productId: 'prod_2001',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details != null, true);
    expect(details!.subtotal, 100);
    expect(details.totalDiscount, 25);
    expect(details.total, 75);
    expect(details.items.single.discountAmount, 25);
  });

  test('canonical unique ids can be used in offer targets and order details expose them', () async {
    final store = await _openOfferTestStore();
    final offerLocalId = await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        uniqueId: 'offer:remote:9001',
        name: 'Canonical Product Offer',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.percentage,
        targetIds: ['product-uuid-2001'],
        percentageValue: 20,
      ),
    );

    final offers = await store.offers.list(store.scope);
    final savedOffer = offers.firstWhere((offer) => offer.localId == offerLocalId);
    expect(savedOffer.uniqueId, 'offer:remote:9001');

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        uniqueId: 'order:remote:7001',
        restaurantName: 'Canonical Offer Restaurant',
        customerName: 'Canonical Customer',
        mobile: '9000000009',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        uniqueId: 'order-item:remote:8001',
        orderId: orderId,
        productVariantId: 'var_1001',
        productId: 'prod_2001',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details != null, true);
    expect(details!.uniqueId, 'order:remote:7001');
    expect(details.items.single.item.uniqueId, 'order-item:remote:8001');
    expect(details.subtotal, 100);
    expect(details.totalDiscount, 20);
    expect(details.total, 80);
  });

  test('order details returns discounted items and avoids double counting across offers', () async {
    final store = await _openOfferTestStore();
    final flatOfferId = await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Category 10 Flat 30',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.flat,
        targetIds: ['10'],
        flatValue: 30,
      ),
    );
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Alpha Beta 10 Percent',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.percentage,
        targetIds: ['prod_2001', 'prod_2002'],
        percentageValue: 10,
      ),
    );

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Offer Restaurant',
        customerName: 'Offer Customer',
        mobile: '9000000001',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final alphaItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1001',
        productId: 'prod_2001',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1002',
        productId: 'prod_2002',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );

    var details = await store.orders.details(store.scope, orderId);
    expect(details != null, true);
    expect(details!.subtotal, 150);
    expect(details.totalDiscount, 30);
    expect(details.total, 120);
    expect(details.items.length, 2);
    expect(details.appliedOffers.length, 1);
    expect(details.appliedOffers.single.localId, flatOfferId);
    expect(
      details.items.fold<double>(0, (total, item) => total + item.discountAmount),
      30,
    );
    expect(
      details.items.firstWhere((item) => item.item.id == alphaItemId).appliedOfferLocalIds,
      [flatOfferId],
    );

    final offers = await store.offers.list(store.scope);
    expect(offers.length, greaterThanOrEqualTo(2));
    expect(offers.firstWhere((offer) => offer.localId == flatOfferId).targetIds, ['10']);

    final items = await store.orders.listItems(store.scope, orderId);
    final betaItemId = items.firstWhere((item) => item.productId == 'prod_2002').id;
    await store.orders.deleteItem(store.scope, betaItemId);

    details = await store.orders.details(store.scope, orderId);
    expect(details != null, true);
    expect(details!.subtotal, 100);
    expect(details.totalDiscount, 30);
    expect(details.total, 70);
    expect(details.appliedOffers.single.localId, flatOfferId);
  });

  test('buy N get M uses the cheapest eligible unit as free', () async {
    final store = await _openOfferTestStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Category 20 Buy 2 Get 1',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.buyNGetM,
        targetIds: ['20'],
        buyQuantity: 2,
        getQuantity: 1,
      ),
    );

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Buy Get Restaurant',
        customerName: 'Buy Get Customer',
        mobile: '9000000002',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1003',
        productId: 'prod_2003',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1004',
        productId: 'prod_2004',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1005',
        productId: 'prod_2005',
        quantity: 1,
        createdBy: 'order-offer-test',
        createdOn: createdOn,
      ),
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details != null, true);
    expect(details!.subtotal, 35);
    expect(details.totalDiscount, 5);
    expect(details.total, 30);
    expect(details.appliedOffers.length, 1);
    expect(details.appliedOffers.single.offerType, StoreOfferType.buyNGetM);
    expect(
      details.items.firstWhere((item) => item.item.productId == 'prod_2005').discountAmount,
      5,
    );
    expect(
      details.items.firstWhere((item) => item.item.productId == 'prod_2003').discountAmount,
      0,
    );
  });

  test('total offer applies bill-level percentage when minimum amount is reached', () async {
    final store = await _openOfferTestStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Bill 10 Percent Above 120',
        targetType: StoreOfferTargetType.bill,
        offerType: StoreOfferType.totalOffer,
        targetIds: [],
        percentageValue: 10,
        minimumBillAmount: 120,
      ),
    );

    final orderId = await _createOfferOrder(
      store,
      [
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1001',
          productId: 'prod_2001',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: DateTime.now().toIso8601String(),
        ),
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1002',
          productId: 'prod_2002',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: DateTime.now().toIso8601String(),
        ),
      ],
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details, isNotNull);
    expect(details!.subtotal, 150);
    expect(details.totalValue, 150);
    expect(details.totalDiscount, 15);
    expect(details.offerAppliedValue, 15);
    expect(details.finalValue, 135);
    expect(details.total, 135);
    expect(details.items.every((item) => item.discountAmount == 0), isTrue);
    expect(details.appliedOffers.length, 1);
    expect(details.appliedOffers.single.offerType, StoreOfferType.totalOffer);

    final summaries = await store.orders.listSummaries(store.scope);
    final summary = summaries.firstWhere((item) => item.orderId == orderId);
    expect(summary.totalValue, 150);
    expect(summary.offerAppliedValue, 15);
    expect(summary.finalValue, 135);
    expect(summary.total, 135);
  });

  test('total offer does not apply when bill threshold is not reached', () async {
    final store = await _openOfferTestStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        name: 'Bill 10 Percent Above 200',
        targetType: StoreOfferTargetType.bill,
        offerType: StoreOfferType.totalOffer,
        targetIds: [],
        percentageValue: 10,
        minimumBillAmount: 200,
      ),
    );

    final orderId = await _createOfferOrder(
      store,
      [
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1002',
          productId: 'prod_2002',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: DateTime.now().toIso8601String(),
        ),
      ],
    );

    final details = await store.orders.details(store.scope, orderId);
    expect(details, isNotNull);
    expect(details!.subtotal, 50);
    expect(details.totalValue, 50);
    expect(details.offerAppliedValue, 0);
    expect(details.finalValue, 50);
    expect(details.total, 50);
    expect(details.appliedOffers.where((offer) => offer.offerType == StoreOfferType.totalOffer), isEmpty);
  });

  test('offer feature demo covers percentage, flat and buy n get m scenarios', () async {
    final store = await _openOfferTestStore();
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        uniqueId: 'offer-category-10-percent',
        name: 'Category 10 Percent',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.percentage,
        targetIds: ['category-uuid-10'],
        percentageValue: 10,
      ),
    );
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        uniqueId: 'offer-beta-flat',
        name: 'Beta Flat 12',
        targetType: StoreOfferTargetType.product,
        offerType: StoreOfferType.flat,
        targetIds: ['product-uuid-2002'],
        flatValue: 12,
      ),
    );
    await store.offers.save(
      store.scope,
      const StoreSaveOfferRequest(
        uniqueId: 'offer-category-20-buy-2-get-1',
        name: 'Category 20 Buy 2 Get 1',
        targetType: StoreOfferTargetType.category,
        offerType: StoreOfferType.buyNGetM,
        targetIds: ['category-uuid-20'],
        buyQuantity: 2,
        getQuantity: 1,
      ),
    );

    final now = DateTime.now().toIso8601String();

    final percentageOrderId = await _createOfferOrder(
      store,
      [
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1001',
          productId: 'prod_2001',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1002',
          productId: 'prod_2002',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
      ],
    );
    final percentageDetails = await store.orders.details(store.scope, percentageOrderId);
    expect(percentageDetails != null, true);
    expect(percentageDetails!.subtotal, 150);
    expect(percentageDetails.totalDiscount, 15);
    expect(percentageDetails.total, 135);

    final flatOrderId = await _createOfferOrder(
      store,
      [
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1002',
          productId: 'prod_2002',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
      ],
    );
    final flatDetails = await store.orders.details(store.scope, flatOrderId);
    expect(flatDetails != null, true);
    expect(flatDetails!.subtotal, 50);
    expect(flatDetails.totalDiscount, 12);
    expect(flatDetails.total, 38);

    final buyGetOrderId = await _createOfferOrder(
      store,
      [
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1003',
          productId: 'prod_2003',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1004',
          productId: 'prod_2004',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
        StoreAddOrderItemRequest(
          orderId: 0,
          productVariantId: 'var_1005',
          productId: 'prod_2005',
          quantity: 1,
          createdBy: 'order-offer-test',
          createdOn: now,
        ),
      ],
    );
    final buyGetDetails = await store.orders.details(store.scope, buyGetOrderId);
    expect(buyGetDetails != null, true);
    expect(buyGetDetails!.subtotal, 35);
    expect(buyGetDetails.totalDiscount, 5);
    expect(buyGetDetails.total, 30);
  });
}