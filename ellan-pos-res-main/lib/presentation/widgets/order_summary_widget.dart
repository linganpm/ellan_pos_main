import 'package:flutter/material.dart';
import '../../core/currency_format.dart';
import '../../core/utils/font_utility.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/cart_discount_line.dart';

class OrderSummaryWidget extends StatelessWidget {
  final double subTotal;
  final double deliveryCharge;
  final double netTotal;
  final List<CartDiscountLine> discounts;
  final Map<String, double> discountAmounts;
  final double offerAppliedAmount;
  final List<String> offerLabels;
  final double serviceTaxValue;
  final double serviceTaxPercentage;
  final double tipsAmount;
  final List<CartItem> cartItems;

  const OrderSummaryWidget({
    super.key,
    required this.subTotal,
    required this.deliveryCharge,
    required this.netTotal,
    this.discounts = const [],
    this.discountAmounts = const {},
    this.offerAppliedAmount = 0,
    this.offerLabels = const [],
    this.serviceTaxValue = 0,
    this.serviceTaxPercentage = 0,
    this.tipsAmount = 0,
    this.cartItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: constraints.maxWidth.isFinite
                  ? (constraints.maxWidth - 32).clamp(200.0, 600.0)
                  : 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryRow('Sub Total', PosCurrency.format(subTotal)),
                  if (deliveryCharge > 0.0001) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Delivery Charge',
                      PosCurrency.format(deliveryCharge),
                    ),
                  ],
                  if (offerAppliedAmount > 0.0001) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      offerLabels.isEmpty
                          ? 'Offer applied'
                          : 'Offer · ${offerLabels.take(2).join(', ')}',
                      '-${PosCurrency.format(offerAppliedAmount)}',
                      color: Colors.green.shade700,
                    ),
                  ],
                  for (final discount in discounts) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      '${discount.title} (${discount.percentage.toStringAsFixed(0)}%)',
                      '-${PosCurrency.format(discountAmounts[discount.id] ?? 0)}',
                      color: Colors.green.shade700,
                    ),
                  ],
                  if (serviceTaxPercentage > 0.0001) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Service Tax (${serviceTaxPercentage.toStringAsFixed(0)}%)',
                      '+${PosCurrency.format(serviceTaxValue)}',
                      color: Colors.orange.shade700,
                    ),
                  ],
                  if (tipsAmount > 0.0001) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'Tips',
                      '+${PosCurrency.format(tipsAmount)}',
                      color: Colors.blue.shade700,
                    ),
                  ],
                  if (_addonLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Add-ons',
                      style: FontUtility.body.copyWith(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final line in _addonLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          line,
                          style: FontUtility.body.copyWith(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Net Total',
                        style: FontUtility.heading.copyWith(fontSize: 16),
                      ),
                      Text(
                        PosCurrency.format(netTotal),
                        style: FontUtility.heading.copyWith(
                          fontSize: 20,
                          color: const Color(0xFF4A00E0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> get _addonLines {
    final lines = <String>[];
    for (final item in cartItems) {
      if (item.addons.isEmpty) continue;
      final addons = item.addons
          .map((a) => '${a.addonItemName} ×${a.quantity}')
          .join(', ');
      lines.add('${item.product.name}: $addons');
    }
    return lines;
  }

  Widget _buildSummaryRow(String title, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: FontUtility.body.copyWith(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: FontUtility.subheading.copyWith(
            fontSize: 14,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
