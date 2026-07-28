import 'package:pos_orders_offline/store.dart';
import 'package:pos_orders_offline/store_config.dart';
import 'package:pos_orders_offline/store_models.dart';

/// Abstract repository exposing store-related operations used by the domain
/// and presentation layers. Implementations should delegate to low-level
/// controllers or data sources.
abstract class StoreRepository {
  Future<StoreOrganisation?> resolveOrganisation(String orgCode);
  Future<StoreConfig> loadRemoteConfig(String orgCode);
  Future<void> bootWithConfig(StoreConfig config);
  Future<bool> login({required String orgCode, required String email, required String password});
  List<StoreAccessibleStore> accessibleStores();
}
