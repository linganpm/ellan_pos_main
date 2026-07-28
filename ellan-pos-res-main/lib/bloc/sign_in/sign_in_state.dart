import 'package:equatable/equatable.dart';

class SignInState extends Equatable {
  final String identifier; // Staff ID (reg number) or email
  final String password;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final bool obscurePassword;
  final bool navigateToHome;

  const SignInState({
    this.identifier = '',
    this.password = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.obscurePassword = true,
    this.navigateToHome = false
  });

  bool get isPasswordValid => password.isNotEmpty;
  bool get isValid => identifier.trim().isNotEmpty && password.isNotEmpty;

  SignInState copyWith({
    String? identifier,
    String? password,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool? obscurePassword,
    bool clearError = false,
    bool navigateToHome = false
  }) {
    return SignInState(
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }

  @override
  List<Object?> get props => [
        identifier,
        password,
        isLoading,
        errorMessage,
        isSuccess,
        obscurePassword,
      ];
}
