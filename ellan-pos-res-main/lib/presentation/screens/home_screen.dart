import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/cart_draft_store.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/routes.dart';
import 'package:pos_tablet/core/store_trade_modes.dart';
import 'package:pos_tablet/presentation/screens/order_create_screen.dart';
import 'package:pos_tablet/presentation/screens/scheduled_payments_screen.dart';
import 'package:pos_tablet/presentation/widgets/order_creation_sheet.dart';
import 'package:pos_tablet/presentation/widgets/org_local_clock_badge.dart';
import 'package:pos_tablet/presentation/widgets/pos_home_button.dart';
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
import 'package:pos_tablet/presentation/widgets/customer_support.dart';
import 'refunds_screen.dart';
import 'tables_screen.dart';
import '../../core/order_list_route_observer.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

class HomeScreen extends StatefulWidget {
  final bool openNewOrderSheet;
  final bool openOrders;
  final String? openOrdersPricingMode;

  const HomeScreen({
    super.key,
    this.openNewOrderSheet = false,
    this.openOrders = false,
    this.openOrdersPricingMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  StoreTradeModes _tradeModes = StoreTradeModes.current();
  bool _dineInEnabled = false;
  Object? _orderTypesError;
  PageRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _route) {
      orderListRouteObserver.unsubscribe(this);
      _route = route;
      orderListRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _loadOrderTypes();
  }

  Future<void> _loadOrderTypes() async {
    try {
      final types = await getIt<UiStoreController>().loadOrderTypes();
      if (!mounted) return;
      setState(() {
        _dineInEnabled = types.any((type) => type.isDineIn);
        _orderTypesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _orderTypesError = error);
    }
  }

  void _onTradeModesChanged() {
    if (mounted) setState(() => _tradeModes = StoreTradeModes.current());
  }

  @override
  void dispose() {
    orderListRouteObserver.unsubscribe(this);
    StoreTradeModes.changes.removeListener(_onTradeModesChanged);
    super.dispose();
  }

  int _scheduledTodayCount = 0;
  int _draftCount = 0;

  @override
  void initState() {
    super.initState();
    _loadOrderTypes();
    StoreTradeModes.changes.addListener(_onTradeModesChanged);
    _loadScheduledToday();
    _loadDraftCount();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.openOrders) {
        final mode = (widget.openOrdersPricingMode ?? '').trim();
        final Widget target;
        if (mode == 'buying') {
          target = const PurchasesListScreen();
        } else if (mode == 'selling') {
          target = const SalesListScreen();
        } else {
          target = const SalesListScreen();
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => target));
      } else if (widget.openNewOrderSheet) {
        showOrderCreationBottomSheet(context);
      }
    });
  }

  Future<void> _loadDraftCount() async {
    try {
      final drafts = await CartDraftStore.list();
      final controller = getIt<UiStoreController>();
      if (controller.store != null) {
        for (final draft in drafts) {
          final orderId = draft.args.openOrderId;
          if (orderId == null) continue;
          try {
            await controller.alignOrderPricingMode(
              orderId,
              draft.args.pricingMode,
            );
          } catch (_) {
            // A stale draft must not block the home screen.
          }
        }
      }
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('saved-draft-delete-${draft.id}'),
                              tooltip: context.l10n.orderDeleteOrder,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFFF512F),
                              ),
                              onPressed: () async {
                                final removed = await _discardSavedDraft(draft);
                                if (removed && sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              },
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.black45,
                            ),
                          ],
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

  Future<bool> _discardSavedDraft(CartDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.orderDeleteOrderQuestion),
        content: Text(context.l10n.orderDeleteOrderBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
            ),
            child: Text(context.l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    var deleted = true;
    try {
      final orderId = draft.args.openOrderId;
      if (orderId != null) {
        deleted = await getIt<UiStoreController>().discardOrder(orderId);
      }
      await CartDraftStore.delete(draft.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.errorCouldNotDeleteOrder('$error'))),
      );
      return false;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deleted ? l10n.orderDeletedTableFreed : l10n.orderCancelledTableFreed,
        ),
      ),
    );
    return true;
  }

  Future<void> _restoreDraft(CartDraft draft) async {
    final args = OrderCreateScreenArgs(
      orderType: draft.args.orderType,
      orderTypeKey: draft.args.orderTypeKey,
      pricingMode: draft.args.pricingMode,
      name: draft.args.name,
      phone: draft.args.phone,
      email: draft.args.email,
      customerUniqueId: draft.args.customerUniqueId,
      floor: draft.args.floor,
      table: draft.args.table,
      tableId: draft.args.tableId,
      draftId: draft.id,
      openOrderId: draft.args.openOrderId,
      draftSnapshot: CartDraftSnapshot(
        items: draft.items,
        discounts: draft.discounts,
        serviceTaxPercentage: draft.serviceTaxPercentage,
        tipsAmount: draft.tipsAmount,
        deliveryCharge: draft.deliveryCharge,
        orderHistory: draft.orderHistory,
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => args.pricingMode == 'buying'
            ? PurchaseOrderScreen(args: args)
            : SalesOrderScreen(args: args),
      ),
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
      body: MediaQuery.sizeOf(context).width < 900 ||
              MediaQuery.sizeOf(context).shortestSide < 600
          ? _buildGridHome(context)
          : SafeArea(
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
                                  if (_tradeModes.sell) ...[
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildMenuCard(
                                        context,
                                        title: 'Sales',
                                        iconData: Icons.trending_up_rounded,
                                        color: const Color(0xFF178A45),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const SalesListScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  if (_tradeModes.buy) ...[
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: _buildMenuCard(
                                        context,
                                        title:
                                            Localizations.localeOf(context)
                                                .languageCode
                                                .toLowerCase()
                                                .startsWith('ta')
                                            ? 'கொள்முதல்'
                                            : 'Purchases',
                                        iconData: Icons.trending_down_rounded,
                                        color: const Color(0xFFD32F2F),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const PurchasesListScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
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
                                      onTap: () => _openCompany(context),
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
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildTablesOption(context)),
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

  Future<void> _openCompany(BuildContext context) async {
    final store = getIt<UiStoreController>().store;
    if (store == null) return;
    final allowed = await store.auth.hasStoreRole('admin');
    if (!context.mounted) return;
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.homeStoreAdminRequiredCompany),
      ));
      return;
    }
    Navigator.pushNamed(context, AppRoutes.company);
  }

  Widget _buildTablesOption(BuildContext context) {
    if (!_tradeModes.sell) return const SizedBox.shrink();
    return Builder(
      builder: (context) {
        if (_orderTypesError != null) {
          return TextButton(
            onPressed: _loadOrderTypes,
            child: Text('${context.l10n.tablesLoadFailed}\n${context.l10n.actionRetry}'),
          );
        }
        if (!_dineInEnabled) {
          return const SizedBox.shrink();
        }
        void openTables() => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const TablesScreen()),
        );
        return _buildMenuCard(
          context,
          title: context.l10n.homeTables,
          iconData: Icons.table_restaurant_rounded,
          color: const Color(0xFF00897B),
          onTap: openTables,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final store = context.read<UiStoreController>().store;
    final storeName = store?.storeName.trim();
    final title = (storeName != null && storeName.isNotEmpty)
        ? storeName
        : AppLocalizations.of(context)!.homePosDashboard;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: const PosHomeButton(),
      leadingWidth: 56,
      titleSpacing: 0,
      title: PosBrandTitle(
        child: Text(
        title,
        style: FontUtility.heading.copyWith(fontSize: compact ? 18 : 22),
        overflow: TextOverflow.ellipsis,
      ),
      ),
      actions: [
        if (compact)
          PopupMenuButton<String>(
            tooltip: context.l10n.homeMenu,
            onSelected: (value) async {
              if (value == 'sync') {
                Navigator.pushNamed(context, AppRoutes.sync);
                return;
              }
              if (value == 'setup') {
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
                return;
              }
              if (value == 'settings') {
                Navigator.pushNamed(context, AppRoutes.deviceSettings);
                return;
              }
              if (value == 'profile') {
                Navigator.pushNamed(context, AppRoutes.profile);
                return;
              }
              if (value == 'language-en') {
                context.read<LanguageBloc>().add(
                  ChangeLanguageEvent(const Locale('en')),
                );
                return;
              }
              if (value == 'language-ta') {
                context.read<LanguageBloc>().add(
                  ChangeLanguageEvent(const Locale('ta')),
                );
                return;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sync',
                child: Text(context.l10n.syncTitle),
              ),
              PopupMenuItem(
                value: 'setup',
                child: Text(context.l10n.homeStoreSetup),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text(context.l10n.homeDeviceSettings),
              ),
              PopupMenuItem(
                value: 'profile',
                child: Text(context.l10n.profileMyProfile),
              ),
              PopupMenuItem(
                value: 'language-en',
                child: Text(context.l10n.languageEnglish),
              ),
              PopupMenuItem(
                value: 'language-ta',
                child: Text(context.l10n.languageTamil),
              ),
            ],
          ),
        if (!compact) ...[
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: OrgLocalClockBadge(),
          ),
          const CustomerSupportButton(),
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
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            foregroundColor: const Color(0xFF4A00E0),
          ),
          onPressed: () {
            final controller = getIt<UiStoreController>();
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.staffLock,
              (route) => false,
              arguments: {
                'storeId': controller.store?.scope.storeId,
                'storeName': controller.store?.storeName,
              },
            );
          },
          child: Text(context.l10n.actionLock),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey.withOpacity(0.2), height: 1.0),
      ),
    );
  }

  Widget _buildGridHome(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    final tiles = <Widget>[
      _buildMenuCard(
        context,
        title: AppLocalizations.of(context)!.homePosDashboard,
        iconData: Icons.dashboard_rounded,
        color: const Color(0xFF4A00E0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        },
      ),
      if (_tradeModes.sell)
        _buildMenuCard(
          context,
          title: 'Sales',
          iconData: Icons.trending_up_rounded,
          color: const Color(0xFF178A45),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesListScreen()),
            );
          },
        ),
      if (_tradeModes.buy)
        _buildMenuCard(
          context,
          title:
              Localizations.localeOf(
                context,
              ).languageCode.toLowerCase().startsWith('ta')
              ? 'கொள்முதல்'
              : 'Purchases',
          iconData: Icons.trending_down_rounded,
          color: const Color(0xFFD32F2F),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchasesListScreen()),
            );
          },
        ),
      _buildMenuCard(
        context,
        title: context.l10n.homeCatalogs,
        iconData: Icons.inventory_2_rounded,
        color: const Color(0xFFFFA751),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CatalogScreen()),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: context.l10n.homeCredits,
        iconData: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFFF512F),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreditsScreen()),
          ).then((_) => _loadScheduledToday());
        },
      ),
      _buildMenuCard(
        context,
        title: context.l10n.homeRefunds,
        iconData: Icons.undo_rounded,
        color: const Color(0xFFE53935),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RefundsScreen()),
          );
        },
      ),
      _buildMenuCard(
        context,
        title: context.l10n.homeCompany,
        iconData: Icons.apartment_rounded,
        color: const Color(0xFF1B5E20),
        onTap: () => _openCompany(context),
      ),
      _buildMenuCard(
        context,
        title: context.l10n.homeCustomers,
        iconData: Icons.people_alt_rounded,
        color: const Color(0xFF00C9FF),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomersScreen()),
          );
        },
      ),
      if (_tradeModes.sell && (_dineInEnabled || _orderTypesError != null))
        _buildTablesOption(context),
      _buildMenuCard(
        context,
        title: '${context.l10n.homeSavedDrafts} ($_draftCount)',
        iconData: Icons.drafts_rounded,
        color: const Color(0xFF4A00E0),
        onTap: _openDraftsSheet,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(phone ? 16 : 20, 12, phone ? 16 : 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_scheduledTodayCount > 0) ...[
              Material(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                      vertical: 14,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
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
              const SizedBox(height: 16),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 900 ? 3 : 2;
                  final gap = phone ? 14.0 : 16.0;
                  return GridView.count(
                    padding: const EdgeInsets.only(bottom: 108),
                    crossAxisCount: cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    childAspectRatio: phone
                        ? 1.12
                        : (cols == 2 ? 1.42 : 1.35),
                    children: tiles,
                  );
                },
              ),
            ),
          ],
        ),
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
    final roomy = MediaQuery.sizeOf(context).width >= 900;
    return Material(
      color: Colors.white,
      elevation: roomy ? 4 : 1,
      shadowColor: const Color(0x221B1433),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        hoverColor: color.withValues(alpha: 0.06),
        highlightColor: color.withValues(alpha: 0.1),
        splashColor: color.withValues(alpha: 0.18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < 210 || constraints.maxHeight < 150;
            final iconSize = narrow ? 32.0 : 40.0;
            final iconPad = narrow ? 12.0 : 14.0;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 12 : 16,
                vertical: narrow ? 12 : 14,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPad),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, size: iconSize, color: color),
                  ),
                  SizedBox(height: narrow ? 10 : 14),
                  Text(
                    title,
                    style: FontUtility.heading.copyWith(
                      fontSize: narrow ? 16 : 20,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
