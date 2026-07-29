import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_tablet/bloc/language/language_bloc.dart';
import 'package:pos_tablet/bloc/language/language_event.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/core/localization/status_labels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLocalizations', () {
    test('English and Tamil load shared keys', () async {
      final en = lookupAppLocalizations(const Locale('en'));
      final ta = lookupAppLocalizations(const Locale('ta'));

      expect(en.appName, isNotEmpty);
      expect(ta.appName, isNotEmpty);
      expect(en.signInButton, 'Sign In');
      expect(ta.signInButton, isNot(equals(en.signInButton)));
      expect(en.homeNewOrderCount(3), contains('3'));
      expect(ta.homeNewOrderCount(3), contains('3'));
      expect(en.dineInTable('4'), contains('4'));
      expect(ta.dineInTable('4'), contains('4'));
    });

    testWidgets('MaterialApp resolves delegates for en and ta', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Text(l10n.dashboardTitle);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Text), findsOneWidget);
      }
    });
  });

  group('LanguageBloc persistence', () {
    test('restores Tamil from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        LanguageBloc.localePreferenceKey: 'ta',
      });
      final prefs = await SharedPreferences.getInstance();
      final bloc = LanguageBloc.fromPrefs(prefs);
      expect(bloc.state.locale.languageCode, 'ta');
      await bloc.close();
    });

    test('defaults to English and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = LanguageBloc.fromPrefs(prefs);
      expect(bloc.state.locale.languageCode, 'en');

      final future = bloc.stream.first;
      bloc.add(ChangeLanguageEvent(const Locale('ta')));
      final state = await future;
      expect(state.locale.languageCode, 'ta');
      expect(prefs.getString(LanguageBloc.localePreferenceKey), 'ta');
      await bloc.close();
    });
  });

  group('status labels', () {
    test('maps payment tokens without changing raw API values', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        localizedPaymentStatusLabel(l10n, 'part paid'),
        l10n.statusPartial,
      );
      expect(localizedPaymentStatusLabel(l10n, 'ORDER_COMPLETED'), isNotEmpty);
      expect(
        localizedOrderStatusLabel(l10n, 'ORDER_PENDING'),
        l10n.statusOrderPending,
      );
    });
  });
}
