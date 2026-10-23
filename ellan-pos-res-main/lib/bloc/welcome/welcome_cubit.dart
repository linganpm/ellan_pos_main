import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/company_device_setup.dart';
import '../../core/device_approval.dart';
import '../../core/device_setup_store.dart';
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
    var orgId = activeOrg ?? '';
    // The env parent is Store Global, not the shop this tablet is joining.
    if (orgId.trim() == kDefaultRootOrgInstanceId.trim()) {
      orgId = '';
    }

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
        organizationName: orgId,
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

  /// Device setup only: one bootstrap lookup, then cache everything locally.
  /// Ordering never uses backend APIs after this.
  Future<void> submit() async {
    if (!state.isValid || state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      await CompanyDeviceSetupService(prefs).setupDevice(
        serverUrl: state.serverUrl.trim(),
        orgCode: state.organizationName.trim(),
      );

      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          savedServers: _setupStore.listServerEntries(),
          clearError: true,
        ),
      );
    } on CompanySetupException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          savedServers: _setupStore.listServerEntries(),
          errorMessage: e.message,
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
