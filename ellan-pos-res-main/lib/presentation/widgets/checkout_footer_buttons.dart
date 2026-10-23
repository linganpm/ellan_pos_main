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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE6E8EE))),
      ),
      child: SizedBox(
        height: 64,
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
                  elevation: 0,
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
                  elevation: 0,
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
      ),
    );
  }
}
