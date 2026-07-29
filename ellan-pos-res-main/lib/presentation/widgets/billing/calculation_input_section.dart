import 'package:flutter/material.dart';
import '../../../core/currency_format.dart';
import '../../../core/utils/font_utility.dart';
import '../../../core/localization/l10n_context.dart';

class CalculationInputSection extends StatefulWidget {
  final String title;
  final String placeholder;
  final Function(double) onApply;
  final VoidCallback onCancel;

  /// When true, value is a free amount (tips). When false, percentage 1–100.
  final bool isAmount;
  final String? suffixText;

  const CalculationInputSection({
    super.key,
    required this.title,
    required this.placeholder,
    required this.onApply,
    required this.onCancel,
    this.isAmount = false,
    this.suffixText,
  });

  @override
  State<CalculationInputSection> createState() =>
      _CalculationInputSectionState();
}

class _CalculationInputSectionState extends State<CalculationInputSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validate);
  }

  @override
  void dispose() {
    _controller.removeListener(_validate);
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final value = double.tryParse(_controller.text);
    setState(() {
      if (widget.isAmount) {
        _isValid = value != null && value > 0;
      } else {
        _isValid = value != null && value > 0 && value <= 100;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suffix =
        widget.suffixText ?? (widget.isAmount ? PosCurrency.symbol() : '%');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: FontUtility.heading.copyWith(fontSize: 18),
              ),
              IconButton(
                tooltip: context.l10n.actionClose,
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: FontUtility.subheading.copyWith(fontSize: 18),
            decoration: InputDecoration(
              hintText: widget.placeholder,
              suffixText: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF4A00E0),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isValid
                  ? () => widget.onApply(double.parse(_controller.text))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                context.l10n.billingApply,
                style: FontUtility.heading.copyWith(
                  color: _isValid ? Colors.white : Colors.grey.shade500,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
