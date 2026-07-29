import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/company/presentation/company_reports_screen.dart';
import 'package:pos_tablet/features/company/presentation/company_settings_screen.dart';
import 'package:pos_tablet/features/company/presentation/company_staffs_screen.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// Company hub: Settings + Staffs for the open store.
class CompanyHubScreen extends StatelessWidget {
  const CompanyHubScreen({super.key});

  static const _primary = Color(0xFF4A00E0);

  Future<bool> _ensureAdmin(BuildContext context) async {
    final store = context.read<UiStoreController>().store;
    if (store == null) return false;
    final ok = await store.auth.hasStoreRole('admin');
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.storeAdminAccessRequired)),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<UiStoreController>().store;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: Text(
          context.l10n.commonCompany,
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            store?.storeName ?? context.l10n.companyOpenStore,
            style: FontUtility.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.commonServiceInstanceShort(
              '${store?.storeRemoteId ?? store?.serviceInstanceId ?? context.l10n.commonEmpty}',
            ),
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          _tile(
            context,
            icon: Icons.settings_rounded,
            title: context.l10n.companySettingsTitle,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CompanySettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.badge_rounded,
            title: context.l10n.companyStaffsTitle,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyStaffsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.insights_rounded,
            title: context.l10n.commonReports,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyReportsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _tile(
            context,
            icon: Icons.storefront_rounded,
            title: context.l10n.storeSetupTitle,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              Navigator.pushNamed(context, AppRoutes.storeSetup);
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: FontUtility.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
