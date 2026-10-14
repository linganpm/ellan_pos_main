import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:pos_orders_offline/store_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bloc/language/language_bloc.dart';
import 'constants/discovery_constants.dart';
import 'controllers/ui_store_controller.dart';
import 'device_approval.dart';
import 'device_setup_store.dart';
import 'di/service_locator.dart';
import 'offline_pos_config.dart';

/// Preference keys that survive a company switch (device identity + language).
const kDevicePreservedPrefKeys = <String>{
  'deviceId',
  'deviceMake',
  'deviceModel',
  LanguageBloc.localePreferenceKey,
};

class CompanySetupException implements Exception {
  final String message;

  const CompanySetupException(this.message);

  @override
  String toString() => message;
}

/// Reads hardware identity into prefs (`deviceId`, `deviceMake`, `deviceModel`).
Future<void> collectAndStoreDeviceInfo(SharedPreferences prefs) async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    String make;
    String model;
    String deviceId;

    if (kIsWeb) {
      final info = await deviceInfo.webBrowserInfo;
      make = info.vendor ?? 'Web';
      model = info.userAgent ?? 'Browser';
      deviceId = info.userAgent ?? 'web';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await deviceInfo.androidInfo;
      make = info.manufacturer;
      model = info.model;
      deviceId = info.id;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final info = await deviceInfo.iosInfo;
      make = info.name;
      model = info.model;
      deviceId = info.identifierForVendor ?? '';
    } else if (defaultTargetPlatform == TargetPlatform.linux) {
      final info = await deviceInfo.linuxInfo;
      make = info.name.isNotEmpty ? info.name : 'Linux';
      final versionId = info.versionId;
      model = info.prettyName.isNotEmpty
          ? info.prettyName
          : (versionId != null && versionId.isNotEmpty ? versionId : 'Desktop');
      deviceId = info.machineId ?? '';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      final info = await deviceInfo.macOsInfo;
      make = 'Apple';
      model = info.model;
      deviceId = info.systemGUID ?? '';
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      final info = await deviceInfo.windowsInfo;
      make = 'Windows';
      model = info.computerName;
      deviceId = info.deviceId;
    } else {
      make = 'unknown';
      model = 'POS Desktop';
      deviceId = '';
    }

    // Keep values within gateway column limits.
    if (make.length > 128) make = make.substring(0, 128);
    if (model.length > 128) model = model.substring(0, 128);
    if (deviceId.length > 128) deviceId = deviceId.substring(0, 128);
    await prefs.setString('deviceMake', make);
    await prefs.setString('deviceModel', model);
    if (deviceId.isNotEmpty) {
      await prefs.setString('deviceId', deviceId);
    }
  } catch (_) {
    // Keep existing / default device identity.
  }
}

/// Binds this device to a company: approval check, one bootstrap download,
/// local cache, and offline store boot. Used by "join existing" and sign-in.
class CompanyDeviceSetupService {
  final SharedPreferences prefs;

  const CompanyDeviceSetupService(this.prefs);

  DeviceSetupStore get _setupStore => DeviceSetupStore(prefs);

  Uri _bootstrapUri(String orgCode) =>
      Uri.parse(kDiscoveryUrl).replace(
        queryParameters: {
          'orgCode': orgCode,
          'deviceId': posDeviceId(prefs),
          'environment': 'development',
        },
      );

  /// Read-only check that [orgCode] names a company on the gateway.
  Future<bool> organisationExists(String orgCode) async {
    final response = await http
        .get(_bootstrapUri(orgCode))
        .timeout(const Duration(seconds: 20));
    return response.statusCode != 404;
  }

  /// Returns the organisation code resolved by the gateway.
  Future<String> setupDevice({
    required String serverUrl,
    required String orgCode,
  }) async {
    final setupStore = _setupStore;

    // Persist the gateway choice before any network call so retries and
    // cold starts reuse the same host.
    await setupStore.saveServerEntry(
      PosServerEntry(serverUrl: serverUrl, orgInstanceId: orgCode),
    );

    // Approval gate first: the organisation must recognise this device as
    // registered, approved and active before any org data is fetched.
    await collectAndStoreDeviceInfo(prefs);
    final deviceId = posDeviceId(prefs);
    final approval = await DeviceApprovalService(prefs)
        .registerAndCheck(
          orgRef: orgCode,
          deviceId: deviceId,
          make: posDeviceMake(prefs),
          model: posDeviceModel(prefs),
        )
        .timeout(const Duration(seconds: 20));
    if (!approval.approved) {
      throw CompanySetupException(
        approval.message.isNotEmpty
            ? approval.message
            : 'This device is not approved for "$orgCode". '
                  'Contact your organisation administrator.',
      );
    }

    final bootstrapResponse = await http
        .get(_bootstrapUri(orgCode))
        .timeout(const Duration(seconds: 20));
    if (bootstrapResponse.statusCode == 404) {
      throw CompanySetupException(
        'We could not find an organisation for "$orgCode". '
        'Please check the company code and try again.',
      );
    }
    if (bootstrapResponse.statusCode == 403) {
      throw CompanySetupException(
        'This device is not approved for "$orgCode". Contact your '
        'organisation administrator.',
      );
    }
    if (bootstrapResponse.statusCode < 200 ||
        bootstrapResponse.statusCode >= 300) {
      throw StateError(
        'Bootstrap failed with status ${bootstrapResponse.statusCode}.',
      );
    }

    final bootstrapPayload =
        jsonDecode(bootstrapResponse.body) as Map<String, dynamic>;
    final organisation = bootstrapPayload['organisation'];
    if (organisation is! Map) {
      throw CompanySetupException(
        'We could not find an organisation for "$orgCode". '
        'Please check the company code and try again.',
      );
    }

    final resolvedOrgCode =
        '${organisation['org_code'] ?? organisation['orgCode'] ?? orgCode}';

    // Prefer inline config from the same bootstrap response (one network hop).
    Map<String, dynamic> remoteConfig;
    final inlineConfig = bootstrapPayload['config'];
    if (inlineConfig is Map) {
      remoteConfig = inlineConfig.cast<String, dynamic>();
    } else {
      final configUrl = bootstrapPayload['config_url'] as String?;
      if (configUrl == null || configUrl.isEmpty) {
        throw StateError('Bootstrap payload missing config and config_url.');
      }
      final configResponse = await http.get(Uri.parse(configUrl));
      if (configResponse.statusCode < 200 ||
          configResponse.statusCode >= 300) {
        throw StateError(
          'Config lookup failed with status ${configResponse.statusCode}.',
        );
      }
      remoteConfig = jsonDecode(configResponse.body) as Map<String, dynamic>;
    }

    final customersPath = (await setupStore.customersFile()).path;
    // First-launch config keeps catalogue import URLs; sealed offline after
    // the operator signs in and the one-time catalogue sync completes.
    final setupConfig = buildFirstLaunchPosConfig(
      remoteConfig: remoteConfig,
      bootstrapPayload: bootstrapPayload,
      localCustomersPath: customersPath,
    );

    await setupStore.saveSetup(
      orgCode: resolvedOrgCode,
      bootstrapPayload: bootstrapPayload,
      setupConfig: setupConfig,
      deviceApproved: true,
    );

    final controller = getIt<UiStoreController>();
    await controller.bootWithConfig(StoreConfig.fromJson(setupConfig));
    await controller.applyBootstrapPayload(bootstrapPayload);
    await controller.registerDeviceLocally(
      deviceId: deviceId,
      make: posDeviceMake(prefs),
      model: posDeviceModel(prefs),
      lat: 0,
      lan: 0,
    );

    return resolvedOrgCode;
  }
}
