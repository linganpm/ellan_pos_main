import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/utils/customer_identity.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/widgets/billing/order_add_payment_dialog.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SalesOrderPaymentsScreen extends StatelessWidget {
  final int orderId;
  final String? orderLabel;
  final bool autoOpenRecord;

  const SalesOrderPaymentsScreen({
    super.key,
    required this.orderId,
    this.orderLabel,
    this.autoOpenRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTamil =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
          'ta',
        );
    return OrderPaymentsScreen(
      orderId: orderId,
      orderLabel: orderLabel,
      autoOpenRecord: autoOpenRecord,
      screenTitle: isTamil ? 'விற்பனை பணப்பரிவர்த்தனைகள்' : 'Sale payments',
    );
  }
}

class PurchaseOrderPaymentsScreen extends StatelessWidget {
  final int orderId;
  final String? orderLabel;
  final bool autoOpenRecord;

  const PurchaseOrderPaymentsScreen({
    super.key,
    required this.orderId,
    this.orderLabel,
    this.autoOpenRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final isTamil =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
          'ta',
        );
    return OrderPaymentsScreen(
      orderId: orderId,
      orderLabel: orderLabel,
      autoOpenRecord: autoOpenRecord,
      screenTitle: isTamil
          ? 'கொள்முதல் பணப்பரிவர்த்தனைகள்'
          : 'Purchase payments',
    );
  }
}

/// Lists every payment recorded against a single order.
class OrderPaymentsScreen extends StatefulWidget {
  final int orderId;
  final String? orderLabel;

  /// When true, open the record-payment dialog after the first successful load.
  final bool autoOpenRecord;
  final String? screenTitle;

  const OrderPaymentsScreen({
    super.key,
    required this.orderId,
    this.orderLabel,
    this.autoOpenRecord = false,
    this.screenTitle,
  });

  @override
  State<OrderPaymentsScreen> createState() => _OrderPaymentsScreenState();
}

class _OrderPaymentsScreenState extends State<OrderPaymentsScreen> {
  static const Color _primary = Color(0xFF4A00E0);

