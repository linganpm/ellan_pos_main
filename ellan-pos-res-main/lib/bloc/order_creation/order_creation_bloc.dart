import 'package:flutter_bloc/flutter_bloc.dart';
import 'order_creation_event.dart';
import 'order_creation_state.dart';

class OrderCreationBloc extends Bloc<OrderCreationEvent, OrderCreationState> {
  OrderCreationBloc() : super(const OrderCreationState()) {
    on<SelectOrderType>(_onSelectOrderType);
    on<UpdatePickupDetails>(_onUpdatePickupDetails);
    on<SelectPickupCustomer>(_onSelectPickupCustomer);
    on<ClearPickupCustomer>(_onClearPickupCustomer);
    on<SelectDineInFloor>(_onSelectDineInFloor);
    on<SelectDineInTable>(_onSelectDineInTable);
    on<ValidatePickupForm>(_onValidatePickupForm);
    on<ResetOrderCreation>(_onResetOrderCreation);
  }

  void _onSelectOrderType(SelectOrderType event, Emitter<OrderCreationState> emit) {
    emit(state.copyWith(
      orderType: event.type,
      nameError: null,
      phoneError: null,
    ));
  }

  void _onUpdatePickupDetails(
    UpdatePickupDetails event,
    Emitter<OrderCreationState> emit,
  ) {
    emit(state.copyWith(
      pickupName: event.name,
      pickupPhone: event.phone,
      pickupEmail: event.email,
      clearCustomerUniqueId: true,
      nameError: null,
      phoneError: null,
    ));
  }

  void _onSelectPickupCustomer(
    SelectPickupCustomer event,
    Emitter<OrderCreationState> emit,
  ) {
    emit(state.copyWith(
      customerUniqueId: event.customerUniqueId,
      pickupName: event.name,
      pickupPhone: event.phone,
      pickupEmail: event.email,
      isPickupValid: true,
      nameError: null,
      phoneError: null,
    ));
  }

  void _onClearPickupCustomer(
    ClearPickupCustomer event,
    Emitter<OrderCreationState> emit,
  ) {
    emit(state.copyWith(
      clearCustomerUniqueId: true,
      pickupName: '',
      pickupPhone: '',
      pickupEmail: '',
      isPickupValid: false,
      nameError: null,
      phoneError: null,
    ));
  }

  void _onSelectDineInFloor(SelectDineInFloor event, Emitter<OrderCreationState> emit) {
    emit(state.copyWith(selectedFloor: event.floor, selectedTable: ''));
  }

  void _onSelectDineInTable(SelectDineInTable event, Emitter<OrderCreationState> emit) {
    emit(state.copyWith(selectedTable: event.tableNumber));
  }

  void _onValidatePickupForm(ValidatePickupForm event, Emitter<OrderCreationState> emit) {
    // Selected existing customer (stable unique id) is always valid.
    if (state.hasSelectedCustomer) {
      emit(state.copyWith(
        isPickupValid: true,
        nameError: null,
        phoneError: null,
      ));
      return;
    }

    String? nameError;
    String? phoneError;
    bool isValid = true;

    if (state.pickupName.trim().length < 3) {
      nameError = 'errorNameMinLength';
      isValid = false;
    }

    final RegExp phoneRegExp = RegExp(r'^\d{10}$');
    if (!phoneRegExp.hasMatch(state.pickupPhone.trim())) {
      phoneError = 'errorInvalidPhone';
      isValid = false;
    }

    emit(state.copyWith(
      isPickupValid: isValid,
      nameError: nameError,
      phoneError: phoneError,
    ));
  }

  void _onResetOrderCreation(ResetOrderCreation event, Emitter<OrderCreationState> emit) {
    emit(const OrderCreationState());
  }
}
