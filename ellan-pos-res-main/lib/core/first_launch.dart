import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/ui_store_controller.dart';
import 'device_setup_store.dart';

/// Opens [storeId] and pulls its whole catalogue (products, tables, credits,
/// customers) from the remote in a single pass.
///
/// Catalogue data is per store, so this runs on every store selection rather
/// than only on first launch. A store that was synced before keeps working
/// from its on-device copy when the pull fails; a store that has never been
/// synced cannot open offline.
Future<void> openStoreAndSyncCatalogue({
  required SharedPreferences prefs,
  required UiStoreController controller,
  required String storeId,
  void Function(StoreSyncProgressUpdate update)? onProgress,
}) async {
  final setupStore = DeviceSetupStore(prefs);
  await controller.openStore(storeId);

  final hasLocalCatalogue = setupStore.isCatalogSyncedForStore(storeId);
  try {
    await controller.initialCatalogSync(onProgress: onProgress);
  } catch (error) {
    if (hasLocalCatalogue) {
      return;
    }
    throw StateError(
      'Catalogue sync needs an internet connection the first time a store is '
      'opened. Please connect and try again. ($error)',
    );
  }

  await setupStore.markCatalogSyncedForStore(storeId);
  await setupStore.sealOfflineAfterCatalogSync();
}
