import 'dart:convert';
import 'dart:io';

import '../lib/store.dart';
import '../lib/store_config.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final tempDir = await Directory.systemTemp.createTemp('order_with_addon_example_');
  final productFile = File('${tempDir.path}/products_with_addons.json');

  await productFile.writeAsString(jsonEncode({
    'data': [
      {
        'id': 900,
        'name': 'Addon Demo',
        'slug': 'addon-demo',
        'product_variants': [
          {
            'id': 9001,
            'product_variant_name': 'Loaded Fries',
            'product_name': 'Loaded Fries',
            'preorder_product': false,
            'product_variant_description': 'Fries that require at least one sauce.',
            'product_variant_quantity': 50,
            'product_variant_logo': null,
            'product_data': {
              'id': 9001,
              'logo': null,
              'name': 'Loaded Fries',
              'type': 1,
              'description': null,
              'is_preorder': 0,
              'is_allergens': 0,
            },
            'category_data': {
              'id': 900,
              'name': 'Addon Demo',
              'slug': 'addon-demo',
              'active': 1,
              'parent_id': null,
              'is_preorder': 0,
              'parent_slug': null,
            },
            'product_addon_group_data': [],
            'product_variant_addon_group_data': [
              {
                'id': 77,
                'max': 2,
                'min': 1,
                'name': 'Sauces',
                'active': 1,
                'addon_item_data': [
                  {
                    'id': 701,
                    'name': 'Cheese Dip',
                    'price': 2.0,
                    'sell_price': 2.0,
                    'buy_price': 1.0,
                    'mrp_price': 2.5,
                    'active': 1,
                    'default': 0,
                    'product_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    },
                    'product_variant_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    }
                  },
                  {
                    'id': 702,
                    'name': 'Garlic Mayo',
                    'price': 1.5,
                    'sell_price': 1.5,
                    'buy_price': 0.75,
                    'mrp_price': 2.0,
                    'active': 1,
                    'default': 0,
                    'product_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    },
                    'product_variant_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    }
                  },
                  {
                    'id': 703,
                    'name': 'Hot Sauce',
                    'price': 1.0,
                    'sell_price': 1.0,
                    'buy_price': 0.5,
                    'mrp_price': 1.25,
                    'active': 1,
                    'default': 0,
                    'product_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    },
                    'product_variant_data': {
                      'id': null,
                      'name': null,
                      'active': null,
                    }
                  }
                ]
              }
            ],
            'sell_price': '10.00',
            'buy_price': null,
            'mrp_price': '10.00',
            'proportions': [],
            'offer_data': [],
            'review_max_data': 0.0,
            'review_avg_max_data': 0.0,
            'review_value_data': 0.0,
            'review_max_value_data': 0.0,
            'review_count': null,
            'favourite_data': [],
            'gallery_data': [],
            'delivery_slot_data': [],
          }
        ],
      }
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
      throw StateError('Login failed for addon example.');
    }

    final createdOn = DateTime.now().toIso8601String();
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Addon Example Customer',
        mobile: '+1000001234',
        statusName: 'Pending',
        total: 0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'order-with-addon-example',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
        pricingMode: StoreOrderPricingMode.selling,
      ),
    );
    print('Created order $orderId');

    try {
      await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: 'var_9001',
          productId: 'prod_9001',
          quantity: 2,
          createdBy: 'order-with-addon-example',
          createdOn: createdOn,
        ),
      );
      print('Unexpectedly created item without required add-ons.');
    } on StoreOrderStateException catch (error) {
      print('Blocked missing required add-ons as expected: $error');
    }

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_9001',
        productId: 'prod_9001',
        quantity: 2,
        createdBy: 'order-with-addon-example',
        createdOn: createdOn,
        addons: const [
          StoreAddOrderItemAddonRequest(
            addonGroupId: '77',
            addonGroupName: 'Sauces',
            minSelections: 1,
            maxSelections: 2,
            addonItemId: '701',
            addonItemName: 'Cheese Dip',
            quantity: 1,
          ),
        ],
      ),
    );

    var order = await store.orders.getById(store.scope, orderId);
    var item = (await store.orders.listItems(store.scope, orderId)).single;
    var addons = await store.orders.listItemAddons(store.scope, itemId);
    print('Created item $itemId with ${addons.length} add-on(s).');
    print('Item pricing after create: mode=${order?.pricingMode} sell=${item.sellPrice} buy=${item.buyPrice} base=${item.baseUnitPrice} unit=${item.unitPrice} final=${item.finalPrice} orderTotal=${order?.total}');

    await store.orders.addItemAddon(
      store.scope,
      StoreAddOrderItemAddonRequest(
        orderItemId: itemId,
        addonGroupId: '77',
        addonGroupName: 'Sauces',
        minSelections: 1,
        maxSelections: 2,
        addonItemId: '702',
        addonItemName: 'Garlic Mayo',
        quantity: 1,
      ),
    );

    order = await store.orders.getById(store.scope, orderId);
    item = (await store.orders.listItems(store.scope, orderId)).single;
    addons = await store.orders.listItemAddons(store.scope, itemId);
    print('After adding second add-on: unit=${item.unitPrice} final=${item.finalPrice} orderTotal=${order?.total}');
    for (final addon in addons) {
      print('Addon ${addon.id}: ${addon.addonItemName} qty=${addon.quantity} unit=${addon.unitPrice} total=${addon.totalPrice}');
    }

    try {
      await store.orders.addItemAddon(
        store.scope,
        StoreAddOrderItemAddonRequest(
          orderItemId: itemId,
          addonGroupId: '77',
          addonGroupName: 'Sauces',
          minSelections: 1,
          maxSelections: 2,
          addonItemId: '703',
          addonItemName: 'Hot Sauce',
          quantity: 1,
        ),
      );
      print('Unexpectedly exceeded the add-on max.');
    } on StoreOrderStateException catch (error) {
      print('Blocked third add-on as expected: $error');
    }

    final garlicMayo = addons.firstWhere((addon) => addon.addonItemId == '702');
    await store.orders.deleteItemAddon(store.scope, garlicMayo.id);

    order = await store.orders.getById(store.scope, orderId);
    item = (await store.orders.listItems(store.scope, orderId)).single;
    addons = await store.orders.listItemAddons(store.scope, itemId);
    print('After removing Garlic Mayo: unit=${item.unitPrice} final=${item.finalPrice} orderTotal=${order?.total}');

    try {
      final cheeseDip = addons.firstWhere((addon) => addon.addonItemId == '701');
      await store.orders.deleteItemAddon(store.scope, cheeseDip.id);
      print('Unexpectedly removed the last required add-on.');
    } on StoreOrderStateException catch (error) {
      print('Blocked removing the last required add-on as expected: $error');
    }
  } finally {
    await store.auth.logout();
    await store.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}