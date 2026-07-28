import 'dart:async';

import 'package:pos_orders_offline/pos_orders_offline.dart';

class SyncTableViewModel {
  final String entity;
  final String direction;
  final StoreSyncProgressStage stage;
  final int processedCount;
  final int totalCount;
  final int batchIndex;
  final int totalBatches;
  final String message;
  final String updatedAt;

  const SyncTableViewModel({
    required this.entity,
    required this.direction,
    required this.stage,
    required this.processedCount,
    required this.totalCount,
    required this.batchIndex,
    required this.totalBatches,
    required this.message,
    required this.updatedAt,
  });

  factory SyncTableViewModel.fromProgress(StoreSyncProgressUpdate update) {
    return SyncTableViewModel(
      entity: update.entity,
      direction: update.direction,
      stage: update.stage,
      processedCount: update.processedCount,
      totalCount: update.totalCount,
      batchIndex: update.batchIndex,
      totalBatches: update.totalBatches,
      message: update.message,
      updatedAt: update.updatedAt,
    );
  }

  double get percent {
    if (totalCount <= 0) {
      return stage == StoreSyncProgressStage.completed || stage == StoreSyncProgressStage.skipped ? 100 : 0;
    }
    return (processedCount / totalCount) * 100;
  }
}

class SyncScreenState {
  final bool running;
  final Map<String, SyncTableViewModel> tableProgress;
  final List<StoreSyncAttemptRecord> history;
  final String? error;

  const SyncScreenState({
    this.running = false,
    this.tableProgress = const {},
    this.history = const [],
    this.error,
  });

  SyncScreenState copyWith({
    bool? running,
    Map<String, SyncTableViewModel>? tableProgress,
    List<StoreSyncAttemptRecord>? history,
    String? error,
  }) {
    return SyncScreenState(
      running: running ?? this.running,
      tableProgress: tableProgress ?? this.tableProgress,
      history: history ?? this.history,
      error: error,
    );
  }
}

class SyncFrontendController {
  final Store store;
  final StreamController<SyncScreenState> _stateController = StreamController<SyncScreenState>.broadcast();
  SyncScreenState _state = const SyncScreenState();

  SyncFrontendController(this.store);

  Stream<SyncScreenState> get stream => _stateController.stream;
  SyncScreenState get state => _state;

  Future<void> loadHistory() async {
    final history = await store.sync.history(store.scope, limit: 20);
    _emit(_state.copyWith(history: history, error: null));
  }

  Future<void> runSyncNow({
    int exportBatchSize = StoreSyncService.defaultExportBatchSize,
  }) async {
    _emit(_state.copyWith(running: true, error: null));
    try {
      await store.sync.runConfigured(
        store.scope,
        exportBatchSize: exportBatchSize,
        onProgress: _handleProgress,
      );
      final history = await store.sync.history(store.scope, limit: 20);
      _emit(_state.copyWith(running: false, history: history, error: null));
    } catch (error) {
      _emit(_state.copyWith(running: false, error: error.toString()));
    }
  }

  Future<void> restoreFromRemote() async {
    _emit(_state.copyWith(running: true, error: null));
    try {
      await store.sync.restoreFromRemote(
        store.scope,
        onProgress: _handleProgress,
      );
      final history = await store.sync.history(store.scope, limit: 20);
      _emit(_state.copyWith(running: false, history: history, error: null));
    } catch (error) {
      _emit(_state.copyWith(running: false, error: error.toString()));
    }
  }

  void dispose() {
    _stateController.close();
  }

  void _handleProgress(StoreSyncProgressUpdate update) {
    final nextProgress = Map<String, SyncTableViewModel>.from(_state.tableProgress);
    nextProgress[_progressKey(update.entity, update.direction)] = SyncTableViewModel.fromProgress(update);
    _emit(_state.copyWith(tableProgress: nextProgress, error: null));
  }

  void _emit(SyncScreenState nextState) {
    _state = nextState;
    _stateController.add(nextState);
  }

  String _progressKey(String entity, String direction) => '$entity:$direction';
}

