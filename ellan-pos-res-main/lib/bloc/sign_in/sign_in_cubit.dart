import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/device_approval.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'sign_in_state.dart';

/// Cubit responsible for managing sign-in state and authentication logic.
///
/// Explicit Sign-in always hits the gateway to renew the device lease.
/// Day-to-day staff switching uses [StaffLockCubit] (local, reg number).
class SignInCubit extends Cubit<SignInState> {
  final SharedPreferences prefs;

  SignInCubit({required this.prefs}) : super(const SignInState());

  void identifierChanged(String value) {
    emit(state.copyWith(identifier: value, clearError: true));
  }

  void passwordChanged(String value) {
    emit(state.copyWith(password: value, clearError: true));
  }

  void togglePasswordVisibility() {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }

  /// Submits the sign-in credentials for authentication.
  ///
  /// Always calls the gateway login API and renews the online lease on success.
  /// Silent cold-start login (UserBloc) stays local while the lease is valid.
  Future<void> submit() async {
    if (state.isLoading) return;

    if (!state.isValid) {
      emit(state.copyWith(errorMessage: 'Please fill in all fields'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final orgCode = prefs.getString('orgCode');

      if (orgCode == null || orgCode.isEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'No organization code found. Please complete the setup process first.',
          ),
        );
        return;
      }

      final setupStore = DeviceSetupStore(prefs);
      final controller = getIt<UiStoreController>();

      final cachedConfig = setupStore.loadCachedConfigJson();
      if (cachedConfig != null) {
        await setupStore.persistCachedConfig(cachedConfig);
        await controller.bootWithConfig(StoreConfig.fromJson(cachedConfig));
        final bootstrap = setupStore.loadCachedBootstrapJson();
        if (bootstrap != null) {
          await controller.applyBootstrapPayload(bootstrap);
        }
        await controller.registerDeviceLocally(
          deviceId: posDeviceId(prefs),
          make: posDeviceMake(prefs),
          model: posDeviceModel(prefs),
        );
      }

      // Explicit Sign in always hits the gateway so the operator can renew the
      // lease. Local-only auth is reserved for silent cold-start (UserBloc).
      final loggedIn = await controller.loginToOrganisation(
        orgCode: orgCode,
        email: state.identifier,
        password: state.password,
        deviceId: posDeviceId(prefs),
        forceOnline: true,
        preferLocal: false,
      );

      if (!loggedIn) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'Online sign-in failed. Check credentials and server connection.',
          ),
        );
        return;
      }

      await prefs.setString('userEmail', state.identifier);
      await prefs.setString('lastStaffIdentifier', state.identifier);
      final displayName = controller.currentStaffDisplayName.trim().isNotEmpty
          ? controller.currentStaffDisplayName.trim()
          : state.identifier.trim();
      await prefs.setString('lastStaffDisplayName', displayName);
      await prefs.remove('userPassword');
      await prefs.remove('userLoggedIn');
      await prefs.remove('selectedStoreId');

      final posCode = controller.organisationPosCode;
      if (posCode.isNotEmpty && cachedConfig != null) {
        await setupStore.persistCachedConfig({
          ...cachedConfig,
          'pos_code': posCode,
        });
      }

      final stores = controller.accessibleStores();

      if (stores.isEmpty) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'No accessible stores found for this account. Please contact your administrator.',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          clearError: true,
          navigateToHome: false,
        ),
      );
    } catch (e, _) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'Sign-in failed. Please try again.',
          ),
        ),
      );
    }
  }
}
