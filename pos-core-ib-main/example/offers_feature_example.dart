import 'dart:convert';
import 'dart:io';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final tempDir = await Directory.systemTemp.createTemp('offers_feature_example_');
  final productFile = File('${tempDir.path}/offers_feature_products.json');
  final offerFile = File('${tempDir.path}/offers_feature_seed.json');

  await productFile.writeAsString(jsonEncode({
    'data': [
      {
        'id': 11,
        'unique_id': 'category-meals',
        'name': 'Meals',
        'slug': 'meals',
        'product_variants': [
          {
            'id': 1101,
            'unique_id': 'variant-veg-meal',
            'product_variant_name': 'Veg Meal',
            'product_name': 'Veg Meal',
            'sell_price': 80.0,
            'buy_price': 50.0,
            'mrp_price': 90.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 2101,
              'unique_id': 'product-veg-meal',
              'name': 'Veg Meal',
              'type': 1,
              'description': 'Veg combo',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 11,
              'unique_id': 'category-meals',
              'name': 'Meals',
              'slug': 'meals',
              'active': 1,
            }
          },
          {
            'id': 1102,
            'unique_id': 'variant-mini-meal',
            'product_variant_name': 'Mini Meal',
            'product_name': 'Mini Meal',
            'sell_price': 40.0,
            'buy_price': 25.0,
            'mrp_price': 45.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 2102,
              'unique_id': 'product-mini-meal',
              'name': 'Mini Meal',
              'type': 1,
              'description': 'Mini combo',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 11,
              'unique_id': 'category-meals',
              'name': 'Meals',
              'slug': 'meals',
              'active': 1,
            }
          }
        ]
      },
      {
        'id': 22,
        'unique_id': 'category-snacks',
        'name': 'Snacks',
        'slug': 'snacks',
        'product_variants': [
          {
            'id': 2201,
            'unique_id': 'variant-samosa',
            'product_variant_name': 'Samosa',
            'product_name': 'Samosa',
            'sell_price': 20.0,
            'buy_price': 10.0,
            'mrp_price': 25.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 3201,
              'unique_id': 'product-samosa',
              'name': 'Samosa',
              'type': 1,
              'description': 'Crispy snack',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 22,
              'unique_id': 'category-snacks',
              'name': 'Snacks',
              'slug': 'snacks',
              'active': 1,
            }
          },
          {
            'id': 2202,
            'unique_id': 'variant-tea',
            'product_variant_name': 'Tea',
            'product_name': 'Tea',
            'sell_price': 10.0,
            'buy_price': 6.0,
            'mrp_price': 12.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 3202,
              'unique_id': 'product-tea',
              'name': 'Tea',
              'type': 1,
              'description': 'Hot tea',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 22,
              'unique_id': 'category-snacks',
              'name': 'Snacks',
              'slug': 'snacks',
              'active': 1,
            }
          },
          {
            'id': 2203,
            'unique_id': 'variant-cookie',
            'product_variant_name': 'Cookie',
            'product_name': 'Cookie',
            'sell_price': 5.0,
            'buy_price': 2.0,
            'mrp_price': 7.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 3203,
              'unique_id': 'product-cookie',
              'name': 'Cookie',
              'type': 1,
              'description': 'Sweet snack',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 22,
              'unique_id': 'category-snacks',
              'name': 'Snacks',
              'slug': 'snacks',
              'active': 1,
            }
          }
        ]
      },
      {
        'id': 33,
        'unique_id': 'category-combos',
        'name': 'Combos',
        'slug': 'combos',
        'product_variants': [
          {
            'id': 3301,
            'unique_id': 'variant-family-combo',
            'product_variant_name': 'Family Combo',
            'product_name': 'Family Combo',
            'sell_price': 70.0,
            'buy_price': 40.0,
            'mrp_price': 80.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 4301,
              'unique_id': 'product-family-combo',
              'name': 'Family Combo',
              'type': 1,
              'description': 'Family pack combo',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 33,
              'unique_id': 'category-combos',
              'name': 'Combos',
              'slug': 'combos',
              'active': 1,
            }
          },
          {
            'id': 3302,
            'unique_id': 'variant-party-combo',
            'product_variant_name': 'Party Combo',
            'product_name': 'Party Combo',
            'sell_price': 50.0,
            'buy_price': 30.0,
            'mrp_price': 60.0,
            'product_addon_group_data': const [],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 4302,
              'unique_id': 'product-party-combo',
              'name': 'Party Combo',
              'type': 1,
              'description': 'Party pack combo',
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 33,
              'unique_id': 'category-combos',
              'name': 'Combos',
              'slug': 'combos',
              'active': 1,
            }
          }
        ]
      }
    ]
  }));

  await offerFile.writeAsString(jsonEncode({
    'data': [
      {
        'unique_id': 'offer-meals-10pct',
        'local_id': 'offer-meals-10pct',
        'name': 'Meals 10 Percent',
        'target_type': 'category',
        'offer_type': 'percentage',
        'target_ids': ['category-meals'],
        'percentage_value': 10,
        'active': true,
      },
      {
        'unique_id': 'offer-mini-meal-flat-12',
        'local_id': 'offer-mini-meal-flat-12',
        'name': 'Mini Meal Flat 12',
        'target_type': 'product',
        'offer_type': 'flat',
        'target_ids': ['product-mini-meal'],
        'flat_value': 12,
        'active': true,
      },
      {
        'unique_id': 'offer-snacks-buy-2-get-1',
        'local_id': 'offer-snacks-buy-2-get-1',
        'name': 'Snacks Buy 2 Get 1',
        'target_type': 'category',
        'offer_type': 'buy_n_get_m',
        'target_ids': ['category-snacks'],
        'buy_quantity': 2,
        'get_quantity': 1,
        'active': true,
      },
      {
        'unique_id': 'offer-bill-10-over-100',
        'local_id': 'offer-bill-10-over-100',
        'name': 'Bill 10 Percent Above 100',
        'target_type': 'bill',
        'offer_type': 'total_offer',
        'target_ids': const [],
        'percentage_value': 10,
        'minimum_bill_amount': 100,
        'active': true,
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
      throw StateError('Login failed for offers feature example.');
    }

    print('Seeded offers:');
    for (final offer in await store.offers.list(store.scope)) {
      print('${offer.name} | type=${offer.offerType} | targetType=${offer.targetType} | targets=${offer.targetIds.join(', ')}');
    }

    await _runScenario(
      store,
      label: 'Category Percentage Offer',
      items: const [
        _ExampleItem('var_1101', 'prod_2101'),
        _ExampleItem('var_1102', 'prod_2102'),
      ],
    );

    await _runScenario(
      store,
      label: 'Product Flat Offer',
      items: const [
        _ExampleItem('var_1102', 'prod_2102'),
      ],
    );

    await _runScenario(
      store,
      label: 'Buy N Get M Offer',
      items: const [
        _ExampleItem('var_2201', 'prod_3201'),
        _ExampleItem('var_2202', 'prod_3202'),
        _ExampleItem('var_2203', 'prod_3203'),
      ],
    );

    await _runScenario(
      store,
      label: 'Bill Level Total Offer',
      items: const [
        _ExampleItem('var_3301', 'prod_4301'),
        _ExampleItem('var_3302', 'prod_4302'),
      ],
    );
  } finally {
    await store.auth.logout();
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _runScenario(
  Store store, {
  required String label,
  required List<_ExampleItem> items,
}) async {
  final createdOn = DateTime.now().toIso8601String();
  final orderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: store.storeName,
      customerName: label,
      mobile: '+1000004001',
      statusName: 'Pending',
      total: 0,
      serviceInstance: store.serviceInstanceId,
      createdBy: 'offers-feature-example',
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
        productVariantId: item.variantId,
        productId: item.productId,
        quantity: 1,
        createdBy: 'offers-feature-example',
        createdOn: createdOn,
      ),
    );
  }

  final details = await store.orders.details(store.scope, orderId);
  print('\n$label');
  print(
    'subtotal=${details?.subtotal} '
    'totalValue=${details?.totalValue} '
    'offerAppliedValue=${details?.offerAppliedValue} '
    'discount=${details?.totalDiscount} '
    'finalValue=${details?.finalValue} '
    'total=${details?.total}',
  );
  for (final offer in details?.appliedOffers ?? const <StoreAppliedOfferRecord>[]) {
    print('offer=${offer.name} type=${offer.offerType} discount=${offer.discountAmount}');
  }
  for (final item in details?.items ?? const <StoreOrderItemDetails>[]) {
    print('${item.item.productId} => line=${item.item.finalPrice} discount=${item.discountAmount} totalAfterDiscount=${item.totalAfterDiscount}');
  }
}

class _ExampleItem {
  final String variantId;
  final String productId;

  const _ExampleItem(this.variantId, this.productId);
}