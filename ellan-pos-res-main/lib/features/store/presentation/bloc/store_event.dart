import 'package:equatable/equatable.dart';

abstract class StoreEvent extends Equatable {
  const StoreEvent();

  @override
  List<Object?> get props => [];
}

class StoreInitializeEvent extends StoreEvent {
  final String orgCode;
  const StoreInitializeEvent(this.orgCode);

  @override
  List<Object?> get props => [orgCode];
}

class StoreLoginEvent extends StoreEvent {
  final String orgCode;
  final String email;
  final String password;
  const StoreLoginEvent({required this.orgCode, required this.email, required this.password});

  @override
  List<Object?> get props => [orgCode, email];
}

class StoreLoadAccessibleStoresEvent extends StoreEvent {}

class StoreSelectStoreEvent extends StoreEvent {
  final String storeId;
  const StoreSelectStoreEvent(this.storeId);

  @override
  List<Object?> get props => [storeId];
}
