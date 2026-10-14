import 'package:equatable/equatable.dart';

abstract class OrderListEvent extends Equatable {
  const OrderListEvent();

  @override
  List<Object?> get props => [];
}

class FetchInitialOrders extends OrderListEvent {}

class FetchNextPage extends OrderListEvent {}

class FilterByType extends OrderListEvent {
  final String type;

  const FilterByType(this.type);

  @override
  List<Object?> get props => [type];
}

class FilterByStatus extends OrderListEvent {
  final String status;

  const FilterByStatus(this.status);

  @override
  List<Object?> get props => [status];
}

class ClearStatusFilter extends OrderListEvent {}

/// Dine-in table filter; null shows every table.
class FilterByTable extends OrderListEvent {
  final String? tableId;

  const FilterByTable(this.tableId);

  @override
  List<Object?> get props => [tableId];
}

class SearchOrders extends OrderListEvent {
  final String query;

  const SearchOrders(this.query);

  @override
  List<Object?> get props => [query];
}

class RefreshOrders extends OrderListEvent {}

/// Date window: null for all time, `Today`, `Last 24 hours`, `Yesterday`,
/// or `Custom` with an inclusive [start]..[end] day range.
class FilterByPeriod extends OrderListEvent {
  final String? period;
  final DateTime? start;
  final DateTime? end;

  const FilterByPeriod(this.period, {this.start, this.end});

  @override
  List<Object?> get props => [period, start, end];
}

class UpdateOrderStatus extends OrderListEvent {
  final String orderId;
  final String newStatus;

  const UpdateOrderStatus({required this.orderId, required this.newStatus});

  @override
  List<Object?> get props => [orderId, newStatus];
}
