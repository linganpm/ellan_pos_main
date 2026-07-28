import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Formats money using the organisation currency symbol (never invents `$`).
class PosCurrency {
  PosCurrency._();

  static String symbol({String? storeId}) {
    try {
      final sid = (storeId ??
              getIt<UiStoreController>().store?.scope.storeId ??
              getIt<UiStoreController>().store?.storeId ??
              '')
          .trim();
      return DeviceSetupStore(getIt<SharedPreferences>())
          .currencySymbolForStore(sid.isEmpty ? null : sid);
    } catch (_) {
      return '';
    }
  }

  static String format(num amount, {String? storeId, int decimals = 2}) {
    final value = amount.toDouble().toStringAsFixed(decimals);
    final sym = symbol(storeId: storeId).trim();
    if (sym.isEmpty) return value;
    // Codes like INR/GBP sit before the amount with a space; symbols stick.
    final isCode = RegExp(r'^[A-Za-z]{2,4}$').hasMatch(sym);
    return isCode ? '$sym $value' : '$sym$value';
  }
}
