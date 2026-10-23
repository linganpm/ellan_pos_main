import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

class CustomerAdvanceResult {
  final double amount;
  final String paymentMode;
  final String? referenceId;

  const CustomerAdvanceResult({
    required this.amount,
    required this.paymentMode,
    this.referenceId,
  });
}

class CustomerAdvanceDialog extends StatefulWidget {
  final String customerName;
  final double accountBalance;

  const CustomerAdvanceDialog({
    super.key,
    required this.customerName,
    required this.accountBalance,
  });

  @override
  State<CustomerAdvanceDialog> createState() => _CustomerAdvanceDialogState();
}

class _CustomerAdvanceDialogState extends State<CustomerAdvanceDialog> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  String _paymentMode = StoreCreditRepaymentMode.cash;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.amountGreaterThanZero)),
      );
      return;
    }
    final reference = _referenceController.text.trim();
    Navigator.pop(
      context,
      CustomerAdvanceResult(
        amount: double.parse(amount.toStringAsFixed(2)),
        paymentMode: _paymentMode,
        referenceId: reference.isEmpty ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.add_card_rounded),
      title: Text(context.l10n.customerAdvanceAdd),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.customerName, style: FontUtility.subheading),
              const SizedBox(height: 6),
              Text(
                context.l10n.customerAdvanceExplanation,
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.commonBalanceDue +
                    ': ${PosCurrency.format(widget.accountBalance)}',
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.accountBalance > 0.0001
                      ? Colors.red.shade700
                      : widget.accountBalance < -0.0001
                      ? Colors.green.shade700
                      : Colors.black54,
                ),
              ),
              const SizedBox(height: 18),
              RubberPush(child: TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.commonAmount,
                  prefixText: '${PosCurrency.symbol()} ',
                ),
              )),
              const SizedBox(height: 12),
              RubberPush(child: DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: InputDecoration(
                  labelText: context.l10n.commonPaymentMode,
                ),
                items: [
                  DropdownMenuItem(
                    value: StoreCreditRepaymentMode.cash,
                    child: Text(context.l10n.commonCash),
                  ),
                  DropdownMenuItem(
                    value: StoreCreditRepaymentMode.card,
                    child: Text(context.l10n.commonCard),
                  ),
                  DropdownMenuItem(
                    value: StoreCreditRepaymentMode.voucher,
                    child: Text(context.l10n.commonVoucher),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMode = value);
                },
              )),
              const SizedBox(height: 12),
              RubberPush(child: TextField(
                controller: _referenceController,
                decoration: InputDecoration(
                  labelText: context.l10n.commonReferenceOptional,
                ),
              )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.customerAdvanceRecord),
        ),
      ],
    );
  }
}
