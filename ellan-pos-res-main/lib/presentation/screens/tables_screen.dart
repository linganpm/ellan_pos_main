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
  bool _saving = false;

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
            key: const ValueKey('add-table'),
            tooltip: 'Add table',
            onPressed: _loading || _saving ? null : _addTable,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: l10n.actionRefresh,
            onPressed: _loading || _saving ? null : _refresh,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.dineInNoTables, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _addTable,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add table'),
                      ),
                    ],
                  ),
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
                if (!occupied)
                  IconButton(
                    key: ValueKey('remove-table-${entry.table.tableId}'),
                    tooltip: 'Remove table',
                    onPressed: _saving ? null : () => _removeTable(entry),
                    icon: const Icon(Icons.delete_outline_rounded),
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

  Future<void> _addTable() async {
    final controller = getIt<UiStoreController>();
    final floors = await controller.loadDineInFloors();
    if (!mounted) return;
    final draft = await showDialog<_TableDraft>(
      context: context,
      builder: (context) => _AddTableDialog(floors: floors),
    );
    if (draft == null) return;
    setState(() => _saving = true);
    try {
      final message = await controller.addDineInTable(
        name: draft.name,
        floorName: draft.floorName,
        floorId: draft.floorId,
        capacity: draft.capacity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeTable(_TableOverview entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove table'),
        content: Text('Remove ${entry.table.name}? It will leave the floor and the restaurant Tables menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      final message = await getIt<UiStoreController>().removeDineInTable(
        entry.table.tableId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TableDraft {
  final String name;
  final String floorName;
  final String? floorId;
  final int capacity;

  const _TableDraft({
    required this.name,
    required this.floorName,
    required this.floorId,
    required this.capacity,
  });
}

class _AddTableDialog extends StatefulWidget {
  final List<StoreFloorRecord> floors;

  const _AddTableDialog({required this.floors});

  @override
  State<_AddTableDialog> createState() => _AddTableDialogState();
}

class _AddTableDialogState extends State<_AddTableDialog> {
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _floorName = TextEditingController(text: 'Main');
  late final TextEditingController _seats = TextEditingController(text: '4');
  String? _floorId;
  bool _newFloor = false;

  @override
  void initState() {
    super.initState();
    if (widget.floors.isNotEmpty) {
      _floorId = widget.floors.first.floorId;
      _floorName.text = widget.floors.first.name;
    } else {
      _newFloor = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _floorName.dispose();
    _seats.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final floorName = _floorName.text.trim();
    final seats = int.tryParse(_seats.text.trim()) ?? 4;
    if (name.isEmpty || floorName.isEmpty || seats < 1) return;
    Navigator.pop(
      context,
      _TableDraft(
        name: name,
        floorName: floorName,
        floorId: _newFloor ? null : _floorId,
        capacity: seats,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add table'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Table name'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            if (widget.floors.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _newFloor ? '' : _floorId,
                decoration: const InputDecoration(labelText: 'Floor'),
                items: [
                  for (final floor in widget.floors)
                    DropdownMenuItem(
                      value: floor.floorId,
                      child: Text(floor.name),
                    ),
                  const DropdownMenuItem(value: '', child: Text('New floor')),
                ],
                onChanged: (value) {
                  setState(() {
                    _newFloor = value == null || value.isEmpty;
                    _floorId = _newFloor ? null : value;
                    if (!_newFloor) {
                      final floor = widget.floors.where((item) => item.floorId == value);
                      if (floor.isNotEmpty) _floorName.text = floor.first.name;
                    }
                  });
                },
              ),
            if (_newFloor) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _floorName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Floor name'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _seats,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seats'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
