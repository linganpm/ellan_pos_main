import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/order_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/l10n_context.dart';

/// Lists local order refunds for the open store.
class RefundsScreen extends StatefulWidget {
  /// Optional dashboard period (`Today`, `This Week`, …).
  final String? periodFilter;

  const RefundsScreen({super.key, this.periodFilter});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  static const Color _primary = Color(0xFFE53935);

  bool _loading = true;
  String? _error;
  List<StoreOrderRefundRecord> _refunds = const [];

  final _currency = NumberFormat.currency(symbol: '\$');
  final _time = DateFormat('dd MMM yyyy · hh:mm a');

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
      var rows = await controller.listRefunds();
      final period = (widget.periodFilter ?? '').trim();
      if (period.isNotEmpty) {
        try {
          final range = controller.dashboardDateRangeForFilter(period);
          final prefs = getIt<SharedPreferences>();
          final storeId = controller.store?.storeId;
          final tzName = DeviceSetupStore(prefs).timezoneForStore(storeId);
          rows = rows
              .where((row) {
                final when =
                    OrgTimezone.tryParseWallClock(row.createdOn, tzName) ??
                    DateTime.tryParse(row.createdOn);
                if (when == null) return false;
                return !when.isBefore(range.start) && when.isBefore(range.end);
              })
              .toList(growable: false);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _refunds = rows;
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

  String _formatTime(String raw) {
    final prefs = getIt<SharedPreferences>();
    final storeId = getIt<UiStoreController>().store?.storeId;
    final tzName = DeviceSetupStore(prefs).timezoneForStore(storeId);
    final wall = OrgTimezone.tryParseWallClock(raw, tzName);
    if (wall == null) return raw.isEmpty ? '—' : raw;
    return _time.format(wall);
  }

  @override
  Widget build(BuildContext context) {
    final total = _refunds.fold<double>(0, (sum, row) => sum + row.amount);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          (widget.periodFilter ?? '').trim().isEmpty
              ? context.l10n.commonRefunds
              : context.l10n.refundsPeriodTitle(widget.periodFilter!.trim()),
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
            ? Center(child: Text(_error!))
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.refundsCount(_refunds.length),
                          style: FontUtility.heading.copyWith(fontSize: 18),
                        ),
                        const Spacer(),
                        Text(
                          _currency.format(total),
                          style: FontUtility.heading.copyWith(fontSize: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _refunds.isEmpty
                        ? Center(
                            child: Text(
                              context.l10n.refundsEmpty,
                              style: FontUtility.body.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: _refunds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final refund = _refunds[index];
                              return Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => OrderDetailsScreen(
                                          orderId: refund.orderId,
                                        ),
                                      ),
                                    ).then((_) => _load());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: _primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.undo_rounded,
                                            color: _primary,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.l10n.orderNumber(
                                                  refund.orderId,
                                                ),
                                                style: FontUtility.subheading
                                                    .copyWith(fontSize: 16),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatTime(refund.createdOn),
                                                style: FontUtility.body
                                                    .copyWith(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                    ),
                                              ),
                                              if ((refund.reason ?? '')
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  refund.reason!,
                                                  style: FontUtility.body
                                                      .copyWith(
                                                        fontSize: 12,
                                                        color: Colors.black45,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Text(
                                          _currency.format(refund.amount),
                                          style: FontUtility.heading.copyWith(
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
