import 'package:flutter_bloc/flutter_bloc.dart';
import 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit() : super(const ForgotPasswordState());

  void identifierChanged(String value) {
    emit(state.copyWith(identifier: value, clearError: true));
  }

  Future<void> submit() async {
    if (!state.isValid || state.isLoading) return;

    emit(state.copyWith(isLoading: true, clearError: true));

    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));

    // Success simulation
    emit(state.copyWith(isLoading: false, isSuccess: true));
  }
}
