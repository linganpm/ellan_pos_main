import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/discovery_constants.dart';

const int kPosPinLength = 4;

/// Lock-screen PIN of a staff member who signed in on this device.
///
/// Only the salted hash from the gateway is kept: sha256("$salt:$pin").
class PosLockPin {
  final String customerId;
  final String email;
  final String name;
  final String salt;
  final String sha256Hex;

  const PosLockPin({
    required this.customerId,
    required this.email,
    required this.name,
    required this.salt,
    required this.sha256Hex,
  });

  bool verify(String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString() == sha256Hex;

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'email': email,
    'name': name,
    'salt': salt,
    'sha256': sha256Hex,
  };

  static PosLockPin? fromJson(Map<String, dynamic> json) {
    final salt = '${json['salt'] ?? ''}'.trim();
    final hash = '${json['sha256'] ?? ''}'.trim();
    if (salt.isEmpty || hash.isEmpty) return null;
    return PosLockPin(
      customerId: '${json['customerId'] ?? ''}',
      email: '${json['email'] ?? ''}',
      name: '${json['name'] ?? ''}',
      salt: salt,
      sha256Hex: hash,
    );
  }

  /// PIN hash delivered with a remote sign-in (`customer.pos_pin`), if any.
  static PosLockPin? fromLogin(
    StoreOrganisationLoginResult login, {
    Map<String, dynamic>? pinOverride,
  }) {
    final raw = pinOverride ?? login.customerRow?['pos_pin'];
    if (raw is! Map) return null;
    final row = login.customerRow;
    final name = '${row?['name'] ?? login.customerName}'.trim();
    return PosLockPin.fromJson({
      ...raw.cast<String, dynamic>(),
      'customerId': login.customerId,
      'email': login.email,
      'name': name.isNotEmpty ? name : login.email,
    });
  }
}

/// Lock-screen PINs of every staff member who signed in on this device, so
/// staff can take turns on a shared tablet without going online.
class PosLockPinStore {
  static const _key = 'posLockPins';
  static const _legacyKey = 'posLockPin';
  static const _lastKey = 'posLockPinLast';

  final SharedPreferences prefs;

  const PosLockPinStore(this.prefs);

  List<PosLockPin> loadAll() {
    final out = <PosLockPin>[];
    try {
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        for (final row in jsonDecode(raw) as List) {
          final pin = PosLockPin.fromJson((row as Map).cast<String, dynamic>());
          if (pin != null) out.add(pin);
        }
      }
      final legacy = prefs.getString(_legacyKey);
      if (out.isEmpty && legacy != null && legacy.isNotEmpty) {
        final pin = PosLockPin.fromJson(
          (jsonDecode(legacy) as Map).cast<String, dynamic>(),
        );
        if (pin != null) out.add(pin);
      }
    } catch (_) {}
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  /// Staff member who used the tablet most recently.
  String? get lastCustomerId => prefs.getString(_lastKey);

  Future<void> save(PosLockPin pin) async {
    final all = loadAll()..removeWhere((p) => _sameStaff(p, pin));
    all.add(pin);
    await _write(all);
    await markLast(pin.customerId);
  }

  Future<void> markLast(String customerId) =>
      prefs.setString(_lastKey, customerId);

  Future<void> remove(String customerId) async {
    final all = loadAll()..removeWhere((p) => p.customerId == customerId);
    await _write(all);
    if (lastCustomerId == customerId) await prefs.remove(_lastKey);
  }

  Future<void> clear() async {
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
    await prefs.remove(_lastKey);
  }

  Future<void> _write(List<PosLockPin> all) async {
    await prefs.remove(_legacyKey);
    await prefs.setString(_key, jsonEncode([for (final p in all) p.toJson()]));
  }

  static bool _sameStaff(PosLockPin a, PosLockPin b) => a.customerId.isNotEmpty
      ? a.customerId == b.customerId
      : a.email.toLowerCase() == b.email.toLowerCase();

  /// Creates the PIN on the gateway for the signed-in staff and stores it.
  Future<PosLockPin> createRemote({
    required StoreOrganisationLoginResult login,
    required String pin,
  }) async {
    final token = (login.accessToken ?? '').trim();
    if (token.isEmpty) {
      throw StateError('Sign in online again to set your PIN.');
    }
    final response = await http
        .post(
          Uri.parse(kDiscoveryUrl).replace(path: '/api/pos/staff/pin'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'pin': pin}),
        )
        .timeout(const Duration(seconds: 20));
    Map<String, dynamic> body = const {};
    try {
      body = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('${body['message'] ?? 'Could not save your PIN.'}');
    }
    final raw = body['pos_pin'];
    final lockPin = PosLockPin.fromLogin(
      login,
      pinOverride: raw is Map ? raw.cast<String, dynamic>() : null,
    );
    if (lockPin == null) throw StateError('Could not save your PIN.');
    await save(lockPin);
    return lockPin;
  }
}
