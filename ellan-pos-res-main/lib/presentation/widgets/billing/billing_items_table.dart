import 'package:flutter/material.dart';
import 'package:pos_tablet/core/currency_format.dart';
import '../../../core/utils/font_utility.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../core/localization/l10n_context.dart';
import '../rubber_push.dart';

String _qtyLabel(double qty) {
  final whole = qty == qty.roundToDouble();
  final count = whole ? '${qty.toInt()}' : qty.toStringAsFixed(2);
  return '$count×';
}

class BillingItemsTable extends StatelessWidget {
  final List<CartItem> items;

  /// Tighter row padding when the cart is short so the block sits at the top.
  final bool dense;

  const BillingItemsTable({super.key, required this.items, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final rowPad = narrow ? 10.0 : (dense ? 10.0 : 14.0);
    final fontSize = narrow ? 14.0 : (dense ? 15.0 : 16.0);
    final qtySize = narrow ? 16.0 : (dense ? 20.0 : 22.0);
    final horizontalPad = narrow ? 12.0 : 16.0;
    final colors = Theme.of(context).colorScheme;

    return RubberPush(
      radius: 16,
      trackFocus: false,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: dense ? 8 : 12,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      context.l10n.commonQty,
                      style: FontUtility.subheading.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      context.l10n.commonItem,
                      style: FontUtility.subheading.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      context.l10n.commonPrice,
                      textAlign: TextAlign.right,
                      style: FontUtility.subheading.copyWith(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  color: index.isOdd ? colors.surfaceContainerLow : null,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPad,
                    vertical: rowPad,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          _qtyLabel(item.quantity),
                          style: FontUtility.subheading.copyWith(
                            fontSize: qtySize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            item.addons.isEmpty
                                ? item.product.name
                                : '${item.product.name} (+${item.addons.map((a) => a.addonItemName).join(', ')})',
                            style: FontUtility.body.copyWith(
                              fontSize: fontSize,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          PosCurrency.format(item.totalPrice),
                          textAlign: TextAlign.right,
                          style: FontUtility.subheading.copyWith(
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
