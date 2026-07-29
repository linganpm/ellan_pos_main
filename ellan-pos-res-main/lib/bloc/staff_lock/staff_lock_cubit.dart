import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffLockState extends Equatable {
  final String identifier;
  final String password;
  final bool obscurePassword;
  final bool isLoading;
  final bool loadingStaff;
  final String? errorMessage;
  final bool unlocked;
  final bool needsStorePicker;
  final bool needsOnlineRenew;
  final String? storeId;
  final String? storeName;
  final List<PosStaffOption> staffOptions;
  final List<PosStaffOption> recentStaff;
  final String? selectedCustomerId;
  final bool showAllStaff;

  const StaffLockState({
    this.identifier = '',
    this.password = '',
    this.obscurePassword = true,
    this.isLoading = false,
    this.loadingStaff = false,
    this.errorMessage,
    this.unlocked = false,
    this.needsStorePicker = false,
    this.needsOnlineRenew = false,
    this.storeId,
    this.storeName,
    this.staffOptions = const [],
    this.recentStaff = const [],
    this.selectedCustomerId,
    this.showAllStaff = false,
  });

  bool get isValid => identifier.trim().isNotEmpty && password.isNotEmpty;

  /// Up to 4 recent badges; falls back to first staff when no recents yet.
  List<PosStaffOption> get badgeStaff {
    final recentIds = recentStaff.map((s) => s.customerId).toSet();
    final recentKeys = recentStaff
        .map((s) => s.identifier.toLowerCase())
        .toSet();
    final badges = <PosStaffOption>[...recentStaff.take(4)];
    if (badges.length < 4) {
      for (final option in staffOptions) {
        if (badges.length >= 4) break;
        if (recentIds.contains(option.customerId) ||
            recentKeys.contains(option.identifier.toLowerCase())) {
          continue;
        }
        badges.add(option);
      }
    }
    return badges;
  }

  bool get hasMoreStaff => staffOptions.length > badgeStaff.length;

  StaffLockState copyWith({
    String? identifier,
    String? password,
    bool? obscurePassword,
    bool? isLoading,
    bool? loadingStaff,
    String? errorMessage,
    bool clearError = false,
    bool? unlocked,
    bool? needsStorePicker,
    bool? needsOnlineRenew,
    String? storeId,
    String? storeName,
    List<PosStaffOption>? staffOptions,
    List<PosStaffOption>? recentStaff,
    String? selectedCustomerId,
    bool clearSelectedStaff = false,
    bool? showAllStaff,
  }) {
    return StaffLockState(
      identifier: identifier ?? this.identifier,
      password: password ?? this.password,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isLoading: isLoading ?? this.isLoading,
      loadingStaff: loadingStaff ?? this.loadingStaff,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      unlocked: unlocked ?? this.unlocked,
      needsStorePicker: needsStorePicker ?? this.needsStorePicker,
      needsOnlineRenew: needsOnlineRenew ?? this.needsOnlineRenew,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      staffOptions: staffOptions ?? this.staffOptions,
      recentStaff: recentStaff ?? this.recentStaff,
      selectedCustomerId: clearSelectedStaff
          ? null
          : (selectedCustomerId ?? this.selectedCustomerId),
      showAllStaff: showAllStaff ?? this.showAllStaff,
    );
  }

  @override
  List<Object?> get props => [
    identifier,
    password,
    obscurePassword,
    isLoading,
    loadingStaff,
    errorMessage,
    unlocked,
    needsStorePicker,
    needsOnlineRenew,
    storeId,
    storeName,
    staffOptions,
    recentStaff,
    selectedCustomerId,
    showAllStaff,
  ];
}

class StaffLockCubit extends Cubit<StaffLockState> {
  final SharedPreferences prefs;
  final String? preferredStoreId;
  final String? storeNameHint;

  StaffLockCubit({
    required this.prefs,
    this.preferredStoreId,
    this.storeNameHint,
  }) : super(
         StaffLockState(
           identifier:
               prefs.getString('lastStaffIdentifier') ??
               prefs.getString('userEmail') ??
               '',
           storeId: preferredStoreId ?? prefs.getString('selectedStoreId'),
           storeName: (storeNameHint ?? '').trim().isNotEmpty
               ? storeNameHint!.trim()
               : prefs.getString('selectedStoreName'),
           loadingStaff: true,
         ),
       ) {
    loadStaffOptions();
  }

