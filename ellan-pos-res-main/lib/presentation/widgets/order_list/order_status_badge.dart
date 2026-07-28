import 'package:flutter/material.dart';
import '../../../core/utils/font_utility.dart';

/// Formats raw backend status tokens for display.
///
/// Examples: `ORDER_COMPLETED` / `order_completed` → `Completed`.
String formatOrderStatusLabel(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return text;

  final upper = text.toUpperCase();
  if (upper.startsWith('ORDER_')) {
    text = text.substring(6);
  } else if (text.toLowerCase().startsWith('order ')) {
    text = text.substring(6);
  }

  final parts = text
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .toList();
  return parts.isEmpty ? raw.trim() : parts.join(' ');
}

/// Normalises payment status to Paid / Unpaid / Partial / Refunded.
String formatPaymentStatusLabel(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return 'Paid';
  if (lower.contains('refund')) return 'Refunded';
  if (lower.contains('partial') || lower.contains('part paid')) {
    return 'Partial';
  }
  if (lower.contains('unpaid') ||
      lower.contains('not paid') ||
      lower == 'due' ||
      lower == 'pending') {
    return 'Unpaid';
  }
  if (lower == 'paid' ||
      lower.contains('fully paid') ||
      lower == 'complete' ||
      lower == 'completed') {
    return 'Paid';
  }
  return formatOrderStatusLabel(raw);
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool isPaymentStatus;
  /// Text + color only (no chip background / border).
  final bool plain;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.isPaymentStatus = false,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    final display = isPaymentStatus
        ? formatPaymentStatusLabel(status)
        : formatOrderStatusLabel(status);
    final lowerStatus = display.toLowerCase();

    if (lowerStatus.contains('refunded') ||
        lowerStatus.contains('refund')) {
      backgroundColor = Colors.purple.withValues(alpha: 0.12);
      textColor = Colors.purple.shade700;
    } else if (lowerStatus.contains('completed') ||
        lowerStatus == 'paid' ||
        lowerStatus.contains('ready to serve') ||
        lowerStatus.contains('served') ||
        lowerStatus.contains('collected') ||
        lowerStatus.contains('delivered') ||
        lowerStatus.contains('picked up')) {
      backgroundColor = Colors.green.withValues(alpha: 0.15);
      textColor = Colors.green.shade700;
    } else if (lowerStatus.contains('pending') ||
        lowerStatus.contains('preparing') ||
        lowerStatus.contains('cooking') ||
        lowerStatus.contains('initiated') ||
        lowerStatus.contains('placed') ||
        lowerStatus.contains('approved') ||
        lowerStatus.contains('partial')) {
      backgroundColor = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange.shade800;
    } else if (lowerStatus.contains('cancelled') ||
        lowerStatus.contains('returned') ||
        lowerStatus.contains('failed') ||
        lowerStatus.contains('wrong') ||
        lowerStatus.contains('rejected') ||
        lowerStatus.contains('unpaid')) {
      backgroundColor = Colors.red.withValues(alpha: 0.15);
      textColor = Colors.red.shade700;
    } else if (lowerStatus.contains('delivery') ||
        lowerStatus.contains('shipped') ||
        lowerStatus.contains('shipping') ||
        lowerStatus.contains('way') ||
        lowerStatus.contains('driver')) {
      backgroundColor = Colors.blue.withValues(alpha: 0.15);
      textColor = Colors.blue.shade700;
    } else {
      backgroundColor = Colors.grey.withValues(alpha: 0.15);
      textColor = Colors.grey.shade800;
    }

    final label = Text(
      display,
      style: FontUtility.body.copyWith(
        color: textColor,
        fontWeight: plain ? FontWeight.w500 : FontWeight.w600,
        fontSize: plain ? 12 : 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (plain) return label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3), width: 1),
      ),
      child: label,
    );
  }
}
