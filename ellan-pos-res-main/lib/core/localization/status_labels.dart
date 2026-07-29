import 'l10n/app_localizations.dart';

/// Maps raw backend order-status tokens to localized display labels.
///
/// Internal filter/API values stay unchanged — only the returned string is for UI.
String localizedOrderStatusLabel(AppLocalizations l10n, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  var text = trimmed;
  final upper = text.toUpperCase();
  if (upper.startsWith('ORDER_')) {
    text = text.substring(6);
  } else if (text.toLowerCase().startsWith('order ')) {
    text = text.substring(6);
  }

  final normalized = text
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .toLowerCase();
  switch (normalized) {
    case 'pending':
      return l10n.statusOrderPending;
    case 'accepted':
      return l10n.statusOrderAccepted;
    case 'preparing':
    case 'cooking':
      return l10n.statusOrderPreparing;
    case 'ready':
    case 'ready to serve':
      return l10n.statusOrderReady;
    case 'completed':
    case 'complete':
      return l10n.statusOrderCompleted;
    case 'cancelled':
    case 'canceled':
      return l10n.statusOrderCancelled;
    case 'delivered':
      return l10n.statusDelivered;
    case 'picked up':
    case 'pickup':
      return l10n.statusPickedUp;
    case 'served':
      return l10n.statusServed;
    case 'collected':
      return l10n.statusCollected;
    case 'placed':
      return l10n.statusPlaced;
    case 'approved':
      return l10n.statusApproved;
    case 'initiated':
      return l10n.statusInitiated;
    case 'returned':
      return l10n.statusReturned;
    case 'rejected':
      return l10n.statusRejected;
    case 'failed':
      return l10n.statusFailed;
    case 'open':
      return l10n.statusOpen;
    case 'settled':
      return l10n.statusSettled;
  }

  final parts = text
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .toList();
  return parts.isEmpty ? trimmed : parts.join(' ');
}

/// Maps raw payment-status tokens to localized Paid / Unpaid / Partial / Refunded.
String localizedPaymentStatusLabel(AppLocalizations l10n, String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return l10n.statusPaid;
  if (lower.contains('refund')) return l10n.statusRefunded;
  if (lower.contains('partial') || lower.contains('part paid')) {
    return l10n.statusPartial;
  }
  if (lower.contains('unpaid') ||
      lower.contains('not paid') ||
      lower == 'due' ||
      lower == 'pending') {
    return l10n.statusUnpaid;
  }
  if (lower == 'paid' ||
      lower.contains('fully paid') ||
      lower == 'complete' ||
      lower == 'completed') {
    return l10n.statusPaid;
  }
  return localizedOrderStatusLabel(l10n, raw);
}
