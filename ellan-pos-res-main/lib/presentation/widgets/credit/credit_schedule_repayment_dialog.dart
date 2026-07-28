import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';

class CreditScheduleRepaymentResult {
  final double amount;
  final DateTime dueDate;

  const CreditScheduleRepaymentResult({
    required this.amount,
    required this.dueDate,
  });

  String get dueDateIso {
    final y = dueDate.year.toString().padLeft(4, '0');
    final m = dueDate.month.toString().padLeft(2, '0');
    final d = dueDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class CreditScheduleRepaymentDialog extends StatefulWidget {
  final String customerName;
  final double? suggestedAmount;

  const CreditScheduleRepaymentDialog({
    super.key,
    required this.customerName,
    this.suggestedAmount,
  });

  @override
  State<CreditScheduleRepaymentDialog> createState() =>
      _CreditScheduleRepaymentDialogState();
}

class _CreditScheduleRepaymentDialogState
    extends State<CreditScheduleRepaymentDialog> {
  late final TextEditingController _amountController;
  late DateTime _dueDate;

  @override
  void initState() {
    super.initState();
    final suggested = widget.suggestedAmount;
    _amountController = TextEditingController(
      text: suggested != null && suggested > 0
          ? suggested.toStringAsFixed(2)
          : '',
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _dueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero.')),
      );
      return;
    }
    Navigator.pop(
      context,
      CreditScheduleRepaymentResult(
        amount: double.parse(amount.toStringAsFixed(2)),
        dueDate: _dueDate,
      ),
    );
  }

  String get _dueDateLabel {
    final y = _dueDate.year.toString().padLeft(4, '0');
    final m = _dueDate.month.toString().padLeft(2, '0');
    final d = _dueDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.customerName.isEmpty ? 'Customer' : widget.customerName;
    return AlertDialog(
      title: const Text('Schedule repayment'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: FontUtility.subheading),
            const SizedBox(height: 4),
            Text(
              'Record an upcoming payment promise from this customer.',
              style: FontUtility.body.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              autofocus: true,
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
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Due date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(_dueDateLabel, style: FontUtility.body),
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
          child: const Text('Schedule'),
        ),
      ],
    );
  }
}
