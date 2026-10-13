part of 'store.dart';

class StoreOrdersService {
  final Store _store;

  StoreOrdersService._(this._store);

  Future<List<StoreOrderSummary>> listSummaries(
    StoreScope scope, {
    String? pricingMode,
  }) => _store._listOrderSummaries(scope, pricingMode: pricingMode);

  Future<int> getServeNumberMaximum(StoreScope scope) =>
      _store._getServeNumberMaximum(scope);

  Future<void> setServeNumberMaximum(StoreScope scope, int maximum) =>
      _store._setServeNumberMaximum(scope, maximum);

  Future<StoreOrderDetails?> getById(StoreScope scope, int orderId) =>
      _store._getOrderDetails(scope, orderId);

  Future<StoreOrderDetails?> details(StoreScope scope, int orderId) =>
      _store._getOrderDetails(scope, orderId);

  Future<int> create(StoreScope scope, StoreCreateOrderRequest request) =>
      _store._createOrder(scope, request);

  Future<int> updateStatus(StoreScope scope, int orderId, String status) {
    return _store._updateOrderStatus(scope, orderId, status);
  }

  Future<int> updatePaymentStatus(
    StoreScope scope,
    int orderId,
    String paymentStatus,
  ) {
    return _store._updateOrderPaymentStatus(scope, orderId, paymentStatus);
  }

  Future<bool> alignPricingMode(
    StoreScope scope,
    int orderId,
    String pricingMode,
  ) {
    return _store._alignOrderPricingMode(scope, orderId, pricingMode);
  }

  /// Overrides order money columns after checkout adjustments (tips / tax / etc.).
  Future<int> setAmounts(
    StoreScope scope,
    int orderId, {
    required double totalValue,
    required double offerAppliedValue,
    required double finalValue,
  }) {
    return _store._setOrderAmounts(
      scope,
      orderId,
      totalValue: totalValue,
      offerAppliedValue: offerAppliedValue,
      finalValue: finalValue,
    );
  }

  Future<int> close(StoreScope scope, int orderId, {String status = 'Closed'}) {
    return _store._closeOrder(scope, orderId, status: status);
  }

  Future<void> importFromJsonFile(StoreScope scope, String filePath) {
    return _store._importOrdersFromJsonFile(scope, filePath);
  }

  Future<List<StoreOrderItemRecord>> listItems(StoreScope scope, int orderId) {
    return _store._getOrderItemRecords(scope, orderId);
  }

  Future<List<StoreOrderItemAddonRecord>> listItemAddons(
    StoreScope scope,
    int itemId,
  ) {
    return _store._getOrderItemAddonRecords(scope, itemId);
  }

  Future<List<StoreOrderPaymentRecord>> listPayments(
    StoreScope scope,
    int orderId,
  ) {
    return _store._getOrderPaymentRecords(scope, orderId);
  }

  Future<List<StoreOrderRefundRecord>> listRefunds(
    StoreScope scope, {
    int? orderId,
  }) {
    return _store._getOrderRefundRecords(scope, orderId: orderId);
  }

  Future<List<StoreKitchenCancellationRecord>> listKitchenCancellations(
    StoreScope scope,
    int orderId,
  ) {
    return _store._getKitchenCancellationRecords(scope, orderId);
  }

  Future<int> addItem(
    StoreScope scope,
    StoreAddOrderItemRequest request, {
    bool refreshTotals = true,
    bool recalculateItemPricing = true,
  }) {
    return _store._createOrderItem(
      scope,
      request,
      refreshTotals: refreshTotals,
      recalculateItemPricing: recalculateItemPricing,
    );
  }

  /// Recomputes order totals from items/offers once (after a batch of addItem).
  Future<Map<String, double>> refreshTotals(StoreScope scope, int orderId) {
    return _store._refreshOrderTotals(scope, orderId);
  }

  Future<int> addItemAddon(
    StoreScope scope,
    StoreAddOrderItemAddonRequest request,
  ) {
    return _store._createOrderItemAddon(scope, request);
  }

  Future<int> updateItemQuantity(StoreScope scope, int itemId, int quantity) {
    return _store._updateOrderItemQuantity(scope, itemId, quantity);
  }

  Future<int> deleteItem(StoreScope scope, int itemId) {
    return _store._deleteOrderItem(scope, itemId);
  }

  Future<int> deleteItemAddon(StoreScope scope, int addonId) {
    return _store._deleteOrderItemAddon(scope, addonId);
  }

  Future<int> addPayment(
    StoreScope scope,
    int orderId,
    StoreCreateOrderPaymentRequest request,
  ) {
    return _store._addOrderPayment(scope, request, orderId);
  }

  Future<int> addRefund(
    StoreScope scope,
    int orderId,
    StoreCreateOrderRefundRequest request,
  ) {
    return _store._addOrderRefund(scope, orderId, request);
  }

  Future<void> deleteDraft(StoreScope scope, int orderId) {
    return _store._deleteDraftOrder(scope, orderId);
  }
}
