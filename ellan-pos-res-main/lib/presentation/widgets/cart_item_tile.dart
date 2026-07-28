import 'package:flutter/material.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/sell_unit.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/data/models/cart_item_model.dart';

class CartItemTile extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback? onRemove;
  final bool isReadOnly;

  const CartItemTile({
    super.key,
    required this.cartItem,
    this.onIncrease,
    this.onDecrease,
    this.onRemove,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final unitPrice = cartItem.product.price;
    final hasImage = cartItem.product.imageUrl.trim().isNotEmpty;
    final qtyLabel = cartItem.sellUnit == null
        ? '${cartItem.quantity == cartItem.quantity.roundToDouble() ? cartItem.quantity.toInt() : cartItem.quantity}'
        : formatSellQtyWithUnit(cartItem.quantity, cartItem.sellUnit);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isReadOnly) ...[
            _QtyControls(
              qtyLabel: qtyLabel,
              onDecrease: onDecrease,
              onIncrease: onIncrease,
            ),
            const SizedBox(width: 10),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                qtyLabel,
                style: FontUtility.subheading.copyWith(fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
          ],
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                cartItem.product.imageUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  color: Colors.grey.shade100,
                  child: const Icon(Icons.fastfood, size: 16, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cartItem.product.name,
                  style: FontUtility.subheading.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cartItem.sellUnit == null
                      ? PosCurrency.format(unitPrice)
                      : '${PosCurrency.format(unitPrice)} / '
                          '${formatSellQty(cartItem.sellUnit!.baseQty)} '
                          '${cartItem.sellUnit!.unitShort}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                if (cartItem.addons.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final addon in cartItem.addons)
                    Text(
                      '+ ${addon.addonItemName}'
                      '${addon.quantity > 1 ? ' ×${addon.quantity}' : ''}'
                      '  ${PosCurrency.format(addon.unitPrice * addon.quantity)}',
                      style: FontUtility.body.copyWith(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
                if (cartItem.kotSentQuantity > 0.0001) ...[
                  const SizedBox(height: 4),
                  Text(
                    'KOT ${formatSellQty(cartItem.kotSentQuantity)}'
                    '${cartItem.kotSentQuantity + 0.0001 < cartItem.quantity ? ' · pending more' : ''}',
                    style: FontUtility.body.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PosCurrency.format(cartItem.totalPrice),
                style: FontUtility.heading.copyWith(
                  fontSize: 15,
                  color: const Color(0xFF4A00E0),
                ),
              ),
              if (!isReadOnly) ...[
                const SizedBox(height: 6),
                Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 24,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyControls extends StatelessWidget {
  final String qtyLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  const _QtyControls({
    required this.qtyLabel,
    this.onDecrease,
    this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TapBtn(
            icon: Icons.remove_rounded,
            onTap: onDecrease,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 48,
              child: Text(
                qtyLabel,
                textAlign: TextAlign.center,
                style: FontUtility.subheading.copyWith(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _TapBtn(
            icon: Icons.add_rounded,
            color: const Color(0xFF4A00E0),
            onTap: onIncrease,
          ),
        ],
      ),
    );
  }
}

class _TapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _TapBtn({
    required this.icon,
    this.onTap,
    this.color = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 44,
          child: Icon(icon, size: 26, color: color),
        ),
      ),
    );
  }
}
