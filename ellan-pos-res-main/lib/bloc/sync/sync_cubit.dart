import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_settings_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/network_reachability.dart';

enum SyncItemStatus { pending, running, success, failed, skipped }

enum SyncDirection { download, upload }

class SyncChecklistItem extends Equatable {
  final String id;
  final String entity;
  final SyncDirection direction;
  final String title;
  final String subtitle;
  final SyncItemStatus status;
  final String? detail;
  final int processedCount;
  final int totalCount;
  final int successCount;
  final int failureCount;

  const SyncChecklistItem({
    required this.id,
    required this.entity,
    required this.direction,
    required this.title,
    required this.subtitle,
    this.status = SyncItemStatus.pending,
    this.detail,
    this.processedCount = 0,
    this.totalCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
  });

  SyncChecklistItem copyWith({
    SyncItemStatus? status,
    String? detail,
    int? processedCount,
    int? totalCount,
    int? successCount,
    int? failureCount,
  }) {
    return SyncChecklistItem(
      id: id,
      entity: entity,
      direction: direction,
      title: title,
      subtitle: subtitle,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
    );
  }

  double? get progressFraction {
    if (totalCount <= 0) return null;
    return (processedCount / totalCount).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
    id,
    entity,
    direction,
    title,
    subtitle,
    status,
    detail,
    processedCount,
    totalCount,
    successCount,
    failureCount,
  ];
}

class SyncState extends Equatable {
  final List<SyncChecklistItem> items;
  final bool isRunning;
  final bool completed;
  final String? errorMessage;
  final String? storeName;
  final DateTime? lastSuccessfulSyncAt;

  /// null = not probed yet; false = gateway unreachable (queue locally).
  final bool? gatewayReachable;

  const SyncState({
    required this.items,
    this.isRunning = false,
    this.completed = false,
    this.errorMessage,
    this.storeName,
    this.lastSuccessfulSyncAt,
    this.gatewayReachable,
  });

  bool get isOffline => gatewayReachable == false;

  List<SyncChecklistItem> get downloadItems => items
      .where((item) => item.direction == SyncDirection.download)
      .toList(growable: false);

  List<SyncChecklistItem> get uploadItems => items
      .where((item) => item.direction == SyncDirection.upload)
      .toList(growable: false);

  factory SyncState.initial({String? storeName, DateTime? lastSyncAt}) {
    return SyncState(
      storeName: storeName,
      lastSuccessfulSyncAt: lastSyncAt,
      items: const [
        SyncChecklistItem(
          id: 'customers:export',
          entity: 'customers',
          direction: SyncDirection.upload,
          title: 'Customers Upload',
          subtitle: 'Push retail / business customers created on this device',
        ),
        SyncChecklistItem(
          id: 'orders:export',
          entity: 'orders',
          direction: SyncDirection.upload,
          title: 'Orders Upload',
          subtitle: 'Push POS orders created on this device to the backend',
        ),
        SyncChecklistItem(
          id: 'credits:export',
          entity: 'credits',
          direction: SyncDirection.upload,
          title: 'Credits Upload',
          subtitle: 'Push buy-on-credit sales and repayments to the backend',
        ),
        SyncChecklistItem(
          id: 'customers:import',
          entity: 'customers',
          direction: SyncDirection.download,
          title: 'Customer Sync',
          subtitle: 'Pull customers and roles from the organisation',
        ),
        SyncChecklistItem(
          id: 'products:import',
          entity: 'products',
          direction: SyncDirection.download,
          title: 'Products Catalog Sync',
          subtitle: 'Pull categories and product variants for this store',
        ),
        SyncChecklistItem(
          id: 'product_images:import',
          entity: 'product_images',
          direction: SyncDirection.download,
          title: 'Product Images',
          subtitle:
              'Downloads catalogue photos for offline use without blocking sync',
        ),
        SyncChecklistItem(
          id: 'offers:import',
          entity: 'offers',
          direction: SyncDirection.download,
          title: 'Offers Sync',
          subtitle: 'Pull active product and bill offers for this store',
        ),
        SyncChecklistItem(
          id: 'orders:import',
          entity: 'orders',
          direction: SyncDirection.download,
          title: 'Order Fetch',
          subtitle: 'Pull order drifts into the local store',
        ),
        SyncChecklistItem(
          id: 'credits:import',
          entity: 'credits',
          direction: SyncDirection.download,
          title: 'Credits Sync',
          subtitle: 'Pull customer credit balances',
        ),
        SyncChecklistItem(
          id: 'tables:import',
          entity: 'tables',
          direction: SyncDirection.download,
          title: 'Floors & Tables Sync',
          subtitle: 'Pull floor plans and table layout',
        ),
        SyncChecklistItem(
          id: 'wallets:import',
          entity: 'wallets',
          direction: SyncDirection.download,
          title: 'Wallets Sync',
          subtitle: 'Pull payment wallets defined for this store',
        ),
      ],
    );
  }

