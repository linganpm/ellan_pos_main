part of 'store.dart';

class StoreAuthService {
  final Store _store;

  StoreAuthService._(this._store);

  Future<StoreSession?> login(StoreScope scope, StoreLoginRequest request) => _store._login(scope, request);

  Future<void> logout() => _store._logout();

  Future<bool> isLoggedIn() => _store._isLoggedIn();

  Future<StoreSession?> currentSession() => _store._getCurrentSession();

  Future<StoreCustomer?> currentCustomer() => _store._getCurrentCustomer();

  Future<bool> hasRole(String role) => _store._hasStoreRole(role);

  Future<bool> hasOrganisationRole(String role) => _store._hasOrganisationRole(role);

  Future<bool> hasStoreRole(String role) => _store._hasStoreRole(role);

  Future<String?> currentOrganisationRole() => _store._getCurrentOrganisationRole();

  Future<String?> currentStoreRole() => _store._getCurrentStoreRoleValue();

  Future<bool> canAccessStore(StoreScope scope) => _store._canCurrentCustomerAccessStore(scope);

  Future<StoreRoleAccess?> currentStoreAccess(StoreScope scope) => _store._getCurrentStoreAccess(scope);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _store._changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> resetCustomerPassword({
    required String customerId,
    required String newPassword,
  }) {
    return _store._resetCustomerPassword(
      customerId: customerId,
      newPassword: newPassword,
    );
  }

  Future<void> resetCustomerPasswordByEmail({
    required String email,
    required String newPassword,
  }) {
    return _store._resetCustomerPasswordByEmail(
      email: email,
      newPassword: newPassword,
    );
  }

  /// Store a verified plaintext password as the offline hash for this operator.
  Future<void> persistVerifiedOfflinePassword({
    required String password,
    String? customerId,
    String? identifier,
  }) {
    return _store._persistVerifiedOfflinePassword(
      password: password,
      customerId: customerId,
      identifier: identifier,
    );
  }
}