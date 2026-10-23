import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/order_types_repository.dart';
import 'package:pos_tablet/core/order_list_route_observer.dart';
import 'package:pos_tablet/core/pos_checkout_meta.dart';
import 'package:pos_tablet/presentation/widgets/order_creation_sheet.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/localization/status_labels.dart';
import '../../core/utils/font_utility.dart';
import '../../bloc/order_list/order_list_bloc.dart';
import '../../bloc/order_list/order_list_event.dart';
import '../../bloc/order_list/order_list_state.dart';
import '../widgets/pos_home_button.dart';
import '../widgets/order_list/order_list_row.dart';
import '../widgets/receipt_preview_dialog.dart';
import 'order_details_screen.dart';
import 'order_payments_screen.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';
import 'package:pos_tablet/presentation/widgets/pos_brand_logo.dart';

class SalesListScreen extends StatelessWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return OrderListScreen(
      pricingMode: StoreOrderPricingMode.selling,
      title: isTamil ? 'விற்பனை' : 'Sales',
    );
  }
}

class PurchasesListScreen extends StatelessWidget {
  const PurchasesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isTamil = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ta');
    return OrderListScreen(
      pricingMode: StoreOrderPricingMode.buying,
      title: isTamil ? 'கொள்முதல்' : 'Purchases',
    );
  }
}

class OrderListScreen extends StatelessWidget {
  final String? customerId;
  final String? customerName;
  final String? initialTypeFilter;
  final String? initialStatusFilter;
  final String? periodFilter;
  final String? pricingMode;
  final String? title;

  const OrderListScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.initialTypeFilter,
    this.initialStatusFilter,
    this.periodFilter,
    this.pricingMode,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderListBloc(
        customerIdFilter: customerId,
        customerNameFilter: customerName,
        initialTypeFilter: initialTypeFilter ?? 'All',
        initialStatusFilter: initialStatusFilter,
        periodFilter: periodFilter,
        pricingModeFilter: pricingMode,
      )..add(FetchInitialOrders()),
      child: _OrderListScreenContent(
        customerId: customerId,
        customerName: customerName,
        periodFilter: periodFilter,
        initialStatusFilter: initialStatusFilter,
        pricingMode: pricingMode,
        title: title,
      ),
    );
  }
}

class _OrderListScreenContent extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final String? periodFilter;
  final String? initialStatusFilter;
  final String? pricingMode;
  final String? title;

  const _OrderListScreenContent({
    this.customerId,
    this.customerName,
    this.periodFilter,
    this.initialStatusFilter,
    this.pricingMode,
    this.title,
  });

  @override
  State<_OrderListScreenContent> createState() =>
      _OrderListScreenContentState();
}

