import 'package:equatable/equatable.dart';

/// One named discount line on the cart (order-level or tied to a basket item).
class CartDiscountLine extends Equatable {
  final String id;
  final String title;
  final double percentage;
  /// When set, discount applies to that cart line only.
  final String? targetLineSignature;
  final String? targetItemName;

  const CartDiscountLine({
    required this.id,
    required this.title,
    required this.percentage,
    this.targetLineSignature,
    this.targetItemName,
  });

  bool get isItemDiscount =>
      targetLineSignature != null && targetLineSignature!.isNotEmpty;

  CartDiscountLine copyWith({
    String? id,
    String? title,
    double? percentage,
    String? targetLineSignature,
    String? targetItemName,
  }) {
    return CartDiscountLine(
      id: id ?? this.id,
      title: title ?? this.title,
      percentage: percentage ?? this.percentage,
      targetLineSignature: targetLineSignature ?? this.targetLineSignature,
      targetItemName: targetItemName ?? this.targetItemName,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, percentage, targetLineSignature, targetItemName];
}
