import '../../domain/repositories/store_repository.dart';
import 'package:pos_orders_offline/store.dart';
import 'package:pos_orders_offline/store_config.dart';

/// Use-case responsible for initializing the store context: resolving the
/// organisation (if necessary), loading remote config and booting the UI
/// controller with the retrieved configuration.
class InitializeStore {
  final StoreRepository repository;

  InitializeStore(this.repository);

  Future<StoreConfig?> call({required String orgCode}) async {
    final org = await repository.resolveOrganisation(orgCode);
    if (org == null) return null;
    final config = await repository.loadRemoteConfig(org.orgCode);
    await repository.bootWithConfig(config);
    return config;
  }
}
