import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Add cashier — online + org JWT. Always creates a Cashier on the open store.
class StaffSignupScreen extends StatefulWidget {
  const StaffSignupScreen({super.key});

  @override
  State<StaffSignupScreen> createState() => _StaffSignupScreenState();
}

class _StaffSignupScreenState extends State<StaffSignupScreen> {
  static const _primary = Color(0xFF4A00E0);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);
  static const _surface = Color(0xFFF3F5F9);

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _country = TextEditingController();
  final _role = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _localizedDefaultsSeeded = false;

  @override
  void initState() {
    super.initState();
    _resolveCountry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizedDefaultsSeeded) return;
    _localizedDefaultsSeeded = true;
    _role.text = context.l10n.storeSetupCashier;
    _country.text = context.l10n.signupCountry;
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _country.dispose();
    _role.dispose();
    super.dispose();
  }

  Future<void> _resolveCountry() async {
    final controller = context.read<UiStoreController>();
    final storeId = controller.store?.storeId;
    final prefs = getIt.isRegistered<SharedPreferences>()
        ? getIt<SharedPreferences>()
        : await SharedPreferences.getInstance();
    final meta = DeviceSetupStore(prefs).countryMetaForStore(storeId);
    final parts = <String>[
      if (meta.flag.trim().isNotEmpty) meta.flag.trim(),
      if (meta.name.trim().isNotEmpty) meta.name.trim(),
      if (meta.name.trim().isEmpty && meta.code.trim().isNotEmpty)
        meta.code.trim().toUpperCase(),
    ];
    if (!mounted) return;
    if (parts.isNotEmpty) {
      setState(() => _country.text = parts.join('  '));
    }
  }

  Future<void> _submit() async {
    final controller = context.read<UiStoreController>();
    final login = controller.organisationLogin;
    final store = controller.store;
    final token = login?.accessToken?.trim() ?? '';
    final orgInstance = (login?.serviceInstanceId ?? '').trim().isNotEmpty
        ? login!.serviceInstanceId!.trim()
        : (login?.organisation.orgId.trim() ?? '');

    if (token.isEmpty) {
      setState(
        () => _error =
            'Sign in online first so this tablet has an org session token.',
      );
      return;
    }
    if (orgInstance.isEmpty) {
      setState(() => _error = 'Missing organisation instance id.');
      return;
    }
    if (store == null) {
      setState(
        () => _error = 'Open a store first so staff can be posted to it.',
      );
      return;
    }
    if (_first.text.trim().isEmpty ||
        _last.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _password.text.trim().length < 6 ||
        !RegExp(r'^[A-Za-z0-9]+$').hasMatch(_password.text.trim())) {
      setState(
        () => _error =
            'Fill name, email, phone, and password (min 6 letters/digits).',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final origin = discoveryOrigin(kDiscoveryUrl);
      final uri = Uri.parse('$origin/api/pos/staff/private-signup');
      final branchSi = (store.storeRemoteId ?? '').trim().isNotEmpty
          ? store.storeRemoteId!.trim()
          : (store.serviceInstanceId > 0
                ? '${store.serviceInstanceId}'
                : store.uniqueId);
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'org_instance_id': orgInstance,
          'branch_service_instance': branchSi,
          'fname': _first.text.trim(),
          'lname': _last.text.trim(),
          'email': _email.text.trim(),
          'phn_nbr': _phone.text.trim(),
          'password': _password.text.trim(),
          // Country comes from the store/org on the server — not editable here.
          'role': 'cashier',
          'private_signup': true,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Signup failed (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) {
            message = '${body['message']}';
          }
        } catch (_) {}
        throw StateError(message);
      }
      if (!mounted) return;
      try {
        await controller.syncFromRemote();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.storeSetupCashierCreated)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = userFacingError(e, fallback: 'Could not create staff.'),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: FontUtility.body.copyWith(
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _section({
    required Color accent,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: FontUtility.heading.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Text(
          context.l10n.storeSetupAddCashier,
          style: FontUtility.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: FontUtility.body.copyWith(
                      color: const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _section(
                accent: const Color(0xFF0EA5E9),
                icon: Icons.badge_outlined,
                title: context.l10n.profileTitle,
                children: [
                  TextField(
                    controller: _first,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_loading,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration('First name'),
                  ),
                  _gap(),
                  TextField(
                    controller: _last,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_loading,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration('Last name'),
                  ),
                  _gap(),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration(context.l10n.commonEmail),
                  ),
                  _gap(),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: !_loading,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration(context.l10n.commonPhone),
                  ),
                  _gap(),
                  TextField(
                    enabled: false,
                    controller: _country,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration('Country').copyWith(
                      filled: true,
                      fillColor: const Color(0xFFEEF2F7),
                      suffixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: _muted,
                      ),
                    ),
                  ),
                ],
              ),
              _section(
                accent: const Color(0xFF10B981),
                icon: Icons.lock_outline_rounded,
                title: context.l10n.storeSetupAccess,
                children: [
                  TextField(
                    controller: _password,
                    obscureText: true,
                    enabled: !_loading,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration(context.l10n.commonPassword),
                  ),
                  _gap(),
                  TextField(
                    enabled: false,
                    controller: _role,
                    style: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    decoration: _fieldDecoration('Role').copyWith(
                      filled: true,
                      fillColor: const Color(0xFFEEF2F7),
                      suffixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: _muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: FontUtility.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(context.l10n.storeSetupCreateCashier),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
