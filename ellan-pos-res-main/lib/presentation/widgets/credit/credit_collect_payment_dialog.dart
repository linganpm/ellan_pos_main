import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';

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
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }
    if (amount - widget.outstanding > 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount cannot exceed outstanding (\$${widget.outstanding.toStringAsFixed(2)}).',
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
    final name = widget.customerName.isEmpty ? 'Customer' : widget.customerName;
    return AlertDialog(
      title: const Text('Collect payment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: FontUtility.subheading),
            const SizedBox(height: 4),
            Text(
              'Outstanding \$${widget.outstanding.toStringAsFixed(2)}',
              style: FontUtility.body.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMode,
              decoration: const InputDecoration(
                labelText: 'Payment mode',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: StoreCreditRepaymentMode.cash,
                  child: Text('Cash'),
                ),
                DropdownMenuItem(
                  value: StoreCreditRepaymentMode.card,
                  child: Text('Card'),
                ),
                DropdownMenuItem(
                  value: StoreCreditRepaymentMode.voucher,
                  child: Text('Voucher'),
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
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _amountController.text =
                      widget.outstanding.toStringAsFixed(2);
                },
                child: const Text('Settle full balance'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Collect'),
        ),
      ],
    );
  }
}
