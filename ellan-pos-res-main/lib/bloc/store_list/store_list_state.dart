import 'package:equatable/equatable.dart';
import '../../data/models/store_model.dart';

/// Base class for all store list states
///
/// All states related to store list management should extend this class
abstract class StoreListState extends Equatable {
  const StoreListState();

  @override
  List<Object?> get props => [];
}

/// Initial state of the store list screen
///
/// This state is used when the screen is first created
class StoreListInitial extends StoreListState {
  const StoreListInitial();
}

/// State indicating that stores are being loaded
///
/// This state is emitted while fetching the list of stores from the repository
class StoreListLoading extends StoreListState {
  const StoreListLoading();
}

/// State indicating that stores have been successfully loaded
///
/// This state contains the list of available stores and current selection state
class StoreListLoaded extends StoreListState {
  /// List of available stores
  final List<StoreModel> stores;

  /// ID of the currently selected store (null if none selected)
  final String? selectedStoreId;

  /// Filtered list of stores based on search query
  final List<StoreModel>? filteredStores;

  const StoreListLoaded({
    required this.stores,
    this.selectedStoreId,
    this.filteredStores,
  });

  /// Creates a copy of this state with optional field overrides
  StoreListLoaded copyWith({
    List<StoreModel>? stores,
    String? selectedStoreId,
    List<StoreModel>? filteredStores,
  }) {
    return StoreListLoaded(
      stores: stores ?? this.stores,
      selectedStoreId: selectedStoreId ?? this.selectedStoreId,
      filteredStores: filteredStores ?? this.filteredStores,
    );
  }

  @override
  List<Object?> get props => [stores, selectedStoreId, filteredStores];
}

/// State indicating that a store has been selected
///
/// This state is emitted when the user selects a store from the list
class StoreSelectionChanged extends StoreListState {
  /// The currently selected store
  final StoreModel selectedStore;

  /// List of all available stores
  final List<StoreModel> allStores;

  const StoreSelectionChanged({
    required this.selectedStore,
    required this.allStores,
  });

  @override
  List<Object?> get props => [selectedStore, allStores];
}

/// State indicating that store verification is in progress
///
/// This state is emitted when the user submits the selected store
/// and verification is being performed
class StoreVerificationLoading extends StoreListState {
  /// The store being verified
  final StoreModel store;

  /// Progress text for the catalogue pull, e.g. `Syncing product catalogue 40/120`
  final String? message;

  const StoreVerificationLoading({required this.store, this.message});

  @override
  List<Object?> get props => [store, message];
}

/// State indicating that store verification was successful
///
/// This state signals that the selected store has been verified
/// and the user can proceed to the next screen
class StoreVerificationSuccess extends StoreListState {
  /// The verified store
  final StoreModel store;

  const StoreVerificationSuccess({required this.store});

  @override
  List<Object?> get props => [store];
}

/// State indicating that store verification failed
///
/// This state contains the error message explaining why verification failed
class StoreVerificationFailure extends StoreListState {
  /// Error message describing the verification failure
  final String errorMessage;

  /// The store that failed verification
  final StoreModel? store;

  const StoreVerificationFailure({required this.errorMessage, this.store});

  @override
  List<Object?> get props => [errorMessage, store];
}

/// State indicating a general error occurred
///
/// This state is used for errors during store loading or other operations
class StoreListError extends StoreListState {
  /// Error message describing what went wrong
  final String errorMessage;

  const StoreListError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
