import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/company_device_setup.dart';
import '../../../core/constants/discovery_constants.dart';
import '../../../core/controllers/ui_store_controller.dart';
import '../../../core/device_approval.dart';
import '../../../core/device_setup_store.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/offline_pos_config.dart';
import '../data/signup_api.dart';
import 'company_signup_state.dart';

class CompanySignupCubit extends Cubit<CompanySignupState> {
  CompanySignupCubit({required this.prefs, CompanySignupApi? api})
    : _api = api ?? CompanySignupApi(),
      super(
        CompanySignupState(
          serverUrl: kDefaultServerOrigin,
          parentOrgIdentifier: kDefaultRootOrgInstanceId,
        ),
      ) {
    if (kIsPosDiscoveryConfiguredByEnv) {
      unawaited(continueFromServerParent());
    }
  }

  final SharedPreferences prefs;
  final CompanySignupApi _api;

  static const progressSteps = <({String id, String labelKey})>[
    (id: 'creating_user', labelKey: 'signupProgressCreatingUser'),
    (id: 'creating_company', labelKey: 'signupProgressCreatingCompany'),
    (id: 'setting_profile', labelKey: 'signupProgressSettingProfile'),
    (id: 'setting_up_branch', labelKey: 'signupProgressSettingBranch'),
    (id: 'setting_up_account', labelKey: 'signupProgressSettingAccount'),
    (id: 'success', labelKey: 'signupProgressSuccess'),
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

  void businessTypeChanged(String value) {
    emit(state.copyWith(businessType: value, clearError: true));
  }

  void packageChanged(String value) {
    emit(state.copyWith(packageKey: value, clearError: true));
  }

  void billingIntervalChanged(String value) {
    emit(state.copyWith(billingInterval: value, clearError: true));
  }

  void planCurrencyChanged(String value) {
    emit(state.copyWith(planCurrency: value));
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
    final previous = switch (state.step) {
      CompanySignupStep.country => CompanySignupStep.serverParent,
      CompanySignupStep.account => CompanySignupStep.country,
      CompanySignupStep.verification => CompanySignupStep.account,
      CompanySignupStep.plan => CompanySignupStep.verification,
      CompanySignupStep.setup => CompanySignupStep.plan,
      CompanySignupStep.progress => CompanySignupStep.setup,
      CompanySignupStep.serverParent => null,
    };
    if (previous == null) return;
    emit(
      state.copyWith(
        step: previous,
        clearError: true,
        clearActiveProgress: state.step == CompanySignupStep.progress,
        completedProgressIds: state.step == CompanySignupStep.progress
            ? const []
            : state.completedProgressIds,
      ),
    );
  }

  void continueFromCountry() {
    if (state.countryId.trim().isEmpty) return;
    emit(state.copyWith(step: CompanySignupStep.account, clearError: true));
  }

  Future<void> continueFromServerParent() async {
    if (!state.canContinueServerParent || state.isLoadingMeta) return;

    final origin = discoveryOrigin(state.serverUrl.trim());
    setActiveDiscoveryUrl(origin);
    emit(
      state.copyWith(serverUrl: origin, isLoadingMeta: true, clearError: true),
    );

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
      var countryId = state.countryId.trim();
      if (countryId.isEmpty) {
        for (final country in meta.countries) {
          if (country.code.toUpperCase() == 'IN' ||
              country.name.toLowerCase() == 'india') {
            countryId = country.id;
            break;
          }
        }
      }
      var businessType = state.businessType.trim();
      final known = meta.businessTypes.any((type) => type.id == businessType);
      if (!known && meta.businessTypes.isNotEmpty) {
        businessType = meta.businessTypes
            .firstWhere(
              (type) => type.id == 'restaurant',
              orElse: () => meta.businessTypes.first,
            )
            .id;
      }
      emit(
        state.copyWith(
          isLoadingMeta: false,
          parentOrgName: parent.name,
          parentOrgIdentifier: parent.identifier.isNotEmpty
              ? parent.identifier
              : state.parentOrgIdentifier.trim(),
          countries: meta.countries,
          businessTypes: meta.businessTypes,
          businessType: businessType,
          countryId: countryId,
          step: CompanySignupStep.country,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMeta: false,
          errorMessage: _friendlyError(e),
          errorCode: e is SignupApiException ? e.code : null,
        ),
      );
    }
  }

  void continueFromCompanyDetails() {
    if (!state.canContinueCompanyDetails) return;
    emit(state.copyWith(step: CompanySignupStep.verification, clearError: true));
  }

  void continueFromVerification() {
    emit(state.copyWith(step: CompanySignupStep.plan, clearError: true));
  }

  void continueFromPlan() {
    emit(state.copyWith(step: CompanySignupStep.setup, clearError: true));
  }

  Future<void> submitBranchAndCreate() async {
    if (!state.canSubmitBranch || state.isSubmitting) return;

    emit(
      state.copyWith(
        step: CompanySignupStep.progress,
        isSubmitting: true,
        isSuccess: false,
        completedProgressIds: const [],
        activeProgressId: progressSteps.first.id,
        clearError: true,
      ),
    );

    try {
      await collectAndStoreDeviceInfo(prefs);
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
          'application_type': state.businessType.trim(),
          'business_type': state.businessType.trim(),
          if (state.selectedBusinessType != null &&
              state.selectedBusinessType!.variantId > 0)
            'service_variant_unique_id': state.selectedBusinessType!.variantId,
          'package_key': state.packageKey.trim(),
          'billing_interval': state.billingInterval.trim(),
          'currency': state.planCurrency.trim(),
          'branch_name': state.branchName.trim(),
          'city': state.city.trim(),
          'registration_number': state.registrationNumber.trim(),
          'device_id': deviceId,
          'make': posDeviceMake(prefs),
          'model': posDeviceModel(prefs),
        },
      );

      // A new company must not inherit the previous company's local data or
      // device settings (sync interval, cash denominations, ...).
      final controller = getIt<UiStoreController>();
      await controller.resetAllLocalData(
        keepSavedServers: false,
        preserveKeys: kDevicePreservedPrefKeys,
      );

      final completed = <String>[];
      for (final step in progressSteps) {
        if (step.id == 'success') break;
        emit(
          state.copyWith(
            activeProgressId: step.id,
            completedProgressIds: List<String>.from(completed),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
        completed.add(step.id);
        emit(
          state.copyWith(
            completedProgressIds: List<String>.from(completed),
            clearActiveProgress: true,
          ),
        );
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
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          companyIdentifier: result.companyIdentifier,
          orgInstanceId: result.orgInstanceId,
          completedProgressIds: completed,
          activeProgressId: null,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: _friendlyError(e),
          errorCode: e is SignupApiException ? e.code : null,
          clearActiveProgress: true,
        ),
      );
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
    return e.toString().replaceFirst(
      RegExp(r'^(Bad state|StateError|Exception): '),
      '',
    );
  }
}
