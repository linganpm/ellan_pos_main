import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import '../lib/store.dart';
import '../lib/store_exceptions.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

Map<String, dynamic> _pricingModeProductData() {
  return {
    'data': [
      {
        'id': 700,
        'name': 'Specials',
        'slug': 'specials',
        'product_variants': [
          {
            'id': 901,
            'product_variant_name': 'Chef Combo',
            'product_name': 'Chef Combo',
            'sell_price': 100.0,
            'buy_price': 60.0,
            'mrp_price': 120.0,
            'product_addon_group_data': [
              {
                'id': 'grp_extra',
                'name': 'Extras',
                'min': 1,
                'max': 2,
                'addon_item_data': [
                  {
                    'id': 'addon_sauce',
                    'name': 'Sauce',
                    'sell_price': 5.0,
                    'buy_price': 2.0,
                    'mrp_price': 7.0,
                    'active': true,
                  },
                ],
              },
            ],
            'product_variant_addon_group_data': const [],
            'product_data': {
              'id': 801,
              'name': 'Chef Combo',
              'type': 1,
              'description': 'Combo meal',
              'is_preorder': 0,
              'is_allergens': 0,
            },
          },
        ],
      },
    ],
  };
}

void main() {
  test('Import orders from JSON and list from SQLite table', () async {
    final store = await openLoggedInTestStore(orderJson: 'fixtures/order_list.json');
    final rows = await store.orders.listSummaries(store.scope);
    print('Orders from SQLite:');
    for (final row in rows) {
      print('${row.orderId}: ${row.restaurantName} [${row.statusName}] ${row.total}');
    }
    expect(rows.isNotEmpty, true);
    final importedOrder = await store.orders.getById(store.scope, 634);
    expect(importedOrder != null, true);
    expect(importedOrder!.orderType, StoreOrderType.pickUp);
    expect(importedOrder.pricingMode, StoreOrderPricingMode.selling);
    expect(importedOrder.localId.isNotEmpty, true);
    expect(importedOrder.remoteId, 634);
    await store.close();
  });

  test('Add new order and update status', () async {
    final store = await openLoggedInTestStore();
    final newOrder = StoreCreateOrderRequest(
      id: 5500009999,
      orderId: 5500009999,
      restaurantName: 'Test Restaurant',
      customerName: 'Test User',
      mobile: '1234567890',
      statusName: 'Pending',
      total: 123.45,
      serviceInstance: 1,
      createdBy: 'admin',
      createdOn: DateTime.now().toIso8601String(),
      paymentStatus: 'Unpaid',
      orderType: StoreOrderType.dineIn,
    );
    await store.orders.create(store.scope, newOrder);
    final inserted = await store.orders.getById(store.scope, 5500009999);
    expect(inserted != null, true);
    expect(inserted!.statusName, 'Pending');
    expect(inserted.localId.isNotEmpty, true);
    expect(inserted.remoteId, isNull);
    await store.orders.updateStatus(store.scope, 5500009999, 'Completed');
    final updated = await store.orders.getById(store.scope, 5500009999);
    expect(updated != null, true);
    expect(updated!.statusName, 'Completed');
    await store.close();
  });

  test('Generated order ids are random 10-digit values prefixed with 55', () async {
    final store = await openLoggedInTestStore();

    final firstOrderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Generated Order Restaurant',
        customerName: 'Generated Customer One',
        mobile: '1234567890',
        statusName: 'Pending',
        total: 10,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final secondOrderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: 'Generated Order Restaurant',
        customerName: 'Generated Customer Two',
        mobile: '1234567891',
        statusName: 'Pending',
        total: 12,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );

    expect('$firstOrderId'.length, 10);
    expect('$secondOrderId'.length, 10);
    expect('$firstOrderId'.startsWith('55'), true);
    expect('$secondOrderId'.startsWith('55'), true);
    expect(firstOrderId, isNot(secondOrderId));

    final firstOrder = await store.orders.getById(store.scope, firstOrderId);
    final secondOrder = await store.orders.getById(store.scope, secondOrderId);
    expect(firstOrder != null, true);
    expect(secondOrder != null, true);

    await store.close();
  });

  test('Add item to order_items for specific order', () async {
    final store = await openLoggedInTestStore();
    final orderId = 5500008888;
    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Test Restaurant',
        customerName: 'Test User',
        mobile: '1234567890',
        statusName: 'Pending',
        total: 99.99,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'pv-123',
        productId: 'p-456',
        quantity: 2,
        unitPrice: 49.99,
        finalPrice: 99.98,
        createdBy: 'admin',
        createdOn: DateTime.now().toIso8601String(),
      ),
    );
    final items = await store.orders.listItems(store.scope, orderId);
    expect(items.length, 1);
    expect(items.first.productVariantId, 'pv-123');
    expect(items.first.quantity, 2);
    expect(items.first.unitPrice, 49.99);
    expect(items.first.finalPrice, 99.98);
    await store.close();
  });

  test('Cannot add order item when required product addon selections are missing', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    const orderId = 5500008666;
    final createdOn = DateTime.now().toIso8601String();

    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Addon Requirement Restaurant',
        customerName: 'Addon Requirement Customer',
        mobile: '1234500000',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    await expectLater(
      store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: 'var_41',
          productId: 'prod_41',
          quantity: 1,
          unitPrice: 34,
          finalPrice: 34,
          createdBy: 'admin',
          createdOn: createdOn,
        ),
      ),
      throwsA(isA<StoreOrderStateException>()),
    );

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var_41',
        productId: 'prod_41',
        quantity: 1,
        unitPrice: 34,
        finalPrice: 34,
        createdBy: 'admin',
        createdOn: createdOn,
        addons: const [
          StoreAddOrderItemAddonRequest(
            addonGroupId: '4',
            addonGroupName: 'Toppings',
            minSelections: 1,
            maxSelections: 1,
            addonItemId: '2',
            addonItemName: 'Onion',
            quantity: 1,
            unitPrice: 0,
          ),
        ],
      ),
    );

    expect(itemId, greaterThan(0));
    final items = await store.orders.listItems(store.scope, orderId);
    expect(items.length, 1);
    expect(items.single.productVariantId, 'var_41');

    await store.close();
  });

  test('Store persists multiple payments per order including credited customer', () async {
    final store = await openLoggedInTestStore();
    const orderId = 5500007777;
    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Payment Test Restaurant',
        customerName: 'Payment Customer',
        mobile: '9999999999',
        statusName: 'Pending',
        total: 150,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Partially Paid',
        orderType: StoreOrderType.pickUp,
        payments: const [
          StoreCreateOrderPaymentRequest(
            paymentMode: StoreOrderPaymentMode.cash,
            amount: 100,
            referenceId: 'cash-001',
          ),
          StoreCreateOrderPaymentRequest(
            paymentMode: StoreOrderPaymentMode.credit,
            amount: 50,
            customerId: 'cust_001',
            referenceId: 'credit-001',
          ),
        ],
      ),
    );

    final order = await store.orders.getById(store.scope, orderId);
    expect(order != null, true);
    expect(order!.payments.length, 2);
    expect(order.localId.isNotEmpty, true);
    expect(order.remoteId, isNull);
    expect(order.payments.first.paymentMode, StoreOrderPaymentMode.cash);
    expect(order.payments.first.localId.isNotEmpty, true);
    expect(order.payments.first.remoteId, isNull);
    expect(order.payments.last.paymentMode, StoreOrderPaymentMode.credit);
    expect(order.payments.last.customerId, 'cust_001');

    final listedPayments = await store.orders.listPayments(store.scope, orderId);
    expect(listedPayments.length, 2);

    await store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.card,
        amount: 25,
        referenceId: 'card-001',
      ),
    );

    final updatedOrder = await store.orders.getById(store.scope, orderId);
    expect(updatedOrder != null, true);
    expect(updatedOrder!.payments.length, 3);
    expect(updatedOrder.payments.any((payment) => payment.paymentMode == StoreOrderPaymentMode.card), true);
    expect(updatedOrder.payments.every((payment) => payment.localId.isNotEmpty), true);
    await store.close();
  });

  test('Order item addons update item and order totals with quantity changes', () async {
    final store = await openLoggedInTestStore();
    const orderId = 5500007666;
    final createdOn = DateTime.now().toIso8601String();

    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Addon Price Restaurant',
        customerName: 'Addon Customer',
        mobile: '7777777777',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var-addon-price',
        productId: 'prod-addon-price',
        quantity: 2,
        unitPrice: 10,
        finalPrice: 20,
        createdBy: 'admin',
        createdOn: createdOn,
      ),
    );

    await store.orders.addItemAddon(
      store.scope,
      StoreAddOrderItemAddonRequest(
        orderItemId: itemId,
        addonGroupId: 'grp-toppings',
        addonGroupName: 'Toppings',
        minSelections: 1,
        maxSelections: 2,
        addonItemId: 'addon-onion',
        addonItemName: 'Onion',
        quantity: 1,
        unitPrice: 2,
      ),
    );

    var order = await store.orders.getById(store.scope, orderId);
    var items = await store.orders.listItems(store.scope, orderId);
    expect(order != null, true);
    expect(items.single.unitPrice, 12);
    expect(items.single.finalPrice, 24);
    expect(order!.total, 24);

    await store.orders.addItemAddon(
      store.scope,
      StoreAddOrderItemAddonRequest(
        orderItemId: itemId,
        addonGroupId: 'grp-toppings',
        addonGroupName: 'Toppings',
        minSelections: 1,
        maxSelections: 2,
        addonItemId: 'addon-cheese',
        addonItemName: 'Cheese',
        quantity: 1,
        unitPrice: 3,
      ),
    );

    order = await store.orders.getById(store.scope, orderId);
    items = await store.orders.listItems(store.scope, orderId);
    final addons = await store.orders.listItemAddons(store.scope, itemId);
    expect(addons.length, 2);
    expect(items.single.baseUnitPrice, 10);
    expect(items.single.unitPrice, 15);
    expect(items.single.finalPrice, 30);
    expect(order != null, true);
    expect(order!.total, 30);

    await store.orders.updateItemQuantity(store.scope, itemId, 3);

    order = await store.orders.getById(store.scope, orderId);
    items = await store.orders.listItems(store.scope, orderId);
    expect(items.single.unitPrice, 15);
    expect(items.single.finalPrice, 45);
    expect(order != null, true);
    expect(order!.total, 45);

    final cheeseAddon = addons.firstWhere((addon) => addon.addonItemId == 'addon-cheese');
    await store.orders.deleteItemAddon(store.scope, cheeseAddon.id);

    order = await store.orders.getById(store.scope, orderId);
    items = await store.orders.listItems(store.scope, orderId);
    final remainingAddons = await store.orders.listItemAddons(store.scope, itemId);
    expect(remainingAddons.length, 1);
    expect(items.single.unitPrice, 12);
    expect(items.single.finalPrice, 36);
    expect(order != null, true);
    expect(order!.total, 36);

    await store.close();
  });

  test('Order item addon group min and max are enforced on add and remove', () async {
    final store = await openLoggedInTestStore();
    const orderId = 5500007555;
    final createdOn = DateTime.now().toIso8601String();

    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Addon Validation Restaurant',
        customerName: 'Addon Validation Customer',
        mobile: '7666666666',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );

    final itemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var-addon-validation',
        productId: 'prod-addon-validation',
        quantity: 1,
        unitPrice: 20,
        finalPrice: 20,
        createdBy: 'admin',
        createdOn: createdOn,
      ),
    );

    final firstAddonId = await store.orders.addItemAddon(
      store.scope,
      StoreAddOrderItemAddonRequest(
        orderItemId: itemId,
        addonGroupId: 'grp-sides',
        addonGroupName: 'Sides',
        minSelections: 1,
        maxSelections: 2,
        addonItemId: 'addon-salad',
        addonItemName: 'Salad',
        unitPrice: 4,
      ),
    );

    final secondAddonId = await store.orders.addItemAddon(
      store.scope,
      StoreAddOrderItemAddonRequest(
        orderItemId: itemId,
        addonGroupId: 'grp-sides',
        addonGroupName: 'Sides',
        minSelections: 1,
        maxSelections: 2,
        addonItemId: 'addon-fries',
        addonItemName: 'Fries',
        unitPrice: 5,
      ),
    );

    expect(firstAddonId, greaterThan(0));
    expect(secondAddonId, greaterThan(0));

    await expectLater(
      store.orders.addItemAddon(
        store.scope,
        StoreAddOrderItemAddonRequest(
          orderItemId: itemId,
          addonGroupId: 'grp-sides',
          addonGroupName: 'Sides',
          minSelections: 1,
          maxSelections: 2,
          addonItemId: 'addon-soup',
          addonItemName: 'Soup',
          unitPrice: 6,
        ),
      ),
      throwsA(isA<StoreOrderStateException>()),
    );

    await store.orders.deleteItemAddon(store.scope, firstAddonId);

    await expectLater(
      store.orders.deleteItemAddon(store.scope, secondAddonId),
      throwsA(isA<StoreOrderStateException>()),
    );

    final remainingAddons = await store.orders.listItemAddons(store.scope, itemId);
    expect(remainingAddons.length, 1);
    expect(remainingAddons.single.addonItemId, 'addon-fries');

    await store.close();
  });

  test('Order item changes recalculate total and close requires full payment', () async {
    final store = await openLoggedInTestStore();
    const orderId = 5500007766;
    final createdOn = DateTime.now().toIso8601String();

    await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        id: orderId,
        orderId: orderId,
        restaurantName: 'Lifecycle Test Restaurant',
        customerName: 'Lifecycle Customer',
        mobile: '8888888888',
        statusName: 'Pending',
        total: 0,
        serviceInstance: 1,
        createdBy: 'admin',
        createdOn: createdOn,
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
      ),
    );

    final firstItemId = await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var-1',
        productId: 'prod-1',
        quantity: 2,
        unitPrice: 10,
        finalPrice: 20,
        createdBy: 'admin',
        createdOn: createdOn,
      ),
    );
    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'var-2',
        productId: 'prod-2',
        quantity: 1,
        unitPrice: 15,
        finalPrice: 15,
        createdBy: 'admin',
        createdOn: createdOn,
      ),
    );

    var order = await store.orders.getById(store.scope, orderId);
    expect(order != null, true);
    expect(order!.total, 35);

    await store.orders.updateItemQuantity(store.scope, firstItemId, 3);
    order = await store.orders.getById(store.scope, orderId);
    expect(order != null, true);
    expect(order!.total, 45);

    final items = await store.orders.listItems(store.scope, orderId);
    final secondItemId = items.firstWhere((item) => item.productVariantId == 'var-2').id;
    await store.orders.deleteItem(store.scope, secondItemId);

    order = await store.orders.getById(store.scope, orderId);
    expect(order != null, true);
    expect(order!.total, 30);

    await store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.cash,
        amount: 10,
        referenceId: 'cash-close-1',
      ),
    );

    await expectLater(
      store.orders.close(store.scope, orderId),
      throwsA(isA<StoreOrderStateException>()),
    );

    await store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.card,
        amount: 20,
        referenceId: 'card-close-1',
      ),
    );

    await store.orders.close(store.scope, orderId);
    order = await store.orders.getById(store.scope, orderId);
    expect(order != null, true);
    expect(order!.statusName, 'Closed');

    await store.close();
  });

  test('Product variant and addon records expose sell buy and mrp prices', () async {
    final tempDir = await Directory.systemTemp.createTemp('pricing_mode_product_test_');
    final productFile = File('${tempDir.path}/pricing_mode_products.json');
    await productFile.writeAsString(jsonEncode(_pricingModeProductData()));
    final store = await openAdminLoggedInTestStore(productJson: productFile.path);

    try {
      final variants = await store.products.listVariantsByCategory(store.scope, 700);
      expect(variants.length, 1);
      expect(variants.single.localId, 'var_901');
      expect(variants.single.sellPrice, 100);
      expect(variants.single.buyPrice, 60);
      expect(variants.single.mrpPrice, 120);

      final addonGroups = await store.products.listAddonGroupsForVariant(store.scope, 'var_901');
      expect(addonGroups.length, 1);
      expect(addonGroups.single.items.length, 1);
      expect(addonGroups.single.items.single.sellPrice, 5);
      expect(addonGroups.single.items.single.buyPrice, 2);
      expect(addonGroups.single.items.single.mrpPrice, 7);
    } finally {
      await store.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });

  test('Buying mode uses buy price for items and addons', () async {
    final tempDir = await Directory.systemTemp.createTemp('pricing_mode_buy_order_test_');
    final productFile = File('${tempDir.path}/pricing_mode_products.json');
    await productFile.writeAsString(jsonEncode(_pricingModeProductData()));
    final store = await openAdminLoggedInTestStore(productJson: productFile.path);

    try {
      const orderId = 5500007444;
      final createdOn = DateTime.now().toIso8601String();

      await store.orders.create(
        store.scope,
        StoreCreateOrderRequest(
          id: orderId,
          orderId: orderId,
          restaurantName: 'Buying Mode Restaurant',
          customerName: 'Buying Mode Customer',
          mobile: '7444444444',
          statusName: 'Pending',
          total: 0,
          serviceInstance: 1,
          createdBy: 'admin',
          createdOn: createdOn,
          paymentStatus: 'Unpaid',
          orderType: StoreOrderType.dineIn,
          pricingMode: StoreOrderPricingMode.buying,
        ),
      );

      final itemId = await store.orders.addItem(
        store.scope,
        StoreAddOrderItemRequest(
          orderId: orderId,
          productVariantId: 'var_901',
          productId: 'prod_801',
          quantity: 2,
          createdBy: 'admin',
          createdOn: createdOn,
          addons: const [
            StoreAddOrderItemAddonRequest(
              addonGroupId: 'grp_extra',
              addonGroupName: 'Extras',
              addonItemId: 'addon_sauce',
              addonItemName: 'Sauce',
              quantity: 1,
            ),
          ],
        ),
      );

      final order = await store.orders.getById(store.scope, orderId);
      final items = await store.orders.listItems(store.scope, orderId);
      final addons = await store.orders.listItemAddons(store.scope, itemId);

      expect(order != null, true);
      expect(order!.pricingMode, StoreOrderPricingMode.buying);
      expect(items.single.pricingMode, StoreOrderPricingMode.buying);
      expect(items.single.sellPrice, 100);
      expect(items.single.buyPrice, 60);
      expect(items.single.mrpPrice, 120);
      expect(items.single.baseUnitPrice, 60);
      expect(items.single.unitPrice, 62);
      expect(items.single.finalPrice, 124);
      expect(addons.single.pricingMode, StoreOrderPricingMode.buying);
      expect(addons.single.sellPrice, 5);
      expect(addons.single.buyPrice, 2);
      expect(addons.single.mrpPrice, 7);
      expect(addons.single.unitPrice, 2);
      expect(addons.single.totalPrice, 2);
      expect(order.total, 124);
    } finally {
      await store.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
