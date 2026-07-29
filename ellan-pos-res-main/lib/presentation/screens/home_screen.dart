import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/presentation/screens/order_create_screen.dart';
import 'package:pos_tablet/presentation/screens/scheduled_payments_screen.dart';
import 'package:pos_tablet/presentation/widgets/order_creation_sheet.dart';
import 'package:pos_tablet/presentation/widgets/org_local_clock_badge.dart';
import 'package:pos_tablet/presentation/widgets/staff_logout_confirm_dialog.dart';
import '../../bloc/cart/cart_event.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/localization/l10n_context.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/language/language_bloc.dart';
import '../../bloc/language/language_event.dart';
import 'dashboard_screen.dart';
import 'order_list_screen.dart';
import 'customers_screen.dart';
import 'catalog_screen.dart';
import 'credits_screen.dart';
import 'refunds_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool openNewOrderSheet;
  final bool openOrders;

  const HomeScreen({
    super.key,
    this.openNewOrderSheet = false,
    this.openOrders = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _scheduledTodayCount = 0;
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    _loadScheduledToday();
    _loadDraftCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openOrders) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrderListScreen()),
        );
      } else if (widget.openNewOrderSheet) {
        showOrderCreationBottomSheet(context);
      }
    });
  }

  Future<void> _loadDraftCount() async {
    try {
      final drafts = await CartDraftStore.list();
      if (!mounted) return;
      if (_draftCount == drafts.length) return;
      setState(() => _draftCount = drafts.length);
    } catch (_) {
      // Ignore — drafts are optional local cache.
    }
  }

  Future<void> _openDraftsSheet() async {
    final drafts = await CartDraftStore.list();
    if (!mounted) return;
    setState(() => _draftCount = drafts.length);
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.homeNoSavedDrafts)));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.homeSavedDrafts,
                  style: FontUtility.heading.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drafts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final draft = drafts[index];
                      final itemLines = draft.items
                          .map((item) {
                            final qty =
                                item.quantity == item.quantity.roundToDouble()
                                ? '${item.quantity.toInt()}'
                                : item.quantity.toStringAsFixed(2);
                            return '$qty × ${item.product.name}';
                          })
                          .join(' · ');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          draft.title,
                          style: FontUtility.subheading.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemLines.isEmpty
                                    ? context.l10n.homeNoItems
                                    : itemLines,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: FontUtility.body.copyWith(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PosCurrency.format(draft.netTotal),
                                style: FontUtility.body.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4A00E0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.black45,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _restoreDraft(draft);
                        },
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
    if (mounted) await _loadDraftCount();
  }

  Future<void> _restoreDraft(CartDraft draft) async {
    final args = OrderCreateScreenArgs(
      orderType: draft.args.orderType,
      orderTypeKey: draft.args.orderTypeKey,
      name: draft.args.name,
      phone: draft.args.phone,
      email: draft.args.email,
      customerUniqueId: draft.args.customerUniqueId,
      floor: draft.args.floor,
      table: draft.args.table,
      draftId: draft.id,
      openOrderId: draft.args.openOrderId,
      draftSnapshot: CartDraftSnapshot(
        items: draft.items,
        discounts: draft.discounts,
        serviceTaxPercentage: draft.serviceTaxPercentage,
        tipsAmount: draft.tipsAmount,
        deliveryCharge: draft.deliveryCharge,
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderCreateScreen(args: args)),
    );
    if (mounted) await _loadDraftCount();
  }

  Future<void> _loadScheduledToday() async {
    try {
      final controller = getIt<UiStoreController>();
      if (controller.store == null) return;
      final rows = await controller.loadScheduledCreditRepayments();
      final now = DateTime.now();
      final count = rows.where((row) {
        if (!row.isOpen || row.dueDate.isEmpty) return false;
        final due = DateTime.tryParse(row.dueDate);
        if (due == null) return false;
        return due.year == now.year &&
            due.month == now.month &&
            due.day == now.day;
      }).length;
      if (!mounted) return;
      setState(() => _scheduledTodayCount = count);
    } catch (_) {
      // Store may not be open yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == true) {
          _loadDraftCount();
        }
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Padding(
          // Outer margins around the home dashboard card.
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            children: [
              if (_scheduledTodayCount > 0) ...[
                Material(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ScheduledPaymentsScreen(todayOnly: true),
                        ),
                      ).then((_) => _loadScheduledToday());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_available_rounded,
                            color: Color(0xFFE65100),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_scheduledTodayCount · '
                              '${context.l10n.creditsTodayScheduled}',
                              style: FontUtility.subheading.copyWith(
                                fontSize: 14,
                                color: const Color(0xFFE65100),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFE65100),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  // Home icons sit on top of this internal card.
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: AppLocalizations.of(
                                        context,
                                      )!.homePosDashboard,
                                      iconData: Icons.dashboard_rounded,
                                      color: const Color(0xFF4A00E0),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const DashboardScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: AppLocalizations.of(
                                        context,
                                      )!.homeOrdersList,
                                      iconData: Icons.receipt_long_rounded,
                                      color: const Color(0xFF8E2DE2),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const OrderListScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: context.l10n.homeCustomers,
                                      iconData: Icons.people_alt_rounded,
                                      color: const Color(0xFF00C9FF),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CustomersScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: context.l10n.homeCatalogs,
                                      iconData: Icons.inventory_2_rounded,
                                      color: const Color(0xFFFFA751),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CatalogScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: context.l10n.homeCredits,
                                      iconData:
                                          Icons.account_balance_wallet_rounded,
                                      color: const Color(0xFFFF512F),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const CreditsScreen(),
                                          ),
                                        ).then((_) => _loadScheduledToday());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: context.l10n.homeRefunds,
                                      iconData: Icons.undo_rounded,
                                      color: const Color(0xFFE53935),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const RefundsScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMenuCard(
                                      context,
                                      title: context.l10n.homeCompany,
                                      iconData: Icons.apartment_rounded,
                                      color: const Color(0xFF1B5E20),
                                      onTap: () async {
                                        final store =
                                            getIt<UiStoreController>().store;
                                        if (store == null) return;
                                        final ok = await store.auth
                                            .hasStoreRole('admin');
                                        if (!context.mounted) return;
                                        if (!ok) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                context
                                                    .l10n
                                                    .homeStoreAdminRequiredCompany,
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.company,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  const Expanded(child: SizedBox.shrink()),
                                  const SizedBox(width: 20),
                                  const Expanded(child: SizedBox.shrink()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          tooltip: context.l10n.homeSavedDrafts,
                          onPressed: _openDraftsSheet,
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(
                                Icons.drafts_rounded,
                                color: Color(0xFF4A00E0),
                              ),
                              if (_draftCount > 0)
                                Positioned(
                                  right: -6,
                                  top: -4,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF512F),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _draftCount > 99 ? '99+' : '$_draftCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showOrderCreationBottomSheet(context);
          if (mounted) await _loadDraftCount();
        },
        backgroundColor: const Color(0xFF4A00E0),
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, size: 28),
        label: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Text(
            AppLocalizations.of(context)!.homeCreateOrder,
            style: FontUtility.button,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final store = context.read<UiStoreController>().store;
    final storeName = store?.storeName.trim();
    final title = (storeName != null && storeName.isNotEmpty)
        ? storeName
        : AppLocalizations.of(context)!.homePosDashboard;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4A00E0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF4A00E0),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              title,
              style: FontUtility.heading.copyWith(fontSize: 22),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.black87),
        onPressed: () {
          // TODO: Open drawer
        },
        tooltip: context.l10n.homeMenu,
      ),
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: OrgLocalClockBadge(),
        ),
        FutureBuilder<String>(
          future: getIt<UiStoreController>().resolveStaffDisplayName(),
          builder: (context, snapshot) {
            final name = (snapshot.data ?? '').trim();
            if (name.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A00E0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF4A00E0).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_rounded,
                        size: 18,
                        color: Color(0xFF4A00E0),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: FontUtility.subheading.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4A00E0),
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
        IconButton(
          tooltip: context.l10n.homeStoreSetup,
          onPressed: () async {
            final store = getIt<UiStoreController>().store;
            if (store == null) return;
            final ok = await store.auth.hasStoreRole('admin');
            if (!context.mounted) return;
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.homeStoreAdminRequiredSetup),
                ),
              );
              return;
            }
            Navigator.pushNamed(context, AppRoutes.storeSetup);
          },
          icon: const Icon(Icons.storefront_rounded, color: Color(0xFF4A00E0)),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ValueListenableBuilder<bool>(
            valueListenable: getIt<UiStoreController>().autoSyncFailed,
            builder: (context, failed, _) {
              return IconButton(
                tooltip: failed
                    ? context.l10n.homeSyncFailedRetry
                    : context.l10n.syncTitle,
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.sync);
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.sync_rounded,
                      color: failed
                          ? Colors.red.shade600
                          : const Color(0xFF4A00E0),
                    ),
                    if (failed)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.priority_high_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final confirmed = await showStaffLogoutConfirmDialog(context);
            if (!confirmed || !context.mounted) return;
            final controller = getIt<UiStoreController>();
            final storeId = controller.store?.scope.storeId;
            final storeName = controller.store?.storeName;
            await controller.lockStaff();
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.staffLock,
              (route) => false,
              arguments: {'storeId': storeId, 'storeName': storeName},
            );
          },
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF512F)),
          label: Text(
            context.l10n.actionLogout,
            style: FontUtility.button.copyWith(
              color: const Color(0xFFFF512F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: context.l10n.homeDeviceSettings,
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.deviceSettings);
          },
          icon: const Icon(Icons.settings_rounded, color: Colors.black87),
        ),
        PopupMenuButton<Locale>(
          tooltip: context.l10n.languageLabel,
          onSelected: (Locale locale) {
            context.read<LanguageBloc>().add(ChangeLanguageEvent(locale));
          },
          icon: const Icon(Icons.language_rounded, color: Colors.black87),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
            PopupMenuItem<Locale>(
              value: const Locale('en'),
              child: Text(context.l10n.languageEnglish),
            ),
            PopupMenuItem<Locale>(
              value: const Locale('ta'),
              child: Text(context.l10n.languageTamil),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: Tooltip(
            message: context.l10n.profileMyProfile,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.profile);
              },
              borderRadius: BorderRadius.circular(24),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF4A00E0),
                radius: 20,
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData iconData,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7F8FB),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        hoverColor: color.withValues(alpha: 0.06),
        highlightColor: color.withValues(alpha: 0.1),
        splashColor: color.withValues(alpha: 0.18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, size: 34, color: color),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: FontUtility.heading.copyWith(fontSize: 18),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
