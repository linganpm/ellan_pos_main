import 'package:equatable/equatable.dart';

/// One named discount line on the cart (order-level or tied to a basket item).
class CartDiscountLine extends Equatable {
  final String id;
  final String title;
  final double percentage;

  /// Set when the cashier entered a currency amount instead of a percent.
  final double flatAmount;

  /// When set, discount applies to that cart line only.
  final String? targetLineSignature;
  final String? targetItemName;

  const CartDiscountLine({
    required this.id,
    required this.title,
    required this.percentage,
    this.flatAmount = 0,
    this.targetLineSignature,
    this.targetItemName,
  });

  bool get isItemDiscount =>
      targetLineSignature != null && targetLineSignature!.isNotEmpty;

  bool get isFlat => flatAmount > 0.0001;

  /// [formattedFlat] is the currency string for a flat discount.
  String rateLabel(String formattedFlat) {
    if (isFlat) return '$title ($formattedFlat)';
    final whole = percentage.roundToDouble();
    final pct = (percentage - whole).abs() < 0.001
        ? '${whole.toInt()}'
        : percentage.toStringAsFixed(2);
    return '$title ($pct%)';
  }

  CartDiscountLine copyWith({
    String? id,
    String? title,
    double? percentage,
    double? flatAmount,
    String? targetLineSignature,
    String? targetItemName,
  }) {
    return CartDiscountLine(
      id: id ?? this.id,
      title: title ?? this.title,
      percentage: percentage ?? this.percentage,
      flatAmount: flatAmount ?? this.flatAmount,
      targetLineSignature: targetLineSignature ?? this.targetLineSignature,
      targetItemName: targetItemName ?? this.targetItemName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    percentage,
    flatAmount,
    targetLineSignature,
    targetItemName,
  ];
}
