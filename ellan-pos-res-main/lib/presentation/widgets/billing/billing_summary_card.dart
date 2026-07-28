import 'package:flutter/material.dart';
import '../../../core/currency_format.dart';
import '../../../core/utils/font_utility.dart';
import '../../../data/models/cart_discount_line.dart';

class BillingSummaryCard extends StatelessWidget {
  final double subTotal;
  final double deliveryCharge;
  final List<CartDiscountLine> discounts;
  final Map<String, double> discountAmounts;
  final double offerAppliedAmount;
  final List<String> offerLabels;
  final double serviceTaxValue;
  final double serviceTaxPercentage;
  final double tipsAmount;
  final double netTotal;

  const BillingSummaryCard({
    super.key,
    required this.subTotal,
    required this.deliveryCharge,
    this.discounts = const [],
    this.discountAmounts = const {},
    this.offerAppliedAmount = 0,
    this.offerLabels = const [],
    required this.serviceTaxValue,
    required this.serviceTaxPercentage,
    this.tipsAmount = 0,
    required this.netTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRow('Subtotal', PosCurrency.format(subTotal)),
          if (deliveryCharge > 0.0001) ...[
            const SizedBox(height: 12),
            _buildRow('Delivery Charge', PosCurrency.format(deliveryCharge)),
          ],
          if (offerAppliedAmount > 0.0001) ...[
            const SizedBox(height: 12),
            _buildRow(
              offerLabels.isEmpty
                  ? 'Offer applied'
                  : 'Offer · ${offerLabels.take(2).join(', ')}',
              '-${PosCurrency.format(offerAppliedAmount)}',
              color: Colors.green.shade700,
            ),
          ],
          for (final discount in discounts) ...[
            const SizedBox(height: 12),
            _buildRow(
              '${discount.title} (${discount.percentage.toStringAsFixed(0)}%)',
              '-${PosCurrency.format(discountAmounts[discount.id] ?? 0)}',
              color: Colors.green.shade700,
            ),
          ],
          if (serviceTaxPercentage > 0) ...[
            const SizedBox(height: 12),
            _buildRow(
              'Service Tax (${serviceTaxPercentage.toStringAsFixed(1)}%)',
              '+${PosCurrency.format(serviceTaxValue)}',
              color: Colors.orange.shade700,
            ),
          ],
          if (tipsAmount > 0) ...[
            const SizedBox(height: 12),
            _buildRow(
              'Tips',
              '+${PosCurrency.format(tipsAmount)}',
              color: Colors.blue.shade700,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(thickness: 1.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Total',
                style: FontUtility.heading
                    .copyWith(fontSize: 24, color: Colors.black87),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A00E0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  PosCurrency.format(netTotal),
                  style: FontUtility.heading.copyWith(
                    fontSize: 28,
                    color: const Color(0xFF4A00E0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String title, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: FontUtility.body.copyWith(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: FontUtility.subheading.copyWith(
            fontSize: 16,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
