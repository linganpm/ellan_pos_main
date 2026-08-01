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

    final pad = compact ? 8.0 : 10.0;
    final nameSize = compact ? 13.5 : 15.0;
    final priceSize = compact ? 15.0 : 17.0;
    final iconSize = compact ? 16.0 : 18.0;
    final imageHeight = compact ? 42.0 : 52.0;
    final radius = compact ? 10.0 : 12.0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 0.75),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FB),
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
                    SizedBox(height: compact ? 7 : 8),
                    Text(
                      product.name,
                      style: FontUtility.subheading.copyWith(
                        fontSize: nameSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF202A35),
                        height: 1.18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 3 : 4),
                    Text(
                      priceLabel,
                      style: FontUtility.heading.copyWith(
                        fontSize: priceSize,
                        color: const Color(0xFF0B7285),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (product.offerTag != null &&
                  product.offerTag!.trim().isNotEmpty)
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
