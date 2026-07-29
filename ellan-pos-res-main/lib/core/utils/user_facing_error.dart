/// Maps raw exceptions (HTTP / sockets / timeouts) to short operator-facing copy.
String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (_isConnectionRefused(lower) ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception')) {
    return 'Cannot reach server. Check your connection and Server.';
  }

  if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('deadline exceeded')) {
    return 'Cannot reach server. Check your connection and Server.';
  }

  if (lower.contains('certificate') || lower.contains('handshake')) {
    return 'Secure connection failed. Check the server address and try again.';
  }

  if (lower.contains('401') ||
      lower.contains('unauthorized') ||
      lower.contains('invalid credentials')) {
    return 'Sign-in failed. Check your email and password, then try again.';
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
      return 'Local database is outdated (${noSuch.group(0)}). Fully restart the app, then Sync again.';
    }
    return 'Local database needs an update. Fully restart the app, then try Sync again.';
  }

  if (lower.contains('403') || lower.contains('forbidden')) {
    return 'Access denied. Ask an administrator to check this device and account.';
  }

  // Prefer a short message over a full stack / ClientException dump.
  final firstLine = raw.split('\n').first.trim();
  if (firstLine.isEmpty) return fallback;
  if (firstLine.length > 180 ||
      firstLine.contains('package:') ||
      firstLine.startsWith('#')) {
    return fallback;
  }
  // Strip noisy ClientException / StateError / Exception prefixes.
  final cleaned = firstLine
      .replaceFirst(
        RegExp(r'^ClientException[^:]*:\s*', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^Bad state:\s*', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

bool _isConnectionRefused(String lower) {
  return lower.contains('connection refused') ||
      lower.contains('errno = 111') ||
      lower.contains('errno=111') ||
      (lower.contains('connection') && lower.contains('refused'));
}

bool isNetworkConnectivityError(Object error) {
  final lower = error.toString().toLowerCase();
  return _isConnectionRefused(lower) ||
      lower.contains('cannot reach server') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('check your connection and server');
}
