import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';

class DashboardState extends Equatable {
  final String filter;
  final bool isLoading;
  final String? errorMessage;
  final PosDashboardSnapshot snapshot;

  const DashboardState({
    required this.filter,
    required this.snapshot,
    this.isLoading = false,
    this.errorMessage,
  });

  factory DashboardState.initial() {
    return DashboardState(
      filter: 'Today',
      snapshot: PosDashboardSnapshot.empty(),
      isLoading: true,
    );
  }

  DashboardState copyWith({
    String? filter,
    bool? isLoading,
    String? errorMessage,
    PosDashboardSnapshot? snapshot,
    bool clearError = false,
  }) {
    return DashboardState(
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  List<Object?> get props => [filter, isLoading, errorMessage, snapshot];
}

class DashboardCubit extends Cubit<DashboardState> {
  final UiStoreController controller;

  DashboardCubit({UiStoreController? controller})
    : controller = controller ?? getIt<UiStoreController>(),
      super(DashboardState.initial()) {
    load(filter: 'Today');
  }

  Future<void> load({String? filter}) async {
    final nextFilter = filter ?? state.filter;
    emit(state.copyWith(filter: nextFilter, isLoading: true, clearError: true));
    try {
      final snapshot = await controller.loadDashboardSnapshot(nextFilter);
      emit(state.copyWith(isLoading: false, snapshot: snapshot));
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
          snapshot: PosDashboardSnapshot.empty(),
        ),
      );
    }
  }
}
