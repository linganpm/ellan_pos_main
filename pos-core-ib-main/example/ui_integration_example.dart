import 'package:pos_orders_offline/pos_orders_offline.dart';

class UiStoreController {
  StoreConfig? _config;
  StoreOrganisation? _organisation;
  StoreOrganisationLoginResult? _organisationLogin;
  StoreOrganisationBootstrapSyncResult? _bootstrap;
  StoreDeviceRegistrationRequest? _deviceRegistration;
  Store? _store;

  Store? get store => _store;
  StoreOrganisation? get organisation => _organisation;
  StoreOrganisationLoginResult? get organisationLogin => _organisationLogin;
  StoreOrganisationBootstrapSyncResult? get bootstrap => _bootstrap;

  Future<void> boot({
    StoreEnvironment environment = StoreEnvironment.development,
  }) async {
    _config = await StoreConfig.loadForEnvironment(environment);
  }

  Future<void> bootWithConfig(StoreConfig config) async {
    _config = config;
  }

  Future<StoreOrganisation?> resolveOrganisation(String orgCode) async {
    final config = _requireConfig();
    final organisation = await Store.resolveOrganisationByCode(
      orgCode,
      config: config,
    );
    _organisation = organisation;
    return organisation;
  }

  Future<StoreOrganisationBootstrapSyncResult?> syncOrganisationBootstrap(String orgCode) async {
    final config = _requireConfig();
    final bootstrap = await Store.syncOrganisationBootstrap(
      orgCode: orgCode,
      config: config,
    );
    _bootstrap = bootstrap;
    _organisation = bootstrap?.organisation;
    return bootstrap;
  }

  Future<bool> loginToOrganisation({
    required String orgCode,
    required String email,
    required String password,
  }) async {
    final config = _requireConfig();
    final login = await Store.loginToOrganisation(
      orgCode: orgCode,
      email: email,
      password: password,
      config: config,
    );
    _organisationLogin = login;
    _organisation = login?.organisation;
    return login != null;
  }

  List<StoreAccessibleStore> accessibleStores() {
    return _organisationLogin?.accessibleStores ?? const [];
  }

  Future<StoreDeviceRegistrationResult?> registerDevice({
    required String deviceId,
    required String make,
    required String model,
    double? lat,
    double? lan,
  }) async {
    final config = _requireConfig();
    final organisation = _requireOrganisation();
    final request = StoreDeviceRegistrationRequest(
      deviceId: deviceId,
      make: make,
      model: model,
      lat: lat,
      lan: lan,
    );
    _deviceRegistration = request;
    final result = await Store.registerDeviceForOrganisation(
      orgId: organisation.orgId,
      request: request,
      config: config,
    );
    return result;
  }

  Future<void> openStore(String storeId) async {
    final config = _requireConfig();
    final login = _requireOrganisationLogin();
    final deviceRegistration = _requireDeviceRegistration();

    final existingStore = _store;
    if (existingStore == null) {
      _store = await Store.openAccessibleStore(
        login: login,
        storeId: storeId,
        deviceRegistration: deviceRegistration,
        config: config,
      );
    } else {
      _store = await existingStore.switchAccessibleStore(
        login: login,
        storeId: storeId,
        deviceRegistration: deviceRegistration,
      );
    }

    if (_store!.sync.autoSyncEnabled) {
      _store!.sync.startAutoSync(_store!.scope);
    }
  }

  Future<void> switchStore(String storeId) async {
    final store = _requireStore();
    final login = _requireOrganisationLogin();
    final deviceRegistration = _requireDeviceRegistration();

    _store = await store.switchAccessibleStore(
      login: login,
      storeId: storeId,
      deviceRegistration: deviceRegistration,
    );

    if (_store!.sync.autoSyncEnabled && !_store!.sync.isAutoSyncRunning) {
      _store!.sync.startAutoSync(_store!.scope);
    }
  }

  Future<StoreRoleAccess?> currentStoreAccess() {
    final store = _requireStore();
    return store.auth.currentStoreAccess(store.scope);
  }

  Future<bool> restoreSession() async {
    final store = _requireStore();
    return store.auth.isLoggedIn();
  }

  Future<StoreSession?> currentSession() {
    return _requireStore().auth.currentSession();
  }

