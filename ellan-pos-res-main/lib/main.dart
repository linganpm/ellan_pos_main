import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, Directory;
import 'package:path_provider/path_provider.dart';

// sqflite FFI initialization for desktop (macOS, Linux, Windows)
// ensures sqlite databases can be opened when running outside mobile.
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/splash/splash_bloc.dart';
import 'bloc/user/user_bloc.dart';
import 'core/localization/l10n/app_localizations.dart';
import 'presentation/screens/splash_screen.dart';
import 'core/routes.dart';
import 'presentation/widgets/device_restriction_wrapper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bloc/language/language_bloc.dart';
import 'bloc/language/language_state.dart';
import 'core/utils/font_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/di/service_locator.dart';
import 'core/device_setup_store.dart';
import 'core/org_timezone.dart';
import 'features/store/presentation/bloc/store_bloc.dart';
import 'core/controllers/ui_store_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI on all platforms (Android, iOS, macOS, Windows, Linux)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  try {
    final appSupportDir = await getApplicationSupportDirectory();
    final dbDir = Directory('${appSupportDir.path}/databases');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    await databaseFactory.setDatabasesPath(dbDir.path);
  } catch (e) {
    debugPrint('Failed to set sqflite databases path: $e');
  }

  // Initialize SharedPreferences for app-wide access
  final prefs = await SharedPreferences.getInstance();

  // Org/store IANA zones for dashboard + clock display (vs UTC order stamps).
  OrgTimezone.ensureInitialized();

  // Restore the last-used gateway URL before any POS network helpers run.
  DeviceSetupStore(prefs).restoreActiveDiscoveryUrl();

  // Initialize service locator and register singletons
  await initServiceLocator(prefs: prefs);

  // Lock the orientation to Landscape only
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(PosTabletApp(prefs: prefs));
  });
}

class PosTabletApp extends StatelessWidget {
  final SharedPreferences prefs;

  const PosTabletApp({required this.prefs, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SharedPreferences>(
          create: (context) => prefs,
        ),
        RepositoryProvider<UiStoreController>(
          create: (context) => getIt<UiStoreController>(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SplashBloc>(
            create: (context) => SplashBloc(),
          ),
          BlocProvider<LanguageBloc>(
            create: (context) => LanguageBloc(),
          ),
           BlocProvider<UserBloc>(
             create: (context) => UserBloc(),
           ),
           // Provide the global StoreBloc from the service locator so every
           // widget can access app-level store state.
           BlocProvider<StoreBloc>(
             create: (context) => getIt<StoreBloc>(),
           ),
        ],
        child: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, languageState) {
            return MaterialApp(
              title: 'NexPOS Tablet',
              debugShowCheckedModeBanner: false,
              locale: languageState.locale,
              supportedLocales: const [
                Locale('en'),
                Locale('ta'),
              ],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A00E0)),
                useMaterial3: true,
                textTheme: TextTheme(
                  headlineMedium: FontUtility.heading,
                  bodyMedium: FontUtility.body,
                ),
              ),
              builder: (context, child) {
                // Wrap the entire app with the device restriction widget
                // This ensures that on small screens, the user is forcefully blocked.
                return DeviceRestrictionWrapper(
                  child: child ?? const SizedBox(),
                );
              },
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