  Future<void> loadStaffOptions() async {
    emit(state.copyWith(loadingStaff: true, clearError: true));
    final controller = getIt<UiStoreController>();
    final storeId = preferredStoreId ?? state.storeId;
    final resolvedName =
        controller.staffUnlockStoreName(storeId: storeId) ??
        ((storeNameHint ?? '').trim().isNotEmpty
            ? storeNameHint!.trim()
            : null) ??
        prefs.getString('selectedStoreName');
    final earlyName = (resolvedName ?? state.storeName ?? '').trim();
    if (earlyName.isNotEmpty) {
      emit(state.copyWith(loadingStaff: true, storeName: earlyName));
    }
    try {
      final staff = await controller.listLocalStaffOptions(storeId: storeId);
      final recent = await controller.loadRecentStaffOptions();
      // Keep recent entries that still exist in this store's staff list only.
      final byId = {for (final s in staff) s.customerId: s};
      final byIdent = {for (final s in staff) s.identifier.toLowerCase(): s};
      final resolvedRecent = <PosStaffOption>[];
      for (final row in recent) {
        final match =
            byId[row.customerId] ?? byIdent[row.identifier.toLowerCase()];
        if (match == null) continue;
        if (resolvedRecent.any(
          (s) =>
              s.customerId == match.customerId ||
              s.identifier.toLowerCase() == match.identifier.toLowerCase(),
        )) {
          continue;
        }
        resolvedRecent.add(match);
      }

      String? selectedId = state.selectedCustomerId;
      final currentId = state.identifier.trim().toLowerCase();
      if (selectedId == null && currentId.isNotEmpty) {
        for (final option in staff) {
          if (option.identifier.toLowerCase() == currentId ||
              option.name.toLowerCase() == currentId) {
            selectedId = option.customerId;
            break;
          }
        }
      }
      final name = (resolvedName ?? '').trim();
      if (name.isNotEmpty) {
        await prefs.setString('selectedStoreName', name);
      }
      emit(
        state.copyWith(
          loadingStaff: false,
          storeName: name.isNotEmpty ? name : state.storeName,
          staffOptions: staff,
          recentStaff: resolvedRecent,
          selectedCustomerId: selectedId,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          loadingStaff: false,
          storeName: (resolvedName ?? '').trim().isNotEmpty
              ? resolvedName!.trim()
              : state.storeName,
          staffOptions: const [],
          recentStaff: const [],
        ),
      );
    }
  }

  void identifierChanged(String value) {
    final trimmed = value.trim().toLowerCase();
    String? selectedId;
    for (final option in state.staffOptions) {
      if (option.identifier.toLowerCase() == trimmed ||
          option.name.toLowerCase() == trimmed) {
        selectedId = option.customerId;
        break;
      }
    }
    emit(
      state.copyWith(
        identifier: value,
        clearError: true,
        selectedCustomerId: selectedId,
        clearSelectedStaff: selectedId == null,
      ),
    );
  }

  void selectStaff(PosStaffOption staff) {
    emit(
      state.copyWith(
        identifier: staff.identifier,
        selectedCustomerId: staff.customerId,
        clearError: true,
        showAllStaff: false,
      ),
    );
  }

  void toggleShowAllStaff() {
    emit(state.copyWith(showAllStaff: !state.showAllStaff));
  }

  void passwordChanged(String value) {
    emit(state.copyWith(password: value, clearError: true));
  }

  void togglePasswordVisibility() {
    emit(state.copyWith(obscurePassword: !state.obscurePassword));
  }

  Future<void> unlock() async {
    if (state.isLoading) return;
    if (!state.isValid) {
      emit(state.copyWith(errorMessage: 'Enter staff ID and password'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final controller = getIt<UiStoreController>();
      final result = await controller.unlockStaff(
        identifier: state.identifier,
        password: state.password,
        storeId: preferredStoreId ?? state.storeId,
      );

      if (result.needsOnlineRenew) {
        emit(
          state.copyWith(
            isLoading: false,
            needsOnlineRenew: true,
            errorMessage: result.message,
          ),
        );
        return;
      }

      if (!result.ok) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: result.message ?? 'Could not unlock',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          unlocked: true,
          needsStorePicker: result.needsStorePicker,
          storeId: result.storeId,
          password: '',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: userFacingError(
            e,
            fallback: 'Could not unlock. Try again.',
          ),
        ),
      );
    }
  }
}
