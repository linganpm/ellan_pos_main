import 'package:flutter/material.dart';
import 'package:pos_tablet/core/currency_format.dart';
import '../../../core/utils/font_utility.dart';
import '../../../data/models/cart_item_model.dart';

class BillingItemsTable extends StatelessWidget {
  final List<CartItem> items;

  /// Tighter row padding when the cart is short so the block sits at the top.
  final bool dense;

  const BillingItemsTable({
    super.key,
    required this.items,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final rowPad = dense ? 10.0 : 14.0;
    final fontSize = dense ? 14.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: dense ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'Qty',
                    style: FontUtility.subheading.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item',
                    style: FontUtility.subheading.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price',
                    textAlign: TextAlign.right,
                    style: FontUtility.subheading.copyWith(
                      fontSize: 13,
                      color: Colors.grey.shade700,
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
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowPad),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${item.quantity}x',
                        style: FontUtility.subheading.copyWith(
                          fontSize: fontSize,
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
                          style: FontUtility.body.copyWith(fontSize: fontSize),
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
    );
  }
}
