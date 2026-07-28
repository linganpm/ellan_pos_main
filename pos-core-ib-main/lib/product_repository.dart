import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:convert';

import 'store_models.dart';

class ProductRepository {
  final Database db;
  ProductRepository(this.db);

  Future<Map<String, dynamic>?> getProductVariantById(StoreScope scope, String productVariantId) async {
    final rows = await db.query(
      'product_variants',
      where: 'orgId = ? AND storeId = ? AND (unique_id = ? OR localId = ? OR CAST(variantId AS TEXT) = ?)',
      whereArgs: [scope.orgId, scope.storeId, productVariantId, productVariantId, productVariantId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getProductByVariantId(StoreScope scope, String productVariantId) async {
    final variant = await getProductVariantById(scope, productVariantId);
    final variantLocalId = variant?['localId'] as String? ?? '';
    if (variantLocalId.isEmpty) {
      return null;
    }
    final rows = await db.query(
      'products',
      where: 'orgId = ? AND storeId = ? AND variantLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, variantLocalId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getCategoryById(StoreScope scope, String categoryId) async {
    final rows = await db.query(
      'categories',
      where: 'orgId = ? AND storeId = ? AND (unique_id = ? OR localId = ? OR CAST(categoryId AS TEXT) = ?)',
      whereArgs: [scope.orgId, scope.storeId, categoryId, categoryId, categoryId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> importProductsFromJson(StoreScope scope, Map<String, dynamic> data) async {
    final products = data['data'] as List<dynamic>;
    for (final product in products) {
      await db.insert('products', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'unique_id': product['unique_id'] ?? product['uniqueId'],
        'localId': product['localId'] ?? product['id']?.toString() ?? '',
        'productId': product['id'],
        'variantLocalId': product['variantLocalId'] ?? '',
        'logo': product['logo'] ?? '',
        'name': product['name'],
        'type': product['type'] ?? 0,
        'description': product['description'] ?? '',
        'is_preorder': product['is_preorder'] ?? 0,
        'is_allergens': product['is_allergens'] ?? 0,
      });
    }
  }

  Future<List<String>> getAllProductNames(StoreScope scope) async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT name FROM products WHERE orgId = ? AND storeId = ?',
      [scope.orgId, scope.storeId],
    );
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> searchProductVariants(
    StoreScope scope, {
    String? query,
    int? limit,
    int? offset,
  }) {
    final whereClauses = <String>['orgId = ?', 'storeId = ?'];
    final whereArgs = <Object?>[scope.orgId, scope.storeId];
    if (query != null && query.isNotEmpty) {
      whereClauses.add('(product_name LIKE ? OR product_variant_name LIKE ? OR barcode LIKE ?)');
      final wildcardQuery = '%$query%';
      whereArgs.addAll([wildcardQuery, wildcardQuery, wildcardQuery]);
    }

    return db.query(
      'product_variants',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'product_name COLLATE NOCASE ASC, product_variant_name COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> getProductVariantsByCategory(StoreScope scope, int categoryId) async {
    // Resolve the category's actual localId — imports may keep a non
    // `cat_<remoteId>` local key, so querying only `cat_$categoryId` misses rows.
    final categoryRows = await db.query(
      'categories',
      columns: ['localId'],
      where:
          'orgId = ? AND storeId = ? AND (categoryId = ? OR localId = ? OR localId = ? OR CAST(categoryId AS TEXT) = ?)',
      whereArgs: [
        scope.orgId,
        scope.storeId,
        categoryId,
        'cat_$categoryId',
        '$categoryId',
        '$categoryId',
      ],
      limit: 1,
    );
    final localId = categoryRows.isNotEmpty
        ? (categoryRows.first['localId'] as String? ?? '').trim()
        : '';
    final keys = <String>{
      if (localId.isNotEmpty) localId,
      'cat_$categoryId',
      '$categoryId',
    }.toList(growable: false);
    if (keys.isEmpty) return const [];

    final placeholders = List.filled(keys.length, '?').join(', ');
    return db.query(
      'product_variants',
      where:
          'orgId = ? AND storeId = ? AND categoryLocalId IN ($placeholders)',
      whereArgs: [scope.orgId, scope.storeId, ...keys],
      orderBy:
          'product_name COLLATE NOCASE ASC, product_variant_name COLLATE NOCASE ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getProductVariantsByCategoryLocalId(
    StoreScope scope,
    String categoryLocalId,
  ) async {
    final key = categoryLocalId.trim();
    if (key.isEmpty) return const [];
    return db.query(
      'product_variants',
      where: 'orgId = ? AND storeId = ? AND categoryLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, key],
      orderBy:
          'product_name COLLATE NOCASE ASC, product_variant_name COLLATE NOCASE ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listCategories(StoreScope scope) async {
    return db.query(
      'categories',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'sorting_order ASC, name COLLATE NOCASE ASC',
    );
  }

  Future<List<int>> listCategoryIdsWithVariants(StoreScope scope) async {
    final rows = await db.rawQuery(
      "SELECT DISTINCT categoryLocalId FROM product_variants WHERE orgId = ? AND storeId = ? AND categoryLocalId IS NOT NULL AND categoryLocalId != ''",
      [scope.orgId, scope.storeId],
    );
    return rows
        .map((row) => row['categoryLocalId'] as String?)
        .whereType<String>()
        .map((value) => value.replaceFirst('cat_', ''))
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  Future<int> countPendingExportProductVariants(StoreScope scope) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM product_variants WHERE orgId = ? AND storeId = ? AND exported = ?',
      [scope.orgId, scope.storeId, 0],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> listPendingExportProductVariants(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) {
    return db.query(
      'product_variants',
      where: 'orgId = ? AND storeId = ? AND exported = ?',
      whereArgs: [scope.orgId, scope.storeId, 0],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> markProductVariantsExported(StoreScope scope, List<String> localIds, {required bool exported}) async {
    if (localIds.isEmpty) {
      return 0;
    }
    final placeholders = List.filled(localIds.length, '?').join(', ');
    final lastExportedAt = exported ? DateTime.now().toIso8601String() : null;
    return db.rawUpdate(
      'UPDATE product_variants SET exported = ?, last_exported_at = ? WHERE orgId = ? AND storeId = ? AND localId IN ($placeholders)',
      [exported ? 1 : 0, lastExportedAt, scope.orgId, scope.storeId, ...localIds],
    );
  }

  Future<List<Map<String, dynamic>>> getAddonGroupsForVariant(StoreScope scope, String productVariantId) async {
    final variantRows = [await getProductVariantById(scope, productVariantId)].whereType<Map<String, dynamic>>().toList(growable: false);
    if (variantRows.isEmpty) {
      return const [];
    }
    final variantLocalId = variantRows.first['localId'] as String? ?? '';
    if (variantLocalId.isEmpty) {
      return const [];
    }
    final rows = await db.query(
      'product_variant_addon_groups',
      where: 'orgId = ? AND storeId = ? AND variantLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, variantLocalId],
      orderBy: 'source ASC, id ASC',
    );
    return rows.map((row) {
      final payload = (row['data'] as String?)?.trim();
      final decoded = payload == null || payload.isEmpty
          ? <String, dynamic>{}
          : (json.decode(payload) as Map).cast<String, dynamic>();
      return {
        ...decoded,
        'source': row['source'],
        'addon_group_id': row['addon_group_id'],
        'addon_group_name': row['addon_group_name'],
        'min_selections': row['min_selections'],
        'max_selections': row['max_selections'],
        'addon_item_data': ((decoded['addon_item_data'] as List<dynamic>?) ?? const []).map((rawItem) {
          final item = rawItem is Map<String, dynamic>
              ? rawItem
              : (rawItem as Map).cast<String, dynamic>();
          final sellPrice = _parsePrice(item['sell_price']) ?? _parsePrice(item['price']) ?? 0;
          final buyPrice = _parsePrice(item['buy_price']) ?? _parsePrice(item['price']);
          final mrpPrice = _parsePrice(item['mrp_price']) ?? _parsePrice(item['price']) ?? sellPrice;
          return {
            ...item,
            'sell_price': sellPrice,
            'buy_price': buyPrice,
            'mrp_price': mrpPrice,
          };
        }).toList(growable: false),
      };
    }).toList(growable: false);
  }

  double? _parsePrice(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
