import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_event.dart';
import '../../bloc/cart/cart_state.dart';
import '../../core/currency_format.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import 'pos_toast.dart';

/// Percent discounts: 5, 10, 15, 25, 50, plus a box for any other percent.
/// Title is optional. An empty title is stored as the plain "Discount" label.
class DiscountEntry extends StatefulWidget {
  final CartState state;

  /// Billing can target one basket line. The order screen discounts the bill.
  final bool allowItemTarget;

  /// Billing confirms with a toast. The order screen stays quiet so Bill stays put.
  final bool confirmApplied;

  /// One-line title and a single row of percents, for the order panel.
  final bool compact;

  const DiscountEntry({
    super.key,
    required this.state,
    this.allowItemTarget = false,
    this.confirmApplied = false,
    this.compact = false,
  });

  static const presets = <int>[5, 10, 15, 25, 50];

  @override
  State<DiscountEntry> createState() => _DiscountEntryState();
}

class _DiscountEntryState extends State<DiscountEntry> {
  final _titleController = TextEditingController();
  final _customController = TextEditingController();
  String? _itemSignature;

  @override
  void dispose() {
    _titleController.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _apply(double pct) {
    if (pct <= 0 || pct > 100) {
      PosToast.failed(context, detail: context.l10n.billingInvalidDiscountPct);
      return;
    }
    final bloc = context.read<CartBloc>();
    final typedTitle = _titleController.text.trim();
    String? itemName;
    if (_itemSignature != null) {
      for (final item in widget.state.cartItems) {
        if (item.lineSignature == _itemSignature) {
          itemName = item.product.name;
          break;
        }
      }
    }
    final title = typedTitle.isEmpty
        ? (itemName == null
              ? context.l10n.commonDiscount
              : '$itemName -discount')
        : typedTitle;
    if (typedTitle.isEmpty && _itemSignature == null) {
      final defaults = {context.l10n.commonDiscount, 'Discount'};
      for (final discount in widget.state.discounts) {
        if (!discount.isItemDiscount && defaults.contains(discount.title)) {
          bloc.add(RemoveDiscount(discountId: discount.id));
        }
      }
    }
    bloc.add(
      ApplyDiscount(
        pct,
        title: title,
        targetLineSignature: _itemSignature,
        targetItemName: itemName,
      ),
    );
    _customController.clear();
    if (widget.confirmApplied) {
      PosToast.success(
        context,
        detail: context.l10n.billingDiscountAdded(title),
      );
    }
  }

  void _applyCustom() {
    final pct = double.tryParse(_customController.text.trim());
    if (pct == null) {
      PosToast.failed(context, detail: context.l10n.billingInvalidDiscountPct);
      return;
    }
    _apply(pct);
  }

  double? get _activePreset {
    for (final discount in widget.state.discounts.reversed) {
      if (discount.isItemDiscount) continue;
      final defaults = {context.l10n.commonDiscount, 'Discount'};
      if (!defaults.contains(discount.title)) continue;
      final whole = discount.percentage.roundToDouble();
      if ((discount.percentage - whole).abs() > 0.001) return null;
      if (DiscountEntry.presets.contains(whole.toInt())) return whole;
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final active = _activePreset;
    final compact = widget.compact;
    final titleLabel =
        '${context.l10n.commonTitleLabel} (${context.l10n.commonOptional})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          style: FontUtility.body.copyWith(fontSize: compact ? 13 : 14),
          decoration: InputDecoration(
            isDense: true,
            labelText: compact ? null : titleLabel,
            hintText: compact ? titleLabel : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: compact ? 8 : 12,
            ),
          ),
        ),
        if (widget.allowItemTarget) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            value: _itemSignature,
            decoration: InputDecoration(
              isDense: true,
              labelText: context.l10n.billingApplyTo,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(context.l10n.billingEntireOrder),
              ),
              for (final item in state.cartItems)
                DropdownMenuItem<String?>(
                  value: item.lineSignature,
                  child: Text(
                    '${item.product.name} · ${PosCurrency.format(item.totalPrice)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _itemSignature = value),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: _PercentBox.size + 12,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final pct in DiscountEntry.presets)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _PercentBox(
                    label: '$pct%',
                    selected: active == pct.toDouble(),
                    onTap: () => _apply(pct.toDouble()),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _PercentBox(
                  selected: false,
                  child: TextField(
                    controller: _customController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _applyCustom(),
                    style: FontUtility.subheading.copyWith(
                      fontSize: compact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              _PercentBox(
                selected: true,
                onTap: _applyCustom,
                child: const Icon(Icons.check_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
        if (state.discounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.discounts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final discount = state.discounts[index];
                return InputChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    '${discount.title} ${_fmtPct(discount.percentage)}%',
                    style: FontUtility.body.copyWith(fontSize: 12),
                  ),
                  onDeleted: () {
                    context.read<CartBloc>().add(
                      RemoveDiscount(discountId: discount.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

String _fmtPct(double pct) {
  if (pct == pct.roundToDouble()) return '${pct.toInt()}';
  return pct
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

class _PercentBox extends StatelessWidget {
  static const size = 64.0;

  final String? label;
  final Widget? child;
  final bool selected;
  final VoidCallback? onTap;

  const _PercentBox({
    this.label,
    this.child,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : const Color(0xFF1F2933);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                (selected ? const Color(0xFF4A00E0) : const Color(0xFF1B1433))
                    .withValues(alpha: selected ? 0.34 : 0.18),
            blurRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF1B1433).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: selected ? const Color(0xFF4A00E0) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child:
                child ??
                Text(
                  label ?? '',
                  style: FontUtility.subheading.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
