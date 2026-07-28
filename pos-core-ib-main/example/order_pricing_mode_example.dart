import 'dart:convert';
import 'dart:io';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final tempDir = await Directory.systemTemp.createTemp('order_pricing_mode_example_');
  final productFile = File('${tempDir.path}/pricing_mode_products.json');

  await productFile.writeAsString(jsonEncode({
    'data': [
      {
        'id': 950,
        'name': 'Pricing Demo',
        'slug': 'pricing-demo',
        'product_variants': [
          {
            'id': 9501,
            'product_variant_name': 'Combo Meal',
            'product_name': 'Combo Meal',
            'sell_price': 25.0,
            'buy_price': 16.0,
            'mrp_price': 30.0,
            'product_addon_group_data': [
              {
                'id': 'grp_side',
                'name': 'Side',
                'min': 1,
                'max': 1,
                'addon_item_data': [
                  {
                    'id': 'addon_soup',
                    'name': 'Soup',
                    'sell_price': 4.0,
                    'buy_price': 1.5,
                    'mrp_price': 5.0,
                    'active': true,
                  },
                ],
              },
            ],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 8501,
              'name': 'Combo Meal',
              'type': 1,
              'description': 'Pricing mode demo product',
              'is_preorder': 0,
              'is_allergens': 0,
            },
          },
        ],
      },
    ],
  }));

  final store = await Store.createForTest(
    config: config,
    // productJson removed: use only API sync
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
      throw StateError('Login failed for pricing mode example.');
    }

    final createdOn = DateTime.now().toIso8601String();

    final defaultOrderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Default Selling Customer',
        mobile: '+1000002001',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'order-pricing-mode-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final defaultItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: defaultOrderId,
        productVariantId: 'var_9501',
        productId: 'prod_8501',
        quantity: 2,
        createdBy: 'order-pricing-mode-example',
        createdOn: createdOn,
        addons: const [
          StoreAddOrderItemAddonRequest(
            addonGroupId: 'grp_side',
            addonGroupName: 'Side',
            addonItemId: 'addon_soup',
            addonItemName: 'Soup',
            quantity: 1,
          ),
        ],
      ),
    );

    await _printOrderSnapshot(
      store: store,
      orderId: defaultOrderId,
      itemId: defaultItemId,
      title: 'Default order mode',
    );

    final buyingOrderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Buying Mode Customer',
        mobile: '+1000002002',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'order-pricing-mode-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
        pricingMode: StoreOrderPricingMode.buying,
      ),
    );

    final buyingItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: buyingOrderId,
        productVariantId: 'var_9501',
        productId: 'prod_8501',
        quantity: 2,
        createdBy: 'order-pricing-mode-example',
        createdOn: createdOn,
        addons: const [
          StoreAddOrderItemAddonRequest(
            addonGroupId: 'grp_side',
            addonGroupName: 'Side',
            addonItemId: 'addon_soup',
            addonItemName: 'Soup',
            quantity: 1,
          ),
        ],
      ),
    );

    await _printOrderSnapshot(
      store: store,
      orderId: buyingOrderId,
      itemId: buyingItemId,
      title: 'Explicit buying mode',
    );
  } finally {
    await store.auth.logout();
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<void> _printOrderSnapshot({
  required Store store,
  required int orderId,
  required int itemId,
  required String title,
}) async {
  final order = await store.orders.getById(store.scope, orderId);
  final item = (await store.orders.listItems(store.scope, orderId)).single;
  final addon = (await store.orders.listItemAddons(store.scope, itemId)).single;

  print('\n$title');
  print('orderId=${order?.orderId} pricingMode=${order?.pricingMode} total=${order?.total}');
  print(
    'item sell=${item.sellPrice} buy=${item.buyPrice} mrp=${item.mrpPrice} '
    'base=${item.baseUnitPrice} unit=${item.unitPrice} final=${item.finalPrice}',
  );
  print(
    'addon sell=${addon.sellPrice} buy=${addon.buyPrice} mrp=${addon.mrpPrice} '
    'unit=${addon.unitPrice} total=${addon.totalPrice}',
  );
}