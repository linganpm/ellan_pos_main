import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/first_launch.dart';
import '../../data/models/store_model.dart';
import 'store_list_state.dart';

/// Cubit-based implementation for store list management.
///
/// Replaces the previous Bloc + repository approach by calling
/// UiStoreController directly (via GetIt) and handling all logic
/// inside the Cubit.
class StoreListCubit extends Cubit<StoreListState> {
  final UiStoreController controller;

  // Holds the list of all available stores
  List<StoreModel> _allStores = [];

  // Currently selected store id
  String? _selectedStoreId;

  StoreListCubit()
      : controller = getIt<UiStoreController>(),
        super(const StoreListInitial());

  /// Loads available stores from the UiStoreController
  Future<void> loadStores() async {
    emit(const StoreListLoading());
    try {
      _allStores = controller.accessibleStores().map((s) => StoreModel(
            storeId: s.store.storeId,
            storeName: s.store.storeName,
            storeRole: s.store.contactPerson,
          )).toList();

      if (_allStores.isEmpty) {
        emit(const StoreListError(errorMessage: 'No stores available. Please contact support.'));
        return;
      }

      emit(StoreListLoaded(stores: _allStores, selectedStoreId: _selectedStoreId));
    } catch (e) {
      emit(StoreListError(errorMessage: 'Failed to load stores: ${e.toString()}'));
    }
  }

  /// Select a store by id
  void selectStore(String storeId) {
    _selectedStoreId = storeId;

    final selectedStore = _allStores.firstWhere(
      (store) => store.storeId == storeId,
      orElse: () => const StoreModel(storeId: '', storeName: '', storeRole: ''),
    );

    if (selectedStore.storeId.isEmpty) {
      emit(const StoreListError(errorMessage: 'Selected store not found'));
      return;
    }

    if (state is StoreListLoaded) {
      final current = state as StoreListLoaded;
      emit(StoreListLoaded(
        stores: current.stores,
        selectedStoreId: _selectedStoreId,
        filteredStores: current.filteredStores,
      ));
    } else {
      emit(StoreListLoaded(stores: _allStores, selectedStoreId: _selectedStoreId));
    }

    emit(StoreSelectionChanged(selectedStore: selectedStore, allStores: _allStores));
  }

  /// Verify the currently selected store
  Future<void> verifySelectedStore() async {
    if (_selectedStoreId == null || _selectedStoreId!.isEmpty) {
      emit(const StoreListError(errorMessage: 'Please select a store first'));
      return;
    }

    final selectedStore = _allStores.firstWhere(
      (s) => s.storeId == _selectedStoreId,
      orElse: () => const StoreModel(storeId: '', storeName: '', storeRole: ''),
    );

    if (selectedStore.storeId.isEmpty) {
      emit(const StoreListError(errorMessage: 'Selected store not found'));
      return;
    }

    emit(StoreVerificationLoading(store: selectedStore));

    try {
      final prefs = getIt<SharedPreferences>();
      await openStoreAndSyncCatalogue(
        prefs: prefs,
        controller: controller,
        storeId: _selectedStoreId!,
        onProgress: (update) {
          if (isClosed) return;
          emit(
            StoreVerificationLoading(
              store: selectedStore,
              message: _syncMessage(update),
            ),
          );
        },
      );
      await controller.refreshAccessControl();

      final storeAccess = await controller.currentStoreAccess();
      if (storeAccess == null || !storeAccess.accessEnabled) {
        throw StateError('Customer does not have access to the selected store.');
      }

      await prefs.setString('selectedStoreId', _selectedStoreId!);

      emit(StoreVerificationSuccess(store: selectedStore));
    } catch (e) {
      emit(StoreVerificationFailure(errorMessage: 'Failed to verify store: ${e.toString()}', store: selectedStore));
    }
  }

  static const _entityLabels = <String, String>{
    'products': 'product catalogue',
    'customers': 'customers',
    'credits': 'credits',
    'tables': 'floors and tables',
    'orders': 'orders',
  };

  String _syncMessage(StoreSyncProgressUpdate update) {
    final label = _entityLabels[update.entity] ?? update.entity;
    if (update.totalCount > 0) {
      return 'Syncing $label ${update.processedCount}/${update.totalCount}';
    }
    return 'Syncing $label';
  }

  /// Search / filter stores by query
  void searchStores(String query) {
    if (state is! StoreListLoaded) return;

    final current = state as StoreListLoaded;
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      emit(StoreListLoaded(stores: current.stores, selectedStoreId: current.selectedStoreId));
      return;
    }

    final filtered = _allStores.where((s) => s.storeName.toLowerCase().contains(q) || s.storeId.toLowerCase().contains(q)).toList();
    emit(StoreListLoaded(stores: current.stores, selectedStoreId: current.selectedStoreId, filteredStores: filtered));
  }
}

