part of 'store.dart';

class StoreCustomersService {
  final Store _store;

  StoreCustomersService._(this._store);

  Future<List<StoreCustomerRecord>> listRecords({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) {
    return _store._listCustomerRecords(
      scope: scope,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<StoreCustomer>> listDetails({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) {
    return _store._listCustomerDetails(
      scope: scope,
      limit: limit,
      offset: offset,
    );
  }

  /// Retail / Business Customers for the open store (Customers screen).
  Future<List<StoreCustomer>> listDirectoryDetails({
    required StoreScope scope,
    int limit = 10,
    int offset = 0,
  }) {
    return _store._listDirectoryCustomerDetails(
      scope: scope,
      limit: limit,
      offset: offset,
    );
  }

  /// Records an order's customer as a Retail (default) / Business Customer for
  /// the store so they appear in the Customers directory and sync upstream.
  /// Returns the local customerId, or null when name/phone are missing.
  Future<String?> recordDirectoryCustomer({
    required StoreScope scope,
    required String name,
    required String phone,
    String? email,
    String? uniqueId,
    String role = 'retail_customer',
  }) {
    return _store._recordDirectoryCustomer(
      scope: scope,
      name: name,
      phone: phone,
      email: email,
      uniqueId: uniqueId,
      role: role,
    );
  }

  Future<List<StoreCustomerRecord>> searchRecords({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
  }) {
    return _store._searchCustomerRecords(
      scope: scope,
      nameQuery: nameQuery,
      phoneQuery: phoneQuery,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<StoreCustomer>> searchDetails({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
  }) {
    return _store._searchCustomerDetailsByQuery(
      StoreCustomerQuery(
        scope: scope,
        nameQuery: nameQuery,
        phoneQuery: phoneQuery,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Future<List<StoreCustomer>> searchDirectoryDetails({
    required StoreScope scope,
    String? nameQuery,
    String? phoneQuery,
    int? limit,
    int? offset,
  }) async {
    final rows = await _store._searchCustomers(
      scope: scope,
      nameQuery: nameQuery,
      phoneQuery: phoneQuery,
      limit: limit,
      offset: offset,
      roles: CustomerRepository.directoryCustomerRoles,
    );
    return rows.map(StoreCustomer.fromRow).toList(growable: false);
  }

  Future<List<StoreCustomer>> listOrganisationDetails({
    required String orgId,
    int limit = 20,
    int offset = 0,
  }) {
    return _store._listOrganisationCustomerDetails(
      orgId: orgId,
      limit: limit,
      offset: offset,
    );
  }

  Future<StoreCustomer?> getById(String customerId) {
    return _store._getCustomer(customerId);
  }

  Future<String> create(StoreCreateCustomerRequest request) {
    return _store._createCustomer(request);
  }

  Future<int> update(String customerId, StoreUpdateCustomerRequest request) {
    return _store._updateCustomer(customerId, request);
  }

  Future<int> delete(String customerId) {
    return _store._deleteCustomer(customerId);
  }
}