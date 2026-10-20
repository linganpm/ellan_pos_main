import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Company profile columns mirrored between `store_info` and the gateway.
const companyProfileFields = [
  'storeName',
  'contactEmail',
  'phone',
  'address',
  'registration_number',
  'tax_number',
  'identifier',
];

/// Pushes company details saved on the device (`profile_pending_sync = 1`)
/// to `POST /api/pos/store/profile`.
class CompanyProfileSync {
  CompanyProfileSync({
    required this.loadProfile,
    required this.markSynced,
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client;

  /// Returns the local profile (see `Store.loadCompanyProfile`).
  final Future<Map<String, dynamic>> Function() loadProfile;

  /// Stores the gateway-confirmed values and clears the pending flags.
  final Future<void> Function(Map<String, String> fields) markSynced;
  final http.Client? _client;
  final Duration timeout;

  static bool isUnreachable(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is http.ClientException ||
      error is FormatException;

  /// Returns true when nothing is pending or the gateway accepted the edit,
  /// false when offline or not signed in (the edit stays queued). Throws
  /// [StateError] with the gateway message when the gateway rejects it.
  Future<bool> push({
    required String origin,
    required String? token,
    required Map<String, String> refs,
  }) async {
    final profile = await loadProfile();
    if (((profile['profile_pending_sync'] as num?)?.toInt() ?? 0) != 1) {
      return true;
    }
    final bearer = token?.trim() ?? '';
    if (bearer.isEmpty) return false;
    String field(String key) => '${profile[key] ?? ''}'.trim();

    final uri = Uri.parse('$origin/api/pos/store/profile');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearer',
    };
    final body = jsonEncode({
      ...refs,
      'store_name': field('storeName'),
      'email': field('contactEmail'),
      'phone': field('phone'),
      'address': field('address'),
      'identifier': field('identifier'),
      'registration_number': field('registration_number'),
      'tax_number': field('tax_number'),
    });

    final http.Response response;
    try {
      final client = _client;
      response = await (client == null
              ? http.post(uri, headers: headers, body: body)
              : client.post(uri, headers: headers, body: body))
          .timeout(timeout);
    } on Object catch (error) {
      if (isUnreachable(error)) return false;
      rethrow;
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // Proxy / captive-portal HTML instead of the gateway: stay queued.
      if (!ok) return false;
    }
    if (!ok) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw StateError(
        (message == null || message.trim().isEmpty)
            ? 'Company settings were rejected (HTTP ${response.statusCode}).'
            : message,
      );
    }

    // The operator saved again while this was in flight: keep that edit
    // pending for the next push instead of overwriting it.
    final latest = await loadProfile();
    final unchanged = companyProfileFields.every(
      (key) => '${latest[key] ?? ''}'.trim() == field(key),
    );
    if (!unchanged) return true;

    final remote = decoded is Map && decoded['store'] is Map
        ? Map<String, dynamic>.from(decoded['store'] as Map)
        : const <String, dynamic>{};
    String pick(String fallbackKey, List<String> keys) {
      for (final key in keys) {
        final value = remote[key];
        if (value != null) return '$value';
      }
      return field(fallbackKey);
    }

    await markSynced({
      'storeName': pick('storeName', const ['storeName', 'store_name']),
      'contactEmail': pick('contactEmail', const [
        'contactEmail',
        'contact_email',
      ]),
      'phone': pick('phone', const ['phone']),
      'address': pick('address', const ['address', 'location']),
      'registration_number': pick('registration_number', const [
        'registration_number',
        'company_registration_number',
      ]),
      'tax_number': pick('tax_number', const [
        'tax_number',
        'company_tax_number',
      ]),
      'identifier': pick('identifier', const ['identifier']),
    });
    return true;
  }
}
