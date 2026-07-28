import 'package:pos_orders_offline/pos_orders_offline.dart';

Future<int> _createDashboardOrder(
  Store store, {
  required String createdOn,
  required String statusName,
  required String orderType,
  required String customerName,
  required String customerPhone,
  required String productVariantId,
  required String productId,
  required int quantity,
  required String createdBy,
  String? paymentMode,
  String? customerId,
}) async {
  final orderId = await store.orders.create(
    store.scope,
    StoreCreateOrderRequest(
      restaurantName: store.storeName,
      customerName: customerName,
      mobile: customerPhone,
      statusName: statusName,
      total: 0,
      serviceInstance: store.serviceInstanceId,
      createdBy: createdBy,
      createdOn: createdOn,
      paymentStatus: paymentMode == null ? 'Unpaid' : 'Paid',
      orderType: orderType,
    ),
  );

  await store.orders.addItem(
    store.scope,
    StoreAddOrderItemRequest(
      orderId: orderId,
      productVariantId: productVariantId,
      productId: productId,
      quantity: quantity,
      createdBy: createdBy,
      createdOn: createdOn,
    ),
  );

  if (paymentMode != null) {
    final details = await store.orders.details(store.scope, orderId);
    if (details == null) {
      throw StateError('Unable to load order details for dashboard example.');
    }

    await store.orders.addPayment(
      store.scope,
      orderId,
      StoreCreateOrderPaymentRequest(
        paymentMode: paymentMode,
        amount: details.total,
        customerId: paymentMode == StoreOrderPaymentMode.credit ? customerId : null,
        referenceId: 'dashboard-$paymentMode-$orderId',
        createdOn: createdOn,
        updatedOn: createdOn,
      ),
    );

    if (paymentMode == StoreOrderPaymentMode.credit) {
      if (customerId == null || customerId.isEmpty) {
        throw ArgumentError('customerId is required for credit dashboard examples.');
      }
      await store.credits.create(
        store.scope,
        StoreCreateCreditRequest(
          orgId: store.orgId,
          customerId: customerId,
          orderId: orderId,
          amount: details.total,
          createdOn: createdOn,
          updatedOn: createdOn,
        ),
      );
    }
  }

  return orderId;
}

void _printStatistics(String title, StoreDashboardStatisticsResult result) {
  print(title);
  print('Dashboard statistics status: ${result.status}');
  print('Granularity: ${result.data.granularity}');
  print('Total orders: ${result.data.totalCount}');
  print('Total sales: ${result.data.totalAmount.toStringAsFixed(2)}');
  print(
    'Breakdown: dine-in=${result.data.totalCountByDineIn}, '
    'delivery=${result.data.totalCountByDelivery}, '
    'pickup=${result.data.totalCountByPickup}, '
    'cancelled=${result.data.totalCountByCancelled}',
  );
  print(
    'Payments: cash=${result.data.totalAmountByCash.toStringAsFixed(2)}, '
    'card=${result.data.totalAmountByCard.toStringAsFixed(2)}, '
    'online=${result.data.totalAmountByOnline.toStringAsFixed(2)}, '
    'pay-later=${result.data.totalAmountByPayLater.toStringAsFixed(2)}',
  );

  print('Buckets:');
  for (final row in result.data.data) {
    if (row.count == 0 && row.amount == 0) {
      continue;
    }
    print(
      '  ${row.date}: orders=${row.count} amount=${row.amount.toStringAsFixed(2)} '
      'delivery=${row.countByDelivery} pickup=${row.countByPickup} '
      'dineIn=${row.countByDineIn}',
    );
  }
  print('');
}

