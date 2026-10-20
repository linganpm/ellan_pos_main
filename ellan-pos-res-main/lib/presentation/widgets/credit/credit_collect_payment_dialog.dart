import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:pos_tablet/core/currency_format.dart';

class CreditCollectPaymentResult {
  final double amount;
  final String paymentMode;
  final String? referenceId;

  const CreditCollectPaymentResult({
    required this.amount,
    required this.paymentMode,
    this.referenceId,
  });
}

class CreditCollectPaymentDialog extends StatefulWidget {
  final String customerName;
  final double outstanding;

  const CreditCollectPaymentDialog({
    super.key,
    required this.customerName,
    required this.outstanding,
  });

  @override
  State<CreditCollectPaymentDialog> createState() =>
      _CreditCollectPaymentDialogState();
}

class _CreditCollectPaymentDialogState
    extends State<CreditCollectPaymentDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  String _paymentMode = StoreCreditRepaymentMode.cash;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.outstanding.toStringAsFixed(2),
    );
    _referenceController = TextEditingController();
  }

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
    if (amount - widget.outstanding > 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed outstanding (${PosCurrency.format(widget.outstanding)}).',
          ),
        ),
      );
      return;
    }
    final reference = _referenceController.text.trim();
    Navigator.pop(
      context,
      CreditCollectPaymentResult(
        amount: double.parse(amount.toStringAsFixed(2)),
        paymentMode: _paymentMode,
        referenceId: reference.isEmpty ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customerName.isEmpty
        ? context.l10n.commonCustomer
        : widget.customerName;
    return AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(context.l10n.creditsCollectPayment),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: FontUtility.subheading),
            const SizedBox(height: 4),
            Text(
              'Outstanding ${PosCurrency.format(widget.outstanding)}',
              style: FontUtility.body.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.commonAmount,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
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
                if (value == null) return;
                setState(() => _paymentMode = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: context.l10n.commonReferenceOptional,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _amountController.text = widget.outstanding.toStringAsFixed(
                    2,
                  );
                },
                child: Text(context.l10n.commonSettleFullBalance),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.creditsCollect),
        ),
      ],
    );
  }
}