  Future<StoreCustomer?> currentCustomer() {
    return _requireStore().auth.currentCustomer();
  }

  Future<List<StoreOrderSummary>> loadOrders() {
    final store = _requireStore();
    return store.orders.listSummaries(store.scope);
  }

  Future<StoreOrderDetails?> loadOrder(int orderId) {
    final store = _requireStore();
    return store.orders.getById(store.scope, orderId);
  }

  Future<int> createWalkInOrder() {
    final store = _requireStore();
    return store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Walk-in Customer',
        mobile: '+1000000000',
        statusName: 'Pending',
        total: 42.5,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'ui-example',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.dineIn,
        payments: const [
          StoreCreateOrderPaymentRequest(
            paymentMode: StoreOrderPaymentMode.cash,
            amount: 20.0,
            referenceId: 'ui-cash-auto-order',
          ),
        ],
      ),
    );
  }

  Future<void> addOrderPayment(int orderId) {
    final store = _requireStore();
    return store.orders.addPayment(
      store.scope,
      orderId,
      const StoreCreateOrderPaymentRequest(
        paymentMode: StoreOrderPaymentMode.card,
        amount: 22.5,
        referenceId: 'ui-card-auto-order',
      ),
    );
  }

  Future<void> closeOrder(int orderId) {
    final store = _requireStore();
    return store.orders.updateStatus(store.scope, orderId, 'Closed');
  }

  Future<List<String>> loadProductNames() {
    final store = _requireStore();
    return store.products.listNames(store.scope);
  }

  Future<List<StoreProductVariantRecord>> loadProductVariants(int categoryId) {
    final store = _requireStore();
    return store.products.listVariantsByCategory(store.scope, categoryId);
  }

  Future<List<StoreCustomer>> searchCustomers(String query) {
    final store = _requireStore();
    return store.customers.searchDetails(scope: store.scope, nameQuery: query, limit: 20);
  }

  Future<StoreSyncBatchResult> runSyncNow() {
    final store = _requireStore();
    return store.sync.syncOrdersProductsCredits(store.scope);
  }

  Future<void> refreshAccessControl() {
    final store = _requireStore();
    final deviceRegistration = _requireDeviceRegistration();
    return store.sync.refreshAccessControl(
      store.scope,
      deviceRegistration: deviceRegistration,
    );
  }

  Future<StoreSyncBatchResult> runSyncNowWithCallbacks({
    void Function(StoreSyncProgressUpdate update)? onProgress,
    int exportBatchSize = StoreSyncService.defaultExportBatchSize,
  }) {
    final store = _requireStore();
    return store.sync.runConfigured(
      store.scope,
      onProgress: onProgress,
      exportBatchSize: exportBatchSize,
    );
  }

  Future<StoreSyncBatchResult> restoreFromRemote({
    void Function(StoreSyncProgressUpdate update)? onProgress,
  }) {
    final store = _requireStore();
    return store.sync.restoreFromRemote(
      store.scope,
      onProgress: onProgress,
    );
  }

  Future<List<StoreSyncAttemptRecord>> loadSyncHistory() {
    final store = _requireStore();
    return store.sync.history(store.scope, limit: 20);
  }

  Future<void> logout() async {
    final store = _requireStore();
    await store.auth.logout();
  }

  Future<void> dispose() async {
    await _store?.close();
    _store = null;
  }

  StoreConfig _requireConfig() {
    final config = _config;
    if (config == null) {
      throw StateError('Controller is not booted. Call boot() first.');
    }
    return config;
  }

  StoreOrganisationLoginResult _requireOrganisationLogin() {
    final login = _organisationLogin;
    if (login == null) {
      throw StateError('Organisation login is required before selecting a store.');
    }
    return login;
  }

  StoreOrganisation _requireOrganisation() {
    final organisation = _organisation;
    if (organisation == null) {
      throw StateError('Organisation must be resolved before registering the device.');
    }
    return organisation;
  }

  StoreDeviceRegistrationRequest _requireDeviceRegistration() {
    final deviceRegistration = _deviceRegistration;
    if (deviceRegistration == null) {
      throw StateError('Register the device before selecting a store.');
    }
    return deviceRegistration;
  }

  Store _requireStore() {
    final store = _store;
    if (store == null) {
      throw StateError('Store is not initialized. Call boot() first.');
    }
    return store;
  }
}

