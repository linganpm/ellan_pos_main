import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/presentation/widgets/order_list/order_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_list_event.dart';
import 'order_list_state.dart';
import '../../data/models/order_list_model.dart';

class OrderListBloc extends Bloc<OrderListEvent, OrderListState> {
  static const int _pageSize = 10;

  final UiStoreController _controller;
  final String? customerIdFilter;
  final String? customerNameFilter;
  final String initialTypeFilter;
  final String? initialStatusFilter;
  final String? periodFilter;
  List<OrderListModel> _allOrders = [];
  List<PosOrderType> _orderTypes = OrderTypesRepository.defaults;
  DateTime? _periodStart;
  DateTime? _periodEnd;

  OrderListBloc({
    UiStoreController? controller,
    this.customerIdFilter,
    this.customerNameFilter,
    this.initialTypeFilter = 'All',
    this.initialStatusFilter,
    this.periodFilter,
  }) : _controller = controller ?? getIt<UiStoreController>(),
        super(OrderListInitial()) {
    on<FetchInitialOrders>(_onFetchInitialOrders);
    on<FetchNextPage>(_onFetchNextPage);
    on<FilterByType>(_onFilterByType);
    on<FilterByStatus>(_onFilterByStatus);
    on<ClearStatusFilter>(_onClearStatusFilter);
    on<SearchOrders>(_onSearchOrders);
    on<RefreshOrders>(_onRefreshOrders);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
  }

  Future<void> _loadOrdersFromDb() async {
    final summaries = await _controller.loadOrders();
    try {
      _orderTypes = await _controller.loadOrderTypes();
    } catch (_) {
      _orderTypes = OrderTypesRepository.defaults;
    }
    String? posCode;
    try {
      posCode = DeviceSetupStore(getIt<SharedPreferences>()).posCode;
    } catch (_) {
      posCode = null;
    }
    _allOrders = summaries
        .map((summary) => _toListModel(summary, posCode))
        .toList(growable: false);
  }

  OrderListModel _toListModel(StoreOrderSummary summary, String? posCode) {
    final mapped = _resolveOrderType(summary.orderType);
    return OrderListModel(
      id: summary.localId,
      orderId: '${summary.orderId}',
      orderType: mapped.label,
      orderTypeKey: mapped.key,
      customerName:
          summary.customerName.isEmpty ? 'Walk-in' : summary.customerName,
      phoneNumber: summary.mobile.isEmpty ? null : summary.mobile,
      email: summary.customerEmail.isEmpty ? null : summary.customerEmail,
      customerUniqueId: summary.customerUniqueId,
      timestamp: DateTime.tryParse(summary.createdOn ?? '') ?? DateTime.now(),
      orderStatus: formatOrderStatusLabel(
        summary.statusName.isEmpty ? 'Completed' : summary.statusName,
      ),
      paymentStatus: formatPaymentStatusLabel(
        summary.paymentStatus.isEmpty ? 'Paid' : summary.paymentStatus,
      ),
      itemCount: summary.itemCount,
      totalAmount: summary.finalValue != 0 ? summary.finalValue : summary.total,
      paidTotal: summary.paidTotal,
      posCode: posCode,
      syncedToRemote: summary.exported,
      serveNumber: summary.serveNumber,
    );
  }

  ({String key, String label}) _resolveOrderType(String raw) {
    final normalized = _normalizeTypeToken(raw);
    for (final type in _orderTypes) {
      if (_normalizeTypeToken(type.key) == normalized ||
          _normalizeTypeToken(type.label) == normalized) {
        return (key: type.key, label: type.label);
      }
    }
    if (normalized.isEmpty) {
      return (key: 'UNKNOWN', label: 'Unknown');
    }
    return (key: raw.trim().toUpperCase(), label: raw.trim());
  }

