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

  const OrderListLoaded({
    required this.orders,
    this.availableOrderTypes = const [],
    this.selectedTypeFilter = 'All',
    this.selectedStatusFilter,
    this.periodFilter,
    this.searchQuery = '',
    this.hasReachedMax = false,
    this.isFetchingMore = false,
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
  }) {
    return OrderListLoaded(
      orders: orders ?? this.orders,
      availableOrderTypes: availableOrderTypes ?? this.availableOrderTypes,
      selectedTypeFilter: selectedTypeFilter ?? this.selectedTypeFilter,
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      periodFilter: periodFilter ?? this.periodFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
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
      ];
}

class OrderListError extends OrderListState {
  final String message;

  const OrderListError(this.message);

  @override
  List<Object?> get props => [message];
}
