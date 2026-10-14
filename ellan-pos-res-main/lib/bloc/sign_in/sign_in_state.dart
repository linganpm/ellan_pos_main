import 'package:equatable/equatable.dart';

class SignInState extends Equatable {
  final String companyCode;
  final String identifier; // Staff ID (reg number) or email
  final String password;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final bool obscurePassword;
  final bool navigateToHome;

  /// Signed in online, but this staff member has no lock PIN yet.
  final bool needsPinSetup;

  const SignInState({
    this.companyCode = '',
    this.identifier = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.obscurePassword = true,
    this.navigateToHome = false,
    this.needsPinSetup = false,
  });

  bool get isPasswordValid => password.isNotEmpty;
  bool get isValid =>
      companyCode.trim().isNotEmpty &&
      identifier.trim().isNotEmpty &&
      password.isNotEmpty;

  SignInState copyWith({
    String? companyCode,
    String? identifier,
    String? password,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool? obscurePassword,
    bool clearError = false,
    bool navigateToHome = false,
    bool? needsPinSetup,
  }) {
    return SignInState(
      companyCode: companyCode ?? this.companyCode,
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      needsPinSetup: needsPinSetup ?? this.needsPinSetup,
    );
  }

  @override
  List<Object?> get props => [
    companyCode,
    identifier,
    password,
    isLoading,
    errorMessage,
    isSuccess,
    obscurePassword,
    needsPinSetup,
  ];
}
