import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/customer_identity.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/staff_logout_confirm_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only profile / account screen for the signed-in POS operator.
///
/// Surfaces everything the device knows about the current user (session,
/// directory customer row), their organisation, the open store and the
/// stores they can access, plus a sign-out action.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _primary = Color(0xFF4A00E0);

  bool _loading = true;
  String? _error;

  StoreSession? _session;
  StoreCustomer? _customer;
  StoreRoleAccess? _storeAccess;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final session = await controller.currentSession();
      final customer = await controller.currentCustomer();
      final storeAccess = await controller.currentStoreAccess();
      if (!mounted) return;
      setState(() {
        _session = session;
        _customer = customer;
        _storeAccess = storeAccess;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showStaffLogoutConfirmDialog(context);
    if (!confirmed) return;

    final controller = getIt<UiStoreController>();
    final storeId = controller.store?.scope.storeId;
    final storeName = controller.store?.storeName;
    try {
      await controller.lockStaff();
    } catch (_) {
      // Still return to the lock screen.
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.staffLock,
      (route) => false,
      arguments: {
        'storeId': storeId,
        'storeName': storeName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Profile', style: FontUtility.heading.copyWith(fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      body: SafeArea(
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF512F), size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = getIt<UiStoreController>();
    final organisation = controller.organisation;
    final store = controller.store;
    final accessibleStores = controller.accessibleStores();

    final displayName = _displayName();
    final email = _customer?.email.trim().isNotEmpty == true
        ? _customer!.email.trim()
        : (_session?.email.trim() ?? '');
    final orgRole = _session?.organisationRole.trim() ?? '';
    final storeRole = (_storeAccess?.role.trim().isNotEmpty == true
        ? _storeAccess!.role.trim()
        : (_session?.storeRole.trim() ?? ''));
    final userId = displayCustomerIdentity(
      regNum: _customer?.usrRegNum,
      customerId: _customer?.customerId.trim().isNotEmpty == true
          ? _customer!.customerId.trim()
          : (_session?.customerId.trim() ?? ''),
      email: email,
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _profileHeader(
          name: displayName,
          email: email,
          orgRole: orgRole,
          storeRole: storeRole,
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Account',
          icon: Icons.person_rounded,
          rows: [
            _DetailRow('Name', displayName),
            _DetailRow('Email', email),
            if ((_customer?.phone ?? '').trim().isNotEmpty)
              _DetailRow('Phone', _customer!.phone.trim()),
            if (userId.isNotEmpty) _DetailRow('Reg no.', userId),
            if (orgRole.isNotEmpty) _DetailRow('Organisation role', orgRole),
            if (storeRole.isNotEmpty) _DetailRow('Store role', storeRole),
            if ((_session?.loginAt ?? '').trim().isNotEmpty)
              _DetailRow('Signed in', _formatDateTime(_session!.loginAt)),
          ],
        ),
        if (organisation != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Organisation',
            icon: Icons.business_rounded,
            rows: [
              _DetailRow('Name', organisation.orgName),
              _DetailRow('Code', organisation.orgCode),
              if (organisation.posCode.trim().isNotEmpty)
                _DetailRow('POS code', organisation.posCode),
            ],
          ),
        ],
        if (store != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Current store',
            icon: Icons.storefront_rounded,
            rows: [
              _DetailRow('Store', store.storeName),
              if (store.uniqueId.trim().isNotEmpty)
                _DetailRow('Store ID', store.uniqueId.trim()),
              _DetailRow('Service instance', store.serviceInstanceId.toString()),
              if (store.serviceVariantType.trim().isNotEmpty)
                _DetailRow('Type', store.serviceVariantType.trim()),
              if (store.contactEmail.trim().isNotEmpty)
                _DetailRow('Contact email', store.contactEmail.trim()),
              if (store.phone.trim().isNotEmpty)
                _DetailRow('Phone', store.phone.trim()),
              if (store.status.trim().isNotEmpty)
                _DetailRow('Status', store.status.trim()),
            ],
          ),
        ],
        if (accessibleStores.isNotEmpty) ...[
          const SizedBox(height: 16),
          _accessibleStoresCard(accessibleStores, store?.storeId),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.deviceSettings),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Device settings'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              side: const BorderSide(color: _primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _displayName() {
    final customerName = _customer?.name.trim() ?? '';
    if (customerName.isNotEmpty) return customerName;
    final email = _session?.email.trim() ?? _customer?.email.trim() ?? '';
    if (email.isNotEmpty) {
      final handle = email.split('@').first.trim();
      if (handle.isNotEmpty) return handle;
    }
    return 'POS Operator';
  }

  Widget _profileHeader({
    required String name,
    required String email,
    required String orgRole,
    required String storeRole,
  }) {
    final initials = _initials(name);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: FontUtility.heading.copyWith(
                color: Colors.white,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: FontUtility.heading.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: FontUtility.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (orgRole.isNotEmpty) _roleChip(orgRole),
                    if (storeRole.isNotEmpty && storeRole != orgRole)
                      _roleChip(storeRole),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: FontUtility.button.copyWith(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<_DetailRow> rows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: FontUtility.heading.copyWith(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 16),
          ...rows.map(_buildDetailRow),
        ],
      ),
    );
  }

  Widget _buildDetailRow(_DetailRow row) {
    final value = row.value.trim().isEmpty ? '—' : row.value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              row.label,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: FontUtility.subheading.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessibleStoresCard(
    List<StoreAccessibleStore> stores,
    String? currentStoreId,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store_mall_directory_rounded,
                    color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('My stores (${stores.length})',
                  style: FontUtility.heading.copyWith(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 8),
          ...stores.map((entry) {
            final isCurrent = currentStoreId != null &&
                entry.store.storeId == currentStoreId;
            final role = entry.access.role.trim();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _primary.withValues(alpha: 0.1),
                    child: Text(
                      _initials(entry.store.storeName),
                      style: FontUtility.button
                          .copyWith(color: _primary, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.store.storeName.isEmpty
                              ? 'Store'
                              : entry.store.storeName,
                          style: FontUtility.subheading.copyWith(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (role.isNotEmpty)
                          Text(
                            role,
                            style: FontUtility.body.copyWith(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Current',
                        style: FontUtility.button
                            .copyWith(color: _primary, fontSize: 11),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatDateTime(String raw) {
    final prefs = getIt<SharedPreferences>();
    final storeId = getIt<UiStoreController>().store?.storeId;
    final tzName = DeviceSetupStore(prefs).timezoneForStore(storeId);
    final local = OrgTimezone.tryParseWallClock(raw, tzName);
    if (local == null) return raw;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} · $hour:$minute $suffix';
  }
}

class _DetailRow {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);
}
