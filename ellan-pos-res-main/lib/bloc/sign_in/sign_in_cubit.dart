import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/pos_orders_offline.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/company_device_setup.dart';
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/device_approval.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/core/pos_lock_pin.dart';
import 'sign_in_state.dart';

/// Cubit responsible for managing sign-in state and authentication logic.
///
/// Explicit Sign-in always hits the gateway to renew the device lease.
/// Day-to-day staff switching uses [StaffLockCubit] (local, reg number).
class SignInCubit extends Cubit<SignInState> {
  final SharedPreferences prefs;

  SignInCubit({required this.prefs}) : super(const SignInState());

  /// Company code from the last setup on this device (what the operator typed,
  /// falling back to the gateway org code).
  String get cachedCompanyCode {
    final orgCode = (prefs.getString(DeviceSetupStore.orgCodeKey) ?? '').trim();
    final active = DeviceSetupStore(prefs).activeOrgInstanceId ?? '';
    // Signup saves the parent org as active until the company is created.
    final isParentOrg =
        active.toLowerCase() == kDefaultRootOrgInstanceId.trim().toLowerCase();
    if (active.isNotEmpty && !isParentOrg) return active;
    return orgCode;
  }

  /// Display name of the company cached on this device, if known.
  String get cachedCompanyName {
    final organisation = DeviceSetupStore(
      prefs,
    ).loadCachedBootstrapJson()?['organisation'];
    if (organisation is! Map) return '';
    return '${organisation['org_name'] ?? organisation['orgName'] ?? ''}'
        .trim();
  }

  bool _isCachedCompany(
    String enteredCode,
    String orgCode,
    DeviceSetupStore setupStore,
  ) {
    final entered = enteredCode.toLowerCase();
    if (entered.isEmpty || orgCode.isEmpty) return false;
    return entered == orgCode.toLowerCase() ||
        entered == (setupStore.activeOrgInstanceId ?? '').toLowerCase();
  }

  /// Creates the lock PIN on the gateway; returns an error message on failure.
  Future<String?> createPin(String pin) async {
    final login = getIt<UiStoreController>().organisationLogin;
    if (login == null) return 'Sign in again to set your PIN.';
    try {
      await PosLockPinStore(prefs).createRemote(login: login, pin: pin);
    } catch (e) {
      return userFacingError(e, fallback: 'Could not save your PIN.');
    }
    return null;
  }

  void pinSetupCompleted() {
    emit(
      state.copyWith(isSuccess: true, needsPinSetup: false, clearError: true),
    );
  }

  void companyCodeChanged(String value) {
    emit(state.copyWith(companyCode: value, clearError: true));
  }

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
      final enteredCode = state.companyCode.trim();
      final setupStore = DeviceSetupStore(prefs);
      final controller = getIt<UiStoreController>();
      var orgCode = (prefs.getString(DeviceSetupStore.orgCodeKey) ?? '').trim();
      var cachedConfig = setupStore.loadCachedConfigJson();

      if (!_isCachedCompany(enteredCode, orgCode, setupStore) ||
          cachedConfig == null) {
        // First sign-in on this device, or a different company: bind the
        // device to [enteredCode] before logging in.
        final setup = CompanyDeviceSetupService(prefs);
        final serverUrl = discoveryOrigin(
          setupStore.activeServerUrl ?? kDefaultServerOrigin,
        );
        if (orgCode.isNotEmpty) {
          // Verify before wiping the previous company's local data.
          if (!await setup.organisationExists(enteredCode)) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage:
                    'We could not find a company for "$enteredCode". '
                    'Check the company code and try again.',
              ),
            );
            return;
          }
          await controller.resetAllLocalData(
            keepSavedServers: false,
            preserveKeys: kDevicePreservedPrefKeys,
          );
        }
        orgCode = await setup.setupDevice(
          serverUrl: serverUrl,
          orgCode: enteredCode,
        );
        cachedConfig = setupStore.loadCachedConfigJson();
      } else {
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

      await controller.ensureDeviceAllowed();

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
      final configToStamp = cachedConfig;
      if (posCode.isNotEmpty && configToStamp != null) {
        await setupStore.persistCachedConfig({
          ...configToStamp,
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

      final login = controller.organisationLogin;
      final lockPin = login == null ? null : PosLockPin.fromLogin(login);
      final pinStore = PosLockPinStore(prefs);
      if (lockPin == null) {
        await pinStore.remove(login?.customerId ?? '');
        emit(
          state.copyWith(
            isLoading: false,
            clearError: true,
            needsPinSetup: true,
          ),
        );
        return;
      }
      await pinStore.save(lockPin);

      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          clearError: true,
          navigateToHome: false,
        ),
      );
    } on CompanySetupException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } on OrganisationNotFoundException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.userMessage));
    } on DeviceAccessDeniedException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.userMessage));
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
