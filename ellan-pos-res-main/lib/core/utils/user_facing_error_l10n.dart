import '../localization/l10n/app_localizations.dart';

/// Maps raw exceptions to short operator-facing copy using [l10n].
///
/// Prefer this at the presentation boundary. Keep [userFacingError] for
/// non-UI layers that cannot depend on localization.
String userFacingErrorL10n(
  AppLocalizations l10n,
  Object error, {
  String? fallback,
}) {
  final resolvedFallback = fallback ?? l10n.errorGeneric;
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (_isConnectionRefused(lower) ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception')) {
    return l10n.errorCannotReachServer;
  }

  if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('deadline exceeded')) {
    return l10n.errorCannotReachServer;
  }

  if (lower.contains('certificate') || lower.contains('handshake')) {
    return l10n.errorSecureConnectionFailed;
  }

  if (lower.contains('401') ||
      lower.contains('unauthorized') ||
      lower.contains('invalid credentials')) {
    return l10n.errorSignInFailed;
  }

  if (lower.contains('databaseexception') ||
      lower.contains('sqliteexception') ||
      lower.contains('no such column') ||
      lower.contains('no such table')) {
    final noSuch = RegExp(
      r'no such (?:column|table):\s*([^\s,]+)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (noSuch != null) {
      return l10n.errorDbOutdated(noSuch.group(0)!);
    }
    return l10n.errorDbNeedsUpdate;
  }

  if (lower.contains('403') || lower.contains('forbidden')) {
    return l10n.errorAccessDenied;
  }

  final firstLine = raw.split('\n').first.trim();
  if (firstLine.isEmpty) return resolvedFallback;
  if (firstLine.length > 180 ||
      firstLine.contains('package:') ||
      firstLine.startsWith('#')) {
    return resolvedFallback;
  }
  final cleaned = firstLine
      .replaceFirst(
        RegExp(r'^ClientException[^:]*:\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .trim();
  return cleaned.isEmpty ? resolvedFallback : cleaned;
}

bool _isConnectionRefused(String lower) {
  return lower.contains('connection refused') ||
      lower.contains('errno = 111') ||
      lower.contains('errno=111') ||
      (lower.contains('connection') && lower.contains('refused'));
}
