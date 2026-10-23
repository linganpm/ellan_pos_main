import 'package:flutter/material.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dashboard/dashboard_cubit.dart';
import '../../core/controllers/checkout_models.dart';
import '../../core/localization/l10n/app_localizations.dart';
import '../../core/utils/font_utility.dart';
import '../widgets/dashboard/overview_card.dart';
import '../widgets/dashboard/sales_chart.dart';
import '../widgets/dashboard/top_items_list.dart';
import '../widgets/dashboard/payment_types_chart.dart';
import '../widgets/dashboard/credit_orders_table.dart';
import 'credits_screen.dart';
import 'order_list_screen.dart';
import 'refunds_screen.dart';
import 'scheduled_payments_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  static const _filters = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'This Year',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 6,
        shadowColor: const Color(0x331B1433),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.dashboardTitle,
          style: FontUtility.heading.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (context, state) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterSection(context, state.filter),
                    const SizedBox(height: 24),
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Text(
                              state.errorMessage!,
                              style: FontUtility.body.copyWith(
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () =>
                                  context.read<DashboardCubit>().load(),
                              child: Text(
                                AppLocalizations.of(context)!.actionRetry,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildDashboardContent(context, state),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, String selected) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: _filters.map((filter) {
        final isSelected = selected == filter;
        return InkWell(
          onTap: () => context.read<DashboardCubit>().load(filter: filter),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4A00E0) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade300,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              _getLocalizedFilter(context, filter),
              style: FontUtility.body.copyWith(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardState state) {
    final snapshot = state.snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildOverviewMetrics(context, snapshot, state.filter),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 700;
            final sales = SizedBox(
              height: 420,
              child: SalesChart(
                filterSelected: _getLocalizedFilter(context, state.filter),
                points: snapshot.salesPoints,
              ),
            );
            final payments = SizedBox(
              height: stack ? 360 : 420,
              child: PaymentTypesChart(
                cashPercentage: snapshot.cashShare,
                cardPercentage: snapshot.cardShare,
                onlinePercentage: snapshot.onlineShare,
                creditPercentage: snapshot.creditShare,
              ),
            );
            if (stack) {
              return Column(
                children: [sales, const SizedBox(height: 24), payments],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: sales),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: payments),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 700;
            final l10n = AppLocalizations.of(context)!;
            final topCategories = SizedBox(
              height: 450,
              child: TopItemsList(
                title: l10n.dashboardTopCategories,
                items: snapshot.topCategories.isEmpty
                    ? [
                        TopItem(
                          name: l10n.dashboardNoCategorySales,
                          count: 0,
                          imageUrl: '',
                        ),
                      ]
                    : [
                        for (final row in snapshot.topCategories)
                          TopItem(
                            name: row.name,
                            count: row.count,
                            imageUrl: '',
                          ),
                      ],
              ),
            );
            final topProducts = SizedBox(
              height: 450,
              child: TopItemsList(
                title: l10n.dashboardTopProducts,
                items: snapshot.topProducts.isEmpty
                    ? [
                        TopItem(
                          name: l10n.dashboardNoProductSales,
                          count: 0,
                          imageUrl: '',
                        ),
                      ]
                    : [
                        for (final row in snapshot.topProducts)
                          TopItem(
                            name: row.name,
                            count: row.count,
                            imageUrl: '',
                          ),
                      ],
              ),
            );
            final credits = SizedBox(
              height: 450,
              child: CreditOrdersTable(
                orders: snapshot.creditOrders.isEmpty
                    ? [
                        CreditOrder(
                          customerName: l10n.dashboardNoOpenCredits,
                          amount: 0,
                          date: l10n.commonEmpty,
                        ),
                      ]
                    : [
                        for (final row in snapshot.creditOrders)
                          CreditOrder(
                            customerName: row.customerName,
                            amount: row.amount,
                            date: row.date,
                          ),
                      ],
              ),
            );
            if (stack) {
              return Column(
                children: [
                  topCategories,
                  const SizedBox(height: 24),
                  topProducts,
                  const SizedBox(height: 24),
                  credits,
                ],
              );
            }
            final columns = constraints.maxWidth >= 1100 ? 3 : 2;
            final panels = [topCategories, topProducts, credits];
            return Column(
              children: [
                for (var i = 0; i < panels.length; i += columns) ...[
                  if (i > 0) const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var col = 0; col < columns; col++) ...[
                        if (col > 0) const SizedBox(width: 24),
                        Expanded(
                          child: i + col < panels.length
                              ? panels[i + col]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverviewMetrics(
    BuildContext context,
    PosDashboardSnapshot snapshot,
    String periodFilter,
  ) {
    final cards = <Widget>[
      for (final type in snapshot.orderTypeCounts)
        _buildOverviewCard(
          type.label,
          '${type.count}',
          _iconForOrderType(type.key),
          _colorForOrderType(type.key),
          onTap: () => _openOrders(
            context,
            periodFilter: periodFilter,
            typeFilter: type.key,
          ),
        ),
      _buildOverviewCard(
        AppLocalizations.of(context)!.dashboardMetricCancelled,
        '${snapshot.cancelledCount}',
        Icons.cancel_rounded,
        const Color(0xFFFF512F),
        onTap: () => _openOrders(
          context,
          periodFilter: periodFilter,
          statusFilter: 'Cancelled',
        ),
      ),
      _buildOverviewCard(
        AppLocalizations.of(context)!.dashboardMetricOrders,
        '${snapshot.totalOrders}',
        Icons.receipt_long_rounded,
        const Color(0xFF92FE9D),
        onTap: () => _openOrders(context, periodFilter: periodFilter),
      ),
      _buildOverviewCard(
        AppLocalizations.of(context)!.dashboardMetricTotalSales,
        PosCurrency.format(snapshot.totalSales, decimals: 0),
        Icons.attach_money_rounded,
        const Color(0xFFFF9A9E),
        onTap: () => _openOrders(context, periodFilter: periodFilter),
      ),
      _buildOverviewCard(
        _withCurrency(AppLocalizations.of(context)!.dashboardPending),
        PosCurrency.format(snapshot.pendingAmount, decimals: 0),
        Icons.hourglass_bottom_rounded,
        const Color(0xFFF79009),
        badge: AppLocalizations.of(
          context,
        )!.dashboardPendingOrders(snapshot.pendingCount),
        onTap: () => _openOrders(context, periodFilter: periodFilter),
      ),
      _buildOverviewCard(
        _withCurrency(AppLocalizations.of(context)!.dashboardCredits),
        PosCurrency.format(snapshot.creditOutstandingAmount, decimals: 0),
        Icons.account_balance_wallet_rounded,
        const Color(0xFF7C4DFF),
        badge: AppLocalizations.of(
          context,
        )!.dashboardPendingOrders(snapshot.creditCount),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreditsScreen()),
        ),
      ),
      _buildOverviewCard(
        AppLocalizations.of(context)!.dashboardRepayments,
        PosCurrency.format(snapshot.repaymentsAmount, decimals: 0),
        Icons.payments_rounded,
        const Color(0xFF26A69A),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScheduledPaymentsScreen()),
        ),
      ),
      _buildOverviewCard(
        AppLocalizations.of(context)!.dashboardRefunds,
        '${snapshot.refundsCount} · ${PosCurrency.format(snapshot.refundsAmount, decimals: 0)}',
        Icons.undo_rounded,
        const Color(0xFFE53935),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RefundsScreen(periodFilter: periodFilter),
          ),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 760
            ? 3
            : width >= 520
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          crossAxisSpacing: 18,
          childAspectRatio: crossAxisCount >= 3 ? 2.05 : 2.2,
          children: cards,
        );
      },
    );
  }

  String _withCurrency(String label) {
    final symbol = PosCurrency.symbol().trim();
    return symbol.isEmpty ? label : '$label ($symbol)';
  }

  void _openOrders(
    BuildContext context, {
    required String periodFilter,
    String? typeFilter,
    String? statusFilter,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderListScreen(
          initialTypeFilter: typeFilter,
          initialStatusFilter: statusFilter,
          periodFilter: periodFilter,
          pricingMode: 'selling',
          title: 'Sales',
        ),
      ),
    );
  }

  IconData _iconForOrderType(String key) {
    final normalized = key.replaceAll(RegExp(r'[^A-Z]'), '');
    if (normalized.contains('DINE')) return Icons.restaurant_rounded;
    if (normalized.contains('DELIVER')) return Icons.delivery_dining_rounded;
    if (normalized.contains('PICK')) return Icons.local_mall_rounded;
    return Icons.receipt_outlined;
  }

  Color _colorForOrderType(String key) {
    final normalized = key.replaceAll(RegExp(r'[^A-Z]'), '');
    if (normalized.contains('DINE')) return const Color(0xFF4A00E0);
    if (normalized.contains('DELIVER')) return const Color(0xFF00C9FF);
    if (normalized.contains('PICK')) return const Color(0xFFFFA751);
    return const Color(0xFF5C6BC0);
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    String? badge,
  }) {
    return OverviewCard(
      title: title,
      value: value,
      icon: icon,
      color: color,
      onTap: onTap,
      badge: badge,
    );
  }

  String _getLocalizedFilter(BuildContext context, String filter) {
    switch (filter) {
      case 'All Time':
        return Localizations.localeOf(
              context,
            ).languageCode.toLowerCase().startsWith('ta')
            ? 'முழு காலம்'
            : 'All Time';
      case 'Yesterday':
        return AppLocalizations.of(context)!.dashboardFilterYesterday;
      case 'Today':
        return AppLocalizations.of(context)!.dashboardFilterToday;
      case 'This Week':
        return AppLocalizations.of(context)!.dashboardFilterWeek;
      case 'This Month':
        return AppLocalizations.of(context)!.dashboardFilterMonth;
      case 'This Year':
        return AppLocalizations.of(context)!.dashboardFilterYear;
      default:
        return filter;
    }
  }
}
