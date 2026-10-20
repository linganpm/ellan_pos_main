import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';

import '../../core/controllers/ui_store_controller.dart';
import '../../core/currency_format.dart';
import '../../core/di/service_locator.dart';
import '../../core/localization/l10n_context.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TableOverview {
  final StoreTableRecord table;
  final List<StoreOrderSummary> orders;

  const _TableOverview(this.table, this.orders);

  double get total => orders.fold(0, (sum, order) => sum + order.finalValue);
}

class _TablesScreenState extends State<TablesScreen> {
  List<_TableOverview> _entries = [];
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<List<_TableOverview>> _load() async {
    final controller = getIt<UiStoreController>();
    final tables = await controller.loadDineInTables();
    final orders = await controller.loadOrders();
    return tables.map((table) {
      final openOrders = orders.where((order) {
        final status = order.statusName.trim().toLowerCase();
        return status != 'closed' &&
            !status.contains('complet') &&
            !status.contains('cancel') &&
            (order.tableId == table.tableId ||
                order.orderId == table.occupiedOrderId);
      }).toList();
      if (table.occupied && openOrders.isEmpty) {
        throw StateError(
          'Open order details unavailable for ${table.displayLabel}.',
        );
      }
      return _TableOverview(table, openOrders);
    }).toList();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _load();
      if (!mounted) return;
      setState(() => _entries = entries);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTables),
        actions: [
          IconButton(
            tooltip: l10n.actionRefresh,
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.tablesLoadFailed, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('$_error', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refresh,
                        child: Text(l10n.actionRetry),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = _entries;
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.dineInNoTables, textAlign: TextAlign.center),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(l10n.tablesLocalHint),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (constraints.maxWidth / 240)
                            .floor()
                            .clamp(1, 6),
                        mainAxisExtent: 250,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _buildTable(entries[index]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTable(_TableOverview entry) {
    final l10n = context.l10n;
    final occupied = entry.table.occupied || entry.orders.isNotEmpty;
    final color = occupied ? const Color(0xFFB45309) : const Color(0xFF15803D);
    return Card(
      key: ValueKey('table-${entry.table.tableId}'),
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_restaurant_rounded, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    occupied ? l10n.dineInBooked : l10n.tablesAvailable,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.table.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              entry.table.floorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              entry.orders
                  .map((order) => '#${order.orderId} · ${order.statusName}')
                  .join(' / '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(l10n.tablesOrderTotal),
            Text(
              PosCurrency.format(entry.total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
