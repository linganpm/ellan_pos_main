import 'package:equatable/equatable.dart';
import 'order_creation_event.dart';

class OrderCreationState extends Equatable {
  final OrderType orderType;
  final String pickupName;
  final String pickupPhone;
  final String pickupEmail;
  /// Stable unique sync id for the selected/created customer.
  final String? customerUniqueId;
  final String selectedFloor;
  final String selectedTable;
  final bool isPickupValid;
  final String? nameError;
  final String? phoneError;

  const OrderCreationState({
    this.orderType = OrderType.pickup,
    this.pickupName = '',
    this.pickupPhone = '',
    this.pickupEmail = '',
    this.customerUniqueId,
    this.selectedFloor = 'first',
    this.selectedTable = '',
    this.isPickupValid = false,
    this.nameError,
    this.phoneError,
  });

  bool get hasSelectedCustomer =>
      customerUniqueId != null && customerUniqueId!.trim().isNotEmpty;

  OrderCreationState copyWith({
    OrderType? orderType,
    String? pickupName,
    String? pickupPhone,
    String? pickupEmail,
    String? customerUniqueId,
    bool clearCustomerUniqueId = false,
    String? selectedFloor,
    String? selectedTable,
    bool? isPickupValid,
    String? nameError,
    String? phoneError,
  }) {
    return OrderCreationState(
      orderType: orderType ?? this.orderType,
      pickupName: pickupName ?? this.pickupName,
      pickupPhone: pickupPhone ?? this.pickupPhone,
      pickupEmail: pickupEmail ?? this.pickupEmail,
      customerUniqueId: clearCustomerUniqueId
          ? null
          : (customerUniqueId ?? this.customerUniqueId),
      selectedFloor: selectedFloor ?? this.selectedFloor,
      selectedTable: selectedTable ?? this.selectedTable,
      isPickupValid: isPickupValid ?? this.isPickupValid,
      nameError: nameError,
      phoneError: phoneError,
    );
  }

  @override
  List<Object?> get props => [
        orderType,
        pickupName,
        pickupPhone,
        pickupEmail,
        customerUniqueId,
        selectedFloor,
        selectedTable,
        isPickupValid,
        nameError,
        phoneError,
      ];
}
