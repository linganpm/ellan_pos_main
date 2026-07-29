import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/core/utils/user_facing_error.dart';
import 'package:pos_tablet/features/store_setup/presentation/staff_signup_screen.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// List store staff and add cashiers (online signup).
class CompanyStaffsScreen extends StatefulWidget {
  const CompanyStaffsScreen({super.key});

  @override
  State<CompanyStaffsScreen> createState() => _CompanyStaffsScreenState();
}

class _CompanyStaffsScreenState extends State<CompanyStaffsScreen> {
  static const _primary = Color(0xFF4A00E0);
  static const _ink = Color(0xFF1A1A2E);
  static const _muted = Color(0xFF6B7280);
  static const _surface = Color(0xFFF3F5F9);

  List<PosStaffOption> _staff = [];
  Map<String, Map<String, dynamic>> _detailsById = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = context.read<UiStoreController>();
      final store = controller.store;
      final storeId = store?.storeId;
      final staff = await controller.listLocalStaffOptions(storeId: storeId);
      final details = <String, Map<String, dynamic>>{};
      if (store != null) {
        try {
          final customers = await store.customers.listDetails(
            scope: store.scope,
            limit: 500,
          );
          for (final c in customers) {
            details[c.customerId] = {
              'email': c.email,
              'phone': c.phone,
              'role': c.role,
              'name': c.name,
              'photo_path': c.photoPath,
            };
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _detailsById = details;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(
          e,
          fallback: context.l10n.errorCouldNotLoadStaff,
        );
        _loading = false;
      });
    }
  }

  Future<void> _addStaff() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffSignupScreen()),
    );
    if (!mounted) return;
    await _reload();
  }

  String _roleLabel(String raw) {
    final role = raw.trim().toLowerCase();
    if (role.isEmpty) return context.l10n.storeSetupCashier;
    if (role.contains('admin')) return context.l10n.storeSetupStoreAdmin;
    if (role.contains('cashier') ||
        role.contains('member') ||
        role.contains('support')) {
      return context.l10n.storeSetupCashier;
    }
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Text(
          context.l10n.commonStaff,
          style: FontUtility.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        actions: [
          Tooltip(
            message: context.l10n.actionRefresh,
            child: Semantics(
              label: context.l10n.actionRefresh,
              button: true,
              child: IconButton(
                onPressed: _loading ? null : _reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Tooltip(
        message: context.l10n.storeSetupAddCashier,
        child: Semantics(
          label: context.l10n.storeSetupAddCashier,
          button: true,
          child: FloatingActionButton(
            onPressed: _addStaff,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: FontUtility.body.copyWith(
                    color: const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : _staff.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: _primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.storeSetupNoCashiersYet,
                      style: FontUtility.heading.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
              itemCount: _staff.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = _staff[i];
                final detail = _detailsById[s.customerId] ?? const {};
                final email = '${detail['email'] ?? ''}'.trim();
                final phone = '${detail['phone'] ?? ''}'.trim();
                final role = _roleLabel('${detail['role'] ?? ''}');
                final name = s.name.trim().isNotEmpty
                    ? s.name.trim()
                    : '${detail['name'] ?? s.identifier}'.trim();
                final identifier = s.identifier.trim();
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        _StaffAvatar(
                          name: name.isEmpty ? '?' : name,
                          photoPath: '${detail['photo_path'] ?? ''}'.trim(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? identifier : name,
                                style: FontUtility.body.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: FontUtility.body.copyWith(
                                    color: _muted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  phone,
                                  style: FontUtility.body.copyWith(
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            role,
                            style: FontUtility.body.copyWith(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StaffAvatar extends StatelessWidget {
  final String name;
  final String photoPath;

  const _StaffAvatar({required this.name, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4A00E0);
    final initial = (name.isNotEmpty ? name[0] : '?').toUpperCase();
    if (photoPath.isNotEmpty) {
      final file = File(photoPath);
      if (file.existsSync()) {
        return CircleAvatar(
          radius: 28,
          backgroundColor: primary.withValues(alpha: 0.12),
          backgroundImage: FileImage(file),
        );
      }
    }
    return CircleAvatar(
      radius: 28,
      backgroundColor: primary.withValues(alpha: 0.12),
      child: Text(
        initial,
        style: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }
}
