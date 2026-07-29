import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/first_launch.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
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

  /// Snapshot used by the UI while verification is in progress / failed.
  List<StoreModel> get allStores => List.unmodifiable(_allStores);

  String? get selectedStoreId => _selectedStoreId;

  void _emitLoaded({List<StoreModel>? filteredStores}) {
    emit(StoreListLoaded(
      stores: _allStores,
      selectedStoreId: _selectedStoreId,
      filteredStores: filteredStores,
    ));
  }

  /// Loads available stores from the UiStoreController
  Future<void> loadStores() async {
    emit(const StoreListLoading());
    try {
      if (controller.accessibleStores().isEmpty) {
        await controller.restoreOrganisationLoginFromCache();
      }
      _allStores = controller.accessibleStores().map((s) => StoreModel(
            storeId: s.store.storeId,
            storeName: s.store.storeName,
            storeRole: s.store.contactPerson,
          )).toList();

      if (_allStores.isEmpty) {
        emit(const StoreListError(
          errorMessage:
              'No stores available for this login. Sign in online again, '
              'or ask an admin to grant store access.',
        ));
        return;
      }

      _emitLoaded();
    } catch (e) {
      emit(StoreListError(
        errorMessage: 'Failed to load stores: ${userFacingError(e)}',
      ));
    }
  }

  /// Select a store by id — keeps [StoreListLoaded] so the list never blanks.
  void selectStore(String storeId) {
    StoreModel? selectedStore;
    for (final store in _allStores) {
      if (store.storeId == storeId) {
        selectedStore = store;
        break;
      }
    }

    if (selectedStore == null) {
      emit(const StoreVerificationFailure(
        errorMessage: 'Selected store not found',
      ));
      _emitLoaded();
      return;
    }

    _selectedStoreId = storeId;
    final filtered = state is StoreListLoaded
        ? (state as StoreListLoaded).filteredStores
        : null;
    _emitLoaded(filteredStores: filtered);
  }

  /// Verify the currently selected store
  Future<void> verifySelectedStore() async {
    if (_selectedStoreId == null || _selectedStoreId!.isEmpty) {
      emit(const StoreVerificationFailure(
        errorMessage: 'Please select a store first',
      ));
      _emitLoaded();
      return;
    }

    StoreModel? selectedStore;
    for (final store in _allStores) {
      if (store.storeId == _selectedStoreId) {
        selectedStore = store;
        break;
      }
    }

    if (selectedStore == null) {
      emit(const StoreVerificationFailure(
        errorMessage: 'Selected store not found',
      ));
      _emitLoaded();
      return;
    }

    final store = selectedStore;
    emit(StoreVerificationLoading(store: store));

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
              store: store,
              message: _syncMessage(update),
            ),
          );
        },
      );
      await controller.refreshAccessControl();

      // Only block when access is explicitly disabled. Missing local access
      // rows (common right after company signup) must not wipe the store list.
      final storeAccess = await controller.currentStoreAccess();
      if (storeAccess != null && !storeAccess.accessEnabled) {
        throw StateError(
          'You do not have access to the selected store. '
          'Ask an administrator to enable access, then try again.',
        );
      }

      await controller.persistSelectedStore(
        storeId: _selectedStoreId!,
        storeName: store.storeName,
      );

      emit(StoreVerificationSuccess(store: store));
    } catch (e) {
      if (isClosed) return;
      emit(StoreVerificationFailure(
        errorMessage: userFacingError(
          e,
          fallback: 'Failed to open store. Check your connection and try again.',
        ),
        store: store,
      ));
      // Restore the selectable list so the operator can retry another store.
      _emitLoaded();
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
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      _emitLoaded();
      return;
    }

    final filtered = _allStores
        .where(
          (s) =>
              s.storeName.toLowerCase().contains(q) ||
              s.storeId.toLowerCase().contains(q),
        )
        .toList();
    _emitLoaded(filteredStores: filtered);
  }
}
