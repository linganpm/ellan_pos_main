import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _withOrgCurrency(Map<String, dynamic> organisation) async {
  SharedPreferences.setMockInitialValues({
    DeviceSetupStore.configJsonKey: jsonEncode({'organisation': organisation}),
  });
  await getIt.reset();
  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pos-currency-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temp.path,
        );
  });

  tearDown(() async {
    await getIt.reset();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    temp.deleteSync(recursive: true);
  });

  test('India organisation formats amounts in rupees', () async {
    await _withOrgCurrency({'currency_code': 'INR', 'currency_symbol': '₹'});
    expect(PosCurrency.symbol(storeId: '283'), '₹');
    expect(PosCurrency.format(1250.5, storeId: '283'), '₹1250.50');
    expect(PosCurrency.format(99, storeId: '283', decimals: 0), '₹99');
  });

  test('code is used when the organisation has no symbol, never \$', () async {
    await _withOrgCurrency({'currency_code': 'INR'});
    expect(PosCurrency.format(10, storeId: '283'), 'INR 10.00');
  });

  test('screens do not hardcode a dollar sign for amounts', () {
    final offenders = <String>[];
    final hardcoded = RegExp(r"""\\\$\$\{|symbol:\s*'\\\$'""");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n/app_localizations')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (hardcoded.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
