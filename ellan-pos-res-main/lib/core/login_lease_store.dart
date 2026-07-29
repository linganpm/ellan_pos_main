import 'package:shared_preferences/shared_preferences.dart';

/// Online-login lease: local sign-in is allowed until [validUntil].
///
/// Lease length comes from the portal (`login_lease_minutes`, default 7 days)
/// and can be refreshed during device sync.
class LoginLeaseStore {
  static const defaultLeaseMinutes = 7 * 24 * 60;
  static const leaseMinutesKey = 'posLoginLeaseMinutes';
  static const lastOnlineLoginAtKey = 'posLastOnlineLoginAt';
  static const validUntilKey = 'posOnlineLoginValidUntil';

  final SharedPreferences _prefs;

  LoginLeaseStore(this._prefs);

  static Future<LoginLeaseStore> open() async {
    return LoginLeaseStore(await SharedPreferences.getInstance());
  }

  int get leaseMinutes {
    final raw = _prefs.getInt(leaseMinutesKey);
    if (raw == null || raw < 1) return defaultLeaseMinutes;
    return raw;
  }

  double get leaseDays => leaseMinutes / (24 * 60);

  DateTime? get lastOnlineLoginAt {
    final raw = _prefs.getString(lastOnlineLoginAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  DateTime? get validUntil {
    final raw = _prefs.getString(validUntilKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  bool get hasLease => validUntil != null;

  bool get isValid {
    final until = validUntil;
    if (until == null) return false;
    return !DateTime.now().isAfter(until);
  }

  bool get isExpired => !isValid;

  Duration? get remaining {
    final until = validUntil;
    if (until == null) return null;
    final delta = until.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }

  Future<void> setLeaseMinutes(int minutes) async {
    final normalized = minutes < 1 ? defaultLeaseMinutes : minutes;
    await _prefs.setInt(leaseMinutesKey, normalized);
    // If a lease is already running, keep the same last-online stamp but
    // recompute expiry from the updated length (ops can extend/shorten on the go).
    final last = lastOnlineLoginAt;
    if (last != null) {
      await _prefs.setString(
        validUntilKey,
        last.add(Duration(minutes: normalized)).toIso8601String(),
      );
    }
  }

  /// Call after a successful online (remote) login.
  Future<void> markOnlineLoginSucceeded({
    DateTime? when,
    int? leaseMinutes,
  }) async {
    if (leaseMinutes != null) {
      await setLeaseMinutes(leaseMinutes);
    }
    final stamp = when ?? DateTime.now();
    final minutes = this.leaseMinutes;
    await _prefs.setString(lastOnlineLoginAtKey, stamp.toIso8601String());
    await _prefs.setString(
      validUntilKey,
      stamp.add(Duration(minutes: minutes)).toIso8601String(),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(lastOnlineLoginAtKey);
    await _prefs.remove(validUntilKey);
  }
}
