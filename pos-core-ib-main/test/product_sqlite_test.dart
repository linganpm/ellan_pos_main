
import 'package:test/test.dart';

import 'test_store_helper.dart';

void main() {
  test('Load products from JSON into SQLite and list categories', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    final productNames = await store.products.listNames(store.scope);
    print('Product names from repository:');
    for (final name in productNames) {
      print(name);
    }
    expect(productNames.isNotEmpty, true);
    await store.close();
  });
}