Future<void> main() async {
  const orgCode = '100001';
  const discoveryUrl = 'http://127.0.0.1:8080/api/bootstrap';

  final organisation = await Store.resolveOrganisationByCodeFromUrl(
    orgCode,
    lookupUrl: discoveryUrl,
  );
  if (organisation == null) {
    throw StateError('Organisation lookup failed');
  }

  final config = await StoreConfig.loadRemoteForOrganisation(
    orgCode: orgCode,
    lookupUrl: discoveryUrl,
  );
  final bootstrap = await Store.syncOrganisationBootstrap(
    orgCode: orgCode,
    config: config,
  );
  if (bootstrap == null || bootstrap.stores.isEmpty) {
    throw StateError('Bootstrap failed');
  }

  final login = await Store.loginToOrganisation(
    orgCode: bootstrap.organisation.orgCode,
    email: config.defaultLogin.email,
    password: config.defaultLogin.password,
    config: config,
  );
  if (login == null) {
    throw StateError('Login failed');
  }

  const deviceRegistration = StoreDeviceRegistrationRequest(
    deviceId: 'example-device-004',
    make: 'Linux',
    model: 'Sync Frontend Example',
    lat: 0,
    lan: 0,
  );
  await Store.registerDeviceForOrganisation(
    orgId: bootstrap.organisation.orgId,
    request: deviceRegistration,
    config: config,
  );

  final store = await Store.openAccessibleStore(
    login: login,
    storeId: bootstrap.stores.first.storeId,
    deviceRegistration: deviceRegistration,
    config: config,
  );
  await store.sync.refreshAccessControl(
    store.scope,
    deviceRegistration: deviceRegistration,
  );
  final controller = SyncFrontendController(store);

  final subscription = controller.stream.listen((state) {
    print('sync-running=${state.running} history=${state.history.length} error=${state.error}');
    for (final entry in state.tableProgress.entries) {
      final table = entry.value;
      print(
        '[${table.entity}:${table.direction}] stage=${table.stage.name} progress=${table.processedCount}/${table.totalCount} batches=${table.batchIndex}/${table.totalBatches} percent=${table.percent.toStringAsFixed(1)} message=${table.message}',
      );
    }
  });

  try {
    final orderId = await store.orders.create(
      store.scope,
      StoreCreateOrderRequest(
        restaurantName: store.storeName,
        customerName: 'Sync Demo Customer',
        mobile: '+1000009999',
        statusName: 'Pending',
        total: 18.0,
        serviceInstance: store.serviceInstanceId,
        createdBy: 'sync-ui-example',
        createdOn: DateTime.now().toIso8601String(),
        paymentStatus: 'Unpaid',
        orderType: StoreOrderType.pickUp,
      ),
    );
    print('Created order with generated orderId=$orderId');

    await store.orders.addItem(
      store.scope,
      StoreAddOrderItemRequest(
        orderId: orderId,
        productVariantId: 'demo-variant-sync-1',
        productId: 'demo-product-sync-1',
        quantity: 2,
        unitPrice: 9.0,
        finalPrice: 18.0,
        createdBy: 'sync-ui-example',
        createdOn: DateTime.now().toIso8601String(),
      ),
    );

    final creditId = await store.credits.create(
      store.scope,
      StoreCreateCreditRequest(
        orgId: store.orgId,
        customerId: 'cust_001',
        orderId: orderId,
        amount: 18.0,
        createdOn: DateTime.now().toIso8601String(),
      ),
    );

    await store.credits.recordRepayment(
      store.scope,
      StoreCreateCreditRepaymentRequest(
        customerId: 'cust_001',
        paymentMode: StoreCreditRepaymentMode.cash,
        totalAmount: 8.0,
        paidOn: DateTime.now().toIso8601String(),
        referenceId: 'sync-ui-example-repayment',
        allocations: [
          StoreCreateCreditRepaymentAllocationRequest(
            creditId: creditId,
            allocatedAmount: 8.0,
          ),
        ],
      ),
    );

    await controller.loadHistory();
    await controller.runSyncNow(exportBatchSize: 100);

    final orderItems = await store.orders.listItems(store.scope, 98001);
    final credits = await store.credits.listRecords(store.scope);
    final repayments = await store.credits.listRepayments(
      store.scope,
      customerId: 'cust_001',
      includeDeleted: true,
    );

    print('Local order items after export sync: ${orderItems.length}');
    print('Credits tracked locally: ${credits.length}');
    print('Repayments tracked locally: ${repayments.length}');
    print('To verify replacement-device recovery, open a fresh store instance and call controller.restoreFromRemote().');
    print('After restore, expect order 98001 items plus the sync-ui-example-repayment allocation graph to be rebuilt.');
  } finally {
    await subscription.cancel();
    controller.dispose();
    await store.auth.logout();
    await store.close();
  }
}