part of 'store.dart';

class StoreDashboardService {
  final Store _store;

  StoreDashboardService._(this._store);

  Future<StoreDashboardStatisticsResult> orderStatisticsGraph(
    StoreScope scope, {
    int sourceType = StoreDashboardSourceType.store,
    String segment = StoreDashboardSegment.month,
    DateTime? referenceDate,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _store._validateScope(scope);
    await _store._requireRole('member');

    final range = _resolveDashboardRange(
      segment: segment,
      referenceDate: referenceDate,
      startDate: startDate,
      endDate: endDate,
    );
    return _buildOrderStatisticsGraph(
      scope,
      sourceType: sourceType,
      range: range,
      segment: segment,
    );
  }

  Future<StoreDashboardSnapshot> snapshot(
    StoreScope scope, {
    int sourceType = StoreDashboardSourceType.store,
    String segment = StoreDashboardSegment.month,
    DateTime? referenceDate,
    DateTime? startDate,
    DateTime? endDate,
    int topLimit = 5,
  }) async {
    _store._validateScope(scope);
    await _store._requireRole('member');

    final range = _resolveDashboardRange(
      segment: segment,
      referenceDate: referenceDate,
      startDate: startDate,
      endDate: endDate,
    );
    final statistics = await _buildOrderStatisticsGraph(
      scope,
      sourceType: sourceType,
      range: range,
      segment: segment,
    );
    final topProducts = await _loadTopProducts(scope, range, limit: topLimit);
    final topCategories = await _loadTopCategories(scope, range, limit: topLimit);
    final creditCustomers = await _store._listCustomerCreditSummaries(
      scope,
      sortBy: StoreCreditCustomerSortBy.amount,
      descending: true,
    );
    final outstandingAmount = creditCustomers.fold<double>(
      0,
      (sum, customer) => sum + customer.totalOutstandingAmount,
    );

    return StoreDashboardSnapshot(
      range: range,
      generatedAt: DateTime.now(),
      statistics: statistics,
      topProducts: topProducts,
      topCategories: topCategories,
      paymentSummary: StoreDashboardPaymentSummary(
        cashAmount: statistics.data.totalAmountByCash,
        cardAmount: statistics.data.totalAmountByCard,
        onlineAmount: statistics.data.totalAmountByOnline,
        creditAmount: statistics.data.totalAmountByPayLater,
      ),
      creditSummary: StoreDashboardCreditSummary(
        customerCount: creditCustomers.length,
        outstandingAmount: outstandingAmount,
      ),
    );
  }

  Future<StoreDashboardStatisticsResult> _buildOrderStatisticsGraph(
    StoreScope scope, {
    required int sourceType,
    required StoreDashboardDateRange range,
    required String segment,
  }) async {
    final startIso = range.start.toIso8601String();
    final endExclusiveIso = range.endExclusive.toIso8601String();

    final orderRows = await _store._db.query(
      'orders',
      where: 'orgId = ? AND storeId = ? AND created_on >= ? AND created_on < ?',
      whereArgs: [scope.orgId, scope.storeId, startIso, endExclusiveIso],
      orderBy: 'created_on ASC, order_id ASC',
    );

    final paymentsByOrderId = await _loadDashboardPaymentsByOrder(scope, orderRows);

    final bucketStrategy = _resolveDashboardBucketStrategy(
      segment: segment,
      range: range,
    );

    final entriesByLabel = <String, StoreDashboardStatisticsEntry>{};
    for (final bucket in bucketStrategy.buckets) {
      entriesByLabel[bucket.label] = StoreDashboardStatisticsEntry.empty(
        date: bucket.label,
      );
    }

    for (final row in orderRows) {
      final createdOn = row['created_on'] as String? ?? '';
      final createdAt = DateTime.tryParse(createdOn)?.toLocal();
      if (createdAt == null) {
        continue;
      }

      final bucket = bucketStrategy.bucketFor(createdAt);
      if (bucket == null) {
        continue;
      }

      final entryKey = bucket.label;
      final current = entriesByLabel[entryKey] ??
          StoreDashboardStatisticsEntry.empty(date: entryKey);
      final orderId = (row['order_id'] as num?)?.toInt() ?? 0;
      final finalValue =
          (row['final_value'] as num?)?.toDouble() ??
          (row['total'] as num?)?.toDouble() ??
          0;
      final orderType = StoreOrderType.normalize(row['order_type'] as String? ?? '');
      final statusName = row['status_name'] as String? ?? '';
      final payments = paymentsByOrderId[orderId] ?? const <StoreOrderPaymentRecord>[];

      entriesByLabel[entryKey] = current.copyWith(
        amount: current.amount + finalValue,
        count: current.count + 1,
        countByDelivery:
            current.countByDelivery + (orderType == StoreOrderType.delivery ? 1 : 0),
        countByPickup:
            current.countByPickup + (orderType == StoreOrderType.pickUp ? 1 : 0),
        countByDineIn:
            current.countByDineIn + (orderType == StoreOrderType.dineIn ? 1 : 0),
        countByInstore: current.countByInstore,
        countByInitiated:
            current.countByInitiated + (_isDashboardInitiatedStatus(statusName) ? 1 : 0),
        countByPlaced:
            current.countByPlaced + (_isDashboardPlacedStatus(statusName) ? 1 : 0),
        countByDelivered:
            current.countByDelivered + (_isDashboardDeliveredStatus(statusName) ? 1 : 0),
        countByCancelled:
            current.countByCancelled + (_isDashboardCancelledStatus(statusName) ? 1 : 0),
        countByPayLater:
            current.countByPayLater + (_hasDashboardPayLater(payments) ? 1 : 0),
        cashAmount:
            current.cashAmount + _sumPaymentsByMode(payments, StoreOrderPaymentMode.cash),
        cardAmount:
            current.cardAmount + _sumPaymentsByMode(payments, StoreOrderPaymentMode.card),
        onlineAmount:
            current.onlineAmount + _sumPaymentsByMode(payments, StoreOrderPaymentMode.online),
        payLaterAmount:
            current.payLaterAmount + _sumPaymentsByMode(payments, StoreOrderPaymentMode.credit),
      );
    }

    final entries = bucketStrategy.buckets
        .map(
          (bucket) =>
              entriesByLabel[bucket.label] ??
              StoreDashboardStatisticsEntry.empty(date: bucket.label),
        )
        .toList(growable: false);
    final data = StoreDashboardStatisticsData.fromEntries(
      entries,
      sourceType: sourceType,
      granularity: bucketStrategy.granularity,
    );
    return StoreDashboardStatisticsResult.success(data: data);
  }

  Future<Map<int, List<StoreOrderPaymentRecord>>> _loadDashboardPaymentsByOrder(
    StoreScope scope,
    List<Map<String, Object?>> orderRows,
  ) async {
    if (orderRows.isEmpty) {
      return const <int, List<StoreOrderPaymentRecord>>{};
    }

    final orderIds = orderRows
        .map((row) => (row['order_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    if (orderIds.isEmpty) {
      return const <int, List<StoreOrderPaymentRecord>>{};
    }

    final placeholders = List.filled(orderIds.length, '?').join(', ');
    final paymentRows = await _store._db.rawQuery(
      'SELECT * FROM order_payments '
      'WHERE orgId = ? AND storeId = ? AND order_id IN ($placeholders) '
      'ORDER BY order_id ASC, id ASC',
      [scope.orgId, scope.storeId, ...orderIds],
    );

    final paymentsByOrderId = <int, List<StoreOrderPaymentRecord>>{};
    for (final row in paymentRows) {
      final payment = StoreOrderPaymentRecord.fromRow(row);
      paymentsByOrderId.putIfAbsent(payment.orderId, () => <StoreOrderPaymentRecord>[])
        ..add(payment);
    }
    return paymentsByOrderId;
  }

  Future<List<StoreDashboardTopProduct>> _loadTopProducts(
    StoreScope scope,
    StoreDashboardDateRange range, {
    required int limit,
  }) async {
    final rows = await _store._db.rawQuery(
      '''
      SELECT
        oi.product_variant_id AS product_variant_id,
        COALESCE(pv.product_name, oi.product_id, '') AS product_name,
        COALESCE(pv.product_variant_name, '') AS variant_name,
        COALESCE(SUM(oi.qty), 0) AS sold_quantity
      FROM order_items oi
      INNER JOIN orders o
        ON o.orgId = oi.orgId
       AND o.storeId = oi.storeId
       AND o.order_id = oi.order_id
      LEFT JOIN product_variants pv
        ON pv.orgId = oi.orgId
       AND pv.storeId = oi.storeId
       AND pv.localId = oi.product_variant_id
      WHERE oi.orgId = ?
        AND oi.storeId = ?
        AND o.created_on >= ?
        AND o.created_on < ?
      GROUP BY oi.product_variant_id, product_name, variant_name
      ORDER BY sold_quantity DESC, product_name COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [
        scope.orgId,
        scope.storeId,
        range.start.toIso8601String(),
        range.endExclusive.toIso8601String(),
        limit,
      ],
    );

    return rows
        .map(
          (row) => StoreDashboardTopProduct(
            productVariantId: row['product_variant_id'] as String? ?? '',
            productName: row['product_name'] as String? ?? 'Unknown product',
            variantName: row['variant_name'] as String? ?? '',
            soldQuantity: (row['sold_quantity'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<List<StoreDashboardTopCategory>> _loadTopCategories(
    StoreScope scope,
    StoreDashboardDateRange range, {
    required int limit,
  }) async {
    final rows = await _store._db.rawQuery(
      '''
      SELECT
        COALESCE(c.localId, '') AS category_local_id,
        COALESCE(c.name, 'Uncategorised') AS category_name,
        COALESCE(SUM(oi.qty), 0) AS sold_quantity
      FROM order_items oi
      INNER JOIN orders o
        ON o.orgId = oi.orgId
       AND o.storeId = oi.storeId
       AND o.order_id = oi.order_id
      LEFT JOIN product_variants pv
        ON pv.orgId = oi.orgId
       AND pv.storeId = oi.storeId
       AND pv.localId = oi.product_variant_id
      LEFT JOIN categories c
        ON c.orgId = pv.orgId
       AND c.storeId = pv.storeId
       AND c.localId = pv.categoryLocalId
      WHERE oi.orgId = ?
        AND oi.storeId = ?
        AND o.created_on >= ?
        AND o.created_on < ?
      GROUP BY category_name
      ORDER BY sold_quantity DESC, category_name COLLATE NOCASE ASC
      LIMIT ?
      ''',
      [
        scope.orgId,
        scope.storeId,
        range.start.toIso8601String(),
        range.endExclusive.toIso8601String(),
        limit,
      ],
    );

    return rows
        .map(
          (row) => StoreDashboardTopCategory(
            categoryLocalId: row['category_local_id'] as String? ?? '',
            categoryName: row['category_name'] as String? ?? 'Uncategorised',
            soldQuantity: (row['sold_quantity'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  }
}

class StoreDashboardSnapshot {
  final StoreDashboardDateRange range;
  final DateTime generatedAt;
  final StoreDashboardStatisticsResult statistics;
  final List<StoreDashboardTopProduct> topProducts;
  final List<StoreDashboardTopCategory> topCategories;
  final StoreDashboardPaymentSummary paymentSummary;
  final StoreDashboardCreditSummary creditSummary;

  const StoreDashboardSnapshot({
    required this.range,
    required this.generatedAt,
    required this.statistics,
    required this.topProducts,
    required this.topCategories,
    required this.paymentSummary,
    required this.creditSummary,
  });
}

class StoreDashboardStatisticsResult {
  final StoreDashboardStatisticsData data;
  final String message;
  final Map<String, Object?> moreInfo;
  final String status;

  const StoreDashboardStatisticsResult({
    required this.data,
    required this.message,
    required this.moreInfo,
    required this.status,
  });

  factory StoreDashboardStatisticsResult.success({
    required StoreDashboardStatisticsData data,
    String message = '',
    Map<String, Object?> moreInfo = const <String, Object?>{},
  }) {
    return StoreDashboardStatisticsResult(
      data: data,
      message: message,
      moreInfo: moreInfo,
      status: 'Success',
    );
  }
}

class StoreDashboardStatisticsData {
  final List<StoreDashboardStatisticsEntry> data;
  final String granularity;
  final int totalCount;
  final int totalCountByDelivery;
  final int totalCountByPickup;
  final int totalCountByInstore;
  final int totalCountByDineIn;
  final int totalCountByInitiated;
  final int totalCountByPlaced;
  final int totalCountByDelivered;
  final int totalCountByCancelled;
  final int totalCountByPayLater;
  final double totalAmount;
  final double totalAmountByCard;
  final double totalAmountByCash;
  final double totalAmountByOnline;
  final double totalAmountByPayLater;
  final StoreDashboardSourceSummary source;

  const StoreDashboardStatisticsData({
    required this.data,
    required this.granularity,
    required this.totalCount,
    required this.totalCountByDelivery,
    required this.totalCountByPickup,
    required this.totalCountByInstore,
    required this.totalCountByDineIn,
    required this.totalCountByInitiated,
    required this.totalCountByPlaced,
    required this.totalCountByDelivered,
    required this.totalCountByCancelled,
    required this.totalCountByPayLater,
    required this.totalAmount,
    required this.totalAmountByCard,
    required this.totalAmountByCash,
    required this.totalAmountByOnline,
    required this.totalAmountByPayLater,
    required this.source,
  });

  factory StoreDashboardStatisticsData.fromEntries(
    List<StoreDashboardStatisticsEntry> entries, {
    required int sourceType,
    required String granularity,
  }) {
    var totalCount = 0;
    var totalCountByDelivery = 0;
    var totalCountByPickup = 0;
    var totalCountByInstore = 0;
    var totalCountByDineIn = 0;
    var totalCountByInitiated = 0;
    var totalCountByPlaced = 0;
    var totalCountByDelivered = 0;
    var totalCountByCancelled = 0;
    var totalCountByPayLater = 0;
    var totalAmount = 0.0;
    var totalAmountByCard = 0.0;
    var totalAmountByCash = 0.0;
    var totalAmountByOnline = 0.0;
    var totalAmountByPayLater = 0.0;

    for (final entry in entries) {
      totalCount += entry.count;
      totalCountByDelivery += entry.countByDelivery;
      totalCountByPickup += entry.countByPickup;
      totalCountByInstore += entry.countByInstore;
      totalCountByDineIn += entry.countByDineIn;
      totalCountByInitiated += entry.countByInitiated;
      totalCountByPlaced += entry.countByPlaced;
      totalCountByDelivered += entry.countByDelivered;
      totalCountByCancelled += entry.countByCancelled;
      totalCountByPayLater += entry.countByPayLater;
      totalAmount += entry.amount;
      totalAmountByCard += entry.cardAmount;
      totalAmountByCash += entry.cashAmount;
      totalAmountByOnline += entry.onlineAmount;
      totalAmountByPayLater += entry.payLaterAmount;
    }

    return StoreDashboardStatisticsData(
      data: entries,
      granularity: granularity,
      totalCount: totalCount,
      totalCountByDelivery: totalCountByDelivery,
      totalCountByPickup: totalCountByPickup,
      totalCountByInstore: totalCountByInstore,
      totalCountByDineIn: totalCountByDineIn,
      totalCountByInitiated: totalCountByInitiated,
      totalCountByPlaced: totalCountByPlaced,
      totalCountByDelivered: totalCountByDelivered,
      totalCountByCancelled: totalCountByCancelled,
      totalCountByPayLater: totalCountByPayLater,
      totalAmount: totalAmount,
      totalAmountByCard: totalAmountByCard,
      totalAmountByCash: totalAmountByCash,
      totalAmountByOnline: totalAmountByOnline,
      totalAmountByPayLater: totalAmountByPayLater,
      source: StoreDashboardSourceSummary.fromTotals(
        sourceType: sourceType,
        totalCount: totalCount,
        totalAmount: totalAmount,
      ),
    );
  }
}

class StoreDashboardStatisticsEntry {
  final String date;
  final double amount;
  final int count;
  final int countByDelivery;
  final int countByPickup;
  final int countByDineIn;
  final int countByInstore;
  final int countByInitiated;
  final int countByPlaced;
  final int countByDelivered;
  final int countByCancelled;
  final int countByPayLater;
  final double cashAmount;
  final double cardAmount;
  final double onlineAmount;
  final double payLaterAmount;

  const StoreDashboardStatisticsEntry({
    required this.date,
    required this.amount,
    required this.count,
    required this.countByDelivery,
    required this.countByPickup,
    required this.countByDineIn,
    required this.countByInstore,
    required this.countByInitiated,
    required this.countByPlaced,
    required this.countByDelivered,
    required this.countByCancelled,
    required this.countByPayLater,
    required this.cashAmount,
    required this.cardAmount,
    required this.onlineAmount,
    required this.payLaterAmount,
  });

  factory StoreDashboardStatisticsEntry.empty({required String date}) {
    return StoreDashboardStatisticsEntry(
      date: date,
      amount: 0,
      count: 0,
      countByDelivery: 0,
      countByPickup: 0,
      countByDineIn: 0,
      countByInstore: 0,
      countByInitiated: 0,
      countByPlaced: 0,
      countByDelivered: 0,
      countByCancelled: 0,
      countByPayLater: 0,
      cashAmount: 0,
      cardAmount: 0,
      onlineAmount: 0,
      payLaterAmount: 0,
    );
  }

  StoreDashboardStatisticsEntry copyWith({
    String? date,
    double? amount,
    int? count,
    int? countByDelivery,
    int? countByPickup,
    int? countByDineIn,
    int? countByInstore,
    int? countByInitiated,
    int? countByPlaced,
    int? countByDelivered,
    int? countByCancelled,
    int? countByPayLater,
    double? cashAmount,
    double? cardAmount,
    double? onlineAmount,
    double? payLaterAmount,
  }) {
    return StoreDashboardStatisticsEntry(
      date: date ?? this.date,
      amount: amount ?? this.amount,
      count: count ?? this.count,
      countByDelivery: countByDelivery ?? this.countByDelivery,
      countByPickup: countByPickup ?? this.countByPickup,
      countByDineIn: countByDineIn ?? this.countByDineIn,
      countByInstore: countByInstore ?? this.countByInstore,
      countByInitiated: countByInitiated ?? this.countByInitiated,
      countByPlaced: countByPlaced ?? this.countByPlaced,
      countByDelivered: countByDelivered ?? this.countByDelivered,
      countByCancelled: countByCancelled ?? this.countByCancelled,
      countByPayLater: countByPayLater ?? this.countByPayLater,
      cashAmount: cashAmount ?? this.cashAmount,
      cardAmount: cardAmount ?? this.cardAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      payLaterAmount: payLaterAmount ?? this.payLaterAmount,
    );
  }
}

class StoreDashboardSourceSummary {
  final int totalCountByWeb;
  final int totalCountByStore;
  final int totalCountByMobile;
  final double totalAmountByMobile;
  final double totalAmountByStore;
  final double totalAmountByWeb;

  const StoreDashboardSourceSummary({
    required this.totalCountByWeb,
    required this.totalCountByStore,
    required this.totalCountByMobile,
    required this.totalAmountByMobile,
    required this.totalAmountByStore,
    required this.totalAmountByWeb,
  });

  factory StoreDashboardSourceSummary.fromTotals({
    required int sourceType,
    required int totalCount,
    required double totalAmount,
  }) {
    switch (sourceType) {
      case StoreDashboardSourceType.web:
        return StoreDashboardSourceSummary(
          totalCountByWeb: totalCount,
          totalCountByStore: 0,
          totalCountByMobile: 0,
          totalAmountByMobile: 0,
          totalAmountByStore: 0,
          totalAmountByWeb: totalAmount,
        );
      case StoreDashboardSourceType.mobile:
        return StoreDashboardSourceSummary(
          totalCountByWeb: 0,
          totalCountByStore: 0,
          totalCountByMobile: totalCount,
          totalAmountByMobile: totalAmount,
          totalAmountByStore: 0,
          totalAmountByWeb: 0,
        );
      case StoreDashboardSourceType.store:
      default:
        return StoreDashboardSourceSummary(
          totalCountByWeb: 0,
          totalCountByStore: totalCount,
          totalCountByMobile: 0,
          totalAmountByMobile: 0,
          totalAmountByStore: totalAmount,
          totalAmountByWeb: 0,
        );
    }
  }
}

class StoreDashboardPaymentSummary {
  final double cashAmount;
  final double cardAmount;
  final double onlineAmount;
  final double creditAmount;

  const StoreDashboardPaymentSummary({
    required this.cashAmount,
    required this.cardAmount,
    required this.onlineAmount,
    required this.creditAmount,
  });

  double get total => cashAmount + cardAmount + onlineAmount + creditAmount;
}

class StoreDashboardCreditSummary {
  final int customerCount;
  final double outstandingAmount;

  const StoreDashboardCreditSummary({
    required this.customerCount,
    required this.outstandingAmount,
  });
}

class StoreDashboardTopProduct {
  final String productVariantId;
  final String productName;
  final String variantName;
  final int soldQuantity;

  const StoreDashboardTopProduct({
    required this.productVariantId,
    required this.productName,
    required this.variantName,
    required this.soldQuantity,
  });

  String get displayName =>
      variantName.trim().isEmpty ? productName : '$productName $variantName';
}

class StoreDashboardTopCategory {
  final String categoryLocalId;
  final String categoryName;
  final int soldQuantity;

  const StoreDashboardTopCategory({
    required this.categoryLocalId,
    required this.categoryName,
    required this.soldQuantity,
  });
}

class StoreDashboardDateRange {
  final DateTime start;
  final DateTime end;
  final DateTime endExclusive;

  const StoreDashboardDateRange({
    required this.start,
    required this.end,
    required this.endExclusive,
  });
}

class StoreDashboardSegment {
  static const String day = 'day';
  static const String week = 'week';
  static const String month = 'month';
  static const String year = 'year';
  static const String custom = 'custom';

  static const Set<String> supported = {day, week, month, year, custom};

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == day) {
      return day;
    }
    if (normalized == week) {
      return week;
    }
    if (normalized == month) {
      return month;
    }
    if (normalized == year) {
      return year;
    }
    if (normalized == custom) {
      return custom;
    }
    throw ArgumentError.value(value, 'value', 'Unsupported dashboard segment.');
  }
}

class StoreDashboardGranularity {
  static const String hour = 'hour';
  static const String day = 'day';
  static const String week = 'week';
  static const String month = 'month';
}

class StoreDashboardSourceType {
  static const int web = 0;
  static const int store = 1;
  static const int mobile = 2;
}

class _StoreDashboardBucket {
  final String label;
  final DateTime start;
  final DateTime endExclusive;

  const _StoreDashboardBucket({
    required this.label,
    required this.start,
    required this.endExclusive,
  });

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(endExclusive);
  }
}

class _StoreDashboardBucketStrategy {
  final String granularity;
  final List<_StoreDashboardBucket> buckets;

  const _StoreDashboardBucketStrategy({
    required this.granularity,
    required this.buckets,
  });

  _StoreDashboardBucket? bucketFor(DateTime value) {
    for (final bucket in buckets) {
      if (bucket.contains(value)) {
        return bucket;
      }
    }
    return null;
  }
}

_StoreDashboardBucketStrategy _resolveDashboardBucketStrategy({
  required String segment,
  required StoreDashboardDateRange range,
}) {
  final normalizedSegment = StoreDashboardSegment.normalize(segment);
  switch (normalizedSegment) {
    case StoreDashboardSegment.day:
      return _buildHourlyDashboardBuckets(range.start);
    case StoreDashboardSegment.week:
      return _buildDailyDashboardBuckets(range.start, range.end);
    case StoreDashboardSegment.month:
      return _buildWeeklyDashboardBuckets(range.start, range.end);
    case StoreDashboardSegment.year:
      return _buildMonthlyDashboardBuckets(range.start, range.end);
    case StoreDashboardSegment.custom:
      final totalDays = range.end.difference(range.start).inDays + 1;
      if (totalDays <= 1) {
        return _buildHourlyDashboardBuckets(range.start);
      }
      if (totalDays <= 7) {
        return _buildDailyDashboardBuckets(range.start, range.end);
      }
      if (totalDays <= 31) {
        return _buildWeeklyDashboardBuckets(range.start, range.end);
      }
      return _buildMonthlyDashboardBuckets(range.start, range.end);
  }

  throw ArgumentError.value(segment, 'segment', 'Unsupported dashboard segment.');
}

_StoreDashboardBucketStrategy _buildHourlyDashboardBuckets(DateTime date) {
  final dayStart = _stripDashboardTime(date);
  final buckets = <_StoreDashboardBucket>[];
  for (var hour = 0; hour < 24; hour++) {
    final start = dayStart.add(Duration(hours: hour));
    buckets.add(
      _StoreDashboardBucket(
        label: '${hour.toString().padLeft(2, '0')}:00',
        start: start,
        endExclusive: start.add(const Duration(hours: 1)),
      ),
    );
  }
  return _StoreDashboardBucketStrategy(
    granularity: StoreDashboardGranularity.hour,
    buckets: buckets,
  );
}

_StoreDashboardBucketStrategy _buildDailyDashboardBuckets(
  DateTime start,
  DateTime end,
) {
  final buckets = <_StoreDashboardBucket>[];
  for (
    var current = _stripDashboardTime(start);
    !current.isAfter(_stripDashboardTime(end));
    current = current.add(const Duration(days: 1))
  ) {
    buckets.add(
      _StoreDashboardBucket(
        label: _formatDashboardDate(current),
        start: current,
        endExclusive: current.add(const Duration(days: 1)),
      ),
    );
  }
  return _StoreDashboardBucketStrategy(
    granularity: StoreDashboardGranularity.day,
    buckets: buckets,
  );
}

_StoreDashboardBucketStrategy _buildWeeklyDashboardBuckets(
  DateTime start,
  DateTime end,
) {
  final normalizedStart = _stripDashboardTime(start);
  final normalizedEnd = _stripDashboardTime(end);
  final buckets = <_StoreDashboardBucket>[];
  var current = normalizedStart;
  var weekIndex = 1;
  while (!current.isAfter(normalizedEnd)) {
    final bucketEnd = _minDateTime(
      current.add(const Duration(days: 6)),
      normalizedEnd,
    );
    buckets.add(
      _StoreDashboardBucket(
        label: 'Week $weekIndex',
        start: current,
        endExclusive: bucketEnd.add(const Duration(days: 1)),
      ),
    );
    current = bucketEnd.add(const Duration(days: 1));
    weekIndex += 1;
  }
  return _StoreDashboardBucketStrategy(
    granularity: StoreDashboardGranularity.week,
    buckets: buckets,
  );
}

_StoreDashboardBucketStrategy _buildMonthlyDashboardBuckets(
  DateTime start,
  DateTime end,
) {
  final normalizedStart = _stripDashboardTime(start);
  final normalizedEnd = _stripDashboardTime(end);
  final buckets = <_StoreDashboardBucket>[];
  var current = DateTime(normalizedStart.year, normalizedStart.month, 1);
  while (!current.isAfter(normalizedEnd)) {
    final nextMonth = current.month == 12
        ? DateTime(current.year + 1, 1, 1)
        : DateTime(current.year, current.month + 1, 1);
    final bucketStart = current.isBefore(normalizedStart) ? normalizedStart : current;
    final bucketEnd = _minDateTime(
      nextMonth.subtract(const Duration(days: 1)),
      normalizedEnd,
    );
    buckets.add(
      _StoreDashboardBucket(
        label: _formatDashboardMonthLabel(bucketStart),
        start: bucketStart,
        endExclusive: bucketEnd.add(const Duration(days: 1)),
      ),
    );
    current = nextMonth;
  }
  return _StoreDashboardBucketStrategy(
    granularity: StoreDashboardGranularity.month,
    buckets: buckets,
  );
}

StoreDashboardDateRange _resolveDashboardRange({
  required String segment,
  DateTime? referenceDate,
  DateTime? startDate,
  DateTime? endDate,
}) {
  final reference = (referenceDate ?? DateTime.now()).toLocal();
  final normalizedSegment = StoreDashboardSegment.normalize(segment);
  if (normalizedSegment == StoreDashboardSegment.custom) {
    if (startDate == null || endDate == null) {
      throw ArgumentError(
        'startDate and endDate are required for the custom dashboard segment.',
      );
    }
    final start = _stripDashboardTime(startDate.toLocal());
    final end = _stripDashboardTime(endDate.toLocal());
    if (end.isBefore(start)) {
      throw ArgumentError('endDate must be on or after startDate.');
    }
    return StoreDashboardDateRange(
      start: start,
      end: end,
      endExclusive: end.add(const Duration(days: 1)),
    );
  }

  switch (normalizedSegment) {
    case StoreDashboardSegment.day:
      final day = _stripDashboardTime(reference);
      return StoreDashboardDateRange(
        start: day,
        end: day,
        endExclusive: day.add(const Duration(days: 1)),
      );
    case StoreDashboardSegment.week:
      final day = _stripDashboardTime(reference);
      final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
      return StoreDashboardDateRange(
        start: start,
        end: start.add(const Duration(days: 6)),
        endExclusive: start.add(const Duration(days: 7)),
      );
    case StoreDashboardSegment.year:
      final day = _stripDashboardTime(reference);
      final start = DateTime(day.year, 1, 1);
      return StoreDashboardDateRange(
        start: start,
        end: day,
        endExclusive: day.add(const Duration(days: 1)),
      );
    case StoreDashboardSegment.month:
      final day = _stripDashboardTime(reference);
      final start = DateTime(day.year, day.month, 1);
      return StoreDashboardDateRange(
        start: start,
        end: day,
        endExclusive: day.add(const Duration(days: 1)),
      );
    case StoreDashboardSegment.custom:
      throw ArgumentError('Custom range requires explicit startDate and endDate.');
  }

  throw ArgumentError.value(segment, 'segment', 'Unsupported dashboard segment.');
}

DateTime _stripDashboardTime(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatDashboardDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString().padLeft(4, '0');
  return '$day-$month-$year';
}

String _formatDashboardMonthLabel(DateTime value) {
  const monthLabels = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${monthLabels[value.month - 1]} ${value.year}';
}

DateTime _minDateTime(DateTime left, DateTime right) {
  return left.isBefore(right) ? left : right;
}

bool _isDashboardInitiatedStatus(String statusName) {
  final normalized = statusName.trim().toLowerCase();
  return normalized.contains('initiated') ||
      normalized.contains('pending') ||
      normalized.contains('open');
}

bool _isDashboardPlacedStatus(String statusName) {
  final normalized = statusName.trim().toLowerCase();
  return normalized.contains('placed') || normalized.contains('accepted');
}

bool _isDashboardDeliveredStatus(String statusName) {
  final normalized = statusName.trim().toLowerCase();
  return normalized.contains('delivered') ||
      normalized.contains('complete') ||
      normalized == 'closed';
}

bool _isDashboardCancelledStatus(String statusName) {
  return statusName.trim().toLowerCase().contains('cancel');
}

bool _hasDashboardPayLater(List<StoreOrderPaymentRecord> payments) {
  for (final payment in payments) {
    if (payment.paymentMode == StoreOrderPaymentMode.credit) {
      return true;
    }
  }
  return false;
}

double _sumPaymentsByMode(
  List<StoreOrderPaymentRecord> payments,
  String paymentMode,
) {
  var total = 0.0;
  for (final payment in payments) {
    if (payment.paymentMode == paymentMode) {
      total += payment.amount;
    }
  }
  return total;
}