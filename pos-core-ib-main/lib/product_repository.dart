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
    final whereClauses = <String>['orgId = ?', 'storeId = ?', 'deleted = 0'];
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
          'orgId = ? AND storeId = ? AND deleted = 0 AND categoryLocalId IN ($placeholders)',
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
      where: 'orgId = ? AND storeId = ? AND categoryLocalId = ? AND deleted = 0',
      whereArgs: [scope.orgId, scope.storeId, key],
      orderBy:
          'product_name COLLATE NOCASE ASC, product_variant_name COLLATE NOCASE ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listCategories(StoreScope scope) async {
    return db.query(
      'categories',
      where: 'orgId = ? AND storeId = ? AND deleted = 0',
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
      // product_variants PK is localId — there is no integer `id` column.
      orderBy: 'localId ASC',
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

  /// Write-back server ids from products export mappings onto local SQLite rows.
  Future<void> applyProductExportMappings(
    StoreScope scope,
    List<Map<String, dynamic>> mappings,
  ) async {
    for (final mapping in mappings) {
      final variantLocalId = '${mapping['localId'] ?? ''}'.trim();
      if (variantLocalId.isEmpty) continue;

      final uniqueId = '${mapping['unique_id'] ?? mapping['variant_id'] ?? ''}'.trim();
      final variantIdRaw = mapping['variant_id'];
      final variantId = variantIdRaw is int
          ? variantIdRaw
          : int.tryParse('${variantIdRaw ?? ''}');
      final masterProductUnique =
          '${mapping['master_product_unique_id'] ?? ''}'.trim();

      final variantUpdate = <String, Object?>{};
      if (uniqueId.isNotEmpty) variantUpdate['unique_id'] = uniqueId;
      if (variantId != null) variantUpdate['variantId'] = variantId;
      if (masterProductUnique.isNotEmpty) {
        variantUpdate['master_unique_id'] = masterProductUnique;
      }
      if (variantUpdate.isNotEmpty) {
        await db.update(
          'product_variants',
          variantUpdate,
          where: 'orgId = ? AND storeId = ? AND localId = ?',
          whereArgs: [scope.orgId, scope.storeId, variantLocalId],
        );
      }

      final categoryLocalId = '${mapping['category_local_id'] ?? ''}'.trim();
      final categoryUnique =
          '${mapping['category_unique_id'] ?? mapping['category_id'] ?? ''}'.trim();
      final categoryIdRaw = mapping['category_id'];
      final categoryId = categoryIdRaw is int
          ? categoryIdRaw
          : int.tryParse('${categoryIdRaw ?? ''}');
      final masterCategoryUnique =
          '${mapping['master_category_unique_id'] ?? ''}'.trim();
      if (categoryLocalId.isNotEmpty) {
        final beforeCats = await db.query(
          'categories',
          columns: ['name', 'short_code', 'master_unique_id'],
          where: 'orgId = ? AND storeId = ? AND localId = ?',
          whereArgs: [scope.orgId, scope.storeId, categoryLocalId],
          limit: 1,
        );
        final previousMasterCat =
            beforeCats.isEmpty
                ? ''
                : '${beforeCats.first['master_unique_id'] ?? ''}'.trim();
        final categoryUpdate = <String, Object?>{};
        if (categoryUnique.isNotEmpty) categoryUpdate['unique_id'] = categoryUnique;
        if (categoryId != null) {
          categoryUpdate['categoryId'] = categoryId;
          categoryUpdate['id'] = categoryId;
        }
        if (masterCategoryUnique.isNotEmpty) {
          categoryUpdate['master_unique_id'] = masterCategoryUnique;
        }
        if (categoryUpdate.isNotEmpty) {
          await db.update(
            'categories',
            categoryUpdate,
            where: 'orgId = ? AND storeId = ? AND localId = ?',
            whereArgs: [scope.orgId, scope.storeId, categoryLocalId],
          );
        }
        if (masterCategoryUnique.isNotEmpty) {
          final name = beforeCats.isEmpty
              ? ''
              : '${beforeCats.first['name'] ?? ''}'.trim();
          if (name.isNotEmpty) {
            String? reclaimLocalId;
            if (previousMasterCat.isNotEmpty &&
                previousMasterCat != masterCategoryUnique) {
              final legacy = await db.query(
                'master_categories',
                columns: ['localId'],
                where: 'orgId = ? AND unique_id = ?',
                whereArgs: [scope.orgId, previousMasterCat],
                limit: 1,
              );
              if (legacy.isNotEmpty) {
                reclaimLocalId = '${legacy.first['localId']}';
              }
            }
            await upsertMasterCategory(
              orgId: scope.orgId,
              localId: reclaimLocalId ?? 'mcat_$masterCategoryUnique',
              uniqueId: masterCategoryUnique,
              name: name,
              shortCode: beforeCats.isEmpty
                  ? null
                  : '${beforeCats.first['short_code'] ?? ''}'.trim().isEmpty
                      ? null
                      : '${beforeCats.first['short_code']}'.trim(),
            );
          }
        }
      }

      final productLocalId = '${mapping['product_local_id'] ?? ''}'.trim();
      final productUnique =
          '${mapping['product_unique_id'] ?? mapping['product_id'] ?? ''}'.trim();
      final productIdRaw = mapping['product_id'];
      final productId = productIdRaw is int
          ? productIdRaw
          : int.tryParse('${productIdRaw ?? ''}');
      if (productLocalId.isNotEmpty) {
        final beforeProducts = await db.query(
          'products',
          columns: ['name', 'description', 'master_unique_id'],
          where: 'orgId = ? AND storeId = ? AND localId = ?',
          whereArgs: [scope.orgId, scope.storeId, productLocalId],
          limit: 1,
        );
        final previousMasterProd = beforeProducts.isEmpty
            ? ''
            : '${beforeProducts.first['master_unique_id'] ?? ''}'.trim();
        final productUpdate = <String, Object?>{};
        if (productUnique.isNotEmpty) productUpdate['unique_id'] = productUnique;
        // products PK is localId; server id lives in productId (no `id` column).
        if (productId != null) productUpdate['productId'] = productId;
        if (masterProductUnique.isNotEmpty) {
          productUpdate['master_unique_id'] = masterProductUnique;
        }
        if (productUpdate.isNotEmpty) {
          await db.update(
            'products',
            productUpdate,
            where: 'orgId = ? AND storeId = ? AND localId = ?',
            whereArgs: [scope.orgId, scope.storeId, productLocalId],
          );
        }
        if (masterProductUnique.isNotEmpty) {
          final pname = beforeProducts.isEmpty
              ? ''
              : '${beforeProducts.first['name'] ?? ''}'.trim();
          if (pname.isNotEmpty) {
            String? reclaimLocalId;
            if (previousMasterProd.isNotEmpty &&
                previousMasterProd != masterProductUnique) {
              final legacy = await db.query(
                'master_products',
                columns: ['localId'],
                where: 'orgId = ? AND unique_id = ?',
                whereArgs: [scope.orgId, previousMasterProd],
                limit: 1,
              );
              if (legacy.isNotEmpty) {
                reclaimLocalId = '${legacy.first['localId']}';
              }
            }
            await upsertMasterProduct(
              orgId: scope.orgId,
              localId: reclaimLocalId ?? 'mprod_$masterProductUnique',
              uniqueId: masterProductUnique,
              name: pname,
              description: beforeProducts.isEmpty
                  ? null
                  : '${beforeProducts.first['description'] ?? ''}',
              masterCategoryUniqueId: masterCategoryUnique.isEmpty
                  ? null
                  : masterCategoryUnique,
            );
          }
        }
      } else if (masterProductUnique.isNotEmpty || productUnique.isNotEmpty) {
        // Fall back: product linked via variant localId.
        final product = await getProductByVariantId(scope, variantLocalId);
        final resolvedLocal = '${product?['localId'] ?? ''}'.trim();
        if (resolvedLocal.isNotEmpty) {
          final productUpdate = <String, Object?>{};
          if (productUnique.isNotEmpty) productUpdate['unique_id'] = productUnique;
          if (productId != null) productUpdate['productId'] = productId;
          if (masterProductUnique.isNotEmpty) {
            productUpdate['master_unique_id'] = masterProductUnique;
          }
          await db.update(
            'products',
            productUpdate,
            where: 'orgId = ? AND storeId = ? AND localId = ?',
            whereArgs: [scope.orgId, scope.storeId, resolvedLocal],
          );
        }
      }
    }
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

  String _newLocalId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  /// Tenant master categories available for linking into any branch store.
  Future<List<Map<String, dynamic>>> listMasterCategories(String orgId) {
    return db.query(
      'master_categories',
      where: 'orgId = ?',
      whereArgs: [orgId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<Map<String, dynamic>> upsertMasterCategory({
    required String orgId,
    String? localId,
    String? uniqueId,
    required String name,
    String? shortCode,
    String? serviceVariantType,
  }) async {
    final requestedLocal = (localId ?? '').trim();
    final resolvedUnique = (uniqueId ?? '').trim().isEmpty
        ? (requestedLocal.isEmpty ? _newLocalId('mcat') : requestedLocal)
        : uniqueId!.trim();

    String id = requestedLocal;
    // Prefer an existing row that already owns this unique_id (avoids mcat_ts + mcat_server dupes).
    final byUnique = await db.query(
      'master_categories',
      where: 'orgId = ? AND unique_id = ?',
      whereArgs: [orgId, resolvedUnique],
      limit: 1,
    );
    if (byUnique.isNotEmpty) {
      id = '${byUnique.first['localId']}';
    } else if (id.isNotEmpty) {
      final byLocal = await db.query(
        'master_categories',
        where: 'orgId = ? AND localId = ?',
        whereArgs: [orgId, id],
        limit: 1,
      );
      if (byLocal.isEmpty) {
        // Also reclaim a local-created master whose unique_id still equals its localId.
        final byLegacyUnique = await db.query(
          'master_categories',
          where: 'orgId = ? AND unique_id = ?',
          whereArgs: [orgId, id],
          limit: 1,
        );
        if (byLegacyUnique.isNotEmpty) {
          id = '${byLegacyUnique.first['localId']}';
        }
      }
    }
    if (id.isEmpty) {
      id = 'mcat_$resolvedUnique';
    }

    final row = <String, Object?>{
      'localId': id,
      'orgId': orgId,
      'unique_id': resolvedUnique,
      'name': name.trim(),
      'short_code': shortCode?.trim(),
      'service_variant_type': serviceVariantType?.trim(),
      'exported': 0,
      'last_exported_at': null,
    };
    await db.insert(
      'master_categories',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return row.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> upsertMasterProduct({
    required String orgId,
    String? localId,
    String? uniqueId,
    required String name,
    String? masterCategoryUniqueId,
    String? description,
  }) async {
    final requestedLocal = (localId ?? '').trim();
    final resolvedUnique = (uniqueId ?? '').trim().isEmpty
        ? (requestedLocal.isEmpty ? _newLocalId('mprod') : requestedLocal)
        : uniqueId!.trim();

    String id = requestedLocal;
    final byUnique = await db.query(
      'master_products',
      where: 'orgId = ? AND unique_id = ?',
      whereArgs: [orgId, resolvedUnique],
      limit: 1,
    );
    if (byUnique.isNotEmpty) {
      id = '${byUnique.first['localId']}';
    } else if (id.isNotEmpty) {
      final byLocal = await db.query(
        'master_products',
        where: 'orgId = ? AND localId = ?',
        whereArgs: [orgId, id],
        limit: 1,
      );
      if (byLocal.isEmpty) {
        final byLegacyUnique = await db.query(
          'master_products',
          where: 'orgId = ? AND unique_id = ?',
          whereArgs: [orgId, id],
          limit: 1,
        );
        if (byLegacyUnique.isNotEmpty) {
          id = '${byLegacyUnique.first['localId']}';
        }
      }
    }
    if (id.isEmpty) {
      id = 'mprod_$resolvedUnique';
    }

    final row = <String, Object?>{
      'localId': id,
      'orgId': orgId,
      'unique_id': resolvedUnique,
      'master_category_unique_id': masterCategoryUniqueId?.trim(),
      'name': name.trim(),
      'description': description?.trim() ?? '',
      'exported': 0,
      'last_exported_at': null,
    };
    await db.insert(
      'master_products',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return row.cast<String, dynamic>();
  }

  /// Links a master category into the open store (local copy).
  Future<Map<String, dynamic>> linkMasterCategoryToStore({
    required StoreScope scope,
    required String masterLocalId,
  }) async {
    final masters = await db.query(
      'master_categories',
      where: 'orgId = ? AND localId = ?',
      whereArgs: [scope.orgId, masterLocalId],
      limit: 1,
    );
    if (masters.isEmpty) {
      throw StateError('Master category not found');
    }
    final master = masters.first;
    final masterUnique =
        '${master['unique_id'] ?? master['localId']}'.trim();
    final existing = await db.query(
      'categories',
      where: 'orgId = ? AND storeId = ? AND master_unique_id = ?',
      whereArgs: [scope.orgId, scope.storeId, masterUnique],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await db.update(
        'categories',
        {'exported': 0, 'last_exported_at': null, 'name': master['name']},
        where: 'localId = ?',
        whereArgs: [existing.first['localId']],
      );
      return Map<String, dynamic>.from(existing.first)
        ..['name'] = master['name']
        ..['exported'] = 0;
    }
    final localId = _newLocalId('cat');
    final row = <String, Object?>{
      'localId': localId,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': localId,
      'categoryId': null,
      'name': master['name'],
      'slug': '',
      'logo': '',
      'sorting_order': 0,
      'description': '',
      'parent_id': null,
      'short_code': master['short_code'],
      'depth': 1,
      'path': master['name'],
      'id': null,
      'master_unique_id': masterUnique,
      'exported': 0,
      'last_exported_at': null,
      'deleted': 0,
    };
    await db.insert('categories', row);
    return row.cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createLocalSellableItem({
    required StoreScope scope,
    required String categoryLocalId,
    required String productName,
    required String packageName,
    required double sellPrice,
    required String unitLabel,
    required double unitQty,
    String? taxLabel,
    String? description,
  }) async {
    final category = await getCategoryById(scope, categoryLocalId);
    if (category == null) {
      throw StateError('Category not found');
    }
    final masterCatUnique =
        '${category['master_unique_id'] ?? category['unique_id'] ?? category['localId']}'
            .trim();

    final masterProductId = _newLocalId('mprod');
    await db.insert('master_products', {
      'localId': masterProductId,
      'orgId': scope.orgId,
      'unique_id': masterProductId,
      'master_category_unique_id': masterCatUnique,
      'name': productName.trim(),
      'description': description?.trim() ?? '',
      'exported': 0,
      'last_exported_at': null,
    });

    final productLocalId = _newLocalId('prod');
    final variantLocalId = _newLocalId('var');
    await db.insert('products', {
      'localId': productLocalId,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': productLocalId,
      'productId': null,
      'variantLocalId': variantLocalId,
      'logo': '',
      'name': productName.trim(),
      'type': 0,
      'description': description?.trim() ?? '',
      'is_preorder': 0,
      'is_allergens': 0,
      'categoryLocalId': category['localId'],
      'master_unique_id': masterProductId,
      'exported': 0,
      'deleted': 0,
    });

    final qty = unitQty <= 0 ? 1.0 : unitQty;
    await db.insert('product_variants', {
      'localId': variantLocalId,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': variantLocalId,
      'variantId': null,
      'categoryLocalId': category['localId'],
      'barcode': '',
      'product_variant_name': packageName.trim(),
      'product_name': productName.trim(),
      'preorder_product': 0,
      'product_variant_description': description?.trim() ?? '',
      'product_variant_quantity': qty.round(),
      'product_variant_logo': '',
      'sell_price': sellPrice.toStringAsFixed(2),
      'buy_price': sellPrice.toStringAsFixed(2),
      'mrp_price': sellPrice.toStringAsFixed(2),
      'sell_unit_code': null,
      'sell_unit_short': unitLabel.trim(),
      'sell_unit_label': unitLabel.trim(),
      'sell_unit_base_qty': qty,
      'tax_label': taxLabel?.trim(),
      'master_unique_id': variantLocalId,
      'exported': 0,
      'last_imported_at': null,
      'last_exported_at': null,
      'deleted': 0,
    });

    return {
      'productLocalId': productLocalId,
      'variantLocalId': variantLocalId,
      'masterProductLocalId': masterProductId,
      'categoryLocalId': category['localId'],
    };
  }

  Future<void> updateLocalVariant({
    required StoreScope scope,
    required String variantLocalId,
    String? packageName,
    String? productName,
    double? sellPrice,
    String? unitLabel,
    double? unitQty,
    String? taxLabel,
    String? description,
  }) async {
    final existing = await getProductVariantById(scope, variantLocalId);
    if (existing == null) {
      throw StateError('Variant not found');
    }
    final updates = <String, Object?>{
      'exported': 0,
      'last_exported_at': null,
    };
    if (packageName != null) updates['product_variant_name'] = packageName.trim();
    if (productName != null) updates['product_name'] = productName.trim();
    if (sellPrice != null) {
      final price = sellPrice.toStringAsFixed(2);
      updates['sell_price'] = price;
      updates['buy_price'] = price;
      updates['mrp_price'] = price;
    }
    if (unitLabel != null) {
      updates['sell_unit_short'] = unitLabel.trim();
      updates['sell_unit_label'] = unitLabel.trim();
    }
    if (unitQty != null) {
      updates['sell_unit_base_qty'] = unitQty <= 0 ? 1.0 : unitQty;
      updates['product_variant_quantity'] = (unitQty <= 0 ? 1.0 : unitQty).round();
    }
    if (taxLabel != null) updates['tax_label'] = taxLabel.trim();
    if (description != null) {
      updates['product_variant_description'] = description.trim();
    }
    await db.update(
      'product_variants',
      updates,
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, existing['localId']],
    );
  }

  Future<Map<String, dynamic>> upsertLocalOffer({
    required StoreScope scope,
    String? localId,
    required String name,
    required String offerType,
    double? percentageValue,
    double? flatValue,
    double? minimumBillAmount,
    String? description,
    List<String> targetVariantLocalIds = const [],
  }) async {
    final id =
        (localId ?? '').trim().isEmpty ? _newLocalId('offer') : localId!.trim();
    final now = DateTime.now().toIso8601String();
    final row = <String, Object?>{
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': id,
      'local_id': id,
      'name': name.trim(),
      'target_type': targetVariantLocalIds.isEmpty ? 'bill' : 'product',
      'offer_type': offerType,
      'percentage_value': percentageValue,
      'flat_value': flatValue,
      'minimum_bill_amount': minimumBillAmount,
      'buy_quantity': null,
      'get_quantity': null,
      'active': 1,
      'created_on': now,
      'updated_on': now,
      'exported': 0,
      'description': description?.trim() ?? '',
      'deleted': 0,
    };
    final existing = await db.query(
      'offers',
      where: 'orgId = ? AND storeId = ? AND local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('offers', row);
    } else {
      row['created_on'] = existing.first['created_on'];
      await db.update(
        'offers',
        row,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
    await db.delete(
      'offer_targets',
      where: 'orgId = ? AND storeId = ? AND offer_local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    for (final target in targetVariantLocalIds) {
      if (target.trim().isEmpty) continue;
      await db.insert('offer_targets', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'offer_local_id': id,
        'target_value': target.trim(),
      });
    }
    return row.cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listLocalOffers(StoreScope scope) {
    return db.query(
      'offers',
      where: 'orgId = ? AND storeId = ? AND COALESCE(deleted, 0) = 0',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<List<String>> listOfferTargetVariantIds(
    StoreScope scope,
    String offerLocalId,
  ) async {
    final id = offerLocalId.trim();
    if (id.isEmpty) return const [];
    final rows = await db.query(
      'offer_targets',
      columns: ['target_value'],
      where: 'orgId = ? AND storeId = ? AND offer_local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    return rows
        .map((row) => '${row['target_value'] ?? ''}'.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> upsertAddonGroup({
    required StoreScope scope,
    String? localId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    List<({String name, double price})> items = const [],
  }) async {
    final id =
        (localId ?? '').trim().isEmpty ? _newLocalId('agrp') : localId!.trim();
    await db.insert(
      'catalog_addon_groups',
      {
        'localId': id,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'unique_id': id,
        'name': name.trim(),
        'min_select': minSelect,
        'max_select': maxSelect < 1 ? 1 : maxSelect,
        'exported': 0,
        'last_exported_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.delete(
      'catalog_addon_items',
      where: 'orgId = ? AND storeId = ? AND groupLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    for (final item in items) {
      final itemId = _newLocalId('aitm');
      await db.insert('catalog_addon_items', {
        'localId': itemId,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'groupLocalId': id,
        'unique_id': itemId,
        'name': item.name.trim(),
        'price': item.price.toStringAsFixed(2),
        'exported': 0,
      });
    }
    return {'localId': id, 'name': name.trim()};
  }

  Future<void> linkAddonGroupToVariant({
    required StoreScope scope,
    required String variantLocalId,
    required String groupLocalId,
  }) async {
    await db.insert(
      'catalog_variant_addon_links',
      {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'variantLocalId': variantLocalId,
        'groupLocalId': groupLocalId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.update(
      'product_variants',
      {'exported': 0, 'last_exported_at': null},
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, variantLocalId],
    );
  }

  Future<List<Map<String, dynamic>>> listAddonGroups(StoreScope scope) {
    return db.query(
      'catalog_addon_groups',
      where: 'orgId = ? AND storeId = ? AND deleted = 0',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listAddonItemsForGroup(
    StoreScope scope,
    String groupLocalId,
  ) {
    return db.query(
      'catalog_addon_items',
      where: 'orgId = ? AND storeId = ? AND groupLocalId = ? AND deleted = 0',
      whereArgs: [scope.orgId, scope.storeId, groupLocalId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  /// Rich export rows: pending variants with category + product + addons + offers.
  Future<List<Map<String, dynamic>>> listPendingExportCatalogRows(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    final variants = await listPendingExportProductVariants(
      scope,
      limit: limit,
      offset: offset,
    );
    final rows = <Map<String, dynamic>>[];
    for (final variant in variants) {
      final categoryLocalId = '${variant['categoryLocalId'] ?? ''}'.trim();
      final category = categoryLocalId.isEmpty
          ? null
          : await getCategoryById(scope, categoryLocalId);
      final product = await getProductByVariantId(
        scope,
        '${variant['localId']}',
      );
      List<Map<String, Object?>> addonLinks = const [];
      try {
        addonLinks = await db.query(
          'catalog_variant_addon_links',
          where: 'orgId = ? AND storeId = ? AND variantLocalId = ?',
          whereArgs: [scope.orgId, scope.storeId, variant['localId']],
        );
      } catch (_) {
        // Older DBs may lack catalogue addon tables until schema repair runs.
      }
      final addonGroups = <Map<String, dynamic>>[];
      for (final link in addonLinks) {
        List<Map<String, Object?>> groups = const [];
        try {
          groups = await db.query(
            'catalog_addon_groups',
            where: 'orgId = ? AND storeId = ? AND localId = ?',
            whereArgs: [scope.orgId, scope.storeId, link['groupLocalId']],
            limit: 1,
          );
        } catch (_) {
          continue;
        }
        if (groups.isEmpty) continue;
        final group = Map<String, dynamic>.from(groups.first);
        try {
          group['items'] = await listAddonItemsForGroup(
            scope,
            '${group['localId']}',
          );
        } catch (_) {
          group['items'] = const <Map<String, dynamic>>[];
        }
        addonGroups.add(group);
      }
      rows.add({
        ...variant,
        'deleted': (variant['deleted'] as num?)?.toInt() == 1 ? 1 : 0,
        'category': category,
        'product': product,
        'addon_groups': addonGroups,
        'master_category_unique_id':
            category?['master_unique_id'] ?? category?['unique_id'],
        'master_product_unique_id':
            product?['master_unique_id'] ?? product?['unique_id'],
      });
    }
    return rows;
  }

  Future<int> countPendingExportOffers(StoreScope scope) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM offers WHERE orgId = ? AND storeId = ? AND exported = ?',
      [scope.orgId, scope.storeId, 0],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> listPendingExportOffers(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    return db.query(
      'offers',
      where: 'orgId = ? AND storeId = ? AND exported = ?',
      whereArgs: [scope.orgId, scope.storeId, 0],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> markOffersExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    if (localIds.isEmpty) return 0;
    final placeholders = List.filled(localIds.length, '?').join(',');
    return db.rawUpdate(
      'UPDATE offers SET exported = ? WHERE orgId = ? AND storeId = ? AND local_id IN ($placeholders)',
      [exported ? 1 : 0, scope.orgId, scope.storeId, ...localIds],
    );
  }

  Future<int> markAddonGroupsExportedForVariants(
    StoreScope scope,
    List<String> variantLocalIds,
  ) async {
    if (variantLocalIds.isEmpty) return 0;
    final placeholders = List.filled(variantLocalIds.length, '?').join(',');
    List<Map<String, Object?>> links;
    try {
      links = await db.rawQuery(
        '''
        SELECT DISTINCT groupLocalId FROM catalog_variant_addon_links
        WHERE orgId = ? AND storeId = ? AND variantLocalId IN ($placeholders)
        ''',
        [scope.orgId, scope.storeId, ...variantLocalIds],
      );
    } catch (_) {
      return 0;
    }
    final groupIds = links
        .map((row) => '${row['groupLocalId'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (groupIds.isEmpty) return 0;
    final groupPlaceholders = List.filled(groupIds.length, '?').join(',');
    final now = DateTime.now().toIso8601String();
    try {
      return await db.rawUpdate(
        '''
        UPDATE catalog_addon_groups SET exported = 1, last_exported_at = ?
        WHERE orgId = ? AND storeId = ? AND localId IN ($groupPlaceholders)
        ''',
        [now, scope.orgId, scope.storeId, ...groupIds],
      );
    } catch (_) {
      return 0;
    }
  }

  Future<void> markCatalogMastersExportedFromVariants(
    StoreScope scope,
    List<String> variantLocalIds,
  ) async {
    if (variantLocalIds.isEmpty) return;
    final placeholders = List.filled(variantLocalIds.length, '?').join(',');
    final now = DateTime.now().toIso8601String();
    await db.rawUpdate(
      '''
      UPDATE categories SET exported = 1, last_exported_at = ?
      WHERE orgId = ? AND storeId = ? AND localId IN (
        SELECT DISTINCT categoryLocalId FROM product_variants
        WHERE orgId = ? AND storeId = ? AND localId IN ($placeholders)
      )
      ''',
      [now, scope.orgId, scope.storeId, scope.orgId, scope.storeId, ...variantLocalIds],
    );
    await db.rawUpdate(
      '''
      UPDATE master_categories SET exported = 1, last_exported_at = ?
      WHERE orgId = ? AND unique_id IN (
        SELECT DISTINCT master_unique_id FROM categories
        WHERE orgId = ? AND storeId = ? AND master_unique_id IS NOT NULL
          AND localId IN (
            SELECT DISTINCT categoryLocalId FROM product_variants
            WHERE orgId = ? AND storeId = ? AND localId IN ($placeholders)
          )
      )
      ''',
      [
        now,
        scope.orgId,
        scope.orgId,
        scope.storeId,
        scope.orgId,
        scope.storeId,
        ...variantLocalIds,
      ],
    );
  }

  /// Soft-delete a sellable package; marks pending export so Sync tombstones server.
  Future<void> softDeleteVariant(StoreScope scope, String variantLocalId) async {
    final id = variantLocalId.trim();
    if (id.isEmpty) return;
    await db.update(
      'product_variants',
      {'deleted': 1, 'exported': 0, 'last_exported_at': null},
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    await db.update(
      'products',
      {'deleted': 1, 'exported': 0},
      where: 'orgId = ? AND storeId = ? AND variantLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
  }

  Future<void> softDeleteCategory(StoreScope scope, String categoryLocalId) async {
    final id = categoryLocalId.trim();
    if (id.isEmpty) return;
    await db.update(
      'categories',
      {'deleted': 1, 'exported': 0, 'last_exported_at': null},
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    final variants = await db.query(
      'product_variants',
      columns: ['localId'],
      where: 'orgId = ? AND storeId = ? AND categoryLocalId = ? AND deleted = 0',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    for (final row in variants) {
      await softDeleteVariant(scope, '${row['localId']}');
    }
  }

  Future<void> softDeleteOffer(StoreScope scope, String offerLocalId) async {
    final id = offerLocalId.trim();
    if (id.isEmpty) return;
    await db.update(
      'offers',
      {
        'deleted': 1,
        'exported': 0,
        'active': 0,
        'updated_on': DateTime.now().toIso8601String(),
      },
      where: 'orgId = ? AND storeId = ? AND local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
  }

  Future<void> softDeleteAddonGroup(StoreScope scope, String groupLocalId) async {
    final id = groupLocalId.trim();
    if (id.isEmpty) return;
    await db.update(
      'catalog_addon_groups',
      {'deleted': 1, 'exported': 0, 'last_exported_at': null},
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    await db.update(
      'catalog_addon_items',
      {'deleted': 1, 'exported': 0},
      where: 'orgId = ? AND storeId = ? AND groupLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    // Mark linked variants pending so Sync exports the tombstone nested in rows.
    final links = await db.query(
      'catalog_variant_addon_links',
      columns: ['variantLocalId'],
      where: 'orgId = ? AND storeId = ? AND groupLocalId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
    for (final link in links) {
      final variantLocalId = '${link['variantLocalId'] ?? ''}'.trim();
      if (variantLocalId.isEmpty) continue;
      await db.update(
        'product_variants',
        {'exported': 0, 'last_exported_at': null},
        where: 'orgId = ? AND storeId = ? AND localId = ?',
        whereArgs: [scope.orgId, scope.storeId, variantLocalId],
      );
    }
  }

  Future<void> renameCategory(
    StoreScope scope,
    String categoryLocalId, {
    required String name,
  }) async {
    final id = categoryLocalId.trim();
    final trimmed = name.trim();
    if (id.isEmpty || trimmed.isEmpty) return;
    await db.update(
      'categories',
      {
        'name': trimmed,
        'path': trimmed,
        'exported': 0,
        'last_exported_at': null,
      },
      where: 'orgId = ? AND storeId = ? AND localId = ?',
      whereArgs: [scope.orgId, scope.storeId, id],
    );
  }

  Future<List<Map<String, dynamic>>> listMasterProducts(String orgId) {
    return db.query(
      'master_products',
      where: 'orgId = ?',
      whereArgs: [orgId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  /// Links a master product into a store category with a default package.
  Future<Map<String, dynamic>> linkMasterProductToStore({
    required StoreScope scope,
    required String masterLocalId,
    required String categoryLocalId,
  }) async {
    final masters = await db.query(
      'master_products',
      where: 'orgId = ? AND localId = ?',
      whereArgs: [scope.orgId, masterLocalId],
      limit: 1,
    );
    if (masters.isEmpty) {
      throw StateError('Master product not found');
    }
    final master = masters.first;
    final category = await getCategoryById(scope, categoryLocalId);
    if (category == null) {
      throw StateError('Category not found');
    }
    final masterUnique =
        '${master['unique_id'] ?? master['localId']}'.trim();
    final productName = '${master['name']}'.trim();

    final existingProducts = await db.query(
      'products',
      where:
          'orgId = ? AND storeId = ? AND master_unique_id = ? AND COALESCE(deleted, 0) = 0',
      whereArgs: [scope.orgId, scope.storeId, masterUnique],
      limit: 1,
    );
    if (existingProducts.isNotEmpty) {
      final existing = existingProducts.first;
      final variantLocalId = '${existing['variantLocalId'] ?? ''}'.trim();
      await db.update(
        'products',
        {
          'exported': 0,
          'name': productName,
          'description': '${master['description'] ?? ''}',
          'categoryLocalId': category['localId'],
        },
        where: 'localId = ?',
        whereArgs: [existing['localId']],
      );
      if (variantLocalId.isNotEmpty) {
        await db.update(
          'product_variants',
          {
            'exported': 0,
            'last_exported_at': null,
            'product_name': productName,
            'categoryLocalId': category['localId'],
            'product_variant_description': '${master['description'] ?? ''}',
          },
          where: 'orgId = ? AND storeId = ? AND localId = ?',
          whereArgs: [scope.orgId, scope.storeId, variantLocalId],
        );
      }
      return {
        'productLocalId': existing['localId'],
        'variantLocalId': variantLocalId,
        'masterProductLocalId': master['localId'],
        'categoryLocalId': category['localId'],
      };
    }

    final productLocalId = _newLocalId('prod');
    final variantLocalId = _newLocalId('var');
    await db.insert('products', {
      'localId': productLocalId,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': productLocalId,
      'productId': null,
      'variantLocalId': variantLocalId,
      'logo': '',
      'name': productName,
      'type': 0,
      'description': '${master['description'] ?? ''}',
      'is_preorder': 0,
      'is_allergens': 0,
      'categoryLocalId': category['localId'],
      'master_unique_id': masterUnique,
      'exported': 0,
      'deleted': 0,
    });
    await db.insert('product_variants', {
      'localId': variantLocalId,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': variantLocalId,
      'variantId': null,
      'categoryLocalId': category['localId'],
      'barcode': '',
      'product_variant_name': 'Regular',
      'product_name': productName,
      'preorder_product': 0,
      'product_variant_description': '${master['description'] ?? ''}',
      'product_variant_quantity': 1,
      'product_variant_logo': '',
      'sell_price': '1.00',
      'buy_price': '1.00',
      'mrp_price': '1.00',
      'sell_unit_code': null,
      'sell_unit_short': 'pcs',
      'sell_unit_label': 'pcs',
      'sell_unit_base_qty': 1.0,
      'tax_label': null,
      'master_unique_id': masterUnique,
      'exported': 0,
      'last_imported_at': null,
      'last_exported_at': null,
      'deleted': 0,
    });
    return {
      'productLocalId': productLocalId,
      'variantLocalId': variantLocalId,
      'masterProductLocalId': master['localId'],
      'categoryLocalId': category['localId'],
    };
  }
}
