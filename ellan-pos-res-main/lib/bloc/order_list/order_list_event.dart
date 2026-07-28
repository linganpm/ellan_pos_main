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

class SearchOrders extends OrderListEvent {
  final String query;

  const SearchOrders(this.query);

  @override
  List<Object?> get props => [query];
}

class RefreshOrders extends OrderListEvent {}

class UpdateOrderStatus extends OrderListEvent {
  final String orderId;
  final String newStatus;

  const UpdateOrderStatus({required this.orderId, required this.newStatus});

  @override
  List<Object?> get props => [orderId, newStatus];
}