  List<StoreOrderPaymentRecord> _payments = const [];
  StoreOrderDetails? _order;
  Map<String, String> _customerLabels = const {};
  bool _loading = true;
  bool _recording = false;
  bool _autoRecordOpened = false;
  String? _error;

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
      final order = await controller.loadOrder(widget.orderId);
      final payments = await controller.loadOrderPayments(widget.orderId);
      final labels = <String, String>{};
      for (final payment in payments) {
        final id = (payment.customerId ?? '').trim();
        if (id.isEmpty || labels.containsKey(id)) continue;
        final customer = await controller.loadCustomerById(id);
        labels[id] = displayCustomerIdentity(
          regNum: customer?.usrRegNum,
          customerId: id,
          email: customer?.email,
        );
      }
      if (!mounted) return;
      setState(() {
        _order = order;
        _payments = payments;
        _customerLabels = labels;
        _loading = false;
      });
      if (widget.autoOpenRecord && !_autoRecordOpened) {
        _autoRecordOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_remaining > 0.0001 &&
              !StoreOrderStatus.isCancelled(_order?.statusName ?? '') &&
              !StoreOrderStatus.isCompleted(_order?.statusName ?? '')) {
            _recordPayment();
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  double get _orderTotal {
    final order = _order;
    if (order == null) return 0;
    return order.finalValue > 0 ? order.finalValue : order.total;
  }

  double get _paidTotal => _payments.fold<double>(
    0,
    (sum, payment) => sum + (payment.amount - payment.refundedAmount),
  );

  double get _remaining {
    final remaining = _orderTotal - _paidTotal;
    return remaining <= 0 ? 0 : double.parse(remaining.toStringAsFixed(2));
  }

  Future<void> _refundPayment(StoreOrderPaymentRecord payment) async {
    final refundable = payment.refundableAmount;
    if (refundable <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.orderAlreadyFullyRefunded)),
      );
      return;
    }
    final amountController = TextEditingController(
      text: refundable.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.orderPaymentsRefundTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.orderPaymentsRefundableOf(
                PosCurrency.format(refundable),
                PosCurrency.format(payment.amount),
              ),
              style: FontUtility.body.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.orderPaymentsRefundAmount,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: context.l10n.orderPaymentsReasonOptional,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF512F),
            ),
            child: Text(context.l10n.orderPaymentsRefundAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0 || amount > refundable + 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.orderPaymentsRefundAmountRange(
              refundable.toStringAsFixed(2),
            ),
          ),
        ),
      );
      return;
    }
    try {
      await getIt<UiStoreController>().refundPayment(
        orderId: widget.orderId,
        paymentId: payment.id,
        amount: amount,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.orderRefundedAmount(PosCurrency.format(amount)),
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.orderRefundFailed(error.toString())),
        ),
      );
    }
  }

  Future<void> _recordPayment() async {
    final remaining = _remaining;
    if (remaining <= 0.0001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.orderAlreadyFullyPaid)),
      );
      return;
    }

    final modes = defaultOrderPaymentModes(context);
    final result = await showDialog<OrderAddPaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OrderAddPaymentDialog(
        remainingAmount: remaining,
        paymentMode: modes.first.mode,
        paymentLabel: modes.first.label,
        title: context.l10n.orderRecordPayment,
        confirmLabel: context.l10n.orderPaymentsAddPayment,
        showModePicker: true,
        modeOptions: modes,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _recording = true);
    try {
      final outcome = await getIt<UiStoreController>().recordOrderPayment(
        orderId: widget.orderId,
        paymentMethod: result.paymentMode,
        amount: result.amount,
        referenceId: result.referenceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.balance <= 0.0001
                ? context.l10n.orderPaymentsRecordedFullyPaid
                : context.l10n.orderPaymentsRecordedBalance(
                    PosCurrency.format(outcome.balance),
                  ),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.orderPaymentFailed(error.toString())),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleOrder = widget.orderLabel ?? '#${widget.orderId}';
    final isTamil =
        Localizations.localeOf(context).languageCode.toLowerCase().startsWith(
          'ta',
        );
    final defaultTitle = _order?.pricingMode == StoreOrderPricingMode.buying
        ? (isTamil ? 'கொள்முதல் பணப்பரிவர்த்தனைகள்' : 'Purchase payments')
        : (isTamil ? 'விற்பனை பணப்பரிவர்த்தனைகள்' : 'Sale payments');
    final status = _order?.statusName ?? '';
    final canAdd =
        !_loading &&
        _error == null &&
        _remaining > 0.0001 &&
        !StoreOrderStatus.isCancelled(status) &&
        !StoreOrderStatus.isCompleted(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.screenTitle ?? defaultTitle} · $titleOrder',
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          tooltip: context.l10n.actionBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _loading || _recording ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: _recording ? null : _recordPayment,
              backgroundColor: _primary,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _recording
                    ? context.l10n.commonSaving
                    : context.l10n.orderAddRecordPayment,
              ),
            )
          : null,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF512F),
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    final remaining = _remaining;
    final paid = _paidTotal;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.payments_rounded, color: _primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.orderPaymentsOrderSummary(
                      PosCurrency.format(_orderTotal),
                      PosCurrency.format(remaining),
                    ),
                    style: FontUtility.body.copyWith(color: Colors.black54),
                  ),
                ),
                Text(
                  PosCurrency.format(paid),
                  style: FontUtility.heading.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _payments.isEmpty
              ? Center(
                  child: Text(
                    remaining > 0.0001
                        ? context.l10n.orderPaymentsNoPaymentsUnpaid
                        : context.l10n.orderPaymentsNoPaymentsRecorded,
                    style: FontUtility.body.copyWith(color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 88),
                  itemCount: _payments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final payment = _payments[index];
                    return _PaymentTile(
                      payment: payment,
                      timeLabel: _formatTime(payment.createdOn),
                      modeLabel: _displayMode(payment.paymentMode),
                      modeColor: _modeColor(payment.paymentMode),
                      customerLabel:
                          _customerLabels[(payment.customerId ?? '').trim()],
                      onRefund: payment.refundableAmount > 0.0001
                          ? () => _refundPayment(payment)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatTime(String raw) {
    final prefs = getIt<SharedPreferences>();
    final storeId = getIt<UiStoreController>().store?.storeId;
    final tzName = DeviceSetupStore(prefs).timezoneForStore(storeId);
    final wall = OrgTimezone.tryParseWallClock(raw, tzName);
    if (wall == null) return raw.isEmpty ? '—' : raw;
    return _time.format(wall);
  }

  String _displayMode(String raw) {
    switch (raw.trim().toLowerCase()) {
      case StoreOrderPaymentMode.cash:
        return context.l10n.commonCash;
      case StoreOrderPaymentMode.card:
        return context.l10n.commonCard;
      case StoreOrderPaymentMode.online:
        return context.l10n.orderPaymentsOnlineUpi;
      case StoreOrderPaymentMode.credit:
        return context.l10n.commonCredit;
      default:
        return raw.isEmpty ? context.l10n.commonPayments : raw;
    }
  }

  Color _modeColor(String raw) {
    switch (raw.trim().toLowerCase()) {
      case StoreOrderPaymentMode.cash:
        return const Color(0xFF0EA5E9);
      case StoreOrderPaymentMode.card:
        return const Color(0xFF4A00E0);
      case StoreOrderPaymentMode.online:
        return const Color(0xFF8E2DE2);
      case StoreOrderPaymentMode.credit:
        return const Color(0xFFFF512F);
      default:
        return Colors.grey.shade700;
    }
  }
}

class _PaymentTile extends StatelessWidget {
  final StoreOrderPaymentRecord payment;
  final String timeLabel;
  final String modeLabel;
  final Color modeColor;
  final String? customerLabel;
  final VoidCallback? onRefund;

  const _PaymentTile({
    required this.payment,
    required this.timeLabel,
    required this.modeLabel,
    required this.modeColor,
    this.customerLabel,
    this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: modeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_modeIcon(payment.paymentMode), color: modeColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeLabel,
                  style: FontUtility.subheading.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                if (payment.refundedAmount > 0.0001) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.orderPaymentsRefundedLeft(
                      PosCurrency.format(payment.refundedAmount),
                      PosCurrency.format(payment.refundableAmount),
                    ),
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: const Color(0xFFFF512F),
                    ),
                  ),
                ],
                if ((payment.referenceId ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.orderPaymentsRefLabel(payment.referenceId!),
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((customerLabel ?? payment.customerId ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.orderPaymentsCustomerLabel(
                      customerLabel ?? payment.customerId ?? '',
                    ),
                    style: FontUtility.body.copyWith(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PosCurrency.format(payment.amount),
                style: FontUtility.heading.copyWith(fontSize: 18),
              ),
              if (onRefund != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRefund,
                  child: Text(context.l10n.orderPaymentsRefundAction),
                ),
              ] else if (payment.isFullyRefunded)
                Text(
                  context.l10n.statusRefunded,
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(String raw) {
    switch (raw.trim().toLowerCase()) {
      case StoreOrderPaymentMode.cash:
        return Icons.payments_outlined;
      case StoreOrderPaymentMode.card:
        return Icons.credit_card_rounded;
      case StoreOrderPaymentMode.online:
        return Icons.qr_code_2_rounded;
      case StoreOrderPaymentMode.credit:
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment_rounded;
    }
  }
}
