import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:pos_orders_offline/store_config.dart';
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/service_locator.dart';
import '../../core/device_approval.dart';
import '../../core/device_setup_store.dart';
import '../../core/offline_pos_config.dart';
import '../../core/utils/user_facing_error.dart';
import 'welcome_state.dart';

/// One-time device setup: pick a server, register the device, bootstrap offline.
class WelcomeCubit extends Cubit<WelcomeState> {
  final SharedPreferences prefs;

  WelcomeCubit({required this.prefs}) : super(const WelcomeState()) {
    _loadSavedServers();
  }

  DeviceSetupStore get _setupStore => DeviceSetupStore(prefs);

  void _loadSavedServers() {
    final entries = _setupStore.listServerEntries();
    final activeUrl = _setupStore.activeServerUrl;
    final activeOrg = _setupStore.activeOrgInstanceId;

    var serverUrl = kIsPosDiscoveryConfiguredByEnv
        ? kDefaultServerOrigin
        : (activeUrl ?? '');
    var orgId = kIsPosDiscoveryConfiguredByEnv
        ? kDefaultRootOrgInstanceId
        : (activeOrg ?? '');

    if (!kIsPosDiscoveryConfiguredByEnv &&
        (serverUrl.isEmpty || orgId.isEmpty) &&
        entries.isNotEmpty) {
      serverUrl = entries.first.serverUrl;
      orgId = entries.first.orgInstanceId;
    }

    if (serverUrl.isNotEmpty) {
      setActiveDiscoveryUrl(serverUrl);
    }

    emit(
      state.copyWith(
        savedServers: entries,
        // Welcome field is origin only (e.g. http://127.0.0.1:8000) — never /api/...
        serverUrl: serverUrl.isEmpty
            ? kDefaultServerOrigin
            : discoveryOrigin(serverUrl),
        organizationName: orgId.isEmpty ? kDefaultRootOrgInstanceId : orgId,
      ),
    );
  }

  void serverUrlChanged(String value) {
    emit(state.copyWith(serverUrl: value, clearError: true));
  }

  void organizationNameChanged(String name) {
    emit(state.copyWith(organizationName: name, clearError: true));
  }

  void selectSavedServer(PosServerEntry entry) {
    setActiveDiscoveryUrl(entry.serverUrl);
    emit(
      state.copyWith(
        serverUrl: discoveryOrigin(entry.serverUrl),
        organizationName: entry.orgInstanceId,
        clearError: true,
      ),
    );
  }

  Future<void> deleteSavedServer(PosServerEntry entry) async {
    await _setupStore.deleteServerEntry(entry);
    final remaining = _setupStore.listServerEntries();

    var nextUrl = state.serverUrl;
    var nextOrg = state.organizationName;
    final deletedUrl = discoveryOrigin(entry.serverUrl);
    final deletedOrg = entry.orgInstanceId.trim();
    if (discoveryOrigin(state.serverUrl) == deletedUrl &&
        state.organizationName.trim() == deletedOrg) {
      if (remaining.isNotEmpty) {
        nextUrl = discoveryOrigin(remaining.first.serverUrl);
        nextOrg = remaining.first.orgInstanceId;
        setActiveDiscoveryUrl(remaining.first.serverUrl);
      } else {
        nextUrl = '';
        nextOrg = '';
        clearActiveDiscoveryUrl();
      }
    }

    emit(
      state.copyWith(
        savedServers: remaining,
        serverUrl: nextUrl,
        organizationName: nextOrg,
        clearError: true,
      ),
    );
  }

  String get _deviceId => posDeviceId(prefs);

  Future<void> _collectAndStoreDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String make = '';
      String model = '';
      String deviceId = '';

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
        final pretty = info.prettyName;
        final versionId = info.versionId;
        model = pretty.isNotEmpty
            ? pretty
            : (versionId != null && versionId.isNotEmpty
                  ? versionId
                  : 'Desktop');
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
      await prefs.setString('deviceId', deviceId);
    } catch (e) {
      print('Failed to collect device info: $e');
    }
  }

  /// Device setup only: one bootstrap lookup, then cache everything locally.
  /// Ordering never uses backend APIs after this.
  Future<void> submit() async {
    if (!state.isValid || state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final serverUrl = state.serverUrl.trim();
      final orgCode = state.organizationName.trim();
      final setupStore = _setupStore;

      // Persist the gateway choice before any network call so retries and
      // cold starts reuse the same host.
      await setupStore.saveServerEntry(
        PosServerEntry(serverUrl: serverUrl, orgInstanceId: orgCode),
      );

      // Approval gate first: the organisation must recognise this device as
      // registered, approved and active before any org data is fetched.
      await _collectAndStoreDeviceInfo();
      final approval = await DeviceApprovalService(prefs)
          .registerAndCheck(
            orgRef: orgCode,
            deviceId: _deviceId,
            make: posDeviceMake(prefs),
            model: posDeviceModel(prefs),
          )
          .timeout(const Duration(seconds: 20));
      if (!approval.approved) {
        emit(
          state.copyWith(
            isLoading: false,
            savedServers: setupStore.listServerEntries(),
            errorMessage: approval.message.isNotEmpty
                ? approval.message
                : 'This device is not approved for "$orgCode". '
                      'Contact your organisation administrator.',
          ),
        );
        return;
      }

      // Single discovery call for the lifetime of this device setup.
      final bootstrapUri = Uri.parse(kDiscoveryUrl).replace(
        queryParameters: {
          'orgCode': orgCode,
          'deviceId': _deviceId,
          'environment': 'development',
        },
      );
      final bootstrapResponse = await http
          .get(bootstrapUri)
          .timeout(const Duration(seconds: 20));
      if (bootstrapResponse.statusCode == 404) {
        emit(
          state.copyWith(
            isLoading: false,
            savedServers: setupStore.listServerEntries(),
            errorMessage:
                'We could not find an organisation for "$orgCode". '
                'Please check the organisation instance id and try again.',
          ),
        );
        return;
      }
      if (bootstrapResponse.statusCode == 403) {
        emit(
          state.copyWith(
            isLoading: false,
            savedServers: setupStore.listServerEntries(),
            errorMessage:
                'This device is not approved for "$orgCode". Contact your '
                'organisation administrator.',
          ),
        );
        return;
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
        emit(
          state.copyWith(
            isLoading: false,
            savedServers: setupStore.listServerEntries(),
            errorMessage:
                'We could not find an organisation for "$orgCode". '
                'Please check the organisation instance id and try again.',
          ),
        );
        return;
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

      // Seed org directory into the controller from the same payload (no 2nd fetch).
      await controller.applyBootstrapPayload(bootstrapPayload);

      // Local device identity only — approval already confirmed above.
      await controller.registerDeviceLocally(
        deviceId: _deviceId,
        make: posDeviceMake(prefs),
        model: posDeviceModel(prefs),
        lat: 0,
        lan: 0,
      );

      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          savedServers: setupStore.listServerEntries(),
          clearError: true,
        ),
      );
    } on OrganisationNotFoundException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          savedServers: _setupStore.listServerEntries(),
          errorMessage: e.userMessage,
        ),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('WelcomeCubit::submit error: $e\n$st');
      emit(
        state.copyWith(
          isLoading: false,
          savedServers: _setupStore.listServerEntries(),
          errorMessage: userFacingError(
            e,
            fallback:
                'Unable to complete device setup. Check the server address and try again.',
          ),
        ),
      );
    }
  }
}
