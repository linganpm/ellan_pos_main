// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform, Directory;

import 'package:pos_tablet/main.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Initialize sqflite FFI on all platforms for testing
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Ensure a writable directory exists for the test and configure the factory to use it
      try {
        final tempDir = Directory.systemTemp.path;
        final appDir = Directory('$tempDir/pos_tablet_db');
        if (!appDir.existsSync()) {
          appDir.createSync(recursive: true);
        }
        await databaseFactory.setDatabasesPath(appDir.path);
      } catch (_) {
        // Continue if directory creation fails
      }
    } catch (_) {
      // Continue if FFI initialization fails
    }

    // Provide mock SharedPreferences for the widget test
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Initialize the service locator before building the app
    await initServiceLocator(prefs: prefs);

    // Build our app and trigger a frame.
    await tester.pumpWidget(PosTabletApp(prefs: prefs));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
