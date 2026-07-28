class OrderListModel {
  final String id;
  final String orderId;
  final String orderType;
  /// Normalized backend key used for type filters (e.g. PICKUP, DINEIN).
  final String orderTypeKey;
  final String? floorName;
  final String? tableNumber;
  final String customerName;
  final String? phoneNumber;
  final String? email;
  /// Links this row to a directory customer (`user_{id}`).
  final String? customerUniqueId;

  /// Actual order (sale) time recorded on the device — never the sync time.
  final DateTime timestamp;
  final String orderStatus;
  final String paymentStatus; // Paid, Unpaid
  final int itemCount;
  final double totalAmount;
  final double paidTotal;

  /// 4-digit organisation POS code shown under the order id.
  final String? posCode;

  /// True once this order has been uploaded to the remote backend.
  final bool syncedToRemote;

  /// Rotating kitchen/serve reference (10–99).
  final int? serveNumber;

  const OrderListModel({
    required this.id,
    required this.orderId,
    required this.orderType,
    this.orderTypeKey = '',
    this.floorName,
    this.tableNumber,
    required this.customerName,
    this.phoneNumber,
    this.email,
    this.customerUniqueId,
    required this.timestamp,
    required this.orderStatus,
    required this.paymentStatus,
    required this.itemCount,
    required this.totalAmount,
    this.paidTotal = 0,
    this.posCode,
    this.syncedToRemote = false,
    this.serveNumber,
  });

  double get balanceDue {
    final due = totalAmount - paidTotal;
    return due <= 0 ? 0 : double.parse(due.toStringAsFixed(2));
  }

  bool get isDineIn {
    final key = orderTypeKey.replaceAll(RegExp(r'[^A-Z]'), '');
    return key == 'DINEIN' || orderType.toLowerCase().contains('dine');
  }

  String get formattedTableInfo {
    if (isDineIn && floorName != null && tableNumber != null) {
      return '$floorName - Table $tableNumber';
    }
    return '';
  }
}
