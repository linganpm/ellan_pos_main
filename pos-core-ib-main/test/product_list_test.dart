

import 'package:test/test.dart';
import '../lib/store.dart';
import '../lib/store_models.dart';
import 'test_store_helper.dart';

void main() {
  test('List all orders using Store', () async {
    final store = await openLoggedInTestStore(orderJson: 'fixtures/order_list.json');
    final orderRows = await store.orders.listSummaries(store.scope);
    print('Orders:');
    for (final order in orderRows) {
      print('Order ID: ${order.orderId}, Restaurant: ${order.restaurantName}');
    }
    expect(orderRows.isNotEmpty, true);
    await store.close();
  });

  test('List all products using Store', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    final productNames = await store.products.listNames(store.scope);
    print('Product names:');
    for (final name in productNames) {
      print(name);
    }
    expect(productNames.isNotEmpty, true);
    await store.close();
  });
}
