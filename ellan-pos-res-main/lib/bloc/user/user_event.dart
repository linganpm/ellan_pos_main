import 'package:equatable/equatable.dart';

/// Abstract base class for all user-related events.
/// Extends Equatable for value comparison.
abstract class UserEvent extends Equatable {
  const UserEvent();

  @override
  List<Object?> get props => [];
}

/// Event dispatched to initialize the user and store configuration during app launch.
class UserInitializeEvent extends UserEvent {}
