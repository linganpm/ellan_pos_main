import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/features/store/data/repositories/store_repository_impl.dart';
import 'package:pos_tablet/features/store/domain/usecases/initialize_store.dart';
import 'package:pos_tablet/features/store/presentation/bloc/store_bloc.dart';
// ...existing code...

final GetIt getIt = GetIt.instance;

/// Initialize and register application-wide singletons and factories.
/// Call this once during app startup before runApp.
Future<void> initServiceLocator({required SharedPreferences prefs}) async {
  // Register SharedPreferences singleton
  if (!getIt.isRegistered<SharedPreferences>()) {
    getIt.registerSingleton<SharedPreferences>(prefs);
  }

  // Register UiStoreController as a singleton so only one instance exists
  if (!getIt.isRegistered<UiStoreController>()) {
    getIt.registerLazySingleton<UiStoreController>(() => UiStoreController());
  }

  // Repository that wraps UiStoreController functionality
  if (!getIt.isRegistered<StoreRepositoryImpl>()) {
    getIt.registerLazySingleton<StoreRepositoryImpl>(() =>
        StoreRepositoryImpl(getIt<UiStoreController>(), getIt<SharedPreferences>()));
  }

  // Register use-cases
  if (!getIt.isRegistered<InitializeStore>()) {
    getIt.registerLazySingleton<InitializeStore>(() => InitializeStore(getIt<StoreRepositoryImpl>()));
  }

  // Register StoreBloc as a singleton (global app state)
  if (!getIt.isRegistered<StoreBloc>()) {
    getIt.registerLazySingleton<StoreBloc>(() => StoreBloc(
          initializeStore: getIt<InitializeStore>(),
          repository: getIt<StoreRepositoryImpl>(),
        ));
  }

  // Note: the legacy StoreRepository class was removed in favor of using
  // UiStoreController directly from the StoreListCubit. Do not register it.
}
