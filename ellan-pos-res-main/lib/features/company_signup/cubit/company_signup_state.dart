import '../data/signup_api.dart';

enum CompanySignupStep {
  serverParent,
  country,
  account,
  verification,
  plan,
  setup,
  progress,
}

class CompanySignupState {
  final CompanySignupStep step;
  final String serverUrl;
  final String parentOrgIdentifier;
  final String parentOrgName;
  final String companyName;
  final String ownerName;
  final String email;
  final String phoneNumber;
  final String countryId;
  final String password;
  final String businessType;
  final String packageKey;
  final String billingInterval;
  final String planCurrency;
  final String branchName;
  final String city;
  final String registrationNumber;
  final List<SignupCountry> countries;
  final List<SignupBusinessType> businessTypes;
  final bool isLoadingMeta;
  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;
  final String? errorCode;
  final String? companyIdentifier;
  final String? orgInstanceId;
  final List<String> completedProgressIds;
  final String? activeProgressId;

  const CompanySignupState({
    this.step = CompanySignupStep.serverParent,
    this.serverUrl = '',
    this.parentOrgIdentifier = '',
    this.parentOrgName = '',
    this.companyName = '',
    this.ownerName = '',
    this.email = '',
    this.phoneNumber = '',
    this.countryId = '',
    this.password = '',
    this.businessType = 'restaurant',
    this.packageKey = '',
    this.billingInterval = 'monthly',
    this.planCurrency = '',
    this.branchName = '',
    this.city = '',
    this.registrationNumber = '',
    this.countries = const [],
    this.businessTypes = const [],
    this.isLoadingMeta = false,
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
    this.errorCode,
    this.companyIdentifier,
    this.orgInstanceId,
    this.completedProgressIds = const [],
    this.activeProgressId,
  });

  bool get canContinueServerParent =>
      serverUrl.trim().isNotEmpty && parentOrgIdentifier.trim().isNotEmpty;

  bool get canContinueCompanyDetails =>
      companyName.trim().isNotEmpty &&
      ownerName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      countryId.trim().isNotEmpty &&
      password.trim().length >= 6;

  bool get canContinuePlan => packageKey.trim().isNotEmpty;

  bool get canSubmitBranch =>
      businessType.trim().isNotEmpty &&
      branchName.trim().isNotEmpty &&
      city.trim().isNotEmpty;

  SignupCountry? get selectedCountry {
    for (final country in countries) {
      if (country.id == countryId) return country;
    }
    return null;
  }

  CompanySignupState copyWith({
    CompanySignupStep? step,
    String? serverUrl,
    String? parentOrgIdentifier,
    String? parentOrgName,
    String? companyName,
    String? ownerName,
    String? email,
    String? phoneNumber,
    String? countryId,
    String? password,
    String? businessType,
    String? packageKey,
    String? billingInterval,
    String? planCurrency,
    String? branchName,
    String? city,
    String? registrationNumber,
    List<SignupCountry>? countries,
    List<SignupBusinessType>? businessTypes,
    bool? isLoadingMeta,
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
    String? companyIdentifier,
    String? orgInstanceId,
    List<String>? completedProgressIds,
    String? activeProgressId,
    bool clearActiveProgress = false,
  }) {
    return CompanySignupState(
      step: step ?? this.step,
      serverUrl: serverUrl ?? this.serverUrl,
      parentOrgIdentifier: parentOrgIdentifier ?? this.parentOrgIdentifier,
      parentOrgName: parentOrgName ?? this.parentOrgName,
      companyName: companyName ?? this.companyName,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryId: countryId ?? this.countryId,
      password: password ?? this.password,
      businessType: businessType ?? this.businessType,
      packageKey: packageKey ?? this.packageKey,
      billingInterval: billingInterval ?? this.billingInterval,
      planCurrency: planCurrency ?? this.planCurrency,
      branchName: branchName ?? this.branchName,
      city: city ?? this.city,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      countries: countries ?? this.countries,
      businessTypes: businessTypes ?? this.businessTypes,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      companyIdentifier: companyIdentifier ?? this.companyIdentifier,
      orgInstanceId: orgInstanceId ?? this.orgInstanceId,
      completedProgressIds: completedProgressIds ?? this.completedProgressIds,
      activeProgressId: clearActiveProgress
          ? null
          : (activeProgressId ?? this.activeProgressId),
    );
  }
}
