import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Converts POS timestamps into the organisation / store IANA timezone.
///
/// Synced order times are usually UTC (`…Z` / `+00:00`). Dashboard buckets and
/// on-screen clocks must use the org timezone, not UTC components from parse.
class OrgTimezone {
  OrgTimezone._();

  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    _initialized = true;
  }

  static tz.Location? _locationOrNull(String? name) {
    ensureInitialized();
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;
    try {
      return tz.getLocation(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// Current org-local wall clock as a naive [DateTime] (no UTC shift on `.hour`).
  static DateTime nowWallClock([String? name]) {
    final location = _locationOrNull(name);
    if (location == null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
        now.millisecond,
        now.microsecond,
      );
    }
    final now = tz.TZDateTime.now(location);
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  /// Convert a parsed instant into org-local wall clock (naive DateTime).
  static DateTime toWallClock(DateTime value, [String? name]) {
    final location = _locationOrNull(name);
    if (location == null) {
      final local = value.toLocal();
      return DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
        local.second,
        local.millisecond,
        local.microsecond,
      );
    }
    final utc = value.isUtc ? value : value.toUtc();
    final local = tz.TZDateTime.from(utc, location);
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// Parse an ISO timestamp into org-local wall clock.
  static DateTime? tryParseWallClock(String? raw, [String? name]) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return toWallClock(parsed, name);
  }

  static DateTime startOfDay(DateTime wallClock) =>
      DateTime(wallClock.year, wallClock.month, wallClock.day);

  static String formatTime(String? raw, [String? name]) {
    final local = tryParseWallClock(raw, name);
    if (local == null) return (raw ?? '').trim();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static String formatDateTime(String? raw, [String? name]) {
    final local = tryParseWallClock(raw, name);
    if (local == null) return (raw ?? '').trim();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final time = formatTime(raw, name);
    return '$y-$m-$d $time';
  }

  /// Format the current org-local wall clock (e.g. `2:45:08 PM`).
  static String formatNowClock(String? name, {bool includeSeconds = true}) {
    final local = nowWallClock(name);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    if (!includeSeconds) return '$hour:$minute $suffix';
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second $suffix';
  }
}

/// Convert an ISO 3166-1 alpha-2 country code into a flag emoji (e.g. IN → 🇮🇳).
String countryCodeToFlagEmoji(String? countryCode) {
  final code = (countryCode ?? '').trim().toUpperCase();
  if (code.length != 2) return '';
  final a = code.codeUnitAt(0);
  final b = code.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
  return String.fromCharCodes([0x1F1E6 + a - 0x41, 0x1F1E6 + b - 0x41]);
}

/// Best-effort ISO country code from a common IANA timezone name.
String countryCodeFromTimezone(String? timezoneName) {
  final name = (timezoneName ?? '').trim();
  if (name.isEmpty) return '';
  const known = <String, String>{
    'Asia/Kolkata': 'IN',
    'Asia/Calcutta': 'IN',
    'Asia/Dubai': 'AE',
    'Asia/Singapore': 'SG',
    'Asia/Kuala_Lumpur': 'MY',
    'Asia/Jakarta': 'ID',
    'Asia/Bangkok': 'TH',
    'Asia/Hong_Kong': 'HK',
    'Asia/Tokyo': 'JP',
    'Asia/Shanghai': 'CN',
    'Asia/Manila': 'PH',
    'Asia/Riyadh': 'SA',
    'Asia/Qatar': 'QA',
    'Asia/Kuwait': 'KW',
    'Europe/London': 'GB',
    'Europe/Dublin': 'IE',
    'Europe/Paris': 'FR',
    'Europe/Berlin': 'DE',
    'Europe/Amsterdam': 'NL',
    'Europe/Madrid': 'ES',
    'Europe/Rome': 'IT',
    'America/New_York': 'US',
    'America/Chicago': 'US',
    'America/Denver': 'US',
    'America/Los_Angeles': 'US',
    'America/Toronto': 'CA',
    'America/Vancouver': 'CA',
    'Australia/Sydney': 'AU',
    'Australia/Melbourne': 'AU',
    'Pacific/Auckland': 'NZ',
    'Africa/Johannesburg': 'ZA',
    'Africa/Lagos': 'NG',
    'Africa/Nairobi': 'KE',
  };
  final direct = known[name];
  if (direct != null) return direct;
  // Continent/City fallbacks for common regions.
  if (name.startsWith('Asia/Kolkata') || name.contains('Kolkata')) return 'IN';
  if (name.startsWith('Europe/London')) return 'GB';
  return '';
}
