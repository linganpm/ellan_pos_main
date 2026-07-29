import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_tablet/bloc/language/language_bloc.dart';
import 'package:pos_tablet/bloc/language/language_event.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('persists and restores preferred locale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bloc = LanguageBloc.fromPrefs(prefs);
    addTearDown(bloc.close);

    expect(bloc.state.locale.languageCode, 'en');

    bloc.add(ChangeLanguageEvent(const Locale('ta')));
    await tester.pump();
    expect(bloc.state.locale.languageCode, 'ta');
    expect(prefs.getString(LanguageBloc.localePreferenceKey), 'ta');

    final restored = LanguageBloc.fromPrefs(prefs);
    addTearDown(restored.close);
    expect(restored.state.locale.languageCode, 'ta');
  });

  testWidgets('renders English and Tamil auth labels', (tester) async {
    Future<void> pumpLocale(Locale locale) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Column(
                  children: [
                    Text(l10n.actionSignIn),
                    Text(l10n.dashboardTopProducts),
                    Text(l10n.actionCancel),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpLocale(const Locale('en'));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Top Products'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await pumpLocale(const Locale('ta'));
    expect(find.text('உள்நுழைக'), findsOneWidget);
    expect(find.text('சிறந்த பொருட்கள்'), findsOneWidget);
    expect(find.text('ரத்துசெய்'), findsOneWidget);
  });
}
