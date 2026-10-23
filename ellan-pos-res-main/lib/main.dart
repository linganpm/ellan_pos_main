import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// sqflite FFI initialization for desktop / mobile; web uses ffi_web.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/splash/splash_bloc.dart';
import 'bloc/user/user_bloc.dart';
import 'core/localization/l10n/app_localizations.dart';
import 'presentation/screens/splash_screen.dart';
import 'core/routes.dart';
import 'bloc/language/language_bloc.dart';
import 'bloc/language/language_state.dart';
import 'core/pos_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/service_locator.dart';
import 'core/device_settings_store.dart';
import 'core/device_setup_store.dart';
import 'core/constants/discovery_constants.dart';
import 'core/org_timezone.dart';
import 'core/order_list_route_observer.dart';
import 'features/store/presentation/bloc/store_bloc.dart';
import 'core/controllers/ui_store_controller.dart';
import 'presentation/widgets/app_layout_viewport.dart';

import 'main_io_stub.dart' if (dart.library.io) 'main_io.dart' as io_support;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Server URL + root org id from `.env` (see `.env.example`).
  await loadPosDiscoveryEnv();

  if (kIsWeb) {
    // Browser builds need the WASM/web SQLite factory.
    databaseFactory = databaseFactoryFfiWeb;
  } else {
    // Initialize sqflite FFI on Android, iOS, macOS, Windows, Linux
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    try {
      await io_support.configureSqfliteDatabasesPath(databaseFactory);
    } catch (e) {
      debugPrint('Failed to set sqflite databases path: $e');
    }
  }

  // Initialize SharedPreferences for app-wide access
  final prefs = await SharedPreferences.getInstance();

  // Org/store IANA zones for dashboard + clock display (vs UTC order stamps).
  OrgTimezone.ensureInitialized();

  // Restore the last-used gateway URL before any POS network helpers run.
  DeviceSetupStore(prefs).restoreActiveDiscoveryUrl();

  // Initialize service locator and register singletons
  await initServiceLocator(prefs: prefs);

  // Landscape unless Device Settings chooses portrait or automatic.
  await DeviceSettingsStore(prefs).applySavedOrientation();

  runApp(PosTabletApp(prefs: prefs));
}

class PosTabletApp extends StatelessWidget {
  final SharedPreferences prefs;

  const PosTabletApp({required this.prefs, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>(create: (context) => prefs),
        RepositoryProvider<UiStoreController>(
          create: (context) => getIt<UiStoreController>(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SplashBloc>(create: (context) => SplashBloc()),
          BlocProvider<LanguageBloc>(
            create: (context) => LanguageBloc.fromPrefs(prefs),
          ),
          BlocProvider<UserBloc>(create: (context) => UserBloc()),
          // Provide the global StoreBloc from the service locator so every
          // widget can access app-level store state.
          BlocProvider<StoreBloc>(create: (context) => getIt<StoreBloc>()),
        ],
        child: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, languageState) {
            return MaterialApp(
              title: 'EllanPos',
              debugShowCheckedModeBanner: false,
              locale: languageState.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: PosTheme.light(),
              navigatorObservers: [orderListRouteObserver],
              builder: (context, child) =>
                  AppLayoutViewport(child: child ?? const SizedBox.shrink()),
              // Register named routes for navigation across the app. The splash
              // screen remains the initial entry point (home) and can navigate
              // using the named routes defined in AppRoutes.
              routes: AppRoutes.routes,
              onGenerateRoute: AppRoutes.generate,
              home: const SplashScreen(),
            );
          },
        ),
      ),
    );
  }
}
