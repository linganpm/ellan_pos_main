import 'package:equatable/equatable.dart';

/// Abstract base class for all user states.
abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

/// Device is ready and a staff member is signed in for [storeId].
class UserLoaded extends UserState {
  final String storeId;

  const UserLoaded(this.storeId);

  @override
  List<Object?> get props => [storeId];
}

/// Device lease is valid — wait for the next staff member to unlock.
///
/// Does not auto-login the previous operator (many staff share one tablet).
class UserNeedsStaffUnlock extends UserState {
  final String? storeId;
  final bool leaseExpired;

  const UserNeedsStaffUnlock({this.storeId, this.leaseExpired = false});

  @override
  List<Object?> get props => [storeId, leaseExpired];
}

class UserError extends UserState {
  final String message;

  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}
