import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/discovery_constants.dart';
import 'device_setup_store.dart';

/// Who the operator should contact for help with the POS.
class SupportContact {
  final String name;
  final String email;

  /// Parent organisation's contact number, reached over WhatsApp.
  final String whatsapp;

  const SupportContact({this.name = '', this.email = '', this.whatsapp = ''});

  bool get isEmpty => email.isEmpty && whatsapp.isEmpty;

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    String read(String key) => '${json[key] ?? ''}'.trim();
    return SupportContact(
      name: read('name'),
      email: read('email'),
      whatsapp: read('whatsapp'),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'whatsapp': whatsapp,
  };

  /// `POS_SUPPORT_*` from the bundled env file.
  static SupportContact fromEnv() {
    String read(String key) =>
        dotenv.isInitialized ? (dotenv.env[key] ?? '').trim() : '';
    return SupportContact(
      name: read('POS_SUPPORT_NAME'),
      email: read('POS_SUPPORT_EMAIL'),
      whatsapp: read('POS_SUPPORT_WHATSAPP'),
    );
  }
}

/// Loads support details from the gateway (company → parent org), caching
/// the last answer so the sheet still works offline.
class SupportContactService {
  static const _cacheKey = 'posSupportContact';

  final SharedPreferences prefs;

  const SupportContactService(this.prefs);

  String get _orgRef {
    final setup = DeviceSetupStore(prefs);
    final orgCode = (prefs.getString(DeviceSetupStore.orgCodeKey) ?? '').trim();
    if (orgCode.isNotEmpty) return orgCode;
    return setup.activeOrgInstanceId ?? kDefaultRootOrgInstanceId;
  }

  SupportContact? get cached {
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final contact = SupportContact.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      return contact.isEmpty ? null : contact;
    } catch (_) {
      return null;
    }
  }

  Future<SupportContact> load() async {
    try {
      final uri = Uri.parse(
        kDiscoveryUrl,
      ).replace(path: '/api/pos/support', queryParameters: {'org': _orgRef});
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final contact = SupportContact.fromJson(
          (jsonDecode(response.body) as Map).cast<String, dynamic>(),
        );
        if (!contact.isEmpty) {
          await prefs.setString(_cacheKey, jsonEncode(contact.toJson()));
          return contact;
        }
      }
    } catch (_) {
      // Offline or older gateway — fall back below.
    }
    return cached ?? SupportContact.fromEnv();
  }
}
