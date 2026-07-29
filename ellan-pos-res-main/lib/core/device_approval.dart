import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/discovery_constants.dart';

/// Identity this tablet registers under. Collected once at setup; the
/// fallback keeps desktop/dev builds (which report no hardware id) stable.
String posDeviceId(SharedPreferences prefs) {
  final stored = prefs.getString('deviceId');
  return stored != null && stored.isNotEmpty ? stored : 'ui-example-device-001';
}

String posDeviceMake(SharedPreferences prefs) =>
    prefs.getString('deviceMake') ?? 'Linux';

String posDeviceModel(SharedPreferences prefs) =>
    prefs.getString('deviceModel') ?? 'POS Tablet';

/// Raised when the organisation code/id cannot be resolved by the gateway.
class OrganisationNotFoundException implements Exception {
  final String orgRef;

  const OrganisationNotFoundException(this.orgRef);

  String get userMessage =>
      'We could not find an organisation for "$orgRef". '
      'Please check the organisation code and try again.';

  @override
  String toString() => userMessage;
}

/// Outcome of the organisation-side check for this tablet.
class DeviceApproval {
  final bool registered;
  final bool approved;
  final String status;
  final String message;
  final int? loginLeaseMinutes;

  const DeviceApproval({
    required this.registered,
    required this.approved,
    required this.status,
    required this.message,
    this.loginLeaseMinutes,
  });

  factory DeviceApproval.fromJson(Map<String, dynamic> json) {
    final registration = json['registration'];
    final regMap = registration is Map
        ? registration.cast<String, dynamic>()
        : const <String, dynamic>{};
    int? lease =
        _asInt(json['login_lease_minutes']) ??
        _asInt(json['loginLeaseMinutes']) ??
        _asInt(regMap['login_lease_minutes']) ??
        _asInt(regMap['loginLeaseMinutes']);
    if (lease == null) {
      final days =
          _asDouble(json['login_lease_days']) ??
          _asDouble(json['loginLeaseDays']) ??
          _asDouble(regMap['login_lease_days']) ??
          _asDouble(regMap['loginLeaseDays']);
      if (days != null && days > 0) {
        lease = (days * 24 * 60).round();
      }
    }
    return DeviceApproval(
      registered: json['registered'] == true,
      approved: json['approved'] == true,
      status: '${json['status'] ?? 'unknown'}',
      message: '${json['message'] ?? ''}',
      loginLeaseMinutes: lease,
    );
  }

  bool get isPending => status == 'pending';
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse('$value');
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

/// Registers this tablet with the organisation and reports its approval state.
///
/// The POS may only continue when [DeviceApproval.approved] is true; a device
/// stays `pending` until an administrator approves it in the gateway.
class DeviceApprovalService {
  static const statusKey = 'deviceApprovalStatus';
  static const orgIdKey = 'deviceApprovalOrgId';

  final SharedPreferences prefs;
  final http.Client client;

  DeviceApprovalService(this.prefs, {http.Client? client})
    : client = client ?? http.Client();

  /// Registers this tablet against [orgRef] and reports its approval state.
  ///
  /// Idempotent: an unknown device is created as `pending`, a known one only
  /// has its hardware details and heartbeat refreshed. Re-registering never
  /// re-approves a rejected or suspended device.
  ///
  /// [orgRef] accepts either the organisation code or its service instance id.
  Future<DeviceApproval> registerAndCheck({
    required String orgRef,
    required String deviceId,
    required String make,
    required String model,
    double lat = 0,
    double lan = 0,
  }) async {
    final response = await client.post(
      kDeviceRegistrationUrl,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orgId': orgRef,
        'deviceId': deviceId,
        'make': make,
        'model': model,
        'lat': lat,
        'lan': lan,
      }),
    );
    return _handle(response, orgRef);
  }

  /// Re-checks approval without changing the registration record.
  Future<DeviceApproval> check({
    required String orgRef,
    required String deviceId,
  }) async {
    final response = await client.get(
      kDeviceStatusUrl.replace(
        queryParameters: {'orgId': orgRef, 'deviceId': deviceId},
      ),
    );
    return _handle(response, orgRef);
  }

  DeviceApproval _handle(http.Response response, String orgRef) {
    if (response.statusCode == 404) {
      throw OrganisationNotFoundException(orgRef);
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError(
        'Device approval check failed with status ${response.statusCode}.',
      );
    }
    // 403 is the expected response for a device that is not yet approved.
    if (response.statusCode >= 400 && response.statusCode != 403) {
      throw StateError('${body['message'] ?? 'Device approval check failed.'}');
    }
    final approval = DeviceApproval.fromJson(body);
    prefs.setString(statusKey, approval.status);
    prefs.setString(orgIdKey, orgRef);
    final lease = approval.loginLeaseMinutes;
    if (lease != null && lease > 0) {
      // Persist without importing LoginLeaseStore here to avoid cycles —
      // callers apply lease via LoginLeaseStore.setLeaseMinutes.
      prefs.setInt('posLoginLeaseMinutes', lease);
    }
    return approval;
  }
}
