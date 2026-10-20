import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pos_tablet/core/localization/l10n/app_localizations.dart';
import 'package:pos_tablet/presentation/screens/sign_in_screen.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('branded sign-in fits phone and tablet orientations', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    addTearDown(tester.view.reset);
    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(768, 1024),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepositoryProvider<SharedPreferences>.value(
          value: prefs,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SignInScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PosBrandLogo), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Sign in at $size');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('bundled artwork decodes offline at full resolution', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(PosBrandLogo.assetPath);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1254);
      expect(frame.image.height, 1254);
      frame.image.dispose();
      codec.dispose();
    });
  });

  for (final size in [40.0, 72.0, 80.0, 112.0, 180.0]) {
    testWidgets('logo preserves artwork and semantics at $size pixels', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: PosBrandLogo(size: size)),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(PosBrandLogo.assetPath),
          tester.element(find.byType(PosBrandLogo)),
        );
      });
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(tester.getSize(find.byType(Image)), Size.square(size));
      expect(find.bySemanticsLabel('EllanPOS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('generated launcher icons have required platform dimensions', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final expected = <String, int>{
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
        'web/favicon.png': 16,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
      };
      const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
      final contents =
          jsonDecode(await File('$iosDirectory/Contents.json').readAsString())
              as Map<String, dynamic>;
      for (final entry in contents['images'] as List<dynamic>) {
        final icon = entry as Map<String, dynamic>;
        final points = double.parse((icon['size'] as String).split('x').first);
        final scale = double.parse(
          (icon['scale'] as String).replaceAll('x', ''),
        );
        expected['$iosDirectory/${icon['filename']}'] = (points * scale)
            .round();
      }
      for (final entry in expected.entries) {
        final codec = await ui.instantiateImageCodec(
          await File(entry.key).readAsBytes(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, entry.value, reason: entry.key);
        expect(frame.image.height, entry.value, reason: entry.key);
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