void _printSnapshot(StoreDashboardSnapshot snapshot) {
  print('');
  print('Snapshot generated at ${snapshot.generatedAt.toIso8601String()}');
  print(
    'Range: ${snapshot.range.start.toIso8601String()} '
    'to ${snapshot.range.end.toIso8601String()}',
  );
  print(
    'Credit summary: customers=${snapshot.creditSummary.customerCount} '
    'outstanding=${snapshot.creditSummary.outstandingAmount.toStringAsFixed(2)}',
  );

  print('Top categories:');
  if (snapshot.topCategories.isEmpty) {
    print('  No category sales found.');
  } else {
    for (final category in snapshot.topCategories) {
      print('  ${category.categoryName}: qty=${category.soldQuantity}');
    }
  }

  print('Top products:');
  if (snapshot.topProducts.isEmpty) {
    print('  No product sales found.');
  } else {
    for (final product in snapshot.topProducts) {
      print('  ${product.displayName}: qty=${product.soldQuantity}');
    }
  }
}

Future<void> main() async {
  final config = await StoreConfig.loadForEnvironment(StoreEnvironment.test);
  final metadata = config.testStore ?? StoreConfig.defaultTestStoreMetadata;
  final store = await Store.createInMemory(
    orgId: metadata.orgId,
    orgName: metadata.orgName,
    orgCode: metadata.orgCode,
    storeId: metadata.storeId,
    serviceInstanceId: metadata.serviceInstanceId,
    storeName: metadata.storeName,
    logo: metadata.logo,
    uniqueId: metadata.uniqueId,
    contactEmail: metadata.contactEmail,
    phone: metadata.phone,
    contactPerson: metadata.contactPerson,
    status: metadata.status,
    serviceVariantType: metadata.serviceVariantType,
    // orderJson, productJson, customerJson removed: use only API sync
    config: config,
  );

  try {
    final session = await store.auth.login(
      store.scope,
      const StoreLoginRequest(
        email: 'charlie@example.com',
        password: 'charliepass',
      ),
    );
    if (session == null) {
      throw StateError('Admin login failed for dashboard service example.');
    }

    final customerId = await store.customers.create(
      const StoreCreateCustomerRequest(
        name: 'Dashboard Credit Customer',
        email: 'dashboard-credit@example.com',
        phone: '+6500000100',
        country: 'Singapore',
        status: 'active',
        role: 'member',
        password: 'demo123',
      ),
    );

    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));

    final januaryDate = DateTime(now.year, 1, 15, 11, 0);
    final februaryDate = DateTime(now.year, 2, 20, 13, 30);
    final monthDate = DateTime(now.year, now.month, 2, 10, 30);
    final secondMonthDate = DateTime(now.year, now.month, 4, 12, 15);
    final mondayThisWeek = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
      9,
      0,
    );
    final wednesdayThisWeek = mondayThisWeek.add(
      const Duration(days: 2, hours: 9),
    );
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1)).add(const Duration(hours: 10));
    final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
    final todayAfternoon = DateTime(now.year, now.month, now.day, 14, 0);

    await _createDashboardOrder(
      store,
      createdOn: januaryDate.toIso8601String(),
      statusName: 'Delivered',
      orderType: StoreOrderType.delivery,
      customerName: 'January Customer',
      customerPhone: '+6500000009',
      productVariantId: 'var_39',
      productId: 'prod_39',
      quantity: 1,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.cash,
    );

    await _createDashboardOrder(
      store,
      createdOn: februaryDate.toIso8601String(),
      statusName: 'Closed',
      orderType: StoreOrderType.pickUp,
      customerName: 'February Customer',
      customerPhone: '+6500000008',
      productVariantId: 'var_40',
      productId: 'prod_40',
      quantity: 2,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.card,
    );

    await _createDashboardOrder(
      store,
      createdOn: monthDate.toIso8601String(),
      statusName: 'Delivered',
      orderType: StoreOrderType.delivery,
      customerName: 'Delivery Customer',
      customerPhone: '+6500000001',
      productVariantId: 'var_39',
      productId: 'prod_39',
      quantity: 2,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.cash,
    );

    await _createDashboardOrder(
      store,
      createdOn: secondMonthDate.toIso8601String(),
      statusName: 'Closed',
      orderType: StoreOrderType.pickUp,
      customerName: 'Pickup Customer',
      customerPhone: '+6500000002',
      productVariantId: 'var_40',
      productId: 'prod_40',
      quantity: 1,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.card,
    );

    await _createDashboardOrder(
      store,
      createdOn: mondayThisWeek.toIso8601String(),
      statusName: 'Delivered',
      orderType: StoreOrderType.dineIn,
      customerName: 'Monday Customer',
      customerPhone: '+6500000007',
      productVariantId: 'var_39',
      productId: 'prod_39',
      quantity: 1,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.cash,
    );

    await _createDashboardOrder(
      store,
      createdOn: wednesdayThisWeek.toIso8601String(),
      statusName: 'Delivered',
      orderType: StoreOrderType.delivery,
      customerName: 'Wednesday Customer',
      customerPhone: '+6500000006',
      productVariantId: 'var_40',
      productId: 'prod_40',
      quantity: 2,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.online,
    );

    await _createDashboardOrder(
      store,
      createdOn: yesterday.toIso8601String(),
      statusName: 'Pending',
      orderType: StoreOrderType.dineIn,
      customerName: 'Dine-in Customer',
      customerPhone: '+6500000003',
      productVariantId: 'var_39',
      productId: 'prod_39',
      quantity: 3,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.credit,
      customerId: customerId,
    );

    await _createDashboardOrder(
      store,
      createdOn: todayMorning.toIso8601String(),
      statusName: 'Delivered',
      orderType: StoreOrderType.delivery,
      customerName: 'Today Cash Customer',
      customerPhone: '+6500000005',
      productVariantId: 'var_40',
      productId: 'prod_40',
      quantity: 1,
      createdBy: 'dashboard-example',
      paymentMode: StoreOrderPaymentMode.cash,
    );

    await _createDashboardOrder(
      store,
      createdOn: todayAfternoon.toIso8601String(),
      statusName: 'Cancelled',
      orderType: StoreOrderType.delivery,
      customerName: 'Cancelled Customer',
      customerPhone: '+6500000004',
      productVariantId: 'var_40',
      productId: 'prod_40',
      quantity: 1,
      createdBy: 'dashboard-example',
    );

    // final todayStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.day,
    //   referenceDate: now,
    // );
    // _printStatistics('Today example (hourly, 24 buckets)', todayStatistics);
    //
    // final yesterdayStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.day,
    //   referenceDate: yesterday,
    // );
    // _printStatistics(
    //   'Yesterday example (hourly, 24 buckets)',
    //   yesterdayStatistics,
    // );

    // final weeklyStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.week,
    //   referenceDate: now,
    // );
    // _printStatistics('Week example (day-wise, 7 buckets)', weeklyStatistics);
    //
    // final monthlyStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.month,
    //   referenceDate: now,
    // );
    // _printStatistics('Month example (week-wise buckets)', monthlyStatistics);
    //
    // final yearlyStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.year,
    //   referenceDate: now,
    // );
    // _printStatistics('Year example (month-wise buckets)', yearlyStatistics);
    //
    // final customSingleDayStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.custom,
    //   startDate: DateTime(now.year, now.month, now.day),
    //   endDate: DateTime(now.year, now.month, now.day),
    // );
    // _printStatistics(
    //   'Custom one-day example (hourly buckets)',
    //   customSingleDayStatistics,
    // );
    //
    // final customRangeStatistics = await store.dashboard.orderStatisticsGraph(
    //   store.scope,
    //   segment: StoreDashboardSegment.custom,
    //   startDate: DateTime(now.year, now.month, 1),
    //   endDate: DateTime(now.year, now.month, now.day),
    // );
    // _printStatistics(
    //   'Custom multi-day example (adaptive buckets)',
    //   customRangeStatistics,
    // );
    //
    // final monthlySnapshot = await store.dashboard.snapshot(
    //   store.scope,
    //   segment: StoreDashboardSegment.month,
    //   referenceDate: now,
    //   topLimit: 3,
    // );
    // _printSnapshot(monthlySnapshot);
  } finally {
    await store.auth.logout();
    await store.close();
  }
}