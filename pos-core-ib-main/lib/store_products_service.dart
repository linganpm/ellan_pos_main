part of 'store.dart';

class StoreProductsService {
  final Store _store;

  StoreProductsService._(this._store);

  Future<List<String>> listNames(StoreScope scope) => _store._listProductNames(scope);

  Future<List<int>> listCategoryIdsWithVariants(StoreScope scope) {
    return _store._listCategoryIdsWithVariants(scope);
  }

  Future<List<StoreProductCategoryRecord>> listCategories(StoreScope scope) {
    return _store._listProductCategories(scope);
  }

  Future<List<StoreProductVariantRecord>> listVariantsByCategory(StoreScope scope, int categoryId) {
    return _store._getProductVariantRecordsByCategory(scope, categoryId);
  }

  Future<List<StoreProductVariantRecord>> searchDetails({
    required StoreScope scope,
    String? query,
    int? limit,
    int? offset,
  }) {
    return _store._searchProductVariantRecords(
      scope: scope,
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<StoreProductAddonGroupRecord>> listAddonGroupsForVariant(
    StoreScope scope,
    String productVariantId,
  ) {
    return _store._getProductAddonGroupRecords(scope, productVariantId);
  }

  Future<void> importFromJson(StoreScope scope, Map<String, dynamic> data) {
    return _store._importProductsFromJson(scope, data);
  }
}