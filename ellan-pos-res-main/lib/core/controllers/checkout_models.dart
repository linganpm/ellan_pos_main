import 'package:pos_tablet/data/models/cart_item_model.dart';

/// A product category from the store's synced catalogue.
class PosCatalogCategory {
  final int id;
  final String name;

  const PosCatalogCategory({required this.id, required this.name});
}

/// A sellable product variant (package) from the store's synced catalogue.
class PosCatalogProduct {
  final String id;
  /// On-device SQLite local id (`pv_…`); order lines often store this even after
  /// catalogue [id] switches to exported `unique_id`.
  final String localId;
  /// Display name (package / variant preferred).
  final String name;
  /// Parent product name from catalogue.
  final String productName;
  /// Package / variant name from catalogue.
  final String packageName;
  final double price;
  final double? mrpPrice;
  final double? buyPrice;
  final String? barcode;
  final int categoryId;
  final String categoryName;
  /// Remote product-variant id when known (for offer targeting).
  final int? variantId;
  /// Measurable sell unit short label (kg, L, m) when package pricing uses unit+qty.
  final String? sellUnitShort;
  final String? sellUnitLabel;
  final double? sellUnitBaseQty;
  final int? sellUnitCode;

  const PosCatalogProduct({
    required this.id,
    this.localId = '',
    required this.name,
    this.productName = '',
    this.packageName = '',
    required this.price,
    this.mrpPrice,
    this.buyPrice,
    this.barcode,
    required this.categoryId,
    this.categoryName = '',
    this.variantId,
    this.sellUnitShort,
    this.sellUnitLabel,
    this.sellUnitBaseQty,
    this.sellUnitCode,
  });

  bool get hasSellUnit =>
      sellUnitCode != null && sellUnitShort != null && sellUnitShort!.isNotEmpty;

  String get sellUnitDetail {
    if (!hasSellUnit) return '';
    final qty = sellUnitBaseQty;
    final unit = sellUnitShort ?? '';
    if (qty == null || qty <= 0) return unit;
    final qtyLabel = qty == qty.roundToDouble()
        ? '${qty.toInt()}'
        : qty.toStringAsFixed(2);
    return '$qtyLabel $unit';
  }
}

/// The full on-device catalogue for the open store.
class PosCatalogue {
  final List<PosCatalogCategory> categories;
  final List<PosCatalogProduct> products;

  const PosCatalogue({required this.categories, required this.products});
}

/// One cart line persisted during checkout.
class CheckoutLineItem {
  final String productId;
  final String productVariantId;
  final double quantity;
  final double unitPrice;
  final double? lineTotal;
  final String? itemName;
  final List<CartAddonSelection> addons;
  /// Package size for measurable sell units (e.g. 6 for 110/6kg).
  final double? sellUnitBaseQty;
  final String? sellUnitShort;

  const CheckoutLineItem({
    required this.productId,
    required this.productVariantId,
    required this.quantity,
    required this.unitPrice,
    this.lineTotal,
    this.itemName,
    this.addons = const [],
    this.sellUnitBaseQty,
    this.sellUnitShort,
  });
}

/// One tender line applied during checkout (supports split payments).
class CheckoutPaymentLine {
  final String paymentMethod;
  final double amount;
  final String? referenceId;
  final int? creditDueInDays;
  final int? creditInstallmentCount;
  final String? creditInstallmentCadence;

  const CheckoutPaymentLine({
    required this.paymentMethod,
    required this.amount,
    this.referenceId,
    this.creditDueInDays,
    this.creditInstallmentCount,
    this.creditInstallmentCadence,
  });
}

/// Result returned after a successful checkout.
class CheckoutCompletionResult {
  final int orderId;
  final double totalPaid;
  final String paymentMode;
  final String statusName;
  final String restaurantName;
  final String paymentStatus;
  final double balanceDue;

  const CheckoutCompletionResult({
    required this.orderId,
    required this.totalPaid,
    required this.paymentMode,
    required this.statusName,
    required this.restaurantName,
    this.paymentStatus = 'Paid',
    this.balanceDue = 0,
  });
}

/// Result of a kitchen / KOT send session.
class KotSendResult {
  final int orderId;
  final int batchNumber;
  final int itemsMarked;

  const KotSendResult({
    required this.orderId,
    required this.batchNumber,
    required this.itemsMarked,
  });
}

/// One hour point in the dashboard sales trend (amount + order count).
class PosDashboardSalesPoint {
  final String label;
  final double amount;
  final int count;

  const PosDashboardSalesPoint({
    required this.label,
    required this.amount,
    this.count = 0,
  });
}

/// Count of orders for one synced / custom order type on the dashboard.
class PosDashboardOrderTypeCount {
  final String key;
  final String label;
  final int count;

  const PosDashboardOrderTypeCount({
    required this.key,
    required this.label,
    required this.count,
  });
}

/// One staff row in the dashboard sales-by-staff section.
class PosDashboardStaffSales {
  final String staffName;
  final String staffReg;
  final int orderCount;
  final double amount;
  final double creditAmount;

  const PosDashboardStaffSales({
    required this.staffName,
    this.staffReg = '',
    required this.orderCount,
    required this.amount,
    this.creditAmount = 0,
  });
}

/// Aggregated dashboard metrics built from the local POS database.
class PosDashboardSnapshot {
  final List<PosDashboardOrderTypeCount> orderTypeCounts;
  final int cancelledCount;
  final int totalOrders;
  final double totalSales;
  final double cashShare;
  final double cardShare;
  final double onlineShare;
  final double creditShare;
  final int creditCount;
  final double creditOutstandingAmount;
  final double repaymentsAmount;
  final int refundsCount;
  final double refundsAmount;
  final List<PosDashboardSalesPoint> salesPoints;
  final List<({String name, int count})> topCategories;
  final List<({String name, int count})> topProducts;
  final List<PosDashboardStaffSales> staffSales;
  final List<({String customerName, double amount, String date})> creditOrders;

  const PosDashboardSnapshot({
    this.orderTypeCounts = const [],
    required this.cancelledCount,
    required this.totalOrders,
    required this.totalSales,
    required this.cashShare,
    required this.cardShare,
    required this.onlineShare,
    required this.creditShare,
    this.creditCount = 0,
    this.creditOutstandingAmount = 0,
    this.repaymentsAmount = 0,
    this.refundsCount = 0,
    this.refundsAmount = 0,
    required this.salesPoints,
    required this.topCategories,
    this.topProducts = const [],
    this.staffSales = const [],
    required this.creditOrders,
  });

  int get dineInCount => _countForType('DINEIN');
  int get deliveryCount => _countForType('DELIVERY');
  int get pickupCount => _countForType('PICKUP');

  int _countForType(String key) {
    for (final row in orderTypeCounts) {
      if (row.key.replaceAll(RegExp(r'[^A-Z]'), '') == key) return row.count;
    }
    return 0;
  }

  factory PosDashboardSnapshot.empty() {
    return const PosDashboardSnapshot(
      orderTypeCounts: [],
      cancelledCount: 0,
      totalOrders: 0,
      totalSales: 0,
      cashShare: 0,
      cardShare: 0,
      onlineShare: 0,
      creditShare: 0,
      creditCount: 0,
      creditOutstandingAmount: 0,
      repaymentsAmount: 0,
      refundsCount: 0,
      refundsAmount: 0,
      salesPoints: [],
      topCategories: [],
      topProducts: [],
      staffSales: [],
      creditOrders: [],
    );
  }
}
