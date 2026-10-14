import 'package:flutter/foundation.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/ui_store_controller.dart';
import 'di/service_locator.dart';

/// Which order flows a store uses: SELL (sales to customers), BUY (purchases
/// from suppliers), or both. Kept per store on the device so it works offline.
class StoreTradeModes {
  final bool sell;
  final bool buy;

  const StoreTradeModes({this.sell = true, this.buy = true})
    : assert(sell || buy);

  static const all = StoreTradeModes();

  /// Bumped on every save so open screens can refresh.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static String _key(String storeId) => 'storeTradeModes:$storeId';

  static StoreTradeModes load(SharedPreferences prefs, String? storeId) {
    final id = storeId?.trim() ?? '';
    if (id.isEmpty) return all;
    final raw = prefs.getStringList(_key(id));
    if (raw == null) return all;
    final sell = raw.contains(StoreOrderPricingMode.selling);
    final buy = raw.contains(StoreOrderPricingMode.buying);
    if (!sell && !buy) return all;
    return StoreTradeModes(sell: sell, buy: buy);
  }

  /// Modes for the store currently open on this tablet.
  static StoreTradeModes current() {
    return load(
      getIt<SharedPreferences>(),
      getIt<UiStoreController>().store?.scope.storeId,
    );
  }

  Future<void> save(SharedPreferences prefs, String storeId) async {
    await prefs.setStringList(_key(storeId), [
      if (sell) StoreOrderPricingMode.selling,
      if (buy) StoreOrderPricingMode.buying,
    ]);
    changes.value++;
  }

  bool get both => sell && buy;

  bool allows(String pricingMode) =>
      StoreOrderPricingMode.normalize(pricingMode) ==
          StoreOrderPricingMode.buying
      ? buy
      : sell;

  /// [pricingMode] when allowed, otherwise the store's only enabled mode.
  String coerce(String? pricingMode) {
    final mode = StoreOrderPricingMode.normalize(pricingMode);
    if (allows(mode)) return mode;
    return sell ? StoreOrderPricingMode.selling : StoreOrderPricingMode.buying;
  }
}