  SyncState copyWith({
    List<SyncChecklistItem>? items,
    bool? isRunning,
    bool? completed,
    String? errorMessage,
    String? storeName,
    DateTime? lastSuccessfulSyncAt,
    bool? gatewayReachable,
    bool clearError = false,
  }) {
    return SyncState(
      items: items ?? this.items,
      isRunning: isRunning ?? this.isRunning,
      completed: completed ?? this.completed,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      storeName: storeName ?? this.storeName,
      lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
      gatewayReachable: gatewayReachable ?? this.gatewayReachable,
    );
  }

  @override
  List<Object?> get props => [
    items,
    isRunning,
    completed,
    errorMessage,
    storeName,
    lastSuccessfulSyncAt,
    gatewayReachable,
  ];
}

class SyncCubit extends Cubit<SyncState> {
  static const lastSyncAtKey = DeviceSettingsStore.lastSyncAtKey;

  final UiStoreController controller;

  SyncCubit({UiStoreController? controller})
    : controller = controller ?? getIt<UiStoreController>(),
      super(SyncState.initial()) {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final store = controller.store;
    final settingsStore = await DeviceSettingsStore.open();
    final reachable = await NetworkReachability.canReachGateway();
    emit(
      state.copyWith(
        storeName: store?.storeName,
        lastSuccessfulSyncAt: settingsStore.lastSuccessfulSyncAt(),
        gatewayReachable: reachable,
      ),
    );
  }

  Future<void> refreshReachability() async {
    final reachable = await NetworkReachability.canReachGateway();
    emit(state.copyWith(gatewayReachable: reachable));
  }

  Future<void> runSync() async {
    if (state.isRunning) return;

    final reachable = await NetworkReachability.canReachGateway();
    if (!reachable) {
      emit(
        state.copyWith(
          gatewayReachable: false,
          completed: false,
          errorMessage:
              'No connection to the server. Orders stay on this device and will upload when you sync online.',
        ),
      );
      return;
    }

    final reset = state.items
        .map(
          (item) => item.copyWith(
            status: SyncItemStatus.pending,
            detail: '',
            processedCount: 0,
            totalCount: 0,
            successCount: 0,
            failureCount: 0,
          ),
        )
        .toList();
    emit(
      state.copyWith(
        items: reset,
        isRunning: true,
        completed: false,
        gatewayReachable: true,
        clearError: true,
      ),
    );

    try {
      final result = await controller.syncFromRemote(onProgress: _onProgress);
      final finalized = state.items.map((item) {
        if (item.id == 'product_images:import' &&
            item.status == SyncItemStatus.running) {
          return item;
        }
        if (item.status == SyncItemStatus.pending) {
          return item.copyWith(
            status: SyncItemStatus.skipped,
            detail: 'Not configured for this device.',
          );
        }
        return item;
      }).toList();

      final hardFailure = result.operations.any(
        (op) => !op.success && !op.skipped,
      );
      DateTime? syncedAt = state.lastSuccessfulSyncAt;
      if (!hardFailure) {
        syncedAt = DateTime.now();
        final settingsStore = await DeviceSettingsStore.open();
        await settingsStore.markSyncSucceeded(syncedAt);
      }

      emit(
        state.copyWith(
          items: finalized,
          isRunning: false,
          completed: true,
          lastSuccessfulSyncAt: syncedAt,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isRunning: false,
          completed: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onProgress(StoreSyncProgressUpdate update) {
    if (isClosed) return;
    final id = '${update.entity}:${update.direction}';
    final index = state.items.indexWhere((item) => item.id == id);
    if (index < 0) return;

    final SyncItemStatus status;
    switch (update.stage) {
      case StoreSyncProgressStage.running:
        status = SyncItemStatus.running;
        break;
      case StoreSyncProgressStage.completed:
        status = SyncItemStatus.success;
        break;
      case StoreSyncProgressStage.skipped:
        status = SyncItemStatus.skipped;
        break;
      case StoreSyncProgressStage.failed:
        status = SyncItemStatus.failed;
        break;
    }

    final detail = _countDetail(update);

    final items = List<SyncChecklistItem>.from(state.items);
    items[index] = items[index].copyWith(
      status: status,
      detail: detail,
      processedCount: update.processedCount,
      totalCount: update.totalCount,
      successCount: update.successCount,
      failureCount: update.failureCount,
    );
    emit(state.copyWith(items: items));
  }

  String _countDetail(StoreSyncProgressUpdate update) {
    if (update.totalCount <= 0) return update.message;
    final failed = update.failureCount > 0
        ? ' · ${update.failureCount} failed'
        : '';
    return '${update.successCount} synced / ${update.totalCount} total$failed';
  }
}
