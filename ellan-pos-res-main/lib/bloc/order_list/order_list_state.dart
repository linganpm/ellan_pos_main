import 'package:equatable/equatable.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import '../../data/models/order_list_model.dart';

abstract class OrderListState extends Equatable {
  const OrderListState();

  @override
  List<Object?> get props => [];
}

class OrderListInitial extends OrderListState {}

class OrderListLoading extends OrderListState {}

class OrderTableOption extends Equatable {
  final String id;
  final String label;

  /// Orders on this table that are not completed or cancelled.
  final int openOrders;

  const OrderTableOption({
    required this.id,
    required this.label,
    this.openOrders = 0,
  });

  @override
  List<Object?> get props => [id, label, openOrders];
}

class OrderListLoaded extends OrderListState {
  final List<OrderListModel> orders;

  /// Synced order types used for the type filter chips.
  final List<PosOrderType> availableOrderTypes;

  /// `'All'` or a [PosOrderType.key].
  final String selectedTypeFilter;
  final String? selectedStatusFilter;

  /// Dashboard period label when opened from a metric card (`Today`, etc.).
  final String? periodFilter;
  final String searchQuery;
  final bool hasReachedMax;
  final bool isFetchingMore;

  /// Store tables shown when a dine-in type is selected.
  final List<OrderTableOption> availableTables;
  final String? selectedTableFilter;

  /// Active date window (end exclusive) for [periodFilter].
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const OrderListLoaded({
    required this.orders,
    this.availableOrderTypes = const [],
    this.selectedTypeFilter = 'All',
    this.selectedStatusFilter,
    this.periodFilter,
    this.searchQuery = '',
    this.hasReachedMax = false,
    this.isFetchingMore = false,
    this.availableTables = const [],
    this.selectedTableFilter,
    this.periodStart,
    this.periodEnd,
  });

  OrderListLoaded copyWith({
    List<OrderListModel>? orders,
    List<PosOrderType>? availableOrderTypes,
    String? selectedTypeFilter,
    String? selectedStatusFilter,
    String? periodFilter,
    String? searchQuery,
    bool? hasReachedMax,
    bool? isFetchingMore,
    List<OrderTableOption>? availableTables,
    String? selectedTableFilter,
    bool clearTableFilter = false,
    DateTime? periodStart,
    DateTime? periodEnd,
    bool clearPeriod = false,
  }) {
    return OrderListLoaded(
      orders: orders ?? this.orders,
      availableOrderTypes: availableOrderTypes ?? this.availableOrderTypes,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      periodFilter: clearPeriod ? null : (periodFilter ?? this.periodFilter),
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      availableTables: availableTables ?? this.availableTables,
      selectedTableFilter: clearTableFilter
          ? null
          : (selectedTableFilter ?? this.selectedTableFilter),
      periodStart: clearPeriod ? null : (periodStart ?? this.periodStart),
      periodEnd: clearPeriod ? null : (periodEnd ?? this.periodEnd),
    );
  }

  @override
  List<Object?> get props => [
    orders,
    availableOrderTypes,
    selectedTypeFilter,
    selectedStatusFilter,
    periodFilter,
    searchQuery,
    hasReachedMax,
    isFetchingMore,
    availableTables,
    selectedTableFilter,
    periodStart,
    periodEnd,
  ];
}

class OrderListError extends OrderListState {
  final String message;

  const OrderListError(this.message);

  @override
  List<Object?> get props => [message];
}
