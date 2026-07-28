import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/bloc/staff_lock/staff_lock_cubit.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fast staff unlock / switch screen for shared POS tablets.
///
/// Device lease stays valid; only the operator session changes here.
class StaffLockScreen extends StatelessWidget {
  final String? storeId;

  const StaffLockScreen({super.key, this.storeId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StaffLockCubit(
        prefs: context.read<SharedPreferences>(),
        preferredStoreId: storeId,
      ),
      child: _StaffLockView(storeId: storeId),
    );
  }
}

class _StaffLockView extends StatefulWidget {
  final String? storeId;

  const _StaffLockView({this.storeId});

  @override
  State<_StaffLockView> createState() => _StaffLockViewState();
}

class _StaffLockViewState extends State<_StaffLockView> {
  static const _primary = Color(0xFF4A00E0);

  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocus;

  @override
  void initState() {
    super.initState();
    final state = context.read<StaffLockCubit>().state;
    _identifierController = TextEditingController(text: state.identifier);
    _passwordController = TextEditingController();
    _passwordFocus = FocusNode();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onStaffSelected(PosStaffOption staff) {
    context.read<StaffLockCubit>().selectStaff(staff);
    _identifierController.text = staff.identifier;
    _identifierController.selection = TextSelection.collapsed(
      offset: staff.identifier.length,
    );
    _passwordFocus.requestFocus();
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: FontUtility.body.copyWith(
        color: Colors.black38,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF7F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD), width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Future<void> _showMoreStaff(StaffLockState state) async {
    final selected = await showModalBottomSheet<PosStaffOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All staff',
                  style: FontUtility.heading.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.staffOptions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final staff = state.staffOptions[index];
                      final selected =
                          state.selectedCustomerId == staff.customerId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: selected
                              ? _primary
                              : _primary.withValues(alpha: 0.12),
                          child: Text(
                            staff.name.isNotEmpty
                                ? staff.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: selected ? Colors.white : _primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          staff.name,
                          style: FontUtility.subheading.copyWith(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(staff.identifier),
                        trailing: selected
                            ? const Icon(Icons.check_rounded, color: _primary)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, staff),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      _onStaffSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: BlocConsumer<StaffLockCubit, StaffLockState>(
                listener: (context, state) {
                  if (state.needsOnlineRenew) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                    return;
                  }
                  if (!state.unlocked) return;
                  if (state.needsStorePicker) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.storeList,
                      (route) => false,
                    );
                    return;
                  }
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  );
                },
                builder: (context, state) {
                  final badges = state.badgeStaff;
                  return Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Staff unlock',
                              textAlign: TextAlign.center,
                              style: FontUtility.heading.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (state.loadingStaff) ...[
                              const SizedBox(height: 20),
                              const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ] else if (badges.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final staff in badges)
                                    _StaffBadge(
                                      name: staff.name,
                                      selected: state.selectedCustomerId ==
                                          staff.customerId,
                                      onTap: () => _onStaffSelected(staff),
                                    ),
                                  if (state.hasMoreStaff)
                                    _StaffBadge(
                                      name: 'More',
                                      selected: false,
                                      isMore: true,
                                      onTap: () => _showMoreStaff(state),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),
                            TextField(
                              controller: _identifierController,
                              onChanged: context
                                  .read<StaffLockCubit>()
                                  .identifierChanged,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                              style: FontUtility.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                              decoration: _fieldDecoration(
                                hint: 'Staff ID',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: state.obscurePassword,
                              onChanged: context
                                  .read<StaffLockCubit>()
                                  .passwordChanged,
                              onSubmitted: (_) =>
                                  context.read<StaffLockCubit>().unlock(),
                              style: FontUtility.body.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                              decoration: _fieldDecoration(
                                hint: 'Password',
                                suffixIcon: IconButton(
                                  onPressed: context
                                      .read<StaffLockCubit>()
                                      .togglePasswordVisibility,
                                  icon: Icon(
                                    state.obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                  ),
                                ),
                              ),
                            ),
                            if (state.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                state.errorMessage!,
                                style: FontUtility.body.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 56,
                              child: FilledButton(
                                onPressed: state.isLoading
                                    ? null
                                    : () => context
                                        .read<StaffLockCubit>()
                                        .unlock(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: state.isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Unlock',
                                        style: FontUtility.button.copyWith(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.login);
                              },
                              child: Text(
                                'Online device sign-in',
                                style: FontUtility.body.copyWith(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffBadge extends StatelessWidget {
  final String name;
  final bool selected;
  final bool isMore;
  final VoidCallback onTap;

  const _StaffBadge({
    required this.name,
    required this.selected,
    required this.onTap,
    this.isMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Material(
      color: selected
          ? const Color(0xFF4A00E0)
          : isMore
              ? Colors.white
              : const Color(0xFFF3F0FF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              width: 1.5,
              color: selected
                  ? const Color(0xFF4A00E0)
                  : const Color(0xFF4A00E0).withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFF4A00E0).withValues(alpha: 0.12),
                child: isMore
                    ? Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: selected ? Colors.white : const Color(0xFF4A00E0),
                      )
                    : Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : const Color(0xFF4A00E0),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: FontUtility.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: selected ? Colors.white : const Color(0xFF4A00E0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
