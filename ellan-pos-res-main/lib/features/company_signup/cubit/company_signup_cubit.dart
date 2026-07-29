import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/discovery_constants.dart';
import '../../../core/controllers/ui_store_controller.dart';
import '../../../core/device_approval.dart';
import '../../../core/device_setup_store.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/offline_pos_config.dart';
import '../data/signup_api.dart';
import 'company_signup_state.dart';

class CompanySignupCubit extends Cubit<CompanySignupState> {
  CompanySignupCubit({
    required this.prefs,
    CompanySignupApi? api,
  })  : _api = api ?? CompanySignupApi(),
        super(CompanySignupState(
          serverUrl: kDefaultServerOrigin,
          parentOrgIdentifier: kDefaultRootOrgInstanceId,
        ));

  final SharedPreferences prefs;
  final CompanySignupApi _api;

  static const progressSteps = <({String id, String label})>[
    (id: 'creating_user', label: 'Creating user'),
    (id: 'creating_company', label: 'Creating company'),
    (id: 'setting_profile', label: 'Setting profile'),
    (id: 'setting_up_branch', label: 'Setting up branch'),
    (id: 'setting_up_account', label: 'Setting up account'),
    (id: 'success', label: 'Congratulations — success'),
  ];

  DeviceSetupStore get _setupStore => DeviceSetupStore(prefs);

  void serverUrlChanged(String value) {
    emit(state.copyWith(serverUrl: value, clearError: true));
  }

  void parentOrgChanged(String value) {
    emit(state.copyWith(parentOrgIdentifier: value, clearError: true));
  }

  void companyNameChanged(String value) {
    emit(state.copyWith(companyName: value, clearError: true));
  }

  void ownerNameChanged(String value) {
    emit(state.copyWith(ownerName: value, clearError: true));
  }

  void emailChanged(String value) {
    emit(state.copyWith(email: value, clearError: true));
  }

  void phoneChanged(String value) {
    emit(state.copyWith(phoneNumber: value, clearError: true));
  }

  void countryChanged(String value) {
    emit(state.copyWith(countryId: value, clearError: true));
  }

  void passwordChanged(String value) {
    emit(state.copyWith(password: value, clearError: true));
  }

  void passwordConfirmChanged(String value) {
    emit(state.copyWith(passwordConfirm: value, clearError: true));
  }

  void businessTypeChanged(String value) {
    emit(state.copyWith(businessType: value, clearError: true));
  }

  void branchNameChanged(String value) {
    emit(state.copyWith(branchName: value, clearError: true));
  }

  void cityChanged(String value) {
    emit(state.copyWith(city: value, clearError: true));
  }

  void registrationNumberChanged(String value) {
    emit(state.copyWith(registrationNumber: value, clearError: true));
  }

  void goBack() {
    if (state.isSubmitting || state.isSuccess) return;
    switch (state.step) {
      case CompanySignupStep.companyDetails:
        emit(state.copyWith(
          step: CompanySignupStep.serverParent,
          clearError: true,
        ));
      case CompanySignupStep.businessType:
        emit(state.copyWith(
          step: CompanySignupStep.companyDetails,
          clearError: true,
        ));
      case CompanySignupStep.branchDetails:
        emit(state.copyWith(
          step: CompanySignupStep.businessType,
          clearError: true,
        ));
      case CompanySignupStep.progress:
        emit(state.copyWith(
          step: CompanySignupStep.branchDetails,
          clearError: true,
          clearActiveProgress: true,
          completedProgressIds: const [],
        ));
      case CompanySignupStep.serverParent:
        break;
    }
  }

  Future<void> continueFromServerParent() async {
    if (!state.canContinueServerParent || state.isLoadingMeta) return;

    final origin = discoveryOrigin(state.serverUrl.trim());
    setActiveDiscoveryUrl(origin);
    emit(state.copyWith(
      serverUrl: origin,
      isLoadingMeta: true,
      clearError: true,
    ));

    try {
      final parent = await _api.resolveParent(state.parentOrgIdentifier.trim());
      await _setupStore.saveServerEntry(
        PosServerEntry(
          serverUrl: origin,
          orgInstanceId: parent.identifier.isNotEmpty
              ? parent.identifier
              : parent.instanceId,
        ),
      );
      final meta = await _api.fetchMeta();
      // Prefer GB/IN/US when present; otherwise first country.
      var defaultCountry = state.countryId;
      if (defaultCountry.isEmpty) {
        for (final preferred in const ['216', '94', '217']) {
          if (meta.countries.any((c) => c.id == preferred)) {
            defaultCountry = preferred;
            break;
          }
        }
        if (defaultCountry.isEmpty && meta.countries.isNotEmpty) {
          defaultCountry = meta.countries.first.id;
        }
      }
      emit(state.copyWith(
        isLoadingMeta: false,
        parentOrgName: parent.name,
        parentOrgIdentifier: parent.identifier.isNotEmpty
            ? parent.identifier
            : state.parentOrgIdentifier.trim(),
        countries: meta.countries,
        businessTypes: meta.businessTypes,
        countryId: defaultCountry,
        step: CompanySignupStep.companyDetails,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMeta: false,
        errorMessage: _friendlyError(e),
        errorCode: e is SignupApiException ? e.code : null,
      ));
    }
  }

