import 'dart:convert';
import 'dart:io';
import 'sqflite_ffi_io.dart';
import 'package:uuid/uuid.dart';
import 'backend_setup.dart';
import 'store_models.dart';

class OrdersRepository {
  final Database db;
  final Uuid _uuid = Uuid();
  static const Set<String> _supportedPaymentModes = {
    'cash',
    'card',
    'online',
    'credit',
  };

  OrdersRepository(this.db);

  static Future<OrdersRepository> createInMemory() async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: BackendSetup.schemaVersion,
        onCreate: (db, version) async {
          await BackendSetup.createTablesForTest(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await BackendSetup.upgradeTablesForTest(db, oldVersion, newVersion);
        },
      ),
    );
    return OrdersRepository(db);
  }

  Future<void> importOrdersFromJsonFile(
    String filePath, {
    required StoreScope scope,
  }) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final data = json.decode(jsonString);
    await importOrdersFromJsonData(data as Map<String, dynamic>, scope: scope);
  }

  Future<StoreOrderImportOutcome> importOrdersFromJsonData(
    Map<String, dynamic> data, {
    required StoreScope scope,
    bool markAsExported = true,
  }) async {
    final orders = data['data'] as List<dynamic>? ?? const [];
    final importedAt = DateTime.now().toUtc().toIso8601String();
    var appliedCount = 0;
    var skippedCount = 0;
    String? maxAppliedUpdatedOn;
    for (final order in orders) {
      try {
        if (order is! Map) {
          skippedCount += 1;
          continue;
        }
        final orderMap = Map<String, dynamic>.from(order);
        final rowOrgId = orderMap['orgId'] as String? ?? scope.orgId;
        final rowStoreId = orderMap['storeId'] as String? ?? scope.storeId;
        if (rowOrgId != scope.orgId || rowStoreId != scope.storeId) {
          skippedCount += 1;
          continue;
        }
        final statusName =
            '${orderMap['status']?['status_name'] ?? orderMap['status_name'] ?? ''}'
                .trim();
        // Never ingest Draft / Initiated from cloud — those stay device-local.
        if (StoreOrderStatus.isSyncExcluded(statusName)) {
          skippedCount += 1;
          continue;
        }
        final orderId =
            jsonAsInt(orderMap['order_id']) ?? jsonAsInt(orderMap['id']) ?? 0;
        final remoteId =
            jsonAsInt(orderMap['remote_id']) ?? jsonAsInt(orderMap['id']);
        final uniqueId =
            orderMap['unique_id'] as String? ?? orderMap['uniqueId'] as String?;
        final localId = orderMap['local_id'] as String?;
        final existing = await _findExistingOrder(
          scope,
          uniqueId: uniqueId,
          localId: localId,
          remoteId: remoteId,
          orderId: orderId == 0 ? null : orderId,
        );
        final remoteUpdatedOn = _parseTimestamp(
          orderMap['updated_on'] ?? orderMap['updatedOn'],
        );
        if (existing != null &&
            !_shouldApplyRemoteOrder(
              existing: existing,
              remoteUpdatedOn: remoteUpdatedOn,
            )) {
          skippedCount += 1;
          continue;
        }
        final localPending =
            existing != null &&
            ((existing['exported'] as num?)?.toInt() ?? 1) == 0;
        // Pending local rows: apply cloud-newer header only — never wipe
        // payments/items that may still be waiting to export.
        final replaceChildren = !localPending;
        final exportedFlag = localPending ? 0 : (markAsExported ? 1 : 0);
        final resolvedUpdatedOn =
            remoteUpdatedOn?.toUtc().toIso8601String() ??
            _parseTimestamp(
              orderMap['created_on'] ?? orderMap['createdOn'],
            )?.toUtc().toIso8601String() ??
            importedAt;
        final incomingPricingMode =
            orderMap['pricing_mode'] ?? orderMap['pricingMode'];
        final resolvedPricingMode =
            '${incomingPricingMode ?? ''}'.trim().isEmpty
            ? StoreOrderPricingMode.normalize(existing?['pricing_mode'])
            : StoreOrderPricingMode.normalize(incomingPricingMode);
        await db.transaction((txn) async {
          await _upsertOrder(scope, {
            'orgId': scope.orgId,
            'storeId': scope.storeId,
            'unique_id': uniqueId,
            'local_id': localId,
            'remote_id': remoteId,
            'order_id': orderId,
            'restaurant_name': orderMap['restaurant_name'],
            'name': orderMap['name'],
            'mobile': orderMap['mobile'],
            'customer_unique_id':
                orderMap['customer_unique_id'] ??
                orderMap['customerUniqueId'] ??
                orderMap['customer_id'] ??
                orderMap['customerId'],
            'status_name':
                orderMap['status']?['status_name'] ?? orderMap['status_name'],
            'total_value':
                jsonAsDouble(orderMap['total_value']) ??
                jsonAsDouble(orderMap['totalValue']) ??
                jsonAsDouble(orderMap['total']) ??
                0,
            'offer_applied_value':
                jsonAsDouble(orderMap['offer_applied_value']) ??
                jsonAsDouble(orderMap['offerAppliedValue']) ??
                0,
            'final_value':
                jsonAsDouble(orderMap['final_value']) ??
                jsonAsDouble(orderMap['finalValue']) ??
                jsonAsDouble(orderMap['total']) ??
                0,
            'total':
                jsonAsDouble(orderMap['final_value']) ??
                jsonAsDouble(orderMap['finalValue']) ??
                jsonAsDouble(orderMap['total']) ??
                0,
            'service_instance':
                jsonAsInt(orderMap['service_instance']) ??
                jsonAsInt(orderMap['serviceInstance']) ??
                jsonAsInt(existing?['service_instance']) ??
                1,
            'created_by': _preferCreatedBy(
              orderMap['created_by'] ?? orderMap['staff_name'],
              staffReg: orderMap['staff_reg'],
            ),
            'created_on':
                orderMap['created_on'] ?? DateTime.now().toIso8601String(),
            'updated_on': resolvedUpdatedOn,
            'payment_status': orderMap['payment_status'] ?? 'Unpaid',
            'order_type': StoreOrderType.requireSupported(
              orderMap['order_type'] ?? orderMap['type_str'],
              typeCode: jsonAsInt(orderMap['type']),
            ),
            'pricing_mode': resolvedPricingMode,
            'exported': exportedFlag,
            'last_imported_at': importedAt,
            'last_exported_at': null,
          }, executor: txn);
          if (replaceChildren) {
            await replaceOrderPayments(
              scope,
              orderId,
              _extractPaymentsForOrder(orderMap, scope, importedAt),
              executor: txn,
            );
            await replaceOrderItems(
              scope,
              orderId,
              _extractItemsForOrder(
                {...orderMap, 'pricing_mode': resolvedPricingMode},
                scope,
                importedAt,
              ),
              executor: txn,
            );
          }
        });
        appliedCount += 1;
        if (maxAppliedUpdatedOn == null ||
            resolvedUpdatedOn.compareTo(maxAppliedUpdatedOn) > 0) {
          maxAppliedUpdatedOn = resolvedUpdatedOn;
        }
      } catch (e) {
        skippedCount += 1;
        print('Insert error for order: $order\nError: $e');
      }
    }
    return StoreOrderImportOutcome(
      appliedCount: appliedCount,
      skippedCount: skippedCount,
      maxAppliedUpdatedOn: maxAppliedUpdatedOn,
    );
  }

  /// For test compatibility: insert a single order (like addOrder, but with fallback fields)
  Future<int> insertOrder(StoreScope scope, Map<String, dynamic> order) async {
    // Fill required fields with defaults if missing
    final data = {
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': order['unique_id'] ?? order['uniqueId'],
      'local_id': order['local_id'] ?? _newLocalId('order'),
      'remote_id': order['remote_id'],
      'order_id': order['order_id'],
      'restaurant_name': order['restaurant_name'],
      'name': order['name'],
      'mobile': order['mobile'],
      'customer_unique_id':
          order['customer_unique_id'] ??
          order['customerUniqueId'] ??
          order['customer_id'] ??
          order['customerId'],
      'status_name':
          order['status']?['status_name'] ?? order['status_name'] ?? 'Pending',
      'total_value':
          order['total_value'] ?? order['totalValue'] ?? order['total'] ?? 0,
      'offer_applied_value':
          order['offer_applied_value'] ?? order['offerAppliedValue'] ?? 0,
      'final_value':
          order['final_value'] ?? order['finalValue'] ?? order['total'] ?? 0,
      'total':
          order['final_value'] ?? order['finalValue'] ?? order['total'] ?? 0,
      'service_instance': order['service_instance'] ?? 1,
      'created_by': _preferCreatedBy(
        order['created_by'] ?? order['staff_name'],
        staffReg: order['staff_reg'],
      ),
      'created_on': order['created_on'] ?? DateTime.now().toIso8601String(),
      'updated_on':
          order['updated_on'] ??
          order['created_on'] ??
          DateTime.now().toIso8601String(),
      'payment_status': order['payment_status'] ?? 'Unpaid',
      'order_type': StoreOrderType.requireSupported(
        order['order_type'] ?? order['type_str'],
        typeCode: (order['type'] as num?)?.toInt(),
      ),
      'pricing_mode': StoreOrderPricingMode.normalize(order['pricing_mode']),
      'exported': order['exported'] ?? 0,
      'last_imported_at': order['last_imported_at'],
      'last_exported_at': order['last_exported_at'],
    };
    return await db.insert('orders', data);
  }

  /// For test compatibility: get all orders (like listOrders, but returns all fields)
  Future<List<Map<String, dynamic>>> getAllOrders(StoreScope scope) async {
    return await db.query(
      'orders',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
    );
  }

  Future<List<Map<String, dynamic>>> listOrders(
    StoreScope scope, {
    String? pricingMode,
    int? orderId,
  }) async {
    final args = <Object?>[scope.orgId, scope.storeId];
    final orderClause = orderId == null ? '' : 'AND o.order_id = ? ';
    if (orderId != null) args.add(orderId);
    var pricingClause = '';
    final normalizedPricing = (pricingMode ?? '').trim();
    if (normalizedPricing.isNotEmpty) {
      pricingClause = 'AND o.pricing_mode = ? ';
      args.add(StoreOrderPricingMode.normalize(normalizedPricing));
    }
    return await db.rawQuery(
      'SELECT o.orgId, o.storeId, o.unique_id, o.local_id, o.remote_id, o.order_id, '
      'o.restaurant_name, o.name, o.mobile, o.customer_unique_id, o.status_name, '
      'o.order_type, o.payment_status, o.pricing_mode, o.total, o.total_value, '
      'o.offer_applied_value, o.final_value, o.created_by, o.created_on, o.exported, '
      'o.last_imported_at, o.last_exported_at, o.serve_number, '
      'COALESCE('
      '  (SELECT c.email FROM customers c '
      '   WHERE c.orgId = o.orgId AND c.storeId = o.storeId '
      '     AND c.customerId = o.customer_unique_id LIMIT 1),'
      '  (SELECT c2.email FROM customers c2 '
      '   WHERE c2.orgId = o.orgId AND c2.storeId = o.storeId '
      '     AND c2.phone = o.mobile AND o.mobile IS NOT NULL AND o.mobile != \'\' '
      '   LIMIT 1)'
      ') AS customer_email, '
      '(SELECT COUNT(*) FROM order_items i WHERE i.orgId = o.orgId AND i.storeId = o.storeId AND i.order_id = o.order_id) AS item_count, '
      'COALESCE('
      '  (SELECT SUM(p.amount - COALESCE((SELECT SUM(r.amount) FROM order_refunds r '
      '      WHERE r.payment_id = p.id AND r.orgId = p.orgId AND r.storeId = p.storeId), 0)) '
      '   FROM order_payments p '
      '   WHERE p.orgId = o.orgId AND p.storeId = o.storeId AND p.order_id = o.order_id '
      "     AND LOWER(TRIM(p.payment_mode)) NOT IN ('credit', 'pay_later', 'pay later')), "
      '  0'
      ') + $_creditRepaidSql AS paid_total, '
      '$_creditRepaidSql AS credit_repaid_amount, '
      'COALESCE((SELECT SUM(p.amount) FROM order_payments p '
      '   WHERE p.orgId = o.orgId AND p.storeId = o.storeId AND p.order_id = o.order_id '
      "     AND LOWER(TRIM(p.payment_mode)) IN ('credit', 'pay_later', 'pay later')), 0) AS credit_total, "
      '(SELECT i.table_id FROM order_items i WHERE i.orgId = o.orgId AND i.storeId = o.storeId '
      '  AND i.order_id = o.order_id AND COALESCE(i.table_id, \'\') != \'\' ORDER BY i.id LIMIT 1) AS table_id, '
      '(SELECT i.table_name FROM order_items i WHERE i.orgId = o.orgId AND i.storeId = o.storeId '
      '  AND i.order_id = o.order_id AND COALESCE(i.table_id, \'\') != \'\' ORDER BY i.id LIMIT 1) AS table_name, '
      '(SELECT i.floor_name FROM order_items i WHERE i.orgId = o.orgId AND i.storeId = o.storeId '
      '  AND i.order_id = o.order_id AND COALESCE(i.table_id, \'\') != \'\' ORDER BY i.id LIMIT 1) AS floor_name '
      'FROM orders o WHERE o.orgId = ? AND o.storeId = ? '
      '$orderClause'
      '$pricingClause'
      'ORDER BY o.created_on DESC, o.id DESC',
      args,
    );
  }

  static const _creditRepaidSql = '''
    COALESCE((SELECT SUM(a.allocated_amount)
      FROM credit_repayment_allocations a
      INNER JOIN credit_repayments r ON r.id = a.repayment_id
      INNER JOIN credits c ON c.id = a.credit_id
      WHERE c.orgId = o.orgId AND c.storeId = o.storeId AND c.order_id = o.order_id
        AND r.orgId = o.orgId AND r.storeId = o.storeId AND r.deleted_on IS NULL), 0)
  ''';

  Future<int> addOrder(StoreScope scope, Map<String, dynamic> order) async {
    return _upsertOrder(scope, {
      ...order,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
    });
  }

  Future<int> updateOrderStatus(
    StoreScope scope,
    int orderId,
    String status,
  ) async {
    final normalized = status.trim();
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await getOrderById(scope, orderId);
    final previousStatus = '${existing?['status_name'] ?? ''}'.trim();
    final values = <String, Object?>{
      'status_name': normalized,
      'updated_on': now,
    };
    // Draft / Initiated stay local-only; any other status change must re-export.
    if (StoreOrderStatus.isSyncExcluded(normalized)) {
      values['exported'] = 1;
      values['last_exported_at'] = null;
    } else {
      values['exported'] = 0;
      values['last_exported_at'] = null;
      final existingServe = (existing?['serve_number'] as num?)?.toInt();
      if (existingServe == null &&
          StoreOrderStatus.isSyncExcluded(previousStatus)) {
        values['serve_number'] = await allocateServeNumber(scope);
      }
    }
    return await db.update(
      'orders',
      values,
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
  }

  Future<bool> alignOrderPricingMode(
    StoreScope scope,
    int orderId,
    String pricingMode,
  ) async {
    final normalized = StoreOrderPricingMode.requireSupported(pricingMode);
    return db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        columns: ['pricing_mode'],
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      if (StoreOrderPricingMode.normalize(rows.first['pricing_mode']) ==
          normalized) {
        return true;
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'orders',
        {
          'pricing_mode': normalized,
          'updated_on': now,
          'exported': 0,
          'last_exported_at': null,
        },
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.update(
        'order_items',
        {'pricing_mode': normalized},
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.update(
        'order_item_addons',
        {'pricing_mode': normalized},
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      return true;
    });
  }

  /// Allocates the next rotating kitchen/serve number in range 1–configured max.
  Future<int> allocateServeNumber(StoreScope scope) async {
    const counterName = 'serve_number';
    const maximumName = 'serve_number_max';
    const minServe = 1;
    return db.transaction((txn) async {
      final maximumRows = await txn.query(
        'store_counters',
        columns: ['value'],
        where: 'orgId = ? AND storeId = ? AND name = ?',
        whereArgs: [scope.orgId, scope.storeId, maximumName],
        limit: 1,
      );
      final maxServe =
          ((maximumRows.isEmpty ? null : maximumRows.first['value'] as num?)
                      ?.toInt() ??
                  100)
              .clamp(minServe, 9999);
      final rows = await txn.query(
        'store_counters',
        columns: ['value'],
        where: 'orgId = ? AND storeId = ? AND name = ?',
        whereArgs: [scope.orgId, scope.storeId, counterName],
        limit: 1,
      );
      final int next;
      if (rows.isEmpty) {
        next = minServe;
        await txn.insert('store_counters', {
          'orgId': scope.orgId,
          'storeId': scope.storeId,
          'name': counterName,
          'value': next,
        });
      } else {
        final last = (rows.first['value'] as num?)?.toInt() ?? (minServe - 1);
        next = last >= maxServe ? minServe : last + 1;
        await txn.update(
          'store_counters',
          {'value': next},
          where: 'orgId = ? AND storeId = ? AND name = ?',
          whereArgs: [scope.orgId, scope.storeId, counterName],
        );
      }
      return next;
    });
  }

  Future<int> getServeNumberMaximum(StoreScope scope) async {
    final rows = await db.query(
      'store_counters',
      columns: ['value'],
      where: 'orgId = ? AND storeId = ? AND name = ?',
      whereArgs: [scope.orgId, scope.storeId, 'serve_number_max'],
      limit: 1,
    );
    return ((rows.isEmpty ? null : rows.first['value'] as num?)?.toInt() ?? 100)
        .clamp(1, 9999);
  }

  Future<void> setServeNumberMaximum(StoreScope scope, int maximum) async {
    final value = maximum.clamp(1, 9999);
    final updated = await db.update(
      'store_counters',
      {'value': value},
      where: 'orgId = ? AND storeId = ? AND name = ?',
      whereArgs: [scope.orgId, scope.storeId, 'serve_number_max'],
    );
    if (updated == 0) {
      await db.insert('store_counters', {
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'name': 'serve_number_max',
        'value': value,
      });
    }
  }

  Future<int> updatePaymentStatus(
    StoreScope scope,
    int orderId,
    String paymentStatus,
  ) async {
    final order = await getOrderById(scope, orderId);
    final status = '${order?['status_name'] ?? ''}'.trim();
    final values = <String, Object?>{
      'payment_status': paymentStatus,
      'updated_on': DateTime.now().toUtc().toIso8601String(),
    };
    if (StoreOrderStatus.isSyncExcluded(status)) {
      values['exported'] = 1;
      values['last_exported_at'] = null;
    } else {
      values['exported'] = 0;
      values['last_exported_at'] = null;
    }
    return await db.update(
      'orders',
      values,
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
  }

  Future<Map<String, dynamic>?> getOrderById(
    StoreScope scope,
    int orderId,
  ) async {
    final result = await db.query(
      'orders',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getOrderPayments(
    StoreScope scope,
    int orderId,
  ) {
    return db.query(
      'order_payments',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
      orderBy: 'created_on ASC, id ASC',
    );
  }

  Future<void> replaceOrderPayments(
    StoreScope scope,
    int orderId,
    List<Map<String, dynamic>> payments, {
    DatabaseExecutor? executor,
  }) async {
    final dbx = executor ?? db;
    await dbx.delete(
      'order_payments',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
    for (final payment in payments) {
      final row = _sanitizeOrderPaymentRow(payment);
      await dbx.insert('order_payments', {
        ...row,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'local_id': row['local_id'] ?? _newLocalId('order-payment'),
        'order_id': orderId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Drops non-integer `id` values so SQLite INTEGER PK inserts never mismatch.
  Map<String, dynamic> _sanitizeOrderPaymentRow(Map<String, dynamic> payment) {
    final row = Map<String, dynamic>.from(payment);
    final remoteId = jsonAsInt(row['remote_id']) ?? jsonAsInt(row['id']);
    final rawId = '${row['id'] ?? ''}'.trim();
    if (remoteId != null) {
      row['remote_id'] = remoteId;
    } else {
      row.remove('remote_id');
    }
    // Never write a string (e.g. "credit-8") into INTEGER id.
    row.remove('id');
    final localId = '${row['local_id'] ?? ''}'.trim();
    if (localId.isEmpty && remoteId == null && rawId.isNotEmpty) {
      row['local_id'] = rawId;
    }
    return row;
  }

  Future<int> addOrderPayment(
    StoreScope scope,
    Map<String, dynamic> payment,
  ) async {
    final row = _sanitizeOrderPaymentRow(payment);
    final id = await db.insert('order_payments', {
      ...row,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'local_id': row['local_id'] ?? _newLocalId('order-payment'),
    });
    final orderId = jsonAsInt(row['order_id']) ?? 0;
    if (orderId != 0) {
      await _markOrderDirty(scope, orderId);
    }
    return id;
  }

  Future<void> replaceOrderItems(
    StoreScope scope,
    int orderId,
    List<Map<String, dynamic>> items, {
    DatabaseExecutor? executor,
  }) async {
    final dbx = executor ?? db;
    final previousTables = await dbx.query(
      'order_items',
      columns: [
        'unique_id',
        'product_variant_id',
        'table_id',
        'table_name',
        'floor_id',
        'floor_name',
      ],
      where:
          "orgId = ? AND storeId = ? AND order_id = ? AND COALESCE(table_id, '') != ''",
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
    await dbx.delete(
      'order_item_addons',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
    await dbx.delete(
      'order_items',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
    for (final item in items) {
      final itemRow = Map<String, dynamic>.from(item);
      _keepLocalTable(itemRow, previousTables);
      final addons = (itemRow.remove('addons') as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((addon) => addon.cast<String, dynamic>())
          .toList(growable: false);
      final itemId = await dbx.insert('order_items', {
        ...itemRow,
        'orgId': scope.orgId,
        'storeId': scope.storeId,
        'unique_id': itemRow['unique_id'],
        'order_id': orderId,
        'kitchen_sent_quantity': itemRow['kitchen_sent_quantity'] ?? 0,
        'kitchen_sent_batch': itemRow['kitchen_sent_batch'],
        'kitchen_sent_at': itemRow['kitchen_sent_at'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      for (final addon in addons) {
        await addOrderItemAddon(scope, {
          ...addon,
          'order_id': orderId,
          'order_item_id': itemId,
        }, executor: dbx);
      }
    }
  }

  /// Cloud order rows carry no dine-in table; keep the device's assignment
  /// (same item, else same product, else the order's only table).
  static void _keepLocalTable(
    Map<String, dynamic> itemRow,
    List<Map<String, Object?>> previous,
  ) {
    if ('${itemRow['table_id'] ?? ''}'.trim().isNotEmpty || previous.isEmpty) {
      return;
    }
    String text(Object? v) => '${v ?? ''}'.trim();
    final uniqueId = text(itemRow['unique_id']);
    final variantId = text(itemRow['product_variant_id']);
    Map<String, Object?>? match;
    for (final row in previous) {
      if (uniqueId.isNotEmpty && text(row['unique_id']) == uniqueId) {
        match = row;
        break;
      }
    }
    if (match == null && variantId.isNotEmpty) {
      for (final row in previous) {
        if (text(row['product_variant_id']) == variantId) {
          match = row;
          break;
        }
      }
    }
    if (match == null &&
        previous.map((row) => text(row['table_id'])).toSet().length == 1) {
      match = previous.first;
    }
    if (match == null) return;
    for (final key in const [
      'table_id',
      'table_name',
      'floor_id',
      'floor_name',
    ]) {
      itemRow[key] = match[key];
    }
  }

  Future<int> addOrderItem(
    StoreScope scope,
    Map<String, dynamic> item, {
    List<Map<String, dynamic>> addons = const [],
  }) async {
    final itemId = await db.insert('order_items', {
      ...item,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': item['unique_id'],
      'kitchen_sent_quantity': item['kitchen_sent_quantity'] ?? 0,
      'kitchen_sent_batch': item['kitchen_sent_batch'],
      'kitchen_sent_at': item['kitchen_sent_at'],
    });
    for (final addon in addons) {
      await addOrderItemAddon(scope, {...addon, 'order_item_id': itemId});
    }
    return itemId;
  }

  Future<int> addOrderItemAddon(
    StoreScope scope,
    Map<String, dynamic> addon, {
    DatabaseExecutor? executor,
  }) async {
    final dbx = executor ?? db;
    return dbx.insert('order_item_addons', {
      ...addon,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'total_price':
          ((addon['unit_price'] as num?)?.toDouble() ?? 0) *
          ((addon['qty'] as num?)?.toInt() ?? 0),
    });
  }

  Future<List<Map<String, dynamic>>> getOrderItemAddons(
    StoreScope scope,
    int itemId,
  ) {
    return db.query(
      'order_item_addons',
      where: 'orgId = ? AND storeId = ? AND order_item_id = ?',
      whereArgs: [scope.orgId, scope.storeId, itemId],
      orderBy: 'created_on ASC, id ASC',
    );
  }

  Future<Map<String, dynamic>?> getOrderItemAddonById(
    StoreScope scope,
    int addonId,
  ) async {
    final rows = await db.query(
      'order_item_addons',
      where: 'orgId = ? AND storeId = ? AND id = ?',
      whereArgs: [scope.orgId, scope.storeId, addonId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> deleteOrderItemAddon(StoreScope scope, int addonId) {
    return db.delete(
      'order_item_addons',
      where: 'orgId = ? AND storeId = ? AND id = ?',
      whereArgs: [scope.orgId, scope.storeId, addonId],
    );
  }

  Future<int> deleteOrderItemAddonsForItem(StoreScope scope, int itemId) {
    return db.delete(
      'order_item_addons',
      where: 'orgId = ? AND storeId = ? AND order_item_id = ?',
      whereArgs: [scope.orgId, scope.storeId, itemId],
    );
  }

  Future<int> getOrderItemAddonSelectionCount(
    StoreScope scope,
    int itemId, {
    required String addonGroupId,
  }) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(qty), 0) AS total FROM order_item_addons WHERE orgId = ? AND storeId = ? AND order_item_id = ? AND addon_group_id = ?',
      [scope.orgId, scope.storeId, itemId, addonGroupId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<double> getOrderItemAddonUnitTotal(
    StoreScope scope,
    int itemId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total_price), 0) AS total FROM order_item_addons WHERE orgId = ? AND storeId = ? AND order_item_id = ?',
      [scope.orgId, scope.storeId, itemId],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> updateOrderItemPricing(
    StoreScope scope,
    int itemId, {
    required double unitPrice,
    required double finalPrice,
  }) {
    return db.update(
      'order_items',
      {'unit_price': unitPrice, 'final_price': finalPrice},
      where: 'id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [itemId, scope.orgId, scope.storeId],
    );
  }

  Future<int> updateOrderItemQuantity(
    StoreScope scope,
    int itemId, {
    required int quantity,
  }) async {
    final item = await getOrderItemById(scope, itemId);
    if (item == null) {
      return 0;
    }
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
    final finalPrice = unitPrice * quantity;
    return db.update(
      'order_items',
      {'qty': quantity, 'final_price': finalPrice},
      where: 'id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [itemId, scope.orgId, scope.storeId],
    );
  }

  Future<int> deleteOrderItem(StoreScope scope, int itemId) {
    return db.transaction((txn) async {
      await txn.delete(
        'order_item_addons',
        where: 'orgId = ? AND storeId = ? AND order_item_id = ?',
        whereArgs: [scope.orgId, scope.storeId, itemId],
      );
      return txn.delete(
        'order_items',
        where: 'id = ? AND orgId = ? AND storeId = ?',
        whereArgs: [itemId, scope.orgId, scope.storeId],
      );
    });
  }

  Future<Map<String, dynamic>?> getOrderItemById(
    StoreScope scope,
    int itemId,
  ) async {
    final rows = await db.query(
      'order_items',
      where: 'id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [itemId, scope.orgId, scope.storeId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<double> getOrderItemsTotal(StoreScope scope, int orderId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(final_price), 0) AS total FROM order_items WHERE orgId = ? AND storeId = ? AND order_id = ?',
      [scope.orgId, scope.storeId, orderId],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  // Settlement coverage includes credit tenders so finalized credit sales can close.
  // Use summary paid_total for actual receipts, including allocated repayments.
  Future<double> getOrderPaymentsTotal(StoreScope scope, int orderId) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE((
          SELECT SUM(amount) FROM order_payments
          WHERE orgId = ? AND storeId = ? AND order_id = ?
        ), 0)
        -
        COALESCE((
          SELECT SUM(amount) FROM order_refunds
          WHERE orgId = ? AND storeId = ? AND order_id = ?
        ), 0)
        AS total
      ''',
      [
        scope.orgId,
        scope.storeId,
        orderId,
        scope.orgId,
        scope.storeId,
        orderId,
      ],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, dynamic>>> getOrderRefunds(
    StoreScope scope,
    int orderId,
  ) {
    return db.query(
      'order_refunds',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
      orderBy: 'created_on ASC, id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> listAllOrderRefunds(StoreScope scope) {
    return db.query(
      'order_refunds',
      where: 'orgId = ? AND storeId = ?',
      whereArgs: [scope.orgId, scope.storeId],
      orderBy: 'created_on DESC, id DESC',
    );
  }

  Future<double> getPaymentRefundedTotal(
    StoreScope scope,
    int paymentId,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total FROM order_refunds
      WHERE orgId = ? AND storeId = ? AND payment_id = ?
      ''',
      [scope.orgId, scope.storeId, paymentId],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> addOrderRefund(
    StoreScope scope,
    Map<String, dynamic> refund,
  ) async {
    final id = await db.insert('order_refunds', {
      ...refund,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
    });
    final orderId = jsonAsInt(refund['order_id']) ?? 0;
    if (orderId != 0) {
      await _markOrderDirty(scope, orderId);
    }
    return id;
  }

  Future<int> markOrderRefundsExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    if (localIds.isEmpty) return 0;
    final placeholders = List.filled(localIds.length, '?').join(', ');
    return db.rawUpdate(
      'UPDATE order_refunds SET exported = ? WHERE orgId = ? AND storeId = ? AND local_id IN ($placeholders)',
      [exported ? 1 : 0, scope.orgId, scope.storeId, ...localIds],
    );
  }

  /// Hard-delete a Draft order and related local rows. Throws if not Draft.
  Future<void> deleteDraftOrder(StoreScope scope, int orderId) async {
    final order = await getOrderById(scope, orderId);
    if (order == null) {
      throw StateError('Order $orderId was not found.');
    }
    final status = order['status_name'] as String? ?? '';
    if (!StoreOrderStatus.isDraft(status)) {
      throw StateError('Only Draft orders can be deleted.');
    }
    await purgeOrder(scope, orderId);
  }

  Future<int> countOrderPayments(StoreScope scope, int orderId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM order_payments '
      'WHERE orgId = ? AND storeId = ? AND order_id = ?',
      [scope.orgId, scope.storeId, orderId],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Hard-delete an order and every local row that belongs to it.
  Future<void> purgeOrder(StoreScope scope, int orderId) async {
    final items = await getOrderItems(scope, orderId);
    await db.transaction((txn) async {
      for (final item in items) {
        final itemId = (item['id'] as num?)?.toInt() ?? 0;
        if (itemId == 0) continue;
        await txn.delete(
          'order_item_addons',
          where: 'orgId = ? AND storeId = ? AND order_item_id = ?',
          whereArgs: [scope.orgId, scope.storeId, itemId],
        );
      }
      await txn.delete(
        'order_item_kitchen_cancellations',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.delete(
        'order_items',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.delete(
        'order_refunds',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.delete(
        'order_payments',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
      await txn.delete(
        'orders',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
      );
    });
  }

  Future<int> updateOrderAmounts(
    StoreScope scope,
    int orderId, {
    required double totalValue,
    required double offerAppliedValue,
    required double finalValue,
  }) async {
    final order = await getOrderById(scope, orderId);
    final status = '${order?['status_name'] ?? ''}'.trim();
    final values = <String, Object?>{
      'total_value': totalValue,
      'offer_applied_value': offerAppliedValue,
      'final_value': finalValue,
      'total': finalValue,
      'updated_on': DateTime.now().toUtc().toIso8601String(),
    };
    if (StoreOrderStatus.isSyncExcluded(status)) {
      values['exported'] = 1;
      values['last_exported_at'] = null;
    } else {
      values['exported'] = 0;
      values['last_exported_at'] = null;
    }
    return db.update(
      'orders',
      values,
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
  }

  Future<List<Map<String, dynamic>>> getOrderItems(
    StoreScope scope,
    int orderId,
  ) async {
    return await db.query(
      'order_items',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingKitchenOrderItems(
    StoreScope scope,
    int orderId,
  ) async {
    return db.query(
      'order_items',
      where:
          'orgId = ? AND storeId = ? AND order_id = ? AND qty > COALESCE(kitchen_sent_quantity, 0)',
      whereArgs: [scope.orgId, scope.storeId, orderId],
      orderBy: 'id ASC',
    );
  }

  Future<int> getNextKitchenBatchNumber(StoreScope scope, int orderId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(kitchen_sent_batch), 0) + 1 AS next_batch FROM order_items WHERE orgId = ? AND storeId = ? AND order_id = ?',
      [scope.orgId, scope.storeId, orderId],
    );
    return (rows.first['next_batch'] as num?)?.toInt() ?? 1;
  }

  Future<int> markOrderItemsSentToKitchen(
    StoreScope scope,
    Map<int, int> itemQuantities, {
    required int batchNumber,
    required String sentAt,
  }) async {
    if (itemQuantities.isEmpty) {
      return 0;
    }
    var updated = 0;
    final batch = db.batch();
    itemQuantities.forEach((itemId, sentQuantity) {
      batch.rawUpdate(
        'UPDATE order_items SET kitchen_sent_quantity = COALESCE(kitchen_sent_quantity, 0) + ?, kitchen_sent_batch = ?, kitchen_sent_at = ? WHERE orgId = ? AND storeId = ? AND id = ?',
        [sentQuantity, batchNumber, sentAt, scope.orgId, scope.storeId, itemId],
      );
      updated++;
    });
    await batch.commit(noResult: true);
    return updated;
  }

  Future<int> addKitchenCancellation(
    StoreScope scope,
    Map<String, dynamic> cancellation,
  ) {
    return db.insert('order_item_kitchen_cancellations', {
      ...cancellation,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
    });
  }

  Future<List<Map<String, dynamic>>> getKitchenCancellations(
    StoreScope scope,
    int orderId,
  ) {
    return db.query(
      'order_item_kitchen_cancellations',
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
      orderBy: 'created_on ASC, id ASC',
    );
  }

  Future<int> updateKitchenSentQuantity(
    StoreScope scope,
    int itemId, {
    required int kitchenSentQuantity,
  }) {
    return db.update(
      'order_items',
      {'kitchen_sent_quantity': kitchenSentQuantity},
      where: 'id = ? AND orgId = ? AND storeId = ?',
      whereArgs: [itemId, scope.orgId, scope.storeId],
    );
  }

  Future<int> countPendingExportOrders(StoreScope scope) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total FROM orders
      WHERE orgId = ? AND storeId = ? AND exported = ?
        AND LOWER(TRIM(COALESCE(status_name, ''))) NOT LIKE '%draft%'
        AND LOWER(TRIM(COALESCE(status_name, ''))) NOT LIKE '%initiated%'
        AND (
          next_export_at IS NULL
          OR TRIM(COALESCE(next_export_at, '')) = ''
          OR next_export_at <= ?
        )
      ''',
      [scope.orgId, scope.storeId, 0, now],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> listPendingExportOrders(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) {
    return _listPendingExportOrdersWithPayments(
      scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> _listPendingExportOrdersWithPayments(
    StoreScope scope, {
    int? limit,
    int? offset,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final orders = await db.query(
      'orders',
      where:
          "orgId = ? AND storeId = ? AND exported = ? "
          "AND LOWER(TRIM(COALESCE(status_name, ''))) NOT LIKE '%draft%' "
          "AND LOWER(TRIM(COALESCE(status_name, ''))) NOT LIKE '%initiated%' "
          "AND ("
          "next_export_at IS NULL "
          "OR TRIM(COALESCE(next_export_at, '')) = '' "
          "OR next_export_at <= ?"
          ")",
      whereArgs: [scope.orgId, scope.storeId, 0, now],
      orderBy: 'id ASC',
      limit: limit,
      offset: offset,
    );
    if (orders.isEmpty) {
      return const [];
    }

    final orderIds = orders
        .map((row) => (row['order_id'] as num?)?.toInt() ?? 0)
        .where((id) => id != 0)
        .toList(growable: false);
    if (orderIds.isEmpty) {
      return orders
          .map(
            (order) => {
              ..._orderRowToSyncJson(order),
              'payments': const <Map<String, dynamic>>[],
              'refunds': const <Map<String, dynamic>>[],
              'items': const <Map<String, dynamic>>[],
            },
          )
          .toList(growable: false);
    }

    final placeholders = List.filled(orderIds.length, '?').join(', ');
    final scopeArgs = [scope.orgId, scope.storeId, ...orderIds];

    final payments = await db.rawQuery('''
      SELECT * FROM order_payments
      WHERE orgId = ? AND storeId = ? AND order_id IN ($placeholders)
      ORDER BY order_id ASC, created_on ASC, id ASC
      ''', scopeArgs);
    final refunds = await db.rawQuery('''
      SELECT * FROM order_refunds
      WHERE orgId = ? AND storeId = ? AND order_id IN ($placeholders)
      ORDER BY order_id ASC, created_on ASC, id ASC
      ''', scopeArgs);
    final items = await db.rawQuery('''
      SELECT * FROM order_items
      WHERE orgId = ? AND storeId = ? AND order_id IN ($placeholders)
      ORDER BY order_id ASC, id ASC
      ''', scopeArgs);
    final itemIds = items
        .map((row) => (row['id'] as num?)?.toInt() ?? 0)
        .where((id) => id != 0)
        .toList(growable: false);
    final addonsByItemId = <int, List<Map<String, dynamic>>>{};
    if (itemIds.isNotEmpty) {
      final addonPlaceholders = List.filled(itemIds.length, '?').join(', ');
      final addons = await db.rawQuery(
        '''
        SELECT * FROM order_item_addons
        WHERE orgId = ? AND storeId = ? AND order_item_id IN ($addonPlaceholders)
        ORDER BY order_item_id ASC, id ASC
        ''',
        [scope.orgId, scope.storeId, ...itemIds],
      );
      for (final addon in addons) {
        final itemId = (addon['order_item_id'] as num?)?.toInt() ?? 0;
        if (itemId == 0) continue;
        (addonsByItemId[itemId] ??= <Map<String, dynamic>>[]).add(addon);
      }
    }

    final paymentsByOrder = <int, List<Map<String, dynamic>>>{};
    for (final payment in payments) {
      final orderId = (payment['order_id'] as num?)?.toInt() ?? 0;
      (paymentsByOrder[orderId] ??= <Map<String, dynamic>>[]).add(payment);
    }
    final refundsByOrder = <int, List<Map<String, dynamic>>>{};
    for (final refund in refunds) {
      final orderId = (refund['order_id'] as num?)?.toInt() ?? 0;
      (refundsByOrder[orderId] ??= <Map<String, dynamic>>[]).add(refund);
    }
    final itemsByOrder = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final orderId = (item['order_id'] as num?)?.toInt() ?? 0;
      final itemId = (item['id'] as num?)?.toInt() ?? 0;
      final withAddons = {
        ...item,
        'addons': addonsByItemId[itemId] ?? const <Map<String, dynamic>>[],
      };
      (itemsByOrder[orderId] ??= <Map<String, dynamic>>[]).add(withAddons);
    }

    return orders
        .map((order) {
          final orderId = (order['order_id'] as num?)?.toInt() ?? 0;
          return {
            ..._orderRowToSyncJson(order),
            'payments':
                (paymentsByOrder[orderId] ?? const <Map<String, dynamic>>[])
                    .map(_paymentRowToSyncJson)
                    .toList(growable: false),
            'refunds':
                (refundsByOrder[orderId] ?? const <Map<String, dynamic>>[])
                    .map(_refundRowToSyncJson)
                    .toList(growable: false),
            'items': (itemsByOrder[orderId] ?? const <Map<String, dynamic>>[])
                .map(_orderItemRowToSyncJson)
                .toList(growable: false),
          };
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _extractPaymentsForOrder(
    Map<String, dynamic> order,
    StoreScope scope,
    String fallbackTimestamp,
  ) {
    final rawPayments =
        order['payments'] ?? order['payment_data'] ?? order['paymentData'];
    if (rawPayments is! List) {
      return const [];
    }

    final payments = <Map<String, dynamic>>[];
    for (final rawPayment in rawPayments.whereType<Map>()) {
      final payment = rawPayment.cast<String, dynamic>();
      final paymentMode = _normalizePaymentMode(
        payment['payment_mode'] as String? ??
            payment['paymentMode'] as String? ??
            payment['payment_method'] as String? ??
            payment['paymentMethod'] as String? ??
            payment['mode'] as String? ??
            '',
      );
      if (paymentMode.isEmpty) {
        continue;
      }
      final customerId =
          payment['customerId'] as String? ?? payment['customer_id'] as String?;
      // order_payments.id is INTEGER PK. Remote may send synthetic string ids
      // (e.g. "credit-8") — keep those on local_id / remote_id only.
      final remoteId =
          jsonAsInt(payment['remote_id']) ?? jsonAsInt(payment['id']);
      final rawId = '${payment['id'] ?? ''}'.trim();
      final explicitLocalId =
          '${payment['local_id'] ?? payment['localId'] ?? ''}'.trim();
      final localId = explicitLocalId.isNotEmpty
          ? explicitLocalId
          : (remoteId == null && rawId.isNotEmpty ? rawId : null);
      payments.add({
        if (remoteId != null) 'remote_id': remoteId,
        if (localId != null) 'local_id': localId,
        'orgId': payment['orgId'] ?? scope.orgId,
        'storeId': payment['storeId'] ?? scope.storeId,
        'order_id': payment['order_id'] ?? order['order_id'] ?? order['id'],
        'payment_mode': paymentMode,
        'amount': jsonAsDouble(payment['amount']) ?? 0,
        'customerId': paymentMode == 'credit' ? customerId : null,
        'reference_id': payment['reference_id'] ?? payment['referenceId'],
        'created_on':
            payment['created_on'] ?? payment['createdOn'] ?? fallbackTimestamp,
        'updated_on':
            payment['updated_on'] ??
            payment['updatedOn'] ??
            payment['created_on'] ??
            payment['createdOn'] ??
            fallbackTimestamp,
      });
    }
    return payments;
  }

  List<Map<String, dynamic>> _extractItemsForOrder(
    Map<String, dynamic> order,
    StoreScope scope,
    String fallbackTimestamp,
  ) {
    final rawItems =
        order['items'] ?? order['order_items'] ?? order['orderItems'];
    if (rawItems is! List) {
      return const [];
    }

    final orderPricingMode = StoreOrderPricingMode.normalize(
      order['pricing_mode'] ?? order['pricingMode'],
    );
    final items = <Map<String, dynamic>>[];
    for (final rawItem in rawItems.whereType<Map>()) {
      final item = rawItem.cast<String, dynamic>();
      final rawAddons =
          item['addons'] ??
          item['addon_items'] ??
          item['order_item_addons'] ??
          item['orderItemAddons'];
      final addons = <Map<String, dynamic>>[];
      if (rawAddons is List) {
        for (final rawAddon in rawAddons.whereType<Map>()) {
          final addon = rawAddon.cast<String, dynamic>();
          final addonQuantity =
              jsonAsDouble(addon['qty']) ??
              jsonAsDouble(addon['quantity']) ??
              1;
          final addonUnitPrice =
              jsonAsDouble(addon['unit_price']) ??
              jsonAsDouble(addon['unitPrice']) ??
              jsonAsDouble(addon['price']) ??
              0;
          addons.add({
            'orgId': addon['orgId'] ?? scope.orgId,
            'storeId': addon['storeId'] ?? scope.storeId,
            'order_id':
                addon['order_id'] ??
                item['order_id'] ??
                order['order_id'] ??
                order['id'],
            'addon_group_id':
                '${addon['addon_group_id'] ?? addon['addonGroupId'] ?? addon['group_id'] ?? addon['groupName'] ?? addon['groupId'] ?? ''}',
            'addon_group_name':
                addon['addon_group_name'] ??
                addon['addonGroupName'] ??
                addon['group_name'] ??
                addon['groupName'] ??
                '',
            'min_selections':
                jsonAsInt(addon['min_selections']) ??
                jsonAsInt(addon['minSelections']) ??
                jsonAsInt(addon['min']) ??
                0,
            'max_selections':
                jsonAsInt(addon['max_selections']) ??
                jsonAsInt(addon['maxSelections']) ??
                jsonAsInt(addon['max']),
            'addon_item_id':
                '${addon['addon_item_id'] ?? addon['addonItemId'] ?? addon['id'] ?? ''}',
            'addon_item_name':
                addon['addon_item_name'] ??
                addon['addonItemName'] ??
                addon['name'] ??
                '',
            'qty': addonQuantity,
            'pricing_mode': StoreOrderPricingMode.normalize(
              addon['pricing_mode'] ??
                  addon['pricingMode'] ??
                  item['pricing_mode'] ??
                  item['pricingMode'] ??
                  orderPricingMode,
            ),
            'sell_price':
                jsonAsDouble(addon['sell_price']) ??
                jsonAsDouble(addon['sellPrice']) ??
                jsonAsDouble(addon['price']) ??
                addonUnitPrice,
            'buy_price':
                jsonAsDouble(addon['buy_price']) ??
                jsonAsDouble(addon['buyPrice']) ??
                jsonAsDouble(addon['price']),
            'mrp_price':
                jsonAsDouble(addon['mrp_price']) ??
                jsonAsDouble(addon['mrpPrice']) ??
                jsonAsDouble(addon['price']) ??
                addonUnitPrice,
            'unit_price': addonUnitPrice,
            'total_price':
                jsonAsDouble(addon['total_price']) ??
                jsonAsDouble(addon['totalPrice']) ??
                (addonUnitPrice * addonQuantity),
            'created_on':
                addon['created_on'] ?? addon['createdOn'] ?? fallbackTimestamp,
          });
        }
      }
      items.add({
        'id': item['id'],
        'orgId': item['orgId'] ?? scope.orgId,
        'storeId': item['storeId'] ?? scope.storeId,
        'unique_id': item['unique_id'] ?? item['uniqueId'],
        'order_id': item['order_id'] ?? order['order_id'] ?? order['id'],
        'product_variant_id':
            item['product_variant_id'] ?? item['productVariantId'] ?? '',
        'product_id': item['product_id'] ?? item['productId'] ?? '',
        'item_name':
            '${item['item_name'] ?? item['itemName'] ?? item['product_name'] ?? item['productName'] ?? item['name'] ?? ''}'
                .trim(),
        'qty': jsonAsDouble(item['qty']) ?? jsonAsDouble(item['quantity']) ?? 0,
        'pricing_mode': StoreOrderPricingMode.normalize(
          item['pricing_mode'] ?? item['pricingMode'] ?? orderPricingMode,
        ),
        'sell_price':
            jsonAsDouble(item['sell_price']) ??
            jsonAsDouble(item['sellPrice']) ??
            jsonAsDouble(item['unit_price']) ??
            jsonAsDouble(item['unitPrice']) ??
            0,
        'buy_price':
            jsonAsDouble(item['buy_price']) ?? jsonAsDouble(item['buyPrice']),
        'mrp_price':
            jsonAsDouble(item['mrp_price']) ??
            jsonAsDouble(item['mrpPrice']) ??
            jsonAsDouble(item['sell_price']) ??
            jsonAsDouble(item['sellPrice']) ??
            jsonAsDouble(item['unit_price']) ??
            jsonAsDouble(item['unitPrice']) ??
            0,
        'base_unit_price':
            jsonAsDouble(item['base_unit_price']) ??
            jsonAsDouble(item['baseUnitPrice']) ??
            jsonAsDouble(item['unit_price']) ??
            jsonAsDouble(item['unitPrice']) ??
            0,
        'unit_price':
            jsonAsDouble(item['unit_price']) ??
            jsonAsDouble(item['unitPrice']) ??
            0,
        'final_price':
            jsonAsDouble(item['final_price']) ??
            jsonAsDouble(item['finalPrice']) ??
            0,
        'kitchen_sent_quantity':
            jsonAsInt(item['kitchen_sent_quantity']) ??
            jsonAsInt(item['kitchenSentQuantity']) ??
            0,
        'kitchen_sent_batch':
            jsonAsInt(item['kitchen_sent_batch']) ??
            jsonAsInt(item['kitchenSentBatch']),
        'kitchen_sent_at': item['kitchen_sent_at'] ?? item['kitchenSentAt'],
        'created_by': item['created_by'] ?? item['createdBy'] ?? 'import',
        'created_on':
            item['created_on'] ?? item['createdOn'] ?? fallbackTimestamp,
        'addons': addons,
      });
    }
    return items;
  }

  String _normalizePaymentMode(String rawMode) {
    final normalized = rawMode.trim().toLowerCase();
    if (_supportedPaymentModes.contains(normalized)) {
      return normalized;
    }
    return '';
  }

  Map<String, dynamic> _paymentRowToSyncJson(Map<String, dynamic> payment) {
    return {
      'id': payment['remote_id'] ?? payment['id'],
      'local_id': payment['local_id'],
      'remote_id': payment['remote_id'],
      'order_id': payment['order_id'],
      'payment_mode': payment['payment_mode'],
      'amount': payment['amount'],
      'customerId': payment['customerId'],
      'reference_id': payment['reference_id'],
      'created_on': payment['created_on'],
      'updated_on': payment['updated_on'],
    };
  }

  Map<String, dynamic> _refundRowToSyncJson(Map<String, dynamic> refund) {
    return {
      'local_id': refund['local_id'],
      'remote_id': refund['remote_id'],
      'order_id': refund['order_id'],
      'payment_id': refund['payment_id'],
      'payment_local_id': refund['payment_local_id'],
      'payment_reference_id': refund['payment_reference_id'],
      'amount': refund['amount'],
      'reason': refund['reason'],
      'status': refund['status'],
      'created_on': refund['created_on'],
    };
  }

  Map<String, dynamic> _orderRowToSyncJson(Map<String, dynamic> order) {
    return {
      'unique_id': order['unique_id'],
      'local_id': order['local_id'],
      'remote_id': order['remote_id'],
      'order_id': order['order_id'],
      'restaurant_name': order['restaurant_name'],
      'name': order['name'],
      'mobile': order['mobile'],
      'customer_unique_id': order['customer_unique_id'],
      'customerId': order['customer_unique_id'],
      'user_id': order['customer_unique_id'],
      'status_name': order['status_name'],
      'total': order['final_value'] ?? order['total'],
      'total_value': order['total_value'] ?? order['total'],
      'offer_applied_value': order['offer_applied_value'] ?? 0,
      'final_value': order['final_value'] ?? order['total'],
      'service_instance': order['service_instance'],
      'created_by': order['created_by'],
      'created_on': order['created_on'],
      'updated_on': order['updated_on'] ?? order['created_on'],
      'payment_status': order['payment_status'],
      'order_type': order['order_type'],
      'pricing_mode': order['pricing_mode'],
      'exported': order['exported'],
      'last_imported_at': order['last_imported_at'],
      'last_exported_at': order['last_exported_at'],
      'orgId': order['orgId'],
      'storeId': order['storeId'],
    };
  }

  Map<String, dynamic> _orderItemRowToSyncJson(Map<String, dynamic> item) {
    final rawAddons = item['addons'] as List<dynamic>? ?? const [];
    return {
      'id': item['id'],
      'unique_id': item['unique_id'],
      'order_id': item['order_id'],
      'product_variant_id': item['product_variant_id'],
      'product_id': item['product_id'],
      'item_name': item['item_name'] ?? '',
      'product_name': item['item_name'] ?? '',
      'name': item['item_name'] ?? '',
      'table_id': item['table_id'],
      'table_name': item['table_name'],
      'floor_id': item['floor_id'],
      'floor_name': item['floor_name'],
      'qty': item['qty'],
      'pricing_mode': item['pricing_mode'],
      'sell_price': item['sell_price'],
      'buy_price': item['buy_price'],
      'mrp_price': item['mrp_price'],
      'base_unit_price': item['base_unit_price'],
      'unit_price': item['unit_price'],
      'final_price': item['final_price'],
      'created_by': item['created_by'],
      'created_on': item['created_on'],
      'addons': rawAddons
          .map((rawAddon) {
            final addon = rawAddon is Map<String, dynamic>
                ? rawAddon
                : (rawAddon as Map).cast<String, dynamic>();
            return {
              'id': addon['id'],
              'order_item_id': addon['order_item_id'],
              'addon_group_id': addon['addon_group_id'],
              'addon_group_name': addon['addon_group_name'],
              'min_selections': addon['min_selections'],
              'max_selections': addon['max_selections'],
              'addon_item_id': addon['addon_item_id'],
              'addon_item_name': addon['addon_item_name'],
              'qty': addon['qty'],
              'pricing_mode': addon['pricing_mode'],
              'sell_price': addon['sell_price'],
              'buy_price': addon['buy_price'],
              'mrp_price': addon['mrp_price'],
              'unit_price': addon['unit_price'],
              'total_price': addon['total_price'],
              'created_on': addon['created_on'],
            };
          })
          .toList(growable: false),
    };
  }

  Future<int> markOrdersExported(
    StoreScope scope,
    List<String> localIds, {
    required bool exported,
  }) async {
    if (localIds.isEmpty) {
      return 0;
    }
    final placeholders = List.filled(localIds.length, '?').join(', ');
    final now = DateTime.now().toUtc().toIso8601String();
    final lastExportedAt = exported ? now : null;
    final updated = await db.rawUpdate(
      exported
          ? '''
      UPDATE orders
      SET exported = ?, last_exported_at = ?,
          export_fail_count = 0,
          next_export_at = NULL,
          updated_on = COALESCE(NULLIF(TRIM(updated_on), ''), ?)
      WHERE orgId = ? AND storeId = ? AND local_id IN ($placeholders)
      '''
          : '''
      UPDATE orders
      SET exported = ?, last_exported_at = ?, updated_on = ?
      WHERE orgId = ? AND storeId = ? AND local_id IN ($placeholders)
      ''',
      exported
          ? [1, lastExportedAt, now, scope.orgId, scope.storeId, ...localIds]
          : [0, null, now, scope.orgId, scope.storeId, ...localIds],
    );
    if (exported) {
      await db.rawUpdate(
        '''
        UPDATE order_refunds SET exported = 1
        WHERE orgId = ? AND storeId = ? AND order_id IN (
          SELECT order_id FROM orders
          WHERE orgId = ? AND storeId = ? AND local_id IN ($placeholders)
        )
        ''',
        [scope.orgId, scope.storeId, scope.orgId, scope.storeId, ...localIds],
      );
    }
    return updated;
  }

  /// Exponential backoff after gateway ingest failures (cap 30 minutes).
  Future<int> scheduleExportBackoff(
    StoreScope scope,
    List<String> localIds,
  ) async {
    if (localIds.isEmpty) return 0;
    var updated = 0;
    for (final localId in localIds) {
      final trimmed = localId.trim();
      if (trimmed.isEmpty) continue;
      final rows = await db.query(
        'orders',
        columns: ['id', 'export_fail_count'],
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, trimmed],
        limit: 1,
      );
      if (rows.isEmpty) continue;
      final fails =
          ((rows.first['export_fail_count'] as num?)?.toInt() ?? 0) + 1;
      final shift = (fails - 1).clamp(0, 6).toInt();
      final delaySeconds = (30 * (1 << shift)).clamp(30, 1800);
      final nextAt = DateTime.now()
          .toUtc()
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();
      updated += await db.update(
        'orders',
        {'export_fail_count': fails, 'next_export_at': nextAt},
        where: 'id = ?',
        whereArgs: [rows.first['id']],
      );
    }
    return updated;
  }

  Future<Map<String, dynamic>?> _findExistingOrder(
    StoreScope scope, {
    String? uniqueId,
    String? localId,
    int? remoteId,
    int? orderId,
    DatabaseExecutor? executor,
  }) async {
    final dbx = executor ?? db;
    if (uniqueId != null && uniqueId.isNotEmpty) {
      final rows = await dbx.query(
        'orders',
        where: 'orgId = ? AND storeId = ? AND unique_id = ?',
        whereArgs: [scope.orgId, scope.storeId, uniqueId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    if (localId != null && localId.isNotEmpty) {
      final rows = await dbx.query(
        'orders',
        where: 'orgId = ? AND storeId = ? AND local_id = ?',
        whereArgs: [scope.orgId, scope.storeId, localId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    if (remoteId != null) {
      final rows = await dbx.query(
        'orders',
        where: 'orgId = ? AND storeId = ? AND remote_id = ?',
        whereArgs: [scope.orgId, scope.storeId, remoteId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    if (orderId != null && orderId != 0) {
      final rows = await dbx.query(
        'orders',
        where: 'orgId = ? AND storeId = ? AND order_id = ?',
        whereArgs: [scope.orgId, scope.storeId, orderId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return rows.first;
      }
    }
    return null;
  }

  Future<int> _upsertOrder(
    StoreScope scope,
    Map<String, dynamic> order, {
    DatabaseExecutor? executor,
  }) async {
    final dbx = executor ?? db;
    final existing = await _findExistingOrder(
      scope,
      uniqueId: order['unique_id'] as String?,
      localId: order['local_id'] as String?,
      remoteId: jsonAsInt(order['remote_id']),
      orderId: jsonAsInt(order['order_id']),
      executor: dbx,
    );
    final incomingCreatedBy = '${order['created_by'] ?? ''}'.trim();
    final existingCreatedBy = '${existing?['created_by'] ?? ''}'.trim();
    final incomingStatus = '${order['status_name'] ?? ''}'.trim();
    final existingStatus = '${existing?['status_name'] ?? ''}'.trim();
    final mergedStatus = _mergeStatusName(incomingStatus, existingStatus);
    final incomingUpdatedOn = '${order['updated_on'] ?? ''}'.trim();
    final existingUpdatedOn = '${existing?['updated_on'] ?? ''}'.trim();
    final data = <String, dynamic>{
      ...order,
      'orgId': scope.orgId,
      'storeId': scope.storeId,
      'unique_id': (order['unique_id'] as String?)?.isNotEmpty == true
          ? order['unique_id']
          : existing?['unique_id'],
      'local_id': (order['local_id'] as String?)?.isNotEmpty == true
          ? order['local_id']
          : existing?['local_id'] ?? _newLocalId('order'),
      'remote_id': order['remote_id'] ?? existing?['remote_id'],
      'created_by': _mergeCreatedBy(incomingCreatedBy, existingCreatedBy),
      'status_name': mergedStatus,
      'updated_on': incomingUpdatedOn.isNotEmpty
          ? incomingUpdatedOn
          : (existingUpdatedOn.isNotEmpty
                ? existingUpdatedOn
                : DateTime.now().toUtc().toIso8601String()),
    };
    data.remove('id');

    if (existing != null) {
      // Stale cloud status (e.g. Initiated) must not wipe local Cancelled, and
      // must re-export so the gateway applies cancel on the next sync.
      if (StoreOrderStatus.isCancelled(mergedStatus) &&
          !StoreOrderStatus.isCancelled(incomingStatus)) {
        data['exported'] = 0;
        data['last_exported_at'] = null;
        data['updated_on'] = DateTime.now().toUtc().toIso8601String();
      }
      return dbx.update(
        'orders',
        data,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    }
    return dbx.insert(
      'orders',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _markOrderDirty(StoreScope scope, int orderId) async {
    final order = await getOrderById(scope, orderId);
    if (order == null) return;
    final status = '${order['status_name'] ?? ''}'.trim();
    final now = DateTime.now().toUtc().toIso8601String();
    final values = <String, Object?>{
      'updated_on': now,
      'export_fail_count': 0,
      'next_export_at': null,
    };
    if (StoreOrderStatus.isSyncExcluded(status)) {
      values['exported'] = 1;
      values['last_exported_at'] = null;
    } else {
      values['exported'] = 0;
      values['last_exported_at'] = null;
    }
    await db.update(
      'orders',
      values,
      where: 'orgId = ? AND storeId = ? AND order_id = ?',
      whereArgs: [scope.orgId, scope.storeId, orderId],
    );
  }

  String _newLocalId(String prefix) => '$prefix-${_uuid.v4()}';

  Future<void> close() async {
    await db.close();
  }
}

bool _shouldApplyRemoteOrder({
  required Map<String, dynamic> existing,
  required DateTime? remoteUpdatedOn,
}) {
  final localUpdatedOn =
      _parseTimestamp(existing['updated_on']) ??
      _parseTimestamp(existing['created_on']);
  final localPending = ((existing['exported'] as num?)?.toInt() ?? 1) == 0;

  // Pending local mutations win unless cloud is strictly newer.
  if (localPending) {
    if (remoteUpdatedOn == null || localUpdatedOn == null) {
      return false;
    }
    return remoteUpdatedOn.isAfter(localUpdatedOn);
  }

  // Already synced: only apply when cloud is strictly newer.
  if (localUpdatedOn != null && remoteUpdatedOn != null) {
    return remoteUpdatedOn.isAfter(localUpdatedOn);
  }
  // Legacy rows without timestamps still import.
  return true;
}

DateTime? _parseTimestamp(Object? raw) {
  var text = '${raw ?? ''}'.trim();
  if (text.isEmpty) return null;
  // Normalize bare local/ISO timestamps to UTC for stable LWW compares.
  if (!text.endsWith('Z') &&
      !RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(text) &&
      text.contains('T')) {
    text = '${text}Z';
  }
  return DateTime.tryParse(text)?.toUtc();
}

bool _isWeakCreatedBy(String value) {
  final trimmed = value.trim().toLowerCase();
  return trimmed.isEmpty ||
      trimmed == 'import' ||
      trimmed == 'pos' ||
      trimmed == 'system' ||
      trimmed == 'staff';
}

bool _createdByHasExtras(String value) {
  final lower = value.toLowerCase();
  return lower.contains('tips=') ||
      lower.contains('tax=') ||
      lower.contains('disc=') ||
      lower.contains('del=');
}

String _preferCreatedBy(Object? raw, {Object? staffReg}) {
  var text = '${raw ?? ''}'.trim();
  final reg = '${staffReg ?? ''}'.trim();
  if (text.isEmpty && reg.isNotEmpty) {
    text = reg;
  } else if (text.isNotEmpty &&
      reg.isNotEmpty &&
      !text.contains('|') &&
      !text.contains('=')) {
    text = '$text|$reg';
  }
  if (_isWeakCreatedBy(text)) return '';
  return text;
}

String _mergeCreatedBy(String incoming, String existing) {
  if (_isWeakCreatedBy(incoming) && !_isWeakCreatedBy(existing)) {
    return existing;
  }
  if (_isWeakCreatedBy(existing)) {
    return _isWeakCreatedBy(incoming) ? '' : incoming;
  }
  // Keep richer local checkout meta (tips/tax) when remote only has staff name.
  if (_createdByHasExtras(existing) && !_createdByHasExtras(incoming)) {
    return existing;
  }
  return incoming;
}

String _mergeStatusName(String incoming, String existing) {
  if (StoreOrderStatus.isCancelled(existing) &&
      !StoreOrderStatus.isCancelled(incoming)) {
    // Prefer local cancel over stale Initiated/Pending from cloud.
    return existing;
  }
  if (incoming.trim().isEmpty) return existing;
  return incoming;
}
