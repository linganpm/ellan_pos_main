import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/store_repository_impl.dart';
import 'store_event.dart';
import 'store_state.dart';
import '../../../../../features/store/domain/usecases/initialize_store.dart';
import 'package:pos_orders_offline/store_models.dart';

/// Bloc responsible for holding global store-related state. This acts as an
/// application-level state holder for selected store, accessible stores and
/// boot/auth flows. Registered as a singleton in the service locator.
class StoreBloc extends Bloc<StoreEvent, StoreState> {
  final InitializeStore initializeStore;
  final StoreRepositoryImpl repository;

  StoreBloc({required this.initializeStore, required this.repository}) : super(StoreInitial()) {
    on<StoreInitializeEvent>(_onInitialize);
    on<StoreLoadAccessibleStoresEvent>(_onLoadAccessibleStores);
    on<StoreSelectStoreEvent>(_onSelectStore);
    on<StoreLoginEvent>(_onLogin);
  }

  Future<void> _onInitialize(StoreInitializeEvent event, Emitter<StoreState> emit) async {
    emit(StoreLoading());
    try {
      final config = await initializeStore.call(orgCode: event.orgCode);
      if (config == null) {
        emit(const StoreError('Organisation not found'));
        return;
      }
      // After initialization, load accessible stores
      add(StoreLoadAccessibleStoresEvent());
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }

  Future<void> _onLoadAccessibleStores(StoreLoadAccessibleStoresEvent event, Emitter<StoreState> emit) async {
    emit(StoreLoading());
    try {
      final stores = repository.accessibleStores();
      emit(StoreLoaded(stores: stores));
    } catch (e) {
      emit(StoreError(e.toString()));
    }
  }

  Future<void> _onSelectStore(StoreSelectStoreEvent event, Emitter<StoreState> emit) async {
    final current = state;
    if (current is StoreLoaded) {
      emit(StoreLoaded(stores: current.stores, selectedStoreId: event.storeId));
    }
  }

  Future<void> _onLogin(StoreLoginEvent event, Emitter<StoreState> emit) async {
    emit(StoreAuthInProgress());
    try {
      final success = await repository.login(orgCode: event.orgCode, email: event.email, password: event.password);
      if (success) {
        emit(StoreAuthSuccess());
      } else {
        emit(const StoreAuthFailure('Invalid credentials'));
      }
    } catch (e) {
      emit(StoreAuthFailure(e.toString()));
    }
  }
}
