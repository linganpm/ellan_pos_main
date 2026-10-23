import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

class OrderAddPaymentResult {
  final double amount;
  final String paymentMode;
  final String paymentLabel;
  final String? referenceId;

  const OrderAddPaymentResult({
    required this.amount,
    required this.paymentMode,
    required this.paymentLabel,
    this.referenceId,
  });
}

/// Captures a (possibly partial) tender for an order — used at checkout and
/// when recording payment against an existing unpaid/partial order.
class OrderAddPaymentDialog extends StatefulWidget {
  final double remainingAmount;
  final String paymentMode;
  final String paymentLabel;
  final String? title;
  final String? confirmLabel;
  final bool showModePicker;
  final List<({String mode, String label})> modeOptions;

  const OrderAddPaymentDialog({
    super.key,
    required this.remainingAmount,
    required this.paymentMode,
    required this.paymentLabel,
    this.title,
    this.confirmLabel,
    this.showModePicker = false,
    this.modeOptions = const [],
  });

  @override
  State<OrderAddPaymentDialog> createState() => _OrderAddPaymentDialogState();
}

class _OrderAddPaymentDialogState extends State<OrderAddPaymentDialog> {
  static const _tenderPresets = [5.0, 10.0, 20.0, 50.0, 100.0];

  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late String _paymentMode;
  late String _paymentLabel;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remainingAmount.toStringAsFixed(2),
    );
    _referenceController = TextEditingController();
    _paymentMode = widget.paymentMode;
    _paymentLabel = widget.paymentLabel;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _setAmount(double value) {
    final capped = value > widget.remainingAmount
        ? widget.remainingAmount
        : value;
    _amountController.text = capped.toStringAsFixed(2);
    setState(() {});
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.amountGreaterThanZero)),
      );
      return;
    }
    if (amount - widget.remainingAmount > 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.billingAmountExceedsRemaining(
              PosCurrency.format(widget.remainingAmount),
            ),
          ),
        ),
      );
      return;
    }
    final reference = _referenceController.text.trim();
    Navigator.pop(
      context,
      OrderAddPaymentResult(
        amount: double.parse(amount.toStringAsFixed(2)),
        paymentMode: _paymentMode,
        paymentLabel: _paymentLabel,
        referenceId: reference.isEmpty ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.commonRemaining,
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  PosCurrency.format(widget.remainingAmount),
                  textAlign: TextAlign.center,
                  style: FontUtility.heading.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A00E0),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title ?? context.l10n.billingAddPaymentTitle,
                  textAlign: TextAlign.center,
                  style: FontUtility.subheading.copyWith(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.showModePicker && widget.modeOptions.isNotEmpty) ...[
                  RubberPush(child: DropdownButtonFormField<String>(
                    initialValue: _paymentMode,
                    decoration: InputDecoration(
                      labelText: context.l10n.commonPaymentMode,
                    ),
                    items: [
                      for (final option in widget.modeOptions)
                        DropdownMenuItem(
                          value: option.mode,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      final match = widget.modeOptions.firstWhere(
                        (option) => option.mode == value,
                        orElse: () => (mode: value, label: value),
                      );
                      setState(() {
                        _paymentMode = match.mode;
                        _paymentLabel = match.label;
                      });
                    },
                  )),
                  const SizedBox(height: 16),
                ] else
                  Text(
                    _paymentLabel,
                    textAlign: TextAlign.center,
                    style: FontUtility.body.copyWith(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (!widget.showModePicker) const SizedBox(height: 16),
                Text(
                  context.l10n.commonAmount,
                  style: FontUtility.subheading.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                RubberPush(child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: FontUtility.heading.copyWith(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    prefixText: '${PosCurrency.symbol()} ',
                    prefixStyle: FontUtility.heading.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 22,
                    ),
                    border: PosFields.border,
                    filled: true,
                    fillColor: const Color(0xFFF7F8FB),
                  ),
                )),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final preset in _tenderPresets)
                      if (preset <= widget.remainingAmount + 0.0001)
                        ActionChip(
                          label: Text(
                            PosCurrency.format(preset, decimals: 0),
                            style: FontUtility.subheading.copyWith(
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () => _setAmount(preset),
                        ),
                    ActionChip(
                      label: Text(
                        context.l10n.commonExact,
                        style: FontUtility.subheading.copyWith(fontSize: 14),
                      ),
                      onPressed: () => _setAmount(widget.remainingAmount),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                RubberPush(child: TextField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: context.l10n.commonReferenceOptional,
                  ),
                )),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A00E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      (widget.confirmLabel ??
                              context.l10n.billingAddPaymentTitle)
                          .toUpperCase(),
                      style: FontUtility.heading.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      context.l10n.actionCancel,
                      style: FontUtility.subheading.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Default modes when wallets are not available (payments screen).
List<({String mode, String label})> defaultOrderPaymentModes([
  BuildContext? context,
]) {
  final l10n = context?.l10n;
  return [
    (mode: StoreOrderPaymentMode.cash, label: l10n?.commonCash ?? 'Cash'),
    (mode: StoreOrderPaymentMode.card, label: l10n?.commonCard ?? 'Card'),
    (
      mode: StoreOrderPaymentMode.online,
      label: l10n?.orderPaymentsOnlineUpi ?? 'Online / UPI',
    ),
    (mode: StoreOrderPaymentMode.credit, label: l10n?.commonCredit ?? 'Credit'),
  ];
}
