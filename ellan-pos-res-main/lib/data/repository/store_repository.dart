import '../models/store_model.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository responsible for store data operations.
/// 
/// Currently provides dummy store data for testing and demonstration.
/// In production, this would integrate with a backend API to fetch
/// the actual list of stores available to the user.
abstract class IStoreRepository {
  /// Fetches the list of available stores
  /// 
  /// Returns a list of [StoreModel] representing all stores
  /// accessible to the current user.
  Future<List<StoreModel>> getAvailableStores();

  /// Verifies that a selected store is valid and user has access
  /// 
  /// Parameters:
  ///   - storeId: The ID of the store to verify
  /// 
  /// Returns true if store verification is successful
  Future<bool> verifyStore(String storeId);
}

/// Concrete implementation of IStoreRepository
class StoreRepository implements IStoreRepository {
  @override
  Future<List<StoreModel>> getAvailableStores() async {
    try {
      // Get the global UiStoreController instance from the service locator
      final controller = getIt<UiStoreController>();

      // Fetch accessible stores from the authenticated user's session
      final accessibleStores = controller.accessibleStores();

      // Convert StoreAccessibleStore objects to StoreModel objects for UI consumption
      final stores = accessibleStores
          .map((store) => StoreModel(
                storeId: store.store.storeId,
                storeName: store.store.storeName,
                storeRole: store.store.contactPerson, // Default role - actual role may come from API
              ))
          .toList();

      return stores;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> verifyStore(String storeId) async {
    if (storeId.isEmpty) return false;

    try {
      // Simulate verification API call (replace with real backend validation)
      await Future.delayed(const Duration(seconds: 1));

      // Get the global UiStoreController instance from the service locator
      final controller = getIt<UiStoreController>();

      await controller.openStore(storeId);

      // In a real app, call this when connectivity resumes or before starting sync.
      await controller.refreshAccessControl();

      final storeAccess = await controller.currentStoreAccess();
      if (storeAccess == null || !storeAccess.accessEnabled) {
        throw StateError('Customer does not have access to the selected store.');
      }
      // Persist the selected store id so other features can reference it
      final prefs = getIt<SharedPreferences>();
      await prefs.setString('selectedStoreId', storeId);

      return true;
    } catch (e) {
      rethrow;
    }
  }
}

