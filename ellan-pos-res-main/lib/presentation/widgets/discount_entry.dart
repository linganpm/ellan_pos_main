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
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

/// Opens the discount picker. Percent boxes stay off the bill until this runs.
Future<void> showDiscountDialog(
  BuildContext context, {
  required CartState state,
  bool allowItemTarget = false,
  bool confirmApplied = false,
}) {
  final bloc = context.read<CartBloc>();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return BlocProvider.value(
        value: bloc,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: BlocBuilder<CartBloc, CartState>(
                builder: (context, live) {
                  return DiscountEntry(
                    state: live,
                    allowItemTarget: allowItemTarget,
                    confirmApplied: confirmApplied,
                    onClose: () => Navigator.pop(dialogContext),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Percent or a flat amount. Nothing is shown until the cashier asks for it.
class DiscountEntry extends StatefulWidget {
  final CartState state;
  final bool allowItemTarget;
  final bool confirmApplied;
  final VoidCallback? onClose;

  const DiscountEntry({
    super.key,
    required this.state,
    this.allowItemTarget = false,
    this.confirmApplied = false,
    this.onClose,
  });

  @override
  State<DiscountEntry> createState() => _DiscountEntryState();
}

class _DiscountEntryState extends State<DiscountEntry> {
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  String? _itemSignature;
  bool _flat = false;

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _apply() {
    final raw = double.tryParse(_valueController.text.trim());
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
        ? (itemName ?? context.l10n.commonDiscount)
        : typedTitle;

    if (_flat) {
      if (raw == null || raw <= 0) {
        PosToast.failed(context, detail: context.l10n.errorRequiredField);
        return;
      }
    } else if (raw == null || raw <= 0 || raw > 100) {
      PosToast.failed(context, detail: context.l10n.billingInvalidDiscountPct);
      return;
    }

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
        _flat ? 0 : raw,
        flatAmount: _flat ? raw : 0,
        title: title,
        targetLineSignature: _itemSignature,
        targetItemName: itemName,
      ),
    );
    _valueController.clear();
    if (widget.confirmApplied) {
      PosToast.success(
        context,
        detail: context.l10n.billingDiscountAdded(title),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final titleLabel =
        '${context.l10n.commonTitleLabel} (${context.l10n.commonOptional})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.billingAddDiscount,
                style: FontUtility.heading.copyWith(fontSize: 18),
              ),
            ),
            if (widget.onClose != null)
              IconButton(
                tooltip: context.l10n.actionClose,
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(context.l10n.commonPercentage),
              icon: const Icon(Icons.percent_rounded, size: 16),
            ),
            ButtonSegment(
              value: true,
              label: Text(context.l10n.commonAmount),
              icon: const Icon(Icons.payments_outlined, size: 16),
            ),
          ],
          selected: {_flat},
          onSelectionChanged: (next) => setState(() => _flat = next.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 12),
        RubberPush(
          child: TextField(
            controller: _valueController,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            style: FontUtility.heading.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: _flat
                  ? PosCurrency.symbol()
                  : context.l10n.billingPercentageHint,
              filled: true,
              fillColor: const Color(0xFFF7F8FB),
              border: PosFields.border,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        RubberPush(
          child: TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            style: FontUtility.body.copyWith(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              labelText: titleLabel,
              filled: true,
              fillColor: Colors.white,
              border: PosFields.border,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        if (widget.allowItemTarget) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _itemSignature,
            decoration: InputDecoration(
              isDense: true,
              labelText: context.l10n.billingApplyTo,
              filled: true,
              fillColor: Colors.white,
              border: PosFields.border,
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
        if (state.discounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final discount in state.discounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                discount.rateLabel(PosCurrency.format(discount.flatAmount)),
                style: FontUtility.body.copyWith(fontSize: 14),
              ),
              trailing: IconButton(
                tooltip: context.l10n.actionRemove,
                onPressed: () {
                  context.read<CartBloc>().add(
                    RemoveDiscount(discountId: discount.id),
                  );
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _apply,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1F2933),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n.billingAddDiscount),
          ),
        ),
      ],
    );
  }
}
