import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/discovery_constants.dart';

class SignupCountry {
  final String id;
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const SignupCountry({
    required this.id,
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  factory SignupCountry.fromJson(Map<String, dynamic> json) {
    return SignupCountry(
      id: '${json['id'] ?? ''}',
      name: '${json['country_name'] ?? json['name'] ?? ''}',
      code: '${json['country_code'] ?? ''}',
      dialCode: '${json['dial_code'] ?? ''}',
      flag: '${json['flag'] ?? ''}',
    );
  }

  String get displayLabel {
    final flagPart = flag.isNotEmpty ? '$flag ' : '';
    final dialPart = dialCode.isNotEmpty ? ' ($dialCode)' : '';
    return '$flagPart$name$dialPart';
  }
}

class SignupBusinessType {
  final String id;
  final String label;

  const SignupBusinessType({required this.id, required this.label});

  factory SignupBusinessType.fromJson(Map<String, dynamic> json) {
    return SignupBusinessType(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? ''}',
    );
  }
}

class SignupMeta {
  final List<SignupCountry> countries;
  final List<SignupBusinessType> businessTypes;

  const SignupMeta({
    required this.countries,
    required this.businessTypes,
  });
}

class ResolvedParentOrg {
  final String id;
  final String name;
  final String identifier;
  final String instanceId;

  const ResolvedParentOrg({
    required this.id,
    required this.name,
    required this.identifier,
    required this.instanceId,
  });

  factory ResolvedParentOrg.fromJson(Map<String, dynamic> json) {
    return ResolvedParentOrg(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      identifier: '${json['identifier'] ?? ''}',
      instanceId: '${json['instance_id'] ?? ''}',
    );
  }
}

class CompanySignupResult {
  final String companyIdentifier;
  final String companyName;
  final String orgInstanceId;
  final String? email;
  final String? phoneNumber;
  final List<Map<String, dynamic>> steps;
  final Map<String, dynamic> raw;

  const CompanySignupResult({
    required this.companyIdentifier,
    required this.companyName,
    required this.orgInstanceId,
    required this.steps,
    required this.raw,
    this.email,
    this.phoneNumber,
  });

  factory CompanySignupResult.fromJson(Map<String, dynamic> json) {
    final hints = json['login_hints'];
    final hintsMap =
        hints is Map ? hints.cast<String, dynamic>() : <String, dynamic>{};
    final stepsRaw = json['steps'];
    final steps = stepsRaw is List
        ? stepsRaw
            .whereType<Map>()
            .map((row) => row.cast<String, dynamic>())
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return CompanySignupResult(
      companyIdentifier: '${json['company_identifier'] ?? ''}'.trim(),
      companyName: '${json['company_name'] ?? ''}'.trim(),
      orgInstanceId: '${json['org_instance_id'] ?? ''}'.trim(),
      email: '${hintsMap['email'] ?? ''}'.trim().isEmpty
          ? null
          : '${hintsMap['email']}'.trim(),
      phoneNumber: '${hintsMap['phone_number'] ?? ''}'.trim().isEmpty
          ? null
          : '${hintsMap['phone_number']}'.trim(),
      steps: steps,
      raw: json,
    );
  }
}

/// Structured signup/gateway failure with a stable [code] for UI mapping.
class SignupApiException implements Exception {
  final String message;
  final String code;
  final int statusCode;

  const SignupApiException({
    required this.message,
    required this.code,
    required this.statusCode,
  });

  factory SignupApiException.fromResponse({
    required int statusCode,
    required Map<String, dynamic> body,
    String fallback = 'Signup failed.',
  }) {
    final message = '${body['message'] ?? ''}'.trim();
    final code = '${body['code'] ?? ''}'.trim();
    return SignupApiException(
      message: message.isNotEmpty ? message : '$fallback ($statusCode)',
      code: code.isNotEmpty ? code : _fallbackCode(statusCode),
      statusCode: statusCode,
    );
  }

  static String _fallbackCode(int statusCode) {
    return switch (statusCode) {
      404 => 'parent_not_found',
      409 => 'user_exists',
      400 => 'signup_failed',
      _ => 'signup_failed',
    };
  }

  @override
  String toString() => message;
}

class CompanySignupApi {
  Uri _originUri(String path, [Map<String, String>? query]) {
    final origin = discoveryOrigin(kDiscoveryUrl);
    return Uri.parse(origin).replace(path: path, queryParameters: query);
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map) return raw.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  Future<SignupMeta> fetchMeta() async {
    final response = await http.get(_originUri('/api/pos/signup/meta'));
    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode,
        body: decoded,
        fallback: 'Unable to load signup options',
      );
    }
    final countries =
        (decoded['countries'] is List ? decoded['countries'] as List : const [])
            .whereType<Map>()
            .map((row) => SignupCountry.fromJson(row.cast<String, dynamic>()))
            .where((c) => c.id.isNotEmpty)
            .toList(growable: false);
    final types = (decoded['business_types'] is List
            ? decoded['business_types'] as List
            : const [])
        .whereType<Map>()
        .map((row) => SignupBusinessType.fromJson(row.cast<String, dynamic>()))
        .where((t) => t.id.isNotEmpty)
        .toList(growable: false);
    return SignupMeta(
      countries: countries,
      businessTypes: types.isEmpty
          ? const [
              SignupBusinessType(id: 'cafe', label: 'Cafe'),
              SignupBusinessType(id: 'restaurant', label: 'Restaurant'),
              SignupBusinessType(id: 'bakery', label: 'Bakery'),
              SignupBusinessType(id: 'other', label: 'Others'),
            ]
          : types,
    );
  }

  Future<ResolvedParentOrg> resolveParent(String ref) async {
    final response = await http.get(
      _originUri('/api/pos/signup/parent', {
        'ref': ref.trim(),
      }),
    );
    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['ok'] == false) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode == 200 ? 404 : response.statusCode,
        body: decoded,
        fallback: 'Parent organisation was not found',
      );
    }
    final parent = decoded['parent'];
    if (parent is! Map) {
      throw const SignupApiException(
        message: 'Parent organisation was not found.',
        code: 'parent_not_found',
        statusCode: 404,
      );
    }
    return ResolvedParentOrg.fromJson(parent.cast<String, dynamic>());
  }

  Future<CompanySignupResult> createCompany({
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      _originUri('/api/pos/signup/company'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = _decodeMap(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode,
        body: decoded,
      );
    }
    if (decoded['ok'] == false) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode,
        body: decoded,
      );
    }
    return CompanySignupResult.fromJson(decoded);
  }

  Future<Map<String, dynamic>> fetchBootstrap({
    required String orgCode,
    String? deviceId,
  }) async {
    final params = <String, String>{
      'orgCode': orgCode,
      'environment': 'development',
    };
    if (deviceId != null && deviceId.isNotEmpty) {
      params['deviceId'] = deviceId;
    }
    final response = await http.get(_originUri('/api/pos/bootstrap', params));
    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode,
        body: decoded,
        fallback: 'Bootstrap failed',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> fetchConfig({
    required String orgId,
  }) async {
    final response = await http.get(
      _originUri('/api/pos/config', {
        'orgId': orgId,
        'environment': 'development',
      }),
    );
    final decoded = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SignupApiException.fromResponse(
        statusCode: response.statusCode,
        body: decoded,
        fallback: 'Config lookup failed',
      );
    }
    return decoded;
  }
}

/// Floor-staff friendly password: at least 6 characters, any content.
class PasswordRules {
  static bool hasMinLength(String value) => value.trim().length >= 6;

  static bool isValid(String value) => hasMinLength(value);
}