  void continueFromCompanyDetails() {
    if (!state.canContinueCompanyDetails) return;
    emit(state.copyWith(
      step: CompanySignupStep.businessType,
      clearError: true,
    ));
  }

  void continueFromBusinessType() {
    if (!state.canContinueBusinessType) return;
    emit(state.copyWith(
      step: CompanySignupStep.branchDetails,
      clearError: true,
    ));
  }

  Future<void> submitBranchAndCreate() async {
    if (!state.canSubmitBranch || state.isSubmitting) return;

    emit(state.copyWith(
      step: CompanySignupStep.progress,
      isSubmitting: true,
      isSuccess: false,
      completedProgressIds: const [],
      activeProgressId: progressSteps.first.id,
      clearError: true,
    ));

    try {
      await _collectAndStoreDeviceInfo();
      final deviceId = posDeviceId(prefs);

      // Animate first tick while the network call runs.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final result = await _api.createCompany(
        body: {
          'parent_org_identifier': state.parentOrgIdentifier.trim(),
          'company_name': state.companyName.trim(),
          'owner_name': state.ownerName.trim(),
          'email': state.email.trim(),
          'phone_number': state.phoneNumber.trim(),
          'country_id': state.countryId.trim(),
          'password': state.password,
          'business_type': state.businessType.trim(),
          'branch_name': state.branchName.trim(),
          'city': state.city.trim(),
          'registration_number': state.registrationNumber.trim(),
          'device_id': deviceId,
          'make': posDeviceMake(prefs),
          'model': posDeviceModel(prefs),
        },
      );

      final completed = <String>[];
      for (final step in progressSteps) {
        if (step.id == 'success') break;
        emit(state.copyWith(
          activeProgressId: step.id,
          completedProgressIds: List<String>.from(completed),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 450));
        completed.add(step.id);
        emit(state.copyWith(
          completedProgressIds: List<String>.from(completed),
          clearActiveProgress: true,
        ));
      }

      // Persist gateway + bootstrap so login works immediately.
      await _setupStore.saveServerEntry(
        PosServerEntry(
          serverUrl: state.serverUrl.trim(),
          orgInstanceId: result.companyIdentifier,
        ),
      );

      final bootstrap = await _api.fetchBootstrap(
        orgCode: result.companyIdentifier,
        deviceId: deviceId,
      );
      Map<String, dynamic> remoteConfig;
      final inline = bootstrap['config'];
      if (inline is Map) {
        remoteConfig = inline.cast<String, dynamic>();
      } else {
        remoteConfig = await _api.fetchConfig(
          orgId: result.orgInstanceId.isNotEmpty
              ? result.orgInstanceId
              : result.companyIdentifier,
        );
      }

      final customersPath = (await _setupStore.customersFile()).path;
      final setupConfig = buildFirstLaunchPosConfig(
        remoteConfig: remoteConfig,
        bootstrapPayload: bootstrap,
        localCustomersPath: customersPath,
      );
      await _setupStore.saveSetup(
        orgCode: result.companyIdentifier,
        bootstrapPayload: bootstrap,
        setupConfig: setupConfig,
        deviceApproved: true,
      );

      final controller = getIt<UiStoreController>();
      await controller.bootWithConfig(StoreConfig.fromJson(setupConfig));
      await controller.applyBootstrapPayload(bootstrap);
      await controller.registerDeviceLocally(
        deviceId: deviceId,
        make: posDeviceMake(prefs),
        model: posDeviceModel(prefs),
        lat: 0,
        lan: 0,
      );

      completed.add('success');
      emit(state.copyWith(
        isSubmitting: false,
        isSuccess: true,
        companyIdentifier: result.companyIdentifier,
        orgInstanceId: result.orgInstanceId,
        completedProgressIds: completed,
        activeProgressId: null,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        isSuccess: false,
        errorMessage: _friendlyError(e),
        errorCode: e is SignupApiException ? e.code : null,
        clearActiveProgress: true,
      ));
    }
  }

  String _friendlyError(Object e) {
    if (e is SignupApiException) {
      return switch (e.code) {
        'parent_not_found' =>
          'We could not find that parent organisation. Check the identifier and try again.',
        'user_exists' => e.message,
        'invalid_password' => e.message,
        'invalid_email' => 'Please enter a valid email address.',
        'invalid_phone' => 'Please enter a valid phone number.',
        'invalid_country' => 'Please select a valid country.',
        'missing_fields' => e.message,
        _ => e.message,
      };
    }
    return e
        .toString()
        .replaceFirst(RegExp(r'^(Bad state|StateError|Exception): '), '');
  }

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
        model = info.prettyName.isNotEmpty
            ? info.prettyName
            : (info.versionId ?? 'Desktop');
        deviceId = info.machineId ?? '';
      } else {
        make = 'unknown';
        model = 'POS Desktop';
      }

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
}
