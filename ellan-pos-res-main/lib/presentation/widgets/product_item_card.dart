import 'package:flutter/material.dart';
import '../../core/currency_format.dart';
import '../../core/utils/font_utility.dart';
import '../../data/models/product_model.dart';
import 'product_image.dart';

/// Catalogue tile — padding/type scale with grid density.
class ProductItemCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final bool compact;

  /// Quantity of this item already in the current order (0 hides the badge).
  final double cartQuantity;

  const ProductItemCard({
    super.key,
    required this.product,
    required this.onTap,
    this.compact = true,
    this.cartQuantity = 0,
  });

  static const _palette = <Color>[
    Color(0xFF4A00E0),
    Color(0xFF0B7285),
    Color(0xFFE8590C),
    Color(0xFF2B8A3E),
    Color(0xFFC2255C),
    Color(0xFF1971C2),
    Color(0xFF9C36B5),
    Color(0xFFB08900),
  ];

  /// Stable per-product accent so the same item always gets the same colour.
  static Color accentFor(String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  State<ProductItemCard> createState() => _ProductItemCardState();
}

class _ProductItemCardState extends State<ProductItemCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final compact = widget.compact;
    final title = product.productName.isNotEmpty
        ? product.productName
        : product.name;
    final variant =
        product.productName.isNotEmpty &&
            product.variantName.toLowerCase() != title.toLowerCase()
        ? product.variantName
        : '';
    final accent = ProductItemCard.accentFor(
      product.name.trim().isEmpty ? product.id : product.name,
    );
    final inCart = widget.cartQuantity > 0;
    final priceLabel = product.hasSellUnit
        ? '${PosCurrency.format(product.price)} / '
              '${_fmtQty(product.sellUnitBaseQty ?? 1)} ${product.sellUnitShort}'
        : PosCurrency.format(product.price);

    final pad = compact ? 10.0 : 14.0;
    final nameSize = compact ? 16.0 : 18.0;
    final priceSize = compact ? 14.0 : 16.0;
    final radius = compact ? 18.0 : 22.0;
    final onPhoto = product.imageUrl.trim().isNotEmpty;

    return AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: inCart ? accent : const Color(0xFFE6E8EE),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(radius),
            splashColor: accent.withValues(alpha: 0.12),
            highlightColor: accent.withValues(alpha: 0.05),
            child: LayoutBuilder(
              builder: (context, box) {
                // Short tiles drop the artwork so name and price never clip.
                final extraHeight = variant.isNotEmpty ? 20 : 0;
                final tight = variant.isNotEmpty && box.maxHeight < 104;
                final showArt =
                    box.maxHeight >= (compact ? 104 : 118) + extraHeight;
                final nameLines =
                    box.maxHeight >= (compact ? 104 : 124) + extraHeight
                    ? 2
                    : 1;
                final name = Text(
                  title,
                  style: FontUtility.subheading.copyWith(
                    fontSize: tight ? 13 : nameSize,
                    fontWeight: FontWeight.w700,
                    color: onPhoto ? Colors.white : const Color(0xFF1F2933),
                    height: 1.15,
                    shadows: onPhoto
                        ? const [
                            Shadow(color: Color(0x99000000), blurRadius: 8),
                          ]
                        : null,
                  ),
                  maxLines: nameLines,
                  overflow: TextOverflow.ellipsis,
                );
                final details = <Widget>[
                  name,
                  SizedBox(height: tight ? 2 : (compact ? 5 : 6)),
                  if (variant.isNotEmpty) ...[
                    Text(
                      variant,
                      style: FontUtility.body.copyWith(
                        fontSize: tight ? 11 : (compact ? 13 : 15),
                        height: 1.15,
                        color: onPhoto ? Colors.white : accent,
                        fontWeight: FontWeight.w700,
                        shadows: onPhoto
                            ? const [
                                Shadow(color: Color(0x99000000), blurRadius: 8),
                              ]
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: tight ? 2 : 4),
                  ],
                  _priceRow(
                    priceLabel,
                    accent,
                    tight ? 12 : priceSize,
                    tight || compact,
                    chipColor: onPhoto ? Colors.white : null,
                  ),
                ];
                if (onPhoto) {
                  return _photoFill(
                    radius: radius,
                    compact: compact,
                    accent: accent,
                    padding: EdgeInsets.all(tight ? 3 : pad),
                    details: details,
                  );
                }
                return Padding(
                  padding: EdgeInsets.all(tight ? 3 : pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showArt) ...[
                        Expanded(child: _artwork(accent, radius - 5, compact)),
                        SizedBox(height: compact ? 6 : 8),
                      ] else
                        _inlineHeader(accent, compact),
                      if (showArt)
                        name
                      else
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: name,
                          ),
                        ),
                      ...details.skip(1),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Product photo painted edge to edge, stretched to the card box.
  Widget _photoFill({
    required double radius,
    required bool compact,
    required Color accent,
    required EdgeInsets padding,
    required List<Widget> details,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProductImage(
            source: widget.product.imageUrl,
            fit: BoxFit.fill,
            iconSize: compact ? 28 : 32,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x401B1433),
                ],
                stops: [0.0, 0.58, 1.0],
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x591B1433),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: details,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_offerTag != null)
            Positioned(
              top: 4,
              left: 4,
              right: widget.cartQuantity > 0 ? (compact ? 38 : 44) : 4,
              child: Align(
                alignment: Alignment.topLeft,
                child: _offerChip(compact),
              ),
            ),
          if (widget.cartQuantity > 0)
            Positioned(top: 4, right: 4, child: _qtyBadge(accent, compact)),
        ],
      ),
    );
  }

  Widget _artwork(Color accent, double radius, bool compact) {
    final product = widget.product;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Text(
                _initials(product.name),
                style: FontUtility.heading.copyWith(
                  fontSize: compact ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: accent.withValues(alpha: 0.75),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          if (_offerTag != null)
            Positioned(
              top: 4,
              left: 4,
              right: widget.cartQuantity > 0 ? (compact ? 38 : 44) : 4,
              child: Align(
                alignment: Alignment.topLeft,
                child: _offerChip(compact),
              ),
            ),
          if (widget.cartQuantity > 0)
            Positioned(top: 4, right: 4, child: _qtyBadge(accent, compact)),
        ],
      ),
    );
  }

  Widget _inlineHeader(Color accent, bool compact) {
    if (_offerTag == null && widget.cartQuantity <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (_offerTag != null) Flexible(child: _offerChip(compact)),
          const Spacer(),
          if (widget.cartQuantity > 0) _qtyBadge(accent, compact),
        ],
      ),
    );
  }

  Widget _priceRow(
    String label,
    Color accent,
    double size,
    bool compact, {
    Color? chipColor,
  }) {
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 7 : 8,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: chipColor ?? accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: FontUtility.heading.copyWith(
                fontSize: size,
                color: accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String? get _offerTag {
    final tag = widget.product.offerTag?.trim() ?? '';
    return tag.isEmpty ? null : tag;
  }

  Widget _offerChip(bool compact) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 70 : 84),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5F6D), Color(0xFFE03131)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_offer_rounded,
            size: compact ? 9 : 10,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              _offerTag!,
              style: FontUtility.body.copyWith(
                color: Colors.white,
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBadge(Color accent, bool compact) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(widget.cartQuantity),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7, vertical: 2),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '×${_fmtQty(widget.cartQuantity)}',
          style: FontUtility.body.copyWith(
            color: Colors.white,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '•';
    final first = words.first.characters.first;
    final second = words.length > 1 ? words[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  String _fmtQty(double qty) {
    if (qty == qty.roundToDouble()) return '${qty.toInt()}';
    return qty
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
