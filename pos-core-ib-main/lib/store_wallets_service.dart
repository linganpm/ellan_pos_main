part of 'store.dart';

class StoreWalletsService {
  final Store _store;

  StoreWalletsService._(this._store);

  Future<List<StoreWalletRecord>> list(
    StoreScope scope, {
    bool includeInactive = false,
    bool skipAuth = false,
  }) {
    return _store._listWalletRecords(
      scope,
      includeInactive: includeInactive,
      skipAuth: skipAuth,
    );
  }

  Future<void> importFromData(
    StoreScope scope,
    Map<String, dynamic> data, {
    bool replaceScope = false,
    bool skipAuth = false,
  }) {
    return _store._importWalletsFromData(
      scope,
      data,
      replaceScope: replaceScope,
      skipAuth: skipAuth,
    );
  }

  /// Last-synced POS payment-method catalogue for this store (may be empty).
  Future<List<Map<String, dynamic>>> listVariants(StoreScope scope) {
    return _store._listWalletVariantCatalogue(scope);
  }

  /// Persist gateway variant rows so the picker works offline after a sync.
  Future<void> saveVariants(
    StoreScope scope,
    List<Map<String, dynamic>> variants,
  ) {
    return _store._saveWalletVariantCatalogue(scope, variants);
  }

  /// Attach a catalogue variant to this branch in the local DB (offline-safe).
  Future<StoreWalletRecord> addLocalVariant(
    StoreScope scope, {
    required int variantId,
    required String label,
    String? variantName,
    int? variantType,
    int? variantPgType,
    String? paymentMode,
  }) {
    return _store._addLocalWalletVariant(
      scope,
      variantId: variantId,
      label: label,
      variantName: variantName,
      variantType: variantType,
      variantPgType: variantPgType,
      paymentMode: paymentMode,
    );
  }
}