Future<void> main() async {
  final controller = UiStoreController();
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';

  try {
    final organisation = await Store.resolveOrganisationByCodeFromUrl(
      orgCode,
      lookupUrl: discoveryUrl,
    );
    if (organisation == null) {
      throw StateError('Organisation code was not found');
    }

    final remoteConfig = await StoreConfig.loadRemoteForOrganisation(
      orgCode: organisation.orgCode,
      lookupUrl: discoveryUrl,
    );
    await controller.bootWithConfig(remoteConfig);

    print('Organisation found: ${organisation.orgName}');
    print('Remote sync base URL: ${remoteConfig.sync.baseUrl}');

    final bootstrap = await controller.syncOrganisationBootstrap(organisation.orgCode);
    print('Bootstrap stores: ${bootstrap?.stores.length ?? 0}');
    print('Bootstrap customers: ${bootstrap?.customers.length ?? 0}');
    print('Bootstrap store roles: ${bootstrap?.storeRoles.length ?? 0}');
    print('Bootstrap organisation roles: ${bootstrap?.organisationRoles.length ?? 0}');

    final deviceAccess = await controller.registerDevice(
      deviceId: 'ui-example-device-001',
      make: 'Linux',
      model: 'UI Example',
      lat: 0,
      lan: 0,
    );
    print('Device status: ${deviceAccess?.status ?? 'not-required'}');

    final loggedIn = await controller.loginToOrganisation(
      orgCode: organisation.orgCode,
      email: 'alice@example.com',
      password: 'alicepass',
    );

    if (!loggedIn) {
      throw StateError('Login failed');
    }

    final stores = controller.accessibleStores();
    if (stores.isEmpty) {
      throw StateError('No accessible stores found for this customer.');
    }

    print('Accessible stores:');
    for (final entry in stores) {
      print('- ${entry.store.storeName} [${entry.store.storeId}] storeRole=${entry.access.storeRole}');
    }

    await controller.openStore(stores.first.store.storeId);

    // In a real app, call this when connectivity resumes or before starting sync.
    await controller.refreshAccessControl();

    final storeAccess = await controller.currentStoreAccess();
    if (storeAccess == null || !storeAccess.accessEnabled) {
      throw StateError('Customer does not have access to the selected store.');
    }

    final orders = await controller.loadOrders();
    final products = await controller.loadProductNames();
    final session = await controller.currentSession();

    print('Logged in as: ${session?.email}');
    print('Organisation role: ${session?.organisationRole}');
    print('Store role: ${session?.storeRole}');
    print('Selected store: ${controller.store?.storeName}');
    print('Orders loaded: ${orders.length}');
    print('Products loaded: ${products.length}');

    final createdOrderId = await controller.createWalkInOrder();
    print('Created order: $createdOrderId');

    await controller.addOrderPayment(createdOrderId);
    final createdOrder = await controller.loadOrder(createdOrderId);
    print('Order payments after add: ${createdOrder?.payments.length ?? 0}');
    for (final payment in createdOrder?.payments ?? const <StoreOrderPaymentRecord>[]) {
      print('Payment: mode=${payment.paymentMode} amount=${payment.amount} ref=${payment.referenceId}');
    }

    await controller.closeOrder(createdOrderId);
    final closedOrder = await controller.loadOrder(createdOrderId);
    print('Closed order status: ${closedOrder?.statusName}');

    await controller.runSyncNowWithCallbacks(
      onProgress: (update) {
        print(
          'Sync callback: ${update.entity}:${update.direction} stage=${update.stage.name} processed=${update.processedCount}/${update.totalCount} batches=${update.batchIndex}/${update.totalBatches}',
        );
      },
    );

    final syncHistory = await controller.loadSyncHistory();
    print('Sync history entries: ${syncHistory.length}');

    await controller.logout();
  } on StoreSessionExpiredException catch (error) {
    print('Session expired: $error');
  } on StoreAuthException catch (error) {
    print('Auth error: $error');
  } on StoreAuthorizationException catch (error) {
    print('Authorization error: $error');
  } on StoreDeviceAccessException catch (error) {
    print('Device access error: $error');
  } finally {
    await controller.dispose();
  }
}