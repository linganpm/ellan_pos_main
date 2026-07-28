import 'package:equatable/equatable.dart';

class ForgotPasswordState extends Equatable {
  final String identifier; // Email or Mobile Number
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const ForgotPasswordState({
    this.identifier = '',
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  bool get isValid => identifier.trim().isNotEmpty;

  ForgotPasswordState copyWith({
    String? identifier,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return ForgotPasswordState(
      identifier: identifier ?? this.identifier,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [identifier, isLoading, errorMessage, isSuccess];
}
