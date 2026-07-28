import 'package:equatable/equatable.dart';

/// Base class for all store list events
/// 
/// All events related to store list management should extend this class
abstract class StoreListEvent extends Equatable {
  const StoreListEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load the available stores
/// 
/// This event should be emitted when the screen first loads
/// or when the user wants to refresh the store list
class LoadStoresEvent extends StoreListEvent {
  const LoadStoresEvent();
}

/// Event triggered when a user selects a store from the list
/// 
/// Parameters:
///   - storeId: The ID of the selected store
class SelectStoreEvent extends StoreListEvent {
  final String storeId;

  const SelectStoreEvent({required this.storeId});

  @override
  List<Object?> get props => [storeId];
}

/// Event triggered to verify the selected store and proceed
/// 
/// This event initiates the verification process before
/// allowing the user to proceed to the next screen
class VerifyStoreEvent extends StoreListEvent {
  const VerifyStoreEvent();
}

/// Event triggered to search/filter stores by name
/// 
/// Parameters:
///   - query: The search query string
class SearchStoresEvent extends StoreListEvent {
  final String query;

  const SearchStoresEvent({required this.query});

  @override
  List<Object?> get props => [query];
}