class _OrderListScreenContentState extends State<_OrderListScreenContent>
    with RouteAware {
  static const _clearStatusFilter = '__clear_status__';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final pageRoute = route is PageRoute<dynamic> ? route : null;
    if (pageRoute == _subscribedRoute) return;
    if (_subscribedRoute != null) {
      orderListRouteObserver.unsubscribe(this);
    }
    _subscribedRoute = pageRoute;
    if (pageRoute != null) {
      orderListRouteObserver.subscribe(this, pageRoute);
    }
  }

  @override
  void didPopNext() {
    if (mounted) context.read<OrderListBloc>().add(RefreshOrders());
  }

  @override
  void dispose() {
    orderListRouteObserver.unsubscribe(this);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      context.read<OrderListBloc>().add(FetchNextPage());
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<OrderListBloc>().add(SearchOrders(query));
    });
  }

  String _ordersTitle(BuildContext context) {
    final parts = <String>[];
    if (widget.customerName != null && widget.customerName!.trim().isNotEmpty) {
      parts.add(widget.customerName!.trim());
    } else if ((widget.title ?? '').trim().isNotEmpty) {
      parts.add(widget.title!.trim());
    } else {
      parts.add(AppLocalizations.of(context)!.homeOrdersList);
    }
    final status = (widget.initialStatusFilter ?? '').trim();
    if (status.isNotEmpty) parts.add(status);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        title: PosBrandTitle(
          child: Text(
          _ordersTitle(context),
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          const PosHomeButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            onPressed: () {
              context.read<OrderListBloc>().add(RefreshOrders());
            },
            tooltip: AppLocalizations.of(context)!.orderListRefreshButton,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showOrderCreationBottomSheet(
          context,
          initialPricingMode: widget.pricingMode,
          lockPricingMode: (widget.pricingMode ?? '').trim().isNotEmpty,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.homeCreateOrder),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 900 ? 12 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopFilters(context),
              _buildTableFilters(context),
              const SizedBox(height: 24),
              Expanded(
                child: RubberPush(
                  radius: 16,
                  trackFocus: false,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (MediaQuery.sizeOf(context).width >= 900)
                          _buildTableHeader(context),
                        Expanded(child: _buildOrderList()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopFilters(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1100;
    final typeFilter = BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        String selectedType = 'All';
        List<PosOrderType> types = OrderTypesRepository.defaults;
        if (state is OrderListLoaded) {
          selectedType = state.selectedTypeFilter;
          if (state.availableOrderTypes.isNotEmpty) {
            types = state.availableOrderTypes;
          }
        }

        final segments = <Widget>[
          _buildSegment(
            AppLocalizations.of(context)!.orderListFilterAll,
            'All',
            selectedType == 'All',
          ),
        ];
        for (final type in types) {
          segments.add(
            Container(width: 1, color: Colors.grey.withValues(alpha: 0.2)),
          );
          segments.add(
            _buildSegment(type.label, type.key, selectedType == type.key),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: segments),
          ),
        );
      },
    );
    final search = SizedBox(
      width: compact ? null : 300,
      child: RubberPush(
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.orderListSearchHint,
            hintStyle: FontUtility.body.copyWith(color: Colors.black38),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.black45),
            suffixIcon: IconButton(
              tooltip: context.l10n.commonClear,
              icon: const Icon(
                Icons.clear_rounded,
                color: Colors.black45,
                size: 20,
              ),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: PosFields.border,
            enabledBorder: PosFields.border,
            focusedBorder: PosFields.border,
          ),
        ),
      ),
    );
    final statusFilter = BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        String? statusFilter;
        if (state is OrderListLoaded) {
          statusFilter = state.selectedStatusFilter;
        }

        return PopupMenuButton<String>(
          tooltip: AppLocalizations.of(context)!.orderListFilterButton,
          onSelected: (value) {
            if (value == _clearStatusFilter) {
              context.read<OrderListBloc>().add(ClearStatusFilter());
            } else {
              context.read<OrderListBloc>().add(FilterByStatus(value));
            }
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: Icon(
            Icons.filter_list_rounded,
            color: statusFilter != null
                ? const Color(0xFF4A00E0)
                : Colors.black87,
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _clearStatusFilter,
              child: Text(context.l10n.orderListClearFilter),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'Order Pending',
              child: Text(context.l10n.statusOrderPending),
            ),
            PopupMenuItem(
              value: 'Order Preparing',
              child: Text(context.l10n.statusOrderPreparing),
            ),
            PopupMenuItem(
              value: 'Ready To Serve',
              child: Text(context.l10n.orderReadyToServe),
            ),
            PopupMenuItem(
              value: 'Completed',
              child: Text(context.l10n.orderCompleted),
            ),
            PopupMenuItem(
              value: 'Cancelled',
              child: Text(context.l10n.dashboardMetricCancelled),
            ),
            PopupMenuItem(
              value: 'Order Delivered',
              child: Text(context.l10n.orderDeliveredStatus),
            ),
          ],
        );
      },
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          typeFilter,
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: search),
              statusFilter,
              _buildPeriodFilter(context),
            ],
          ),
          const SizedBox(height: 8),
          _buildStatusCounts(context),
        ],
      );
    }
    return Row(
      children: [
        Flexible(child: typeFilter),
        const SizedBox(width: 16),
        search,
        const SizedBox(width: 16),
        statusFilter,
        const SizedBox(width: 12),
        Expanded(child: _buildStatusCounts(context)),
        const SizedBox(width: 12),
        _buildPeriodFilter(context),
      ],
    );
  }

  static const _periodCustom = 'Custom';
  static const _periodAll = '__all__';

  String _periodLabel(BuildContext context, OrderListLoaded state) {
    final l10n = context.l10n;
    switch (state.periodFilter) {
      case null:
        return l10n.orderListPeriodAll;
      case 'Today':
        return l10n.orderListPeriodToday;
      case 'Last 24 hours':
        return l10n.orderListPeriodLast24h;
      case 'Yesterday':
        return l10n.orderListPeriodYesterday;
      case _periodCustom:
        final start = state.periodStart;
        final end = state.periodEnd?.subtract(const Duration(days: 1));
        if (start == null || end == null) return l10n.orderListPeriodCustom;
        final fmt = DateFormat('d MMM');
        return start == end
            ? fmt.format(start)
            : '${fmt.format(start)} – ${fmt.format(end)}';
      default:
        return state.periodFilter!;
    }
  }

  Future<void> _pickCustomPeriod(
    BuildContext context,
    OrderListLoaded state,
  ) async {
    final bloc = context.read<OrderListBloc>();
    final now = DateTime.now();
    final initialEnd = state.periodEnd?.subtract(const Duration(days: 1));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange:
          state.periodFilter == _periodCustom &&
              state.periodStart != null &&
              initialEnd != null
          ? DateTimeRange(start: state.periodStart!, end: initialEnd)
          : null,
    );
    if (range == null) return;
    bloc.add(FilterByPeriod(_periodCustom, start: range.start, end: range.end));
  }

  Widget _buildPeriodFilter(BuildContext context) {
    return BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        if (state is! OrderListLoaded) return const SizedBox.shrink();
        final l10n = context.l10n;
        final active = state.periodFilter != null;
        const accent = Color(0xFF4A00E0);
        PopupMenuItem<String> item(String value, String label) {
          final selected = (state.periodFilter ?? _periodAll) == value;
          return PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Expanded(child: Text(label)),
                if (selected)
                  const Icon(Icons.check_rounded, size: 18, color: accent),
              ],
            ),
          );
        }

        return PopupMenuButton<String>(
          tooltip: l10n.orderListPeriodTooltip,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            final bloc = context.read<OrderListBloc>();
            if (value == _periodCustom) {
              _pickCustomPeriod(context, state);
            } else {
              bloc.add(FilterByPeriod(value == _periodAll ? null : value));
            }
          },
          itemBuilder: (_) => [
            item(_periodAll, l10n.orderListPeriodAll),
            item('Today', l10n.orderListPeriodToday),
            item('Last 24 hours', l10n.orderListPeriodLast24h),
            item('Yesterday', l10n.orderListPeriodYesterday),
            const PopupMenuDivider(),
            item(_periodCustom, l10n.orderListPeriodCustom),
          ],
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active ? accent.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? accent : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: active ? accent : Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  _periodLabel(context, state),
                  style: FontUtility.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active ? accent : Colors.black87,
                  ),
                ),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCounts(BuildContext context) {
    return BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        if (state is! OrderListLoaded) return const SizedBox.shrink();
        final bloc = context.read<OrderListBloc>();
        final counts = bloc.statusCounts(state);
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        final selected = state.selectedStatusFilter?.toLowerCase();
        bool isSelected(String status) {
          if (selected == null) return false;
          final s = status.toLowerCase();
          return selected.contains('cancel')
              ? s.contains('cancel')
              : s == selected;
        }

        return SizedBox(
          height: 30,
          child: Align(
            alignment: Alignment.centerRight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              reverse: true,
              children: [
                for (final entry in counts.entries.toList().reversed)
                  _statusCountCard(
                    label: entry.key,
                    count: entry.value,
                    color: _statusColor(entry.key),
                    selected: isSelected(entry.key),
                    onTap: () => isSelected(entry.key)
                        ? bloc.add(ClearStatusFilter())
                        : bloc.add(FilterByStatus(entry.key)),
                  ),
                _statusCountCard(
                  label: context.l10n.orderListFilterAll,
                  count: total,
                  color: const Color(0xFF4A00E0),
                  selected: selected == null,
                  onTap: () => bloc.add(ClearStatusFilter()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('cancel')) return const Color(0xFFD92D20);
    if (s.contains('complet') || s.contains('closed')) {
      return const Color(0xFF178A45);
    }
    if (s.contains('deliver') || s.contains('served')) {
      return const Color(0xFF0E9384);
    }
    if (s.contains('ready')) return const Color(0xFF2E90FA);
    if (s.contains('prepar')) return const Color(0xFFF79009);
    return const Color(0xFF6B7280);
  }

  Widget _statusCountCard({
    required String label,
    required int count,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: FontUtility.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableFilters(BuildContext context) {
    return BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        if (state is! OrderListLoaded) return const SizedBox.shrink();
        final selectedType = state.selectedTypeFilter;
        final isDineIn =
            state.availableOrderTypes.any(
              (t) => t.key == selectedType && t.isDineIn,
            ) ||
            selectedType.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase() ==
                'DINEIN';
        if (!isDineIn) return const SizedBox.shrink();

        final l10n = context.l10n;
        final bloc = context.read<OrderListBloc>();
        final tables = state.availableTables;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: tables.isEmpty
              ? Text(
                  l10n.orderListNoTables,
                  style: FontUtility.body.copyWith(color: Colors.black54),
                )
              : SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _tableChip(
                        label: l10n.orderListAllTables,
                        selected: state.selectedTableFilter == null,
                        onTap: () => bloc.add(const FilterByTable(null)),
                      ),
                      for (final table in tables)
                        _tableChip(
                          label:
                              RegExp(
                                r'^table\b',
                                caseSensitive: false,
                              ).hasMatch(table.label)
                              ? table.label
                              : l10n.orderListTableChip(table.label),
                          count: table.openOrders,
                          selected: state.selectedTableFilter == table.id,
                          onTap: () => bloc.add(
                            FilterByTable(
                              state.selectedTableFilter == table.id
                                  ? null
                                  : table.id,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _tableChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int count = 0,
  }) {
    const accent = Color(0xFF4A00E0);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: const Icon(Icons.table_restaurant_rounded, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFFF79009),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? accent : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        labelStyle: FontUtility.body.copyWith(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        selectedColor: accent,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? accent : Colors.grey.withValues(alpha: 0.25),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSegment(String title, String value, bool isSelected) {
    return InkWell(
      onTap: () {
        context.read<OrderListBloc>().add(FilterByType(value));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A00E0) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          title,
          style: FontUtility.body.copyWith(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: OrderListColumns.sl,
            child: _headerText(
              loc.orderListColumnSlNo,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: OrderListColumns.order,
            child: _headerText(loc.orderListColumnOrderId),
          ),
          Expanded(
            flex: OrderListColumns.type,
            child: _headerText('', textAlign: TextAlign.center),
          ),
          Expanded(
            flex: OrderListColumns.name,
            child: _headerText(loc.orderListColumnName),
          ),
          Expanded(
            flex: OrderListColumns.time,
            child: _headerText(
              loc.orderListColumnTime,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: OrderListColumns.status,
            child: _headerText(
              loc.orderListColumnStatus,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: OrderListColumns.payment,
            child: _headerText(
              loc.orderListColumnPayment,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: OrderListColumns.items,
            child: _headerText(
              loc.orderListColumnItems,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: OrderListColumns.total,
            child: _headerText(
              PosCurrency.symbol().isEmpty
                  ? loc.orderListColumnTotal
                  : '${loc.orderListColumnTotal} (${PosCurrency.symbol()})',
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: OrderListColumns.actions,
            child: _headerText(
              loc.orderListColumnActions,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerText(String text, {TextAlign textAlign = TextAlign.left}) {
    return Text(
      text,
      textAlign: textAlign,
      style: FontUtility.body.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.black54,
        fontSize: 13,
      ),
    );
  }

  Widget _buildOrderList() {
    return BlocBuilder<OrderListBloc, OrderListState>(
      builder: (context, state) {
        if (state is OrderListLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A00E0)),
          );
        } else if (state is OrderListError) {
          return Center(
            child: Text(
              state.message,
              style: FontUtility.body.copyWith(color: Colors.red),
            ),
          );
        } else if (state is OrderListLoaded) {
          if (state.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.orderListNoOrdersFound,
                    style: FontUtility.subheading.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: state.orders.length + (state.isFetchingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.orders.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4A00E0),
                      strokeWidth: 3,
                    ),
                  ),
                );
              }

              final order = state.orders[index];
              void openDetails() {
                final orderId = int.tryParse(order.orderId);
                if (orderId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.orderListUnableOpenOrder(order.orderId),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(orderId: orderId),
                  ),
                );
              }

              void openPayments() {
                final orderId = int.tryParse(order.orderId);
                if (orderId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.orderListUnableOpenOrder(order.orderId),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => order.isPurchase
                        ? PurchaseOrderPaymentsScreen(
                            orderId: orderId,
                            orderLabel: '#${order.orderId}',
                          )
                        : SalesOrderPaymentsScreen(
                            orderId: orderId,
                            orderLabel: '#${order.orderId}',
                          ),
                  ),
                );
              }

              return OrderListRow(
                order: order,
                index: index,
                onRowTap: openDetails,
                onInfoTap: openDetails,
                onPrintTap: () {
                  _showPrintDialog(context, order.orderId);
                },
                onUpdateTap: () {
                  _showUpdateStatusDialog(
                    context,
                    order.orderId,
                    order.orderStatus,
                  );
                },
                onPayNowTap: openPayments,
                onDeleteTap: order.canDiscard
                    ? () => _confirmDiscardOrder(context, order.orderId)
                    : null,
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Future<void> _confirmDiscardOrder(
    BuildContext context,
    String rawOrderId,
  ) async {
    final orderId = int.tryParse(rawOrderId);
    if (orderId == null) return;
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
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<OrderListBloc>();
    final l10n = context.l10n;
    try {
      final deleted = await getIt<UiStoreController>().discardOrder(orderId);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted
                ? l10n.orderDeletedTableFreed
                : l10n.orderCancelledTableFreed,
          ),
        ),
      );
      bloc.add(RefreshOrders());
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.errorCouldNotDeleteOrder(error.toString())),
        ),
      );
    }
  }

  Future<void> _showPrintDialog(BuildContext context, String orderId) async {
    final parsedOrderId = int.tryParse(orderId);
    if (parsedOrderId == null) return;
    final controller = getIt<UiStoreController>();
    final order = await controller.loadOrder(parsedOrderId);
    if (!context.mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.orderListUnableOpenOrder(orderId))),
      );
      return;
    }
    final meta = PosCheckoutMeta.parse(order.createdBy);
    final paid = order.paidTotal;
    final paymentLabel = order.payments
        .map((payment) => payment.paymentMode)
        .where((mode) => mode.trim().isNotEmpty)
        .toSet()
        .join(' + ');
    await showReceiptPreviewDialog(
      context,
      ReceiptPreviewData(
        orderId: order.orderId,
        storeName: order.restaurantName,
        pricingMode: order.pricingMode,
        partyName: order.customerName,
        partyId: order.customerUniqueId ?? '',
        paymentLabel: paymentLabel.isEmpty ? order.paymentStatus : paymentLabel,
        previousBalance: meta.previousBalance,
        subtotal: order.totalValue,
        offerAmount: order.offerAppliedValue,
        discountAmount: meta.discount,
        deliveryAmount: meta.delivery,
        taxAmount: meta.serviceTax,
        tipsAmount: meta.tips,
        total: order.finalValue,
        paid: paid,
        balanceDue: (order.finalValue - paid).clamp(0, order.finalValue),
        items: [
          for (final detail in order.items)
            ReceiptPreviewItem(
              name: detail.item.itemName.trim().isNotEmpty
                  ? detail.item.itemName.trim()
                  : detail.item.productId,
              quantityLabel: '${detail.item.quantity}×',
              amount: detail.item.finalPrice,
            ),
        ],
      ),
    );
  }

  void _showUpdateStatusDialog(
    BuildContext context,
    String orderId,
    String currentStatus,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.l10n.orderListUpdateStatusTitle,
          style: FontUtility.heading.copyWith(fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.orderListSelectNewStatus(orderId),
              style: FontUtility.body,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                    'Order Pending',
                    'Order Preparing',
                    'Ready To Serve',
                    'Completed',
                  ].map((status) {
                    final isSelected = status == currentStatus;
                    return ChoiceChip(
                      label: Text(
                        localizedOrderStatusLabel(dialogContext.l10n, status),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          context.read<OrderListBloc>().add(
                            UpdateOrderStatus(
                              orderId: orderId,
                              newStatus: status,
                            ),
                          );
                          Navigator.pop(dialogContext);
                        }
                      },
                      selectedColor: const Color(
                        0xFF4A00E0,
                      ).withValues(alpha: 0.1),
                      labelStyle: FontUtility.body.copyWith(
                        color: isSelected
                            ? const Color(0xFF4A00E0)
                            : Colors.black87,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.orderListCancelHint,
              style: FontUtility.body.copyWith(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.l10n.actionCancel,
              style: FontUtility.button.copyWith(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
