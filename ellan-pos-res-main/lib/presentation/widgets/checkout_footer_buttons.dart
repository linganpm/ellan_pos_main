import 'package:flutter/material.dart';
import '../../core/utils/font_utility.dart';

class CheckoutFooterButtons extends StatelessWidget {
  final bool hasItems;
  final bool canSendKot;
  final VoidCallback onKOT;
  final VoidCallback onBill;

  const CheckoutFooterButtons({
    super.key,
    required this.hasItems,
    this.canSendKot = true,
    required this.onKOT,
    required this.onBill,
  });

  @override
  Widget build(BuildContext context) {
    final kotEnabled = hasItems && canSendKot;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: ElevatedButton(
              onPressed: kotEnabled ? onKOT : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4A00E0),
                disabledBackgroundColor: Colors.grey.shade100,
                disabledForegroundColor: Colors.grey.shade400,
                elevation: kotEnabled ? 2 : 0,
                shadowColor: Colors.black.withOpacity(0.1),
                side: BorderSide(
                  color: kotEnabled
                      ? const Color(0xFF4A00E0).withOpacity(0.5)
                      : Colors.transparent,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'KOT',
                style: FontUtility.heading.copyWith(
                  fontSize: 18,
                  color: kotEnabled
                      ? const Color(0xFF4A00E0)
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasItems ? onBill : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A00E0),
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: hasItems ? 6 : 0,
                shadowColor: const Color(0xFF4A00E0).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'BILL',
                style: FontUtility.heading.copyWith(
                  color: hasItems ? Colors.white : Colors.grey.shade500,
                  fontSize: 22,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
