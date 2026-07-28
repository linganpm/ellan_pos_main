part of 'store.dart';

class StoreWalletsService {
  final Store _store;

  StoreWalletsService._(this._store);

  Future<List<StoreWalletRecord>> list(
    StoreScope scope, {
    bool includeInactive = false,
  }) {
    return _store._listWalletRecords(
      scope,
      includeInactive: includeInactive,
    );
  }

  Future<void> importFromData(StoreScope scope, Map<String, dynamic> data) {
    return _store._importWalletsFromData(scope, data);
  }
}
