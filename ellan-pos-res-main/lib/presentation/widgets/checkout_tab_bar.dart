import 'package:flutter/material.dart';
import '../../core/utils/font_utility.dart';
import '../../core/localization/l10n_context.dart';

class CheckoutTabBar extends StatelessWidget {
  final bool isHistoryActive;
  final VoidCallback onNewOrderTap;
  final VoidCallback onHistoryTap;
  final int newOrderCount;

  const CheckoutTabBar({
    super.key,
    required this.isHistoryActive,
    required this.onNewOrderTap,
    required this.onHistoryTap,
    required this.newOrderCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onNewOrderTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isHistoryActive
                      ? const Color(0xFF4A00E0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    newOrderCount > 0
                        ? 'New Order ($newOrderCount)'
                        : context.l10n.commonNewOrder,
                    style: FontUtility.subheading.copyWith(
                      color: !isHistoryActive
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onHistoryTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isHistoryActive
                      ? const Color(0xFF4A00E0)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    context.l10n.commonOrderHistory,
                    style: FontUtility.subheading.copyWith(
                      color: isHistoryActive
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
