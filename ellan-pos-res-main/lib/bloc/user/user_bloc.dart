import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/device_approval.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/login_lease_store.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_event.dart';
import 'user_state.dart';

/// Marks errors the UI must treat as a hard stop rather than a login prompt.
const String deviceNotApprovedPrefix = 'Device not approved.';

/// Cold start boots the device only — staff unlock happens on the lock screen.
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserInitial()) {
    on<UserInitializeEvent>(_onUserInitialize);
  }

  Future<void> _onUserInitialize(
    UserInitializeEvent event,
    Emitter<UserState> emit,
  ) async {
    emit(UserLoading());
    try {
      final prefs = getIt<SharedPreferences>();
      final setupStore = DeviceSetupStore(prefs);
      final controller = getIt<UiStoreController>();
      final lease = await LoginLeaseStore.open();

      setupStore.restoreActiveDiscoveryUrl();

      if (!setupStore.isSetupComplete) {
        emit(
          UserError(
            "No stored organisation code found. Please perform initial setup.",
          ),
        );
        return;
      }

      if (!setupStore.isDeviceApproved) {
        emit(
          UserError(
            '$deviceNotApprovedPrefix This device is not approved for the '
            'organisation. Complete setup while online and ask an administrator '
            'to approve it.',
          ),
        );
        return;
      }

      final orgCode = setupStore.orgCode;
      final cachedConfig = setupStore.loadCachedConfigJson();
      if (orgCode == null || orgCode.isEmpty || cachedConfig == null) {
        emit(
          UserError(
            "No stored configuration found for organisation code '${orgCode ?? ''}'. Please perform initial setup to fetch the latest configuration.",
          ),
        );
        return;
      }

      await controller.bootWithConfig(StoreConfig.fromJson(cachedConfig));

      final bootstrapPayload = setupStore.loadCachedBootstrapJson();
      if (bootstrapPayload != null) {
        await controller.applyBootstrapPayload(bootstrapPayload);
      }

      await controller.registerDeviceLocally(
        deviceId: posDeviceId(prefs),
        make: posDeviceMake(prefs),
        model: posDeviceModel(prefs),
        lat: 0,
        lan: 0,
      );

      if (setupStore.needsOnlineFirstLaunch) {
        emit(UserError("Organisation is set up. Please sign in to continue."));
        return;
      }

      // Lease expired → online device renew (Sign in screen).
      if (lease.isExpired) {
        emit(const UserNeedsStaffUnlock(leaseExpired: true));
        return;
      }

      final selectedStoreId = prefs.getString('selectedStoreId');
      // Never silent-login the previous staff. Open the store shell (when
      // possible) then wait on the staff lock screen.
      final restored = await controller.restoreOrganisationLoginFromCache();
      if (restored && selectedStoreId != null && selectedStoreId.isNotEmpty) {
        try {
          await controller.openStore(selectedStoreId);
          await controller.logout();
        } catch (e, st) {
          // ignore: avoid_print
          print('UserBloc: open store for lock failed: $e\n$st');
        }
      }

      // Drop any leftover password from older builds — multi-staff tablets
      // must not auto-impersonate the last operator.
      await prefs.remove('userPassword');
      await prefs.remove('userLoggedIn');

      final storeName =
          controller.staffUnlockStoreName(storeId: selectedStoreId) ??
          prefs.getString('selectedStoreName');
      emit(
        UserNeedsStaffUnlock(storeId: selectedStoreId, storeName: storeName),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('UserBloc::_onUserInitialize error: $e\n$st');
      emit(
        UserError(
          userFacingError(
            e,
            fallback:
                'Could not start the app. Check your connection and try again.',
          ),
        ),
      );
    }
  }
}
