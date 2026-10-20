import 'dart:convert';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'product_models.dart';
import 'store_models.dart';

class ProductDataImporter {
  final Database db;
  ProductDataImporter(this.db);

  Future<void> importFromJsonFile(String filePath, {required StoreScope scope}) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);
    await importFromJsonData(data as Map<String, dynamic>, scope: scope);
  }

  Future<void> importFromJsonData(
    Map<String, dynamic> data, {
    required StoreScope scope,
    bool markAsExported = true,
  }) async {
    final categories = data['data'] as List<dynamic>? ?? const [];
    final importedAt = DateTime.now().toIso8601String();
    final uuid = Uuid();

    await _importMasterCategories(
      data['master_categories'],
      orgId: scope.orgId,
    );
    await _importMasterProducts(
      data['master_products'],
      orgId: scope.orgId,
    );

    final seenVariantUniqueIds = <String>{};
    final seenCategoryUniqueIds = <String>{};

    for (final cat in categories) {
      if (_isOutOfScope(cat, scope)) {
        continue;
      }
      // Generate or get localId for category
      final categoryRemoteId = cat['id'] is int
          ? cat['id'] as int
          : int.tryParse('${cat['id'] ?? ''}');
      final categoryUniqueId = _normalizedUniqueId(cat['unique_id'] ?? cat['uniqueId'] ?? cat['id']);
      final masterUniqueId = _normalizedUniqueId(
        cat['master_unique_id'] ?? cat['masterUniqueId'] ?? cat['master_id'],
      );
      final existingCategory = await _findExistingCatalogRow(
        'categories',
        scope: scope,
        uniqueId: categoryUniqueId,
        localId: _normalizedUniqueId(cat['local_id'] ?? cat['localId']),
        remoteId: categoryRemoteId,
        remoteIdColumn: 'categoryId',
      );
      final categoryLocalId = (existingCategory['localId'] as String?)
          ?? (cat['local_id'] as String?)
          ?? (cat['localId'] as String?)
          ?? 'cat_${categoryRemoteId ?? uuid.v4()}';
      // A pending local rename/delete wins until Sync exports it.
      if (!_hasPendingLocalChange(existingCategory)) {
        await db.insert(
          'categories',
          {
            'orgId': scope.orgId,
            'storeId': scope.storeId,
            'localId': categoryLocalId,
            'unique_id': categoryUniqueId,
            'master_unique_id': masterUniqueId,
            'categoryId': categoryRemoteId,
            'name': cat['name'],
            'slug': cat['slug'],
            'logo': cat['logo'],
            'sorting_order': cat['sorting_order'],
            'description': cat['description'],
            'parent_id': cat['parent_id'],
            'short_code': cat['short_code'],
            'depth': cat['depth'],
            'path': cat['path'],
              'id': cat['id'],
            'deleted': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      if (categoryUniqueId != null && categoryUniqueId.isNotEmpty) {
        seenCategoryUniqueIds.add(categoryUniqueId);
      }
      // Handle product_variants
      if (cat['product_variants'] != null) {
        for (final variant in cat['product_variants']) {
          if (_isOutOfScope(variant, scope) || _isOutOfScope(variant['product_data'], scope)) {
            continue;
          }
          final variantRemoteId = variant['id'] is int
              ? variant['id'] as int
              : int.tryParse('${variant['id'] ?? ''}');
          final variantUniqueId = _normalizedUniqueId(
            variant['unique_id'] ?? variant['uniqueId'] ?? variant['id'],
          );
          final existingVariant = await _findExistingCatalogRow(
            'product_variants',
            scope: scope,
            uniqueId: variantUniqueId,
            localId: _normalizedUniqueId(variant['local_id'] ?? variant['localId']),
            remoteId: variantRemoteId,
            remoteIdColumn: 'variantId',
          );
          final variantLocalId = (existingVariant['localId'] as String?)
              ?? (variant['local_id'] as String?)
              ?? (variant['localId'] as String?)
              ?? 'var_${variantRemoteId ?? uuid.v4()}';
          // Keep pending local edits/deletes (incl. product row and add-ons):
          // import runs before export, so overwriting here would drop the
          // tombstone and the server would never receive it.
          if (_hasPendingLocalChange(existingVariant)) {
            if (variantUniqueId != null && variantUniqueId.isNotEmpty) {
              seenVariantUniqueIds.add(variantUniqueId);
            }
            continue;
          }
          final sellUnit = _extractDirectSellUnit(variant) ??
              _extractSellUnit(variant['proportions']);
          await db.insert(
            'product_variants',
            {
              'orgId': scope.orgId,
              'storeId': scope.storeId,
              'localId': variantLocalId,
              'unique_id': variantUniqueId,
              'variantId': variantRemoteId,
              'categoryLocalId': categoryLocalId,
              'barcode': variant['barcode'] ?? variant['product_data']?['barcode'],
              'product_variant_name': variant['product_variant_name'],
              'product_name': variant['product_name'],
              'preorder_product': variant['preorder_product'] == true ? 1 : 0,
              'product_variant_description': variant['product_variant_description'],
              'product_variant_quantity': variant['product_variant_quantity'],
              'product_variant_logo': variant['product_variant_logo'],
              'local_image_path': existingVariant['local_image_path'],
              'image_cache_source': existingVariant['image_cache_source'],
              'image_etag': existingVariant['image_etag'],
              'image_last_modified': existingVariant['image_last_modified'],
              'sell_price': variant['sell_price'],
              'buy_price': variant['buy_price'],
              'mrp_price': variant['mrp_price'],
              'sell_unit_code': sellUnit?['code'],
              'sell_unit_short': sellUnit?['short'],
              'sell_unit_label': sellUnit?['label'],
              'sell_unit_base_qty': sellUnit?['base_qty'],
              'review_max_data': variant['review_max_data'],
              'review_avg_max_data': variant['review_avg_max_data'],
              'review_value_data': variant['review_value_data'],
              'review_max_value_data': variant['review_max_value_data'],
              'review_count': variant['review_count'],
              'active': _activeFlag(variant['active']),
              'exported': markAsExported ? 1 : 0,
              'last_imported_at': importedAt,
              'last_exported_at': null,
              'deleted': 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          if (variantUniqueId != null && variantUniqueId.isNotEmpty) {
            seenVariantUniqueIds.add(variantUniqueId);
          }
          await db.delete(
            'product_variant_addon_groups',
            where: 'orgId = ? AND storeId = ? AND variantLocalId = ?',
            whereArgs: [scope.orgId, scope.storeId, variantLocalId],
          );
          await _importAddonGroups(
            scope: scope,
            variantLocalId: variantLocalId,
            variantRemoteId: variantRemoteId,
            rawGroups: variant['product_addon_group_data'],
            source: 'product',
          );
          await _importAddonGroups(
            scope: scope,
            variantLocalId: variantLocalId,
            variantRemoteId: variantRemoteId,
            rawGroups: variant['product_variant_addon_group_data'],
            source: 'variant',
          );
          // Handle product_data
          if (variant['product_data'] != null) {
            final productRemoteId = variant['product_data']['id'] is int
                ? variant['product_data']['id'] as int
                : int.tryParse('${variant['product_data']['id'] ?? ''}');
            final productUniqueId = _normalizedUniqueId(
              variant['product_data']['unique_id'] ??
                  variant['product_data']['uniqueId'] ??
                  variant['product_data']['id'],
            );
            final productMasterUnique = _normalizedUniqueId(
              variant['product_data']['master_unique_id'] ??
                  variant['product_data']['masterUniqueId'],
            );
            final existingProduct = await _findExistingCatalogRow(
              'products',
              scope: scope,
              uniqueId: productUniqueId,
              localId: _normalizedUniqueId(
                variant['product_data']['local_id'] ??
                    variant['product_data']['localId'],
              ),
              remoteId: productRemoteId,
              remoteIdColumn: 'productId',
              masterUniqueId: productMasterUnique,
            );
            final productLocalId = (existingProduct['localId'] as String?)
                ?? (variant['product_data']['local_id'] as String?)
                ?? (variant['product_data']['localId'] as String?)
                ?? 'prod_${productRemoteId ?? uuid.v4()}';
            await db.insert(
              'products',
              {
                'orgId': scope.orgId,
                'storeId': scope.storeId,
                'localId': productLocalId,
                'unique_id': productUniqueId,
                'master_unique_id': productMasterUnique,
                'productId': productRemoteId,
                'variantLocalId': variantLocalId,
                'logo': variant['product_data']['logo'],
                'name': variant['product_data']['name'],
                'type': variant['product_data']['type'],
                'description': variant['product_data']['description'],
                'is_preorder': variant['product_data']['is_preorder'],
                'is_allergens': variant['product_data']['is_allergens'],
                'deleted': 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }

    await _softDeleteMissingExportedRows(
      table: 'product_variants',
      scope: scope,
      seenUniqueIds: seenVariantUniqueIds,
    );
    await _softDeleteMissingExportedRows(
      table: 'categories',
      scope: scope,
      seenUniqueIds: seenCategoryUniqueIds,
    );
  }

  Future<void> _softDeleteMissingExportedRows({
    required String table,
    required StoreScope scope,
    required Set<String> seenUniqueIds,
  }) async {
    // Only drop previously-synced rows missing from server payload.
    // Leave pending local edits (exported=0) alone.
    final rows = await db.query(
      table,
      columns: ['localId', 'unique_id'],
      where: 'orgId = ? AND storeId = ? AND deleted = 0 AND exported = 1',
      whereArgs: [scope.orgId, scope.storeId],
    );
    for (final row in rows) {
      final uniqueId = _normalizedUniqueId(row['unique_id']);
      if (uniqueId == null || uniqueId.isEmpty) continue;
      if (seenUniqueIds.contains(uniqueId)) continue;
      await db.update(
        table,
        {'deleted': 1},
        where: 'orgId = ? AND storeId = ? AND localId = ?',
        whereArgs: [scope.orgId, scope.storeId, row['localId']],
      );
    }
  }

  Future<void> _importMasterProducts(
    dynamic rawMasters, {
    required String orgId,
  }) async {
    if (rawMasters is! List) {
      return;
    }
    for (final raw in rawMasters.whereType<Map>()) {
      final row = raw.cast<String, dynamic>();
      final uniqueId = _normalizedUniqueId(
            row['unique_id'] ?? row['uniqueId'] ?? row['id'],
          ) ??
          '';
      if (uniqueId.isEmpty) continue;
      final requestedLocal =
          _normalizedUniqueId(row['local_id'] ?? row['localId']);
      final name = '${row['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final localId = await _resolveMasterLocalId(
        table: 'master_products',
        orgId: orgId,
        uniqueId: uniqueId,
        requestedLocalId: requestedLocal,
        prefix: 'mprod',
      );
      await db.insert(
        'master_products',
        {
          'localId': localId,
          'orgId': orgId,
          'unique_id': uniqueId,
          'master_category_unique_id': _normalizedUniqueId(
            row['master_category_unique_id'] ?? row['masterCategoryUniqueId'],
          ),
          'name': name,
          'description': row['description'],
          'exported': 1,
          'last_exported_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _importMasterCategories(
    dynamic rawMasters, {
    required String orgId,
  }) async {
    if (rawMasters is! List) {
      return;
    }
    for (final raw in rawMasters.whereType<Map>()) {
      final row = raw.cast<String, dynamic>();
      final uniqueId = _normalizedUniqueId(
            row['unique_id'] ?? row['uniqueId'] ?? row['id'],
          ) ??
          '';
      if (uniqueId.isEmpty) continue;
      final requestedLocal =
          _normalizedUniqueId(row['local_id'] ?? row['localId']);
      final name = '${row['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final localId = await _resolveMasterLocalId(
        table: 'master_categories',
        orgId: orgId,
        uniqueId: uniqueId,
        requestedLocalId: requestedLocal,
        prefix: 'mcat',
      );
      await db.insert(
        'master_categories',
        {
          'localId': localId,
          'orgId': orgId,
          'unique_id': uniqueId,
          'name': name,
          'short_code': row['short_code'],
          'service_variant_type': row['service_variant_type'],
          'exported': 1,
          'last_exported_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<String> _resolveMasterLocalId({
    required String table,
    required String orgId,
    required String uniqueId,
    required String? requestedLocalId,
    required String prefix,
  }) async {
    final byUnique = await db.query(
      table,
      columns: ['localId'],
      where: 'orgId = ? AND unique_id = ?',
      whereArgs: [orgId, uniqueId],
      limit: 1,
    );
    if (byUnique.isNotEmpty) {
      return '${byUnique.first['localId']}';
    }
    final requested = (requestedLocalId ?? '').trim();
    if (requested.isNotEmpty) {
      final byLocal = await db.query(
        table,
        columns: ['localId'],
        where: 'orgId = ? AND localId = ?',
        whereArgs: [orgId, requested],
        limit: 1,
      );
      if (byLocal.isNotEmpty) {
        return '${byLocal.first['localId']}';
      }
    }
    return requested.isNotEmpty ? requested : '${prefix}_$uniqueId';
  }

  Future<Map<String, Object?>> _findExistingCatalogRow(
    String table, {
    required StoreScope scope,
    required String? uniqueId,
    String? localId,
    int? remoteId,
    String? remoteIdColumn,
    String? masterUniqueId,
  }) async {
    if (uniqueId != null && uniqueId.isNotEmpty) {
      final byUnique = await db.query(
        table,
        where: 'orgId = ? AND storeId = ? AND unique_id = ?',
        whereArgs: [scope.orgId, scope.storeId, uniqueId],
        limit: 1,
      );
      if (byUnique.isNotEmpty) return byUnique.first;
    }
    final lid = (localId ?? '').trim();
    if (lid.isNotEmpty) {
      final byLocal = await db.query(
        table,
        where: 'orgId = ? AND storeId = ? AND localId = ?',
        whereArgs: [scope.orgId, scope.storeId, lid],
        limit: 1,
      );
      if (byLocal.isNotEmpty) return byLocal.first;
    }
    if (remoteId != null &&
        remoteIdColumn != null &&
        remoteIdColumn.isNotEmpty) {
      final byRemote = await db.query(
        table,
        where: 'orgId = ? AND storeId = ? AND $remoteIdColumn = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (byRemote.isNotEmpty) return byRemote.first;
    }
    final master = (masterUniqueId ?? '').trim();
    if (master.isNotEmpty) {
      final byMaster = await db.query(
        table,
        where:
            'orgId = ? AND storeId = ? AND master_unique_id = ? AND COALESCE(deleted, 0) = 0',
        whereArgs: [scope.orgId, scope.storeId, master],
        limit: 1,
      );
      if (byMaster.isNotEmpty) return byMaster.first;
    }
    return const <String, Object?>{};
  }

  /// Server `active` (bool/int/string); missing means active for older feeds.
  int _activeFlag(dynamic raw) {
    if (raw == null) return 1;
    if (raw is bool) return raw ? 1 : 0;
    if (raw is num) return raw == 0 ? 0 : 1;
    final text = '$raw'.trim().toLowerCase();
    return const {'0', 'false', 'no'}.contains(text) ? 0 : 1;
  }

  bool _hasPendingLocalChange(Map<String, Object?> existing) {
    if (existing.isEmpty) return false;
    return ((existing['exported'] as num?)?.toInt() ?? 1) == 0;
  }

  String? _normalizedUniqueId(dynamic value) {
    if (value == null) {
      return null;
    }
    final trimmed = '$value'.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isOutOfScope(dynamic rawRow, StoreScope scope) {
    if (rawRow is! Map) {
      return false;
    }
    final row = rawRow.cast<String, dynamic>();
    final rowOrgId = row['orgId'] as String?;
    final rowStoreId = row['storeId'] as String?;
    if (rowOrgId != null && rowOrgId.isNotEmpty && rowOrgId != scope.orgId) {
      return true;
    }
    if (rowStoreId != null && rowStoreId.isNotEmpty && rowStoreId != scope.storeId) {
      return true;
    }
    return false;
  }

  Future<void> _importAddonGroups({
    required StoreScope scope,
    required String variantLocalId,
    required int? variantRemoteId,
    required dynamic rawGroups,
    required String source,
  }) async {
    if (rawGroups is! List) {
      return;
    }
    for (final rawGroup in rawGroups.whereType<Map>()) {
      final group = rawGroup.cast<String, dynamic>();
      await db.insert(
        'product_variant_addon_groups',
        {
          'orgId': scope.orgId,
          'storeId': scope.storeId,
          'variantLocalId': variantLocalId,
          'variantId': variantRemoteId,
          'source': source,
          'addon_group_id': '${group['id'] ?? ''}',
          'addon_group_name': group['name'] ?? '',
          'min_selections': (group['min'] as num?)?.toInt() ?? 0,
          'max_selections': (group['max'] as num?)?.toInt(),
          'data': json.encode(group),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static const _measurableUnits = <int, String>{
    1: 'kg',
    2: 'g',
    3: 'L',
    4: 'mL',
    5: 'cm',
    6: 'in',
    7: 'm',
  };

  /// Dedicated `sell_unit` / `sell_unit_qty` fields on the variant payload.
  /// Preferred over the legacy proportions rows.
  Map<String, dynamic>? _extractDirectSellUnit(dynamic variant) {
    if (variant is! Map) return null;
    final row = variant.cast<String, dynamic>();
    final unitCode = int.tryParse('${row['sell_unit'] ?? ''}');
    if (unitCode == null || !_measurableUnits.containsKey(unitCode)) return null;
    final baseQty = double.tryParse('${row['sell_unit_qty'] ?? '1'}') ?? 1.0;
    final short = _measurableUnits[unitCode]!;
    final label = (row['sell_unit_name'] ?? '').toString().trim();
    return {
      'code': unitCode,
      'short': short,
      'label': label.isEmpty ? short : label,
      'base_qty': baseQty <= 0 ? 1.0 : baseQty,
    };
  }

  Map<String, dynamic>? _extractSellUnit(dynamic raw) {
    if (raw is! List) return null;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final row = entry.cast<String, dynamic>();
      final active = row['active'];
      if (active == 0 || active == false || active == '0') continue;
      final data = row['proportion_data'] is Map
          ? (row['proportion_data'] as Map).cast<String, dynamic>()
          : row;
      final unitCode = int.tryParse('${data['unit'] ?? row['unit'] ?? ''}');
      if (unitCode == null || !_measurableUnits.containsKey(unitCode)) continue;
      final baseQty = double.tryParse(
            '${data['quantity'] ?? row['quantity'] ?? data['value'] ?? row['value'] ?? '1'}',
          ) ??
          1.0;
      if (baseQty <= 0) continue;
      final short = _measurableUnits[unitCode]!;
      final label = (data['label'] ?? row['label'] ?? '').toString().trim();
      return {
        'code': unitCode,
        'short': short,
        'label': label.isEmpty ? short : label,
        'base_qty': baseQty,
      };
    }
    return null;
  }
}