  String _normalizeTypeToken(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Future<void> _onFetchInitialOrders(
    FetchInitialOrders event,
    Emitter<OrderListState> emit,
  ) async {
    emit(OrderListLoading());
    try {
      await _loadOrdersFromDb();
      _resolvePeriodWindow();
      final typeFilter =
          (initialTypeFilter.trim().isEmpty) ? 'All' : initialTypeFilter.trim();
      final statusFilter = (initialStatusFilter ?? '').trim().isEmpty
          ? null
          : initialStatusFilter!.trim();
      final initialData =
          _applyFiltersAndPagination(typeFilter, statusFilter, '', 0);
      emit(OrderListLoaded(
        orders: initialData,
        availableOrderTypes: List.unmodifiable(_orderTypes),
        selectedTypeFilter: typeFilter,
        selectedStatusFilter: statusFilter,
        periodFilter: (periodFilter ?? '').trim().isEmpty
            ? null
            : periodFilter!.trim(),
        hasReachedMax: initialData.length < _pageSize,
      ));
    } catch (e) {
      emit(const OrderListError('Failed to fetch orders.'));
    }
  }

  void _resolvePeriodWindow() {
    final period = (periodFilter ?? '').trim();
    if (period.isEmpty) {
      _periodStart = null;
      _periodEnd = null;
      return;
    }
    try {
      final range = _controller.dashboardDateRangeForFilter(period);
      _periodStart = range.start;
      _periodEnd = range.end;
    } catch (_) {
      _periodStart = null;
      _periodEnd = null;
    }
  }

  Future<void> _onFetchNextPage(
    FetchNextPage event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      if (currentState.hasReachedMax || currentState.isFetchingMore) return;

      emit(currentState.copyWith(isFetchingMore: true));
      try {
        final currentLength = currentState.orders.length;

        final moreData = _applyFiltersAndPagination(
          currentState.selectedTypeFilter,
          currentState.selectedStatusFilter,
          currentState.searchQuery,
          currentLength,
        );

        emit(moreData.isEmpty
            ? currentState.copyWith(hasReachedMax: true, isFetchingMore: false)
            : currentState.copyWith(
                orders: List.of(currentState.orders)..addAll(moreData),
                hasReachedMax: moreData.length < _pageSize,
                isFetchingMore: false,
              ));
      } catch (e) {
        emit(currentState.copyWith(isFetchingMore: false));
      }
    }
  }

