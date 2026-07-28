import 'package:flutter/material.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/credit_account_detail_screen.dart';
import 'package:pos_tablet/presentation/widgets/credit/credit_collect_payment_dialog.dart';

/// Lists all open scheduled credit repayments across customers.
class ScheduledPaymentsScreen extends StatefulWidget {
  /// When true, only show schedules due today (including overdue shown separately).
  final bool todayOnly;

  const ScheduledPaymentsScreen({super.key, this.todayOnly = false});

  @override
  State<ScheduledPaymentsScreen> createState() => _ScheduledPaymentsScreenState();
}

class _ScheduledPaymentsScreenState extends State<ScheduledPaymentsScreen> {
  bool _loading = true;
  String? _error;
  List<StoreScheduledCreditRepayment> _rows = const [];
  Map<String, ({String name, String regNum})> _customers = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isDueToday(StoreScheduledCreditRepayment row) {
    if (!row.isOpen || row.dueDate.isEmpty) return false;
    final due = DateTime.tryParse(row.dueDate);
    if (due == null) return false;
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = getIt<UiStoreController>();
      final scheduled = await controller.loadScheduledCreditRepayments();
      var rows = scheduled.where((row) => row.isOpen).toList(growable: false);
      if (widget.todayOnly) {
        rows = rows.where(_isDueToday).toList(growable: false);
      } else {
        rows = [...rows]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      }

      final customers = <String, ({String name, String regNum})>{};
      for (final row in rows) {
        final id = row.customerId.trim();
        if (id.isEmpty || customers.containsKey(id)) continue;
        final resolved = await controller.resolveCustomerDisplay(id);
        customers[id] = (name: resolved.name, regNum: resolved.regNum);
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _customers = customers;
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

  String _titleFor(StoreScheduledCreditRepayment row) {
    final info = _customers[row.customerId];
    final name = (info?.name ?? '').trim();
    if (name.isNotEmpty && !name.toLowerCase().startsWith('user_')) {
      return name;
    }
    return 'Customer';
  }

  String _subtitleFor(StoreScheduledCreditRepayment row, {required bool overdue}) {
    final info = _customers[row.customerId];
    final reg = (info?.regNum ?? '').trim();
    final parts = <String>[
      if (reg.isNotEmpty) 'Reg $reg',
      'Due ${row.dueDate}',
      if (overdue) 'Overdue',
    ];
    return parts.join(' · ');
  }

  Future<void> _collect(StoreScheduledCreditRepayment schedule) async {
    final name = _titleFor(schedule);
    final result = await showDialog<CreditCollectPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreditCollectPaymentDialog(
        customerName: name,
        outstanding: schedule.amount,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await getIt<UiStoreController>().collectScheduledCreditRepayment(
        scheduleId: schedule.id,
        paymentMode: result.paymentMode,
        referenceId: result.referenceId,
        amount: result.amount,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Collect failed: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.todayOnly ? 'Today\'s scheduled payments' : 'Scheduled payments',
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF4A00E0)),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _rows.isEmpty
                    ? Center(
                        child: Text(
                          widget.todayOnly
                              ? 'No scheduled payments due today.'
                              : 'No open scheduled payments.',
                          style: FontUtility.body.copyWith(color: Colors.black54),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final name = _titleFor(row);
                            final overdue = row.isOverdue;
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  name,
                                  style: FontUtility.subheading.copyWith(fontSize: 15),
                                ),
                                subtitle: Text(
                                  _subtitleFor(row, overdue: overdue),
                                  style: FontUtility.body.copyWith(
                                    fontSize: 12,
                                    color: overdue
                                        ? const Color(0xFFB71C1C)
                                        : Colors.black54,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$${row.amount.toStringAsFixed(2)}',
                                      style: FontUtility.subheading.copyWith(
                                        fontSize: 15,
                                        color: const Color(0xFF4A00E0),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _collect(row),
                                      child: const Text('Collect'),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CreditAccountDetailScreen(
                                        customerId: row.customerId,
                                        customerName: name,
                                      ),
                                    ),
                                  ).then((_) => _load());
                                },
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
