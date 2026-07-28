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
    final categories = data['data'] as List<dynamic>;
    final importedAt = DateTime.now().toIso8601String();
    final uuid = Uuid();

    for (final cat in categories) {
      if (_isOutOfScope(cat, scope)) {
        continue;
      }
      // Generate or get localId for category
      final categoryRemoteId = cat['id'] as int?;
      final categoryUniqueId = _normalizedUniqueId(cat['unique_id'] ?? cat['uniqueId']);
      final existingCategory = await _findExistingRowByUniqueId('categories', scope: scope, uniqueId: categoryUniqueId);
      final categoryLocalId = (existingCategory?['localId'] as String?)
          ?? (cat['local_id'] as String?)
          ?? (cat['localId'] as String?)
          ?? 'cat_${categoryRemoteId ?? uuid.v4()}';
      await db.insert(
        'categories',
        {
          'orgId': scope.orgId,
          'storeId': scope.storeId,
          'localId': categoryLocalId,
          'unique_id': categoryUniqueId,
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Handle product_variants
      if (cat['product_variants'] != null) {
        for (final variant in cat['product_variants']) {
          if (_isOutOfScope(variant, scope) || _isOutOfScope(variant['product_data'], scope)) {
            continue;
          }
          final variantRemoteId = variant['id'] as int?;
          final variantUniqueId = _normalizedUniqueId(variant['unique_id'] ?? variant['uniqueId']);
          final existingVariant = await _findExistingRowByUniqueId('product_variants', scope: scope, uniqueId: variantUniqueId);
          final variantLocalId = (existingVariant?['localId'] as String?)
              ?? (variant['local_id'] as String?)
              ?? (variant['localId'] as String?)
              ?? 'var_${variantRemoteId ?? uuid.v4()}';
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
              'exported': markAsExported ? 1 : 0,
              'last_imported_at': importedAt,
              'last_exported_at': null,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
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
            final productRemoteId = variant['product_data']['id'] as int?;
            final productUniqueId = _normalizedUniqueId(
              variant['product_data']['unique_id'] ?? variant['product_data']['uniqueId'],
            );
            final existingProduct = await _findExistingRowByUniqueId('products', scope: scope, uniqueId: productUniqueId);
            final productLocalId = (existingProduct?['localId'] as String?)
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
                'productId': productRemoteId,
                'variantLocalId': variantLocalId,
                'logo': variant['product_data']['logo'],
                'name': variant['product_data']['name'],
                'type': variant['product_data']['type'],
                'description': variant['product_data']['description'],
                'is_preorder': variant['product_data']['is_preorder'],
                'is_allergens': variant['product_data']['is_allergens'],
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }
  }

  Future<Map<String, Object?>> _findExistingRowByUniqueId(
    String table, {
    required StoreScope scope,
    required String? uniqueId,
  }) async {
    if (uniqueId == null || uniqueId.isEmpty) {
      return const <String, Object?>{};
    }
    final rows = await db.query(
      table,
      where: 'orgId = ? AND storeId = ? AND unique_id = ?',
      whereArgs: [scope.orgId, scope.storeId, uniqueId],
      limit: 1,
    );
    return rows.isEmpty ? const <String, Object?>{} : rows.first;
  }

  String? _normalizedUniqueId(dynamic value) {
    final text = value as String?;
    if (text == null) {
      return null;
    }
    final trimmed = text.trim();
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
