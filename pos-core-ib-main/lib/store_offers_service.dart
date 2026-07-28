part of 'store.dart';

class StoreOffersService {
  final Store _store;

  StoreOffersService._(this._store);

  Future<String> save(StoreScope scope, StoreSaveOfferRequest request) {
    return _store._saveOffer(scope, request);
  }

  Future<List<StoreOfferRecord>> list(StoreScope scope, {bool activeOnly = false}) {
    return _store._listOffers(scope, activeOnly: activeOnly);
  }

  Future<StoreOfferRecord?> getByLocalId(StoreScope scope, String localId) {
    return _store._getOfferByLocalId(scope, localId);
  }

  Future<int> delete(StoreScope scope, String localId) {
    return _store._deleteOffer(scope, localId);
  }

  Future<int> setActive(StoreScope scope, String localId, {required bool active}) {
    return _store._setOfferActive(scope, localId, active: active);
  }
}