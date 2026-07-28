import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io';

import 'store_models.dart';

class OffersRepository {
  final Database db;
  final Uuid _uuid = Uuid();

  OffersRepository(this.db);

  Future<void> importOffersFromJsonFile(String filePath, {required StoreScope scope}) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString) as Map<String, dynamic>;
    await importOffersFromJsonData(data, scope: scope);
  }

  Future<void> importOffersFromJsonData(
    Map<String, dynamic> data, {
    required StoreScope scope,
  }) async {
    final rawOffers = data['data'];
    if (rawOffers is! List) {
      return;
    }
    for (final rawOffer in rawOffers.whereType<Map>()) {
      final offer = rawOffer.cast<String, dynamic>();
      await saveOffer(
        scope,
        StoreSaveOfferRequest(
          localId: offer['local_id'] as String? ?? offer['localId'] as String?,
          uniqueId: offer['unique_id'] as String? ?? offer['uniqueId'] as String?,
          name: offer['name'] as String? ?? '',
          targetType: offer['target_type'] as String? ?? offer['targetType'] as String? ?? StoreOfferTargetType.product,
          offerType: offer['offer_type'] as String? ?? offer['offerType'] as String? ?? StoreOfferType.percentage,
          targetIds: ((offer['target_ids'] as List<dynamic>?)
                      ?? (offer['targetIds'] as List<dynamic>?)
                      ?? (offer['targets'] as List<dynamic>?)
                      ?? const <dynamic>[])
              .map((value) => '$value')
              .toList(growable: false),
          percentageValue: _parseDouble(offer['percentage_value'] ?? offer['percentageValue']),
          flatValue: _parseDouble(offer['flat_value'] ?? offer['flatValue']),
              minimumBillAmount: _parseDouble(offer['minimum_bill_amount'] ?? offer['minimumBillAmount']),
          buyQuantity: _parseInt(offer['buy_quantity'] ?? offer['buyQuantity']),
          getQuantity: _parseInt(offer['get_quantity'] ?? offer['getQuantity']),
          active: (offer['active'] is bool)
              ? offer['active'] as bool
              : ((offer['active'] as num?)?.toInt() ?? 1) == 1,
          createdOn: offer['created_on'] as String? ?? offer['createdOn'] as String?,
          updatedOn: offer['updated_on'] as String? ?? offer['updatedOn'] as String?,
        ),
      );
    }
  }

  Future<String> saveOffer(StoreScope scope, StoreSaveOfferRequest request) async {
    _validateRequest(request);
    final timestamp = DateTime.now().toIso8601String();
    final localId = request.localId?.isNotEmpty == true ? request.localId! : 'offer-${_uuid.v4()}';

    await db.transaction((txn) async {
      final normalizedUniqueId = request.uniqueId?.trim();
      final existing = normalizedUniqueId != null && normalizedUniqueId.isNotEmpty
          ? await txn.query(
              'offers',
              where: 'orgId = ? AND storeId = ? AND unique_id = ?',
              whereArgs: [scope.orgId, scope.storeId, normalizedUniqueId],
              limit: 1,
            )
          : await txn.query(
              'offers',
              where: 'orgId = ? AND storeId = ? AND local_id = ?',
              whereArgs: [scope.orgId, scope.storeId, localId],
              limit: 1,
            );
      final row = {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'unique_id': normalizedUniqueId != null && normalizedUniqueId.isNotEmpty
            ? normalizedUniqueId
            : (existing.isEmpty ? null : existing.first['unique_id']),
        'local_id': localId,
        'name': request.name,
        'target_type': StoreOfferTargetType.requireSupported(request.targetType),
        'offer_type': StoreOfferType.requireSupported(request.offerType),
        'percentage_value': request.percentageValue,
        'flat_value': request.flatValue,
        'minimum_bill_amount': request.minimumBillAmount,
        'buy_quantity': request.buyQuantity,
        'get_quantity': request.getQuantity,
        'active': request.active ? 1 : 0,
        'created_on': existing.isEmpty ? (request.createdOn ?? timestamp) : (existing.first['created_on'] as String? ?? request.createdOn ?? timestamp),
        'updated_on': request.updatedOn ?? timestamp,
      };
      if (existing.isEmpty) {
        await txn.insert('offers', row, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.update(
          'offers',
          row,
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }

      await txn.delete(
        'offer_targets',
        where: 'orgId = ? AND storeId = ? AND offer_local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
      );
      for (final targetId in request.targetIds.map((value) => value.trim()).where((value) => value.isNotEmpty)) {
        await txn.insert(
          'offer_targets',
          {
            'orgId': scope.orgId,
            'storeId': scope.storeId,
            'offer_local_id': localId,
            'target_value': targetId,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    return localId;
  }

  Future<List<StoreOfferRecord>> listOffers(
    StoreScope scope, {
    bool activeOnly = false,
  }) async {
    final rows = await db.query(
      'offers',
      where: activeOnly ? 'orgId = ? AND storeId = ? AND active = ?' : 'orgId = ? AND storeId = ?',
      whereArgs: activeOnly ? [scope.orgId, scope.storeId, 1] : [scope.orgId, scope.storeId],
      orderBy: 'updated_on DESC, id DESC',
    );
    final targets = await _loadTargetsByOffer(scope);
    return rows
        .map((row) => StoreOfferRecord.fromRow(
              row,
              targetIds: targets[row['local_id'] as String? ?? ''] ?? const [],
            ))
        .toList(growable: false);
  }

  Future<StoreOfferRecord?> getOfferByLocalId(StoreScope scope, String localId) async {
    final rows = await db.query(
      'offers',
      where: 'orgId = ? AND storeId = ? AND local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, localId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final targets = await _loadTargetsByOffer(scope, localId: localId);
    return StoreOfferRecord.fromRow(rows.first, targetIds: targets[localId] ?? const []);
  }

  Future<int> deleteOffer(StoreScope scope, String localId) async {
    return db.transaction((txn) async {
      await txn.delete(
        'offer_targets',
        where: 'orgId = ? AND storeId = ? AND offer_local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
      );
      return txn.delete(
        'offers',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
      );
    });
  }

  Future<int> setOfferActive(StoreScope scope, String localId, {required bool active}) {
    return db.update(
      'offers',
      {
        'active': active ? 1 : 0,
        'updated_on': DateTime.now().toIso8601String(),
      },
      where: 'orgId = ? AND storeId = ? AND local_id = ?',
      whereArgs: [scope.orgId, scope.storeId, localId],
    );
  }

  Future<Map<String, List<String>>> _loadTargetsByOffer(StoreScope scope, {String? localId}) async {
    final rows = await db.query(
      'offer_targets',
      where: localId == null
          ? 'orgId = ? AND storeId = ?'
          : 'orgId = ? AND storeId = ? AND offer_local_id = ?',
      whereArgs: localId == null ? [scope.orgId, scope.storeId] : [scope.orgId, scope.storeId, localId],
      orderBy: 'id ASC',
    );
    final byOffer = <String, List<String>>{};
    for (final row in rows) {
      final offerLocalId = row['offer_local_id'] as String? ?? '';
      byOffer.putIfAbsent(offerLocalId, () => <String>[]).add(row['target_value'] as String? ?? '');
    }
    return byOffer;
  }

  void _validateRequest(StoreSaveOfferRequest request) {
    if (request.name.trim().isEmpty) {
      throw ArgumentError.value(request.name, 'name', 'Offer name is required.');
    }

    final offerType = StoreOfferType.requireSupported(request.offerType);
    final targetType = StoreOfferTargetType.requireSupported(request.targetType);

    final hasTargets = request.targetIds.map((value) => value.trim()).where((value) => value.isNotEmpty).isNotEmpty;
    if (offerType == StoreOfferType.totalOffer) {
      final value = request.percentageValue ?? 0;
      final minimumBillAmount = request.minimumBillAmount ?? 0;
      if (targetType != StoreOfferTargetType.bill) {
        throw ArgumentError.value(request.targetType, 'targetType', 'Total offers must use the bill target type.');
      }
      if (value <= 0 || value > 100) {
        throw ArgumentError.value(request.percentageValue, 'percentageValue', 'Total offers require a value between 0 and 100.');
      }
      if (minimumBillAmount <= 0) {
        throw ArgumentError.value(request.minimumBillAmount, 'minimumBillAmount', 'Total offers require a positive minimum bill amount.');
      }
      return;
    }
    if (!hasTargets) {
      throw ArgumentError.value(request.targetIds, 'targetIds', 'At least one offer target is required.');
    }

    if (offerType == StoreOfferType.percentage) {
      final value = request.percentageValue ?? 0;
      if (value <= 0 || value > 100) {
        throw ArgumentError.value(request.percentageValue, 'percentageValue', 'Percentage offers require a value between 0 and 100.');
      }
    }
    if (offerType == StoreOfferType.flat) {
      final value = request.flatValue ?? 0;
      if (value <= 0) {
        throw ArgumentError.value(request.flatValue, 'flatValue', 'Flat offers require a positive discount value.');
      }
    }
    if (offerType == StoreOfferType.buyNGetM) {
      final buyQuantity = request.buyQuantity ?? 0;
      final getQuantity = request.getQuantity ?? 0;
      if (buyQuantity <= 0 || getQuantity <= 0) {
        throw ArgumentError('Buy N get M offers require positive buyQuantity and getQuantity values.');
      }
    }
  }

  double? _parseDouble(dynamic value) {
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

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}