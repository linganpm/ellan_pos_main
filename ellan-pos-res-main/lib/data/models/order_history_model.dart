import 'cart_item_model.dart';

class OrderHistoryModel {
  final String id;
  final int? orderId;
  final int? kotBatch;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime timestamp;

  const OrderHistoryModel({
    required this.id,
    this.orderId,
    this.kotBatch,
    required this.items,
    required this.totalAmount,
    required this.timestamp,
  });
}
