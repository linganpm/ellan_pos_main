import 'dart:convert';
import 'dart:io';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final tempDir = await Directory.systemTemp.createTemp('order_offers_example_');
  final productFile = File('${tempDir.path}/offers_products.json');
  final offerFile = File('${tempDir.path}/offers_seed.json');

  await productFile.writeAsString(jsonEncode({
    'data': [
      {
        'id': 11,
        'name': 'Meals',
        'slug': 'meals',
        'product_variants': [
          {
            'id': 1101,
            'product_variant_name': 'Veg Meal',
            'product_name': 'Veg Meal',
            'sell_price': 80.0,
            'buy_price': 50.0,
            'mrp_price': 90.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 2101,
              'name': 'Veg Meal',
              'type': 1,
              'description': 'Veg combo',
              'is_preorder': 0,
              'is_allergens': 0
            }
          },
          {
            'id': 1102,
            'product_variant_name': 'Mini Meal',
            'product_name': 'Mini Meal',
            'sell_price': 40.0,
            'buy_price': 25.0,
            'mrp_price': 45.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 2102,
              'name': 'Mini Meal',
              'type': 1,
              'description': 'Mini combo',
              'is_preorder': 0,
              'is_allergens': 0
            }
          }
        ]
      }
    ]
  }));

  await offerFile.writeAsString(jsonEncode({
    'data': [
      {
        'local_id': 'offer-category-flat',
        'name': 'Meals Flat 15',
        'target_type': 'category',
        'offer_type': 'flat',
        'target_ids': ['11'],
        'flat_value': 15,
        'active': true
      },
      {
        'local_id': 'offer-bill-10pct',
        'name': 'Bill 10 Percent Above 100',
        'target_type': 'bill',
        'offer_type': 'total_offer',
        'target_ids': const [],
        'percentage_value': 10,
        'minimum_bill_amount': 100,
        'active': true
      }
    ]
  }));

  final store = await Store.createForTest(
    config: config,
    // productJson and offerJson removed: use only API sync
  );

  try {
    final session = await store.auth.login(
      store.scope,
      StoreLoginRequest(
        email: config.defaultLogin.email,
        password: config.defaultLogin.password,
      ),
    );
    if (session == null) {
      throw StateError('Login failed for offers example.');
    }

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Offer Seed Customer',
        mobile: '+1000003001',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'order-offers-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1101',
        productId: 'prod_2101',
        quantity: 1,
        createdBy: 'order-offers-example',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_1102',
        productId: 'prod_2102',
        quantity: 1,
        createdBy: 'order-offers-example',
        createdOn: createdOn,
      ),
    );

    final offers = await store.offers.list(store.scope);
    final details = await store.orders.details(store.scope, orderId);

    print('Seeded offers:');
    for (final offer in offers) {
      print(
        '${offer.localId}: ${offer.name} '
        'type=${offer.offerType} '
        'targetType=${offer.targetType} '
        'targets=${offer.targetIds.join(',')} '
        'percentage=${offer.percentageValue} '
        'flat=${offer.flatValue} '
        'minimumBill=${offer.minimumBillAmount}',
      );
    }

    print('\nOrder details after seeded offers applied:');
    print(
      'subtotal=${details?.subtotal} '
      'totalValue=${details?.totalValue} '
      'offerAppliedValue=${details?.offerAppliedValue} '
      'totalDiscount=${details?.totalDiscount} '
      'finalValue=${details?.finalValue} '
      'total=${details?.total}',
    );
    print('Applied offers:');
    for (final appliedOffer in details?.appliedOffers ?? const <StoreAppliedOfferRecord>[]) {
      print(
        '${appliedOffer.name}: '
        'type=${appliedOffer.offerType} '
        'discount=${appliedOffer.discountAmount} '
        'items=${appliedOffer.orderItemIds.join(',')}',
      );
    }
    for (final item in details?.items ?? const <StoreOrderItemDetails>[]) {
      print('${item.item.productId}: line=${item.item.finalPrice} discount=${item.discountAmount} totalAfterDiscount=${item.totalAfterDiscount} offers=${item.appliedOfferLocalIds.join(',')}');
    }
  } finally {
    await store.auth.logout();
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}