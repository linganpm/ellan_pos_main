import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:pos_tablet/core/constants/discovery_constants.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/features/company/presentation/company_reports_screen.dart';
import 'package:pos_tablet/features/company/presentation/company_settings_screen.dart';
import 'package:pos_tablet/features/company/presentation/company_staffs_screen.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';

/// Company hub: Settings + Staffs for the open store.
class CompanyHubScreen extends StatefulWidget {
  const CompanyHubScreen({super.key});

  @override
  State<CompanyHubScreen> createState() => _CompanyHubScreenState();
}

class _CompanyHubScreenState extends State<CompanyHubScreen> {
  static const _primary = Color(0xFF4A00E0);
  int? _staffCount;
  int? _reportCount;
  int? _catalogueCount;
  Map<String, dynamic>? _pricePlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCounts();
    });
  }

  Future<void> _loadCounts() async {
    final controller = context.read<UiStoreController>();
    final store = controller.store;
    if (store == null) return;
    try {
      final staff = await controller.listLocalStaffOptions(
        storeId: store.scope.storeId,
      );
      final reports = await store.listReportSubscribers();
      final products = await store.products.searchDetails(scope: store.scope);
      Map<String, dynamic>? plan;
      final token = controller.organisationLogin?.accessToken?.trim() ?? '';
      if (token.isNotEmpty) {
        try {
          final uri = Uri.parse(
            '${discoveryOrigin(kDiscoveryUrl)}/api/pos/store/profile',
          ).replace(queryParameters: controller.companyProfileRefs());
          final response = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final body = jsonDecode(response.body);
            if (body is Map && body['price_plan'] is Map) {
              plan = Map<String, dynamic>.from(body['price_plan'] as Map);
            }
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _staffCount = staff.length;
        _reportCount = reports.length;
        _catalogueCount = products.length;
        _pricePlan = plan;
      });
    } catch (_) {}
  }

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
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            store?.storeName ?? context.l10n.companyOpenStore,
            style: FontUtility.heading.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            context.l10n.commonServiceInstanceShort(
              '${store?.storeRemoteId ?? store?.serviceInstanceId ?? context.l10n.commonEmpty}',
            ),
            style: FontUtility.body.copyWith(color: Colors.black54, fontSize: 13),
          ),
          if (_pricePlan != null) ...[
            const SizedBox(height: 14),
            CompanyPricePlanCard(plan: _pricePlan!),
          ],
          const SizedBox(height: 14),
          _tile(
            context,
            icon: Icons.settings_rounded,
            title: context.l10n.companySettingsTitle,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CompanySettingsScreen(),
                ),
              );
            },
          ),
          _tile(
            context,
            icon: Icons.badge_rounded,
            title: context.l10n.companyStaffsTitle,
            count: _staffCount,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyStaffsScreen()),
              );
              if (mounted) await _loadCounts();
            },
          ),
          _tile(
            context,
            icon: Icons.insights_rounded,
            title: context.l10n.commonReports,
            count: _reportCount,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanyReportsScreen()),
              );
              if (mounted) await _loadCounts();
            },
          ),
          _tile(
            context,
            icon: Icons.storefront_rounded,
            title: context.l10n.storeSetupTitle,
            count: _catalogueCount,
            onTap: () async {
              if (!await _ensureAdmin(context)) return;
              if (!context.mounted) return;
              await Navigator.pushNamed(context, AppRoutes.storeSetup);
              if (mounted) await _loadCounts();
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
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: _primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: FontUtility.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: FontUtility.heading.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded, color: Colors.black38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
