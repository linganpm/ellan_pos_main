import 'package:equatable/equatable.dart';
import 'package:pos_tablet/core/device_setup_store.dart';

class WelcomeState extends Equatable {
  final String serverUrl;
  final String organizationName;
  final List<PosServerEntry> savedServers;
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const WelcomeState({
    this.serverUrl = '',
    this.organizationName = '',
    this.savedServers = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  bool get isValid =>
      serverUrl.trim().isNotEmpty && organizationName.trim().isNotEmpty;

  WelcomeState copyWith({
    String? serverUrl,
    String? organizationName,
    List<PosServerEntry>? savedServers,
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return WelcomeState(
      serverUrl: serverUrl ?? this.serverUrl,
      organizationName: organizationName ?? this.organizationName,
      savedServers: savedServers ?? this.savedServers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [
        serverUrl,
        organizationName,
        savedServers,
        isLoading,
        errorMessage,
        isSuccess,
      ];
}
