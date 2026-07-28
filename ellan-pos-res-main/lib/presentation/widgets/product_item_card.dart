import 'package:flutter/material.dart';
import '../../core/currency_format.dart';
import '../../core/utils/font_utility.dart';
import '../../data/models/product_model.dart';

/// Compact catalogue tile — padding/type scale with grid density.
class ProductItemCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final bool compact;

  const ProductItemCard({
    super.key,
    required this.product,
    required this.onTap,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final priceLabel = product.hasSellUnit
        ? '${PosCurrency.format(product.price)} / '
            '${_fmtQty(product.sellUnitBaseQty ?? 1)} ${product.sellUnitShort}'
        : PosCurrency.format(product.price);

    final pad = compact ? 6.0 : 8.0;
    final nameSize = compact ? 11.0 : 12.5;
    final priceSize = compact ? 11.0 : 12.5;
    final iconSize = compact ? 20.0 : 24.0;
    final radius = compact ? 8.0 : 10.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F8),
                          borderRadius: BorderRadius.circular(radius - 2),
                        ),
                        child: product.imageUrl.trim().isEmpty
                            ? Icon(
                                Icons.inventory_2_outlined,
                                size: iconSize,
                                color: Colors.black38,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(radius - 2),
                                child: Image.network(
                                  product.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.inventory_2_outlined,
                                    size: iconSize,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      product.name,
                      style: FontUtility.subheading.copyWith(fontSize: nameSize),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 1 : 2),
                    Text(
                      priceLabel,
                      style: FontUtility.heading.copyWith(
                        fontSize: priceSize,
                        color: const Color(0xFF4A00E0),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (product.offerTag != null && product.offerTag!.trim().isNotEmpty)
                Positioned(
                  top: compact ? 3 : 4,
                  left: compact ? 3 : 4,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: compact ? 64 : 72),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 4 : 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      product.offerTag!,
                      style: FontUtility.body.copyWith(
                        color: Colors.white,
                        fontSize: compact ? 8 : 9,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtQty(double qty) {
    if (qty == qty.roundToDouble()) return '${qty.toInt()}';
    return qty
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
