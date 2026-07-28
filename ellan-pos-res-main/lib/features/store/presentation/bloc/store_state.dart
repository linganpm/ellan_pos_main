import 'package:equatable/equatable.dart';
import 'package:pos_orders_offline/store_models.dart';

abstract class StoreState extends Equatable {
  const StoreState();

  @override
  List<Object?> get props => [];
}

class StoreInitial extends StoreState {}

class StoreLoading extends StoreState {}

class StoreLoaded extends StoreState {
  final List<StoreAccessibleStore> stores;
  final String? selectedStoreId;
  const StoreLoaded({required this.stores, this.selectedStoreId});

  @override
  List<Object?> get props => [stores, selectedStoreId];
}

class StoreError extends StoreState {
  final String message;
  const StoreError(this.message);

  @override
  List<Object?> get props => [message];
}

class StoreAuthInProgress extends StoreState {}

class StoreAuthSuccess extends StoreState {}

class StoreAuthFailure extends StoreState {
  final String message;
  const StoreAuthFailure(this.message);

  @override
  List<Object?> get props => [message];
}
