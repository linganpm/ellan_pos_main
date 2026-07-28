import 'package:equatable/equatable.dart';

/// Model representing a Store in the POS system.
/// 
/// Contains store identification details and user role information
/// for a specific store location.
class StoreModel extends Equatable {
  /// Unique identifier for the store
  final String storeId;

  /// Display name of the store
  final String storeName;

  /// User's role/permission level in this store (e.g., Admin, Cashier, Manager)
  final String storeRole;

  /// Constructor for StoreModel
  const StoreModel({
    required this.storeId,
    required this.storeName,
    required this.storeRole,
  });

  /// Creates a copy of this StoreModel with optional field overrides
  StoreModel copyWith({
    String? storeId,
    String? storeName,
    String? storeRole,
  }) {
    return StoreModel(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeRole: storeRole ?? this.storeRole,
    );
  }

  /// Converts JSON map to StoreModel
  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      storeId: json['storeId'] as String? ?? '',
      storeName: json['storeName'] as String? ?? '',
      storeRole: json['storeRole'] as String? ?? '',
    );
  }

  /// Converts StoreModel to JSON map
  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'storeName': storeName,
      'storeRole': storeRole,
    };
  }

  @override
  List<Object?> get props => [storeId, storeName, storeRole];
}

