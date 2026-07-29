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

  Future<List<StoreProductVariantRecord>> listVariantsByCategoryLocalId(
    StoreScope scope,
    String categoryLocalId,
  ) {
    return _store._getProductVariantRecordsByCategoryLocalId(scope, categoryLocalId);
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

  /// Resolves a variant by `unique_id`, `localId`, or numeric `variantId`.
  Future<StoreProductVariantRecord?> findVariantById(
    StoreScope scope,
    String productVariantId,
  ) {
    return _store._findProductVariantRecordById(scope, productVariantId);
  }

  Future<StoreProductCategoryRecord?> findCategoryById(
    StoreScope scope,
    String categoryId,
  ) {
    return _store._findProductCategoryRecordById(scope, categoryId);
  }

  Future<void> importFromJson(StoreScope scope, Map<String, dynamic> data) {
    return _store._importProductsFromJson(scope, data);
  }

  /// Tenant master categories (shared across branches). Offline-capable.
  Future<List<Map<String, dynamic>>> listMasterCategories() {
    return _store._listMasterCategories();
  }

  Future<Map<String, dynamic>> createMasterCategory({
    required String name,
    String? shortCode,
  }) {
    return _store._upsertMasterCategory(name: name, shortCode: shortCode);
  }

  Future<Map<String, dynamic>> linkMasterCategory({
    required StoreScope scope,
    required String masterLocalId,
  }) {
    return _store._linkMasterCategoryToStore(
      scope: scope,
      masterLocalId: masterLocalId,
    );
  }

  Future<Map<String, dynamic>> createSellableItem({
    required StoreScope scope,
    required String categoryLocalId,
    required String productName,
    required String packageName,
    required double sellPrice,
    required String unitLabel,
    required double unitQty,
    String? taxLabel,
    String? description,
  }) {
    return _store._createLocalSellableItem(
      scope: scope,
      categoryLocalId: categoryLocalId,
      productName: productName,
      packageName: packageName,
      sellPrice: sellPrice,
      unitLabel: unitLabel,
      unitQty: unitQty,
      taxLabel: taxLabel,
      description: description,
    );
  }

  Future<void> updateVariant({
    required StoreScope scope,
    required String variantLocalId,
    String? packageName,
    String? productName,
    double? sellPrice,
    String? unitLabel,
    double? unitQty,
    String? taxLabel,
    String? description,
  }) {
    return _store._updateLocalVariant(
      scope: scope,
      variantLocalId: variantLocalId,
      packageName: packageName,
      productName: productName,
      sellPrice: sellPrice,
      unitLabel: unitLabel,
      unitQty: unitQty,
      taxLabel: taxLabel,
      description: description,
    );
  }

  Future<void> softDeleteVariant({
    required StoreScope scope,
    required String variantLocalId,
  }) {
    return _store._softDeleteVariant(scope: scope, variantLocalId: variantLocalId);
  }

  Future<void> softDeleteCategory({
    required StoreScope scope,
    required String categoryLocalId,
  }) {
    return _store._softDeleteCategory(
      scope: scope,
      categoryLocalId: categoryLocalId,
    );
  }

  Future<void> softDeleteOffer({
    required StoreScope scope,
    required String offerLocalId,
  }) {
    return _store._softDeleteOffer(scope: scope, offerLocalId: offerLocalId);
  }

  Future<void> softDeleteAddonGroup({
    required StoreScope scope,
    required String groupLocalId,
  }) {
    return _store._softDeleteAddonGroup(scope: scope, groupLocalId: groupLocalId);
  }

  Future<void> renameCategory({
    required StoreScope scope,
    required String categoryLocalId,
    required String name,
  }) {
    return _store._renameCategory(
      scope: scope,
      categoryLocalId: categoryLocalId,
      name: name,
    );
  }

  Future<List<Map<String, dynamic>>> listMasterProducts() {
    return _store._listMasterProducts();
  }

  Future<Map<String, dynamic>> linkMasterProduct({
    required StoreScope scope,
    required String masterLocalId,
    required String categoryLocalId,
  }) {
    return _store._linkMasterProductToStore(
      scope: scope,
      masterLocalId: masterLocalId,
      categoryLocalId: categoryLocalId,
    );
  }

  Future<Map<String, dynamic>> upsertOffer({
    required StoreScope scope,
    String? localId,
    required String name,
    required String offerType,
    double? percentageValue,
    double? flatValue,
    double? minimumBillAmount,
    String? description,
    List<String> targetVariantLocalIds = const [],
  }) {
    return _store._upsertLocalOffer(
      scope: scope,
      localId: localId,
      name: name,
      offerType: offerType,
      percentageValue: percentageValue,
      flatValue: flatValue,
      minimumBillAmount: minimumBillAmount,
      description: description,
      targetVariantLocalIds: targetVariantLocalIds,
    );
  }

  Future<List<Map<String, dynamic>>> listOffers(StoreScope scope) {
    return _store._listLocalOffers(scope);
  }

  Future<List<String>> listOfferTargetVariantIds(
    StoreScope scope,
    String offerLocalId,
  ) {
    return _store._listOfferTargetVariantIds(scope, offerLocalId);
  }

  /// Link / unlink [variantLocalId] across the selected offers.
  Future<void> setVariantOfferLinks({
    required StoreScope scope,
    required String variantLocalId,
    required Set<String> selectedOfferLocalIds,
  }) {
    return _store._setVariantOfferLinks(
      scope: scope,
      variantLocalId: variantLocalId,
      selectedOfferLocalIds: selectedOfferLocalIds,
    );
  }

  Future<Map<String, dynamic>> upsertAddonGroup({
    required StoreScope scope,
    String? localId,
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
    List<({String name, double price})> items = const [],
  }) {
    return _store._upsertAddonGroup(
      scope: scope,
      localId: localId,
      name: name,
      minSelect: minSelect,
      maxSelect: maxSelect,
      items: items,
    );
  }

  Future<void> linkAddonGroup({
    required StoreScope scope,
    required String variantLocalId,
    required String groupLocalId,
  }) {
    return _store._linkAddonGroupToVariant(
      scope: scope,
      variantLocalId: variantLocalId,
      groupLocalId: groupLocalId,
    );
  }

  Future<List<Map<String, dynamic>>> listCatalogAddonGroups(StoreScope scope) {
    return _store._listAddonGroups(scope);
  }

  Future<List<Map<String, dynamic>>> listCatalogAddonItems(
    StoreScope scope,
    String groupLocalId,
  ) {
    return _store._listAddonItemsForGroup(scope, groupLocalId);
  }
}