  Future<void> _onFilterByType(
    FilterByType event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      final filteredData = _applyFiltersAndPagination(
        event.type,
        currentState.selectedStatusFilter,
        currentState.searchQuery,
        0,
      );

      emit(currentState.copyWith(
        orders: filteredData,
        selectedTypeFilter: event.type,
        hasReachedMax: filteredData.length < _pageSize,
        isFetchingMore: false,
      ));
    }
  }

  Future<void> _onFilterByStatus(
    FilterByStatus event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      final filteredData = _applyFiltersAndPagination(
        currentState.selectedTypeFilter,
        event.status,
        currentState.searchQuery,
        0,
      );

      emit(currentState.copyWith(
        orders: filteredData,
        selectedStatusFilter: event.status,
        hasReachedMax: filteredData.length < _pageSize,
        isFetchingMore: false,
      ));
    }
  }

  Future<void> _onClearStatusFilter(
    ClearStatusFilter event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      if (currentState.selectedStatusFilter == null) return;

      final filteredData = _applyFiltersAndPagination(
        currentState.selectedTypeFilter,
        null,
        currentState.searchQuery,
        0,
      );

      emit(OrderListLoaded(
        orders: filteredData,
        availableOrderTypes: currentState.availableOrderTypes,
        selectedTypeFilter: currentState.selectedTypeFilter,
        selectedStatusFilter: null,
        periodFilter: currentState.periodFilter,
        searchQuery: currentState.searchQuery,
        hasReachedMax: filteredData.length < _pageSize,
      ));
    }
  }

  Future<void> _onSearchOrders(
    SearchOrders event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      final filteredData = _applyFiltersAndPagination(
        currentState.selectedTypeFilter,
        currentState.selectedStatusFilter,
        event.query,
        0,
      );

      emit(currentState.copyWith(
        orders: filteredData,
        searchQuery: event.query,
        hasReachedMax: filteredData.length < _pageSize,
        isFetchingMore: false,
      ));
    }
  }

  Future<void> _onRefreshOrders(
    RefreshOrders event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is OrderListLoaded) {
      final currentState = state as OrderListLoaded;
      emit(OrderListLoading());

      await _loadOrdersFromDb();
      _resolvePeriodWindow();
      final refreshedData = _applyFiltersAndPagination(
        currentState.selectedTypeFilter,
        currentState.selectedStatusFilter,
        currentState.searchQuery,
        0,
      );

      emit(OrderListLoaded(
        orders: refreshedData,
        availableOrderTypes: List.unmodifiable(_orderTypes),
        selectedTypeFilter: currentState.selectedTypeFilter,
        selectedStatusFilter: currentState.selectedStatusFilter,
        periodFilter: currentState.periodFilter,
        searchQuery: currentState.searchQuery,
        hasReachedMax: refreshedData.length < _pageSize,
      ));
    } else {
      add(FetchInitialOrders());
    }
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<OrderListState> emit,
  ) async {
    if (state is! OrderListLoaded) return;
    final currentState = state as OrderListLoaded;

    try {
      await getIt<UiStoreController>().updateOrderStatus(
        int.parse(event.orderId),
        event.newStatus,
      );
    } catch (error) {
      // Keep local UI consistent even if persist fails; surface via reload.
      add(FetchInitialOrders());
      return;
    }

    final orderIndex =
        _allOrders.indexWhere((o) => o.orderId == event.orderId);
    if (orderIndex != -1) {
      final order = _allOrders[orderIndex];
      _allOrders[orderIndex] = OrderListModel(
        id: order.id,
        orderId: order.orderId,
        orderType: order.orderType,
        orderTypeKey: order.orderTypeKey,
        floorName: order.floorName,
        tableNumber: order.tableNumber,
        customerName: order.customerName,
        phoneNumber: order.phoneNumber,
        email: order.email,
        customerUniqueId: order.customerUniqueId,
        timestamp: order.timestamp,
        orderStatus: event.newStatus,
        paymentStatus: order.paymentStatus,
        itemCount: order.itemCount,
        totalAmount: order.totalAmount,
        paidTotal: order.paidTotal,
        posCode: order.posCode,
        syncedToRemote: false,
        serveNumber: order.serveNumber,
      );
    }

    final updatedData = _applyFiltersAndPagination(
      currentState.selectedTypeFilter,
      currentState.selectedStatusFilter,
      currentState.searchQuery,
      0,
      limit: currentState.orders.length,
    );

    emit(currentState.copyWith(orders: updatedData));
  }

  List<OrderListModel> _applyFiltersAndPagination(
    String typeFilter,
    String? statusFilter,
    String searchQuery,
    int skip, {
    int limit = _pageSize,
  }) {
    var filtered = _allOrders;

    final customerFilter = (customerIdFilter ?? '').trim();
    if (customerFilter.isNotEmpty) {
      final wanted = _normalizeCustomerId(customerFilter);
      filtered = filtered
          .where(
            (o) =>
                _normalizeCustomerId(o.customerUniqueId ?? '') == wanted ||
                (customerNameFilter != null &&
                    customerNameFilter!.trim().isNotEmpty &&
                    o.customerName.toLowerCase() ==
                        customerNameFilter!.trim().toLowerCase()),
          )
          .toList();
    }

    final start = _periodStart;
    final end = _periodEnd;
    if (start != null && end != null) {
      filtered = filtered.where((o) {
        final when = o.timestamp;
        return !when.isBefore(start) && when.isBefore(end);
      }).toList();
    }

    if (typeFilter != 'All') {
      final wanted = _normalizeTypeToken(typeFilter);
      filtered = filtered
          .where(
            (o) =>
                _normalizeTypeToken(o.orderTypeKey) == wanted ||
                _normalizeTypeToken(o.orderType) == wanted,
          )
          .toList();
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      final wantedStatus = statusFilter.toLowerCase();
      filtered = filtered.where((o) {
        final status = o.orderStatus.toLowerCase();
        if (wantedStatus.contains('cancel')) {
          return status.contains('cancel');
        }
        return status == wantedStatus;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase().trim();
      filtered = filtered
          .where(
            (o) =>
                o.orderId.toLowerCase().contains(query) ||
                o.customerName.toLowerCase().contains(query) ||
                (o.phoneNumber?.toLowerCase().contains(query) ?? false) ||
                (o.email?.toLowerCase().contains(query) ?? false),
          )
          .toList();
    }

    return filtered.skip(skip).take(limit).toList();
  }

  String _normalizeCustomerId(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('user_')) return raw;
    if (int.tryParse(raw) != null) return 'user_$raw';
    return raw;
  }
}
