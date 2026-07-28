
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../lib/store.dart';
import 'test_store_helper.dart';

void main() {
  test('Import and list product names using Store', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    final productNames = await store.products.listNames(store.scope);
    print('Product names:');
    for (final name in productNames) {
      print(name);
    }
    expect(productNames.isNotEmpty, true);
    await store.close();
  });

  test('Print product add-ons using Store fixture data', () async {
    final store = await openLoggedInTestStore(productJson: 'fixtures/product_data.json');
    final productNames = await store.products.listNames(store.scope);
    final jsonText = await File('fixtures/product_data.json').readAsString();
    final payload = json.decode(jsonText) as Map<String, dynamic>;
    final categories = payload['data'] as List<dynamic>? ?? const [];
    var addonGroupCount = 0;

    print('Product add-ons:');
    for (final rawCategory in categories.whereType<Map>()) {
      final category = rawCategory.cast<String, dynamic>();
      final variants = category['product_variants'] as List<dynamic>? ?? const [];
      for (final rawVariant in variants.whereType<Map>()) {
        final variant = rawVariant.cast<String, dynamic>();
        final productName = variant['product_name'] as String? ?? 'Unknown product';
        final variantName = variant['product_variant_name'] as String? ?? 'Unknown variant';
        final addonGroups = variant['product_variant_addon_group_data'] as List<dynamic>? ?? const [];
        final productAddonGroups = variant['product_addon_group_data'] as List<dynamic>? ?? const [];
        final allAddonGroups = <dynamic>[...productAddonGroups, ...addonGroups];

        if (allAddonGroups.isEmpty) {
          continue;
        }

        print('$productName / $variantName');
        for (final rawAddonGroup in allAddonGroups.whereType<Map>()) {
          final addonGroup = rawAddonGroup.cast<String, dynamic>();
          addonGroupCount++;
          print(
            '  Add-on group: ${addonGroup['name']} '
            '(min: ${addonGroup['min']}, max: ${addonGroup['max']})',
          );

          final addonItems = addonGroup['addon_item_data'] as List<dynamic>? ?? const [];
          for (final rawAddonItem in addonItems.whereType<Map>()) {
            final addonItem = rawAddonItem.cast<String, dynamic>();
            print('    Item: ${addonItem['name']} | price: ${addonItem['price']}');
          }
        }
      }
    }

    expect(productNames.isNotEmpty, true);
    expect(addonGroupCount, greaterThan(0));
    await store.close();
  });
}
