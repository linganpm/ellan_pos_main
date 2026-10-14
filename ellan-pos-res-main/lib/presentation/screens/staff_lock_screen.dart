import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_approval.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/login_lease_store.dart';
import 'package:pos_tablet/core/pos_lock_pin.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/customer_support.dart';
import 'package:pos_tablet/presentation/widgets/pin_pad.dart';
import '../../core/localization/l10n_context.dart';

const _accent = Color(0xFF4A00E0);
const _danger = Color(0xFFD92D20);
const _maxAttempts = 5;

/// Lock screen for a shared tablet: any staff member who signed in here before
/// picks their name and unlocks with their PIN, fully offline. New staff or a
/// forgotten PIN go through online Sign in.
class StaffLockScreen extends StatefulWidget {
  final String? storeId;
  final String? storeNameHint;

  const StaffLockScreen({super.key, this.storeId, this.storeNameHint});

  @override
  State<StaffLockScreen> createState() => _StaffLockScreenState();
}

class _StaffLockScreenState extends State<StaffLockScreen> {
  final PosLockPinStore _pins = PosLockPinStore(getIt<SharedPreferences>());
  late final List<PosLockPin> _staff = _pins.loadAll();
  late PosLockPin? _pin = _initialStaff();
  String _value = '';
  String? _error;
  int _failures = 0;
  bool _busy = false;

  String get _storeName {
    final hint = widget.storeNameHint?.trim() ?? '';
    if (hint.isNotEmpty) return hint;
    return getIt<UiStoreController>().staffUnlockStoreName(
          storeId: widget.storeId,
        ) ??
        '';
  }

  PosLockPin? _initialStaff() {
    if (_staff.isEmpty) return null;
    final last = _pins.lastCustomerId;
    return _staff.firstWhere(
      (p) => p.customerId == last,
      orElse: () => _staff.first,
    );
  }

  void _select(PosLockPin pin) {
    if (_busy || identical(pin, _pin)) return;
    setState(() {
      _pin = pin;
      _value = '';
      _error = null;
      _failures = 0;
    });
  }

  void _goToSignIn() {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _onChanged(String value) async {
    setState(() {
      _value = value;
      _error = null;
    });
    if (value.length < kPosPinLength) return;

    final pin = _pin;
    if (pin == null || !pin.verify(value)) {
      _failures++;
      if (_failures >= _maxAttempts) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.lockTooManyAttempts)),
        );
        _goToSignIn();
        return;
      }
      setState(() {
        _value = '';
        _error = context.l10n.lockWrongPin(_maxAttempts - _failures);
      });
      return;
    }

    setState(() => _busy = true);
    final message = await _unlockProblem(pin);
    if (!mounted) return;
    if (message == null) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _goToSignIn();
  }

  /// Why the PIN alone cannot reopen the session (null when it can).
  /// Local checks only: lock/unlock must work without network.
  Future<String?> _unlockProblem(PosLockPin pin) async {
    final l10n = context.l10n;
    final controller = getIt<UiStoreController>();
    try {
      await controller.ensureDeviceAllowedOffline();
    } on DeviceAccessDeniedException catch (e) {
      return e.userMessage;
    }
    final lease = await LoginLeaseStore.open();
    if (lease.isExpired) return l10n.lockLeaseExpired;

    if (!await controller.openSessionForPin(pin)) {
      return l10n.lockNoStoreAccess(pin.name);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pin = _pin;
    final storeName = _storeName;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Material(
                    color: Colors.white,
                    elevation: 2,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_staff.length > 1) ...[
                            Text(
                              l10n.lockChooseStaff,
                              style: FontUtility.body.copyWith(
                                color: Colors.black54,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final staff in _staff)
                                  _StaffChip(
                                    name: staff.name,
                                    selected: identical(staff, pin),
                                    onTap: () => _select(staff),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          _Avatar(name: pin?.name ?? ''),
                          const SizedBox(height: 14),
                          Text(
                            pin != null ? pin.name : l10n.lockSignedOutTitle,
                            textAlign: TextAlign.center,
                            style: FontUtility.heading.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            pin != null
                                ? (storeName.isNotEmpty
                                      ? l10n.lockEnterPinAt(storeName)
                                      : l10n.lockEnterPin)
                                : l10n.lockSignedOutBody,
                            textAlign: TextAlign.center,
                            style: FontUtility.body.copyWith(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          if (pin != null) ...[
                            const SizedBox(height: 28),
                            PinPad(
                              value: _value,
                              error: _error != null,
                              enabled: !_busy,
                              onChanged: _onChanged,
                            ),
                            SizedBox(
                              height: 30,
                              child: Center(
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _error ?? '',
                                        style: FontUtility.body.copyWith(
                                          color: _danger,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ] else
                            const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: pin != null
                                ? OutlinedButton.icon(
                                    onPressed: _busy ? null : _goToSignIn,
                                    icon: const Icon(Icons.login_rounded),
                                    label: Text(l10n.lockSignInInstead),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _accent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  )
                                : FilledButton.icon(
                                    onPressed: _goToSignIn,
                                    icon: const Icon(Icons.login_rounded),
                                    label: Text(l10n.lockSignIn),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _accent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 12,
              right: 16,
              child: CustomerSupportButton(filled: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _StaffChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: CircleAvatar(
        backgroundColor: selected
            ? Colors.white
            : _accent.withValues(alpha: 0.1),
        child: Text(
          name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: const TextStyle(
            color: _accent,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      label: Text(name),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF1F2937),
        fontWeight: FontWeight.w600,
      ),
      selectedColor: _accent,
      backgroundColor: const Color(0xFFF3F5F9),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '' : name.trim()[0].toUpperCase();
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: initial.isEmpty
            ? const Icon(Icons.lock_rounded, color: _accent, size: 32)
            : Text(
                initial,
                style: FontUtility.heading.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                ),
              ),
      ),
    );
  }
}
