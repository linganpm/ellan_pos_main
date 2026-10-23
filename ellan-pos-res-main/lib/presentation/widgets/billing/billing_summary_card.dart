import 'package:flutter/material.dart';
import '../../../core/currency_format.dart';
import '../../../core/utils/font_utility.dart';
import '../../../data/models/cart_discount_line.dart';
import '../../../core/localization/l10n_context.dart';

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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRow(context.l10n.commonSubtotal, PosCurrency.format(subTotal)),
          if (deliveryCharge > 0.0001) ...[
            const SizedBox(height: 12),
            _buildRow(
              context.l10n.commonDeliveryCharge,
              PosCurrency.format(deliveryCharge),
            ),
          ],
          if (offerAppliedAmount > 0.0001) ...[
            const SizedBox(height: 12),
            _buildRow(
              offerLabels.isEmpty
                  ? context.l10n.commonOfferApplied
                  : context.l10n.commonOfferLabel(
                      offerLabels.take(2).join(', '),
                    ),
              '-${PosCurrency.format(offerAppliedAmount)}',
              color: Colors.green.shade700,
            ),
          ],
          for (final discount in discounts) ...[
            const SizedBox(height: 12),
            _buildRow(
              discount.rateLabel(PosCurrency.format(discount.flatAmount)),
              '-${PosCurrency.format(discountAmounts[discount.id] ?? 0)}',
              color: Colors.green.shade700,
            ),
          ],
          if (serviceTaxPercentage > 0) ...[
            const SizedBox(height: 12),
            _buildRow(
              context.l10n.commonServiceTaxPct(
                serviceTaxPercentage.toStringAsFixed(1),
              ),
              '+${PosCurrency.format(serviceTaxValue)}',
              color: Colors.orange.shade700,
            ),
          ],
          if (tipsAmount > 0) ...[
            const SizedBox(height: 12),
            _buildRow(
              context.l10n.commonTips,
              '+${PosCurrency.format(tipsAmount)}',
              color: Colors.blue.shade700,
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(thickness: 1.5),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  context.l10n.commonNetTotal,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtility.heading.copyWith(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      PosCurrency.format(netTotal),
                      style: FontUtility.heading.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2933),
                      ),
                    ),
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
