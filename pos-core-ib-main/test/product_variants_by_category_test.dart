
import 'package:test/test.dart';
import 'dart:convert';
import 'dart:io';

import '../lib/store.dart';
import 'test_store_helper.dart';




void main() {
  test('Print all product variants for an available category using Store', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    final categoryIds = await store.products.listCategoryIdsWithVariants(store.scope);
    expect(categoryIds.isNotEmpty, true, reason: 'No categories with product variants were imported');
    final categoryId = categoryIds.first;
    final variants = await store.products.listVariantsByCategory(store.scope, categoryId);
    print('Product Variants for categoryId=$categoryId:');
    for (final variant in variants) {
      print('Variant: \u001b[1m${variant.productVariantName}\u001b[0m, Product: ${variant.productName}');
    }
    expect(variants.isNotEmpty, true, reason: 'No product variants found for categoryId=$categoryId');
    await store.close();
  });

  test('Store product search matches variant barcode', () async {
    final tempDir = await Directory.systemTemp.createTemp('product_barcode_search_test_');
    final productFile = File('${tempDir.path}/products.json');
    await productFile.writeAsString(jsonEncode({
      'data': [
        {
          'id': 99,
          'name': 'Snacks',
          'slug': 'snacks',
          'product_variants': [
            {
              'id': 501,
              'barcode': 'SKU-998877',
              'product_variant_name': 'Masala Chips',
              'product_name': 'Chips',
              'preorder_product': false,
              'product_variant_description': 'spicy chips',
              'product_variant_quantity': 12,
              'product_variant_logo': null,
              'product_data': {
                'id': 301,
                'logo': null,
                'name': 'Chips',
                'type': 1,
                'description': null,
                'is_preorder': 0,
                'is_allergens': 0,
              },
              'category_data': {
                'id': 99,
                'name': 'Snacks',
                'slug': 'snacks',
                'active': 1,
                'parent_id': null,
                'is_preorder': 0,
                'parent_slug': null,
              },
              'product_addon_group_data': [],
              'product_variant_addon_group_data': [],
              'sell_price': '5.00',
              'buy_price': null,
              'mrp_price': '5.00',
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
            },
          ],
        },
      ],
    }));
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final store = await openLoggedInTestStore(productJson: productFile.path);
    addTearDown(store.close);

    final results = await store.products.searchDetails(scope: store.scope, query: '998877');

    expect(results.length, 1);
    expect(results.first.productName, 'Chips');
    expect(results.first.productVariantName, 'Masala Chips');
    expect(results.first.barcode, 'SKU-998877');
  });
}
