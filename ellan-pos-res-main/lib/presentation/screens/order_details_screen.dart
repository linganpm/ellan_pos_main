import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_orders_offline/store_models.dart';
import 'package:pos_tablet/core/controllers/ui_store_controller.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/device_setup_store.dart';
import 'package:pos_tablet/core/di/service_locator.dart';
import 'package:pos_tablet/core/org_timezone.dart';
import 'package:pos_tablet/core/pos_checkout_meta.dart';
import 'package:pos_tablet/core/sell_unit.dart';
import 'package:pos_tablet/core/utils/font_utility.dart';
import 'package:pos_tablet/presentation/screens/order_payments_screen.dart';
import 'package:pos_tablet/presentation/widgets/order_list/order_status_badge.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  static const Color _primary = Color(0xFF4A00E0);

  StoreOrderDetails? _order;
  Map<String, String> _itemLabels = const {};
  Map<String, PosCatalogProduct> _itemCatalogue = const {};
  bool _loading = true;
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
      if (order == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Order #${widget.orderId} was not found.';
        });
        return;
      }
      final labels = await controller.resolveOrderItemLabels(order.items);
      final catalogue = await controller.resolveOrderItemCatalogue(order.items);
      if (!mounted) return;
      setState(() {
        _order = order;
        _itemLabels = labels;
        _itemCatalogue = catalogue;
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

  Future<void> _deleteDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.orderDeleteDraft),
        content: Text(context.l10n.orderDeleteDraftConfirm),
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
    if (confirmed != true || !mounted) return;
    try {
      await getIt<UiStoreController>().deleteDraftOrder(widget.orderId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.errorCouldNotDeleteDraft(error.toString()),
          ),
        ),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final controller = getIt<UiStoreController>();
    final payments = await controller
        .loadOrder(widget.orderId)
        .then((order) => order?.payments ?? const <StoreOrderPaymentRecord>[]);
    final outstanding = payments
        .where((payment) => !payment.isFullyRefunded)
        .toList();

    if (outstanding.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.orderRefundBeforeCancelTitle),
          content: Text(
            context.l10n.orderDetailsRefundablePayments(outstanding.length),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.orderRefundNotNow),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'payments'),
              child: Text(context.l10n.orderGoToPayments),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'refund_cancel'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF512F),
              ),
              child: Text(context.l10n.orderRefundAllAndCancel),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (choice == 'payments') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderPaymentsScreen(orderId: widget.orderId),
          ),
        );
        await _load();
        return;
      }
      if (choice != 'refund_cancel') return;
      try {
        await controller.refundAllAndCancelOrder(
          widget.orderId,
          reason: context.l10n.orderCancelledTitle,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.orderPaymentsRefundedCancelled)),
        );
        await _load();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorCouldNotCancel(error.toString())),
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.orderCancelTitle),
        content: Text(context.l10n.orderCancelConfirm),
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
            child: Text(context.l10n.orderCancelTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await controller.cancelOrder(widget.orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.orderCancelled)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorCouldNotCancel(error.toString())),
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
          context.l10n.orderNumber(widget.orderId),
          style: FontUtility.heading.copyWith(fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_order != null && StoreOrderStatus.canDelete(_order!.statusName))
            IconButton(
              tooltip: context.l10n.actionDelete,
              onPressed: _loading ? null : _deleteDraft,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF512F),
              ),
            ),
          if (_order != null && StoreOrderStatus.canCancel(_order!.statusName))
            IconButton(
              tooltip: context.l10n.actionCancel,
              onPressed: _loading ? null : _cancelOrder,
              icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFF512F)),
            ),
          IconButton(
            tooltip: context.l10n.actionRefresh,
            onPressed: _loading ? null : _load,
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

    final order = _order!;
    final paidTotal = order.payments.fold<double>(
      0,
      (sum, payment) => sum + (payment.amount - payment.refundedAmount),
    );
    final createdLabel = _formatTime(order.createdOn);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _headerCard(order, paidTotal, createdLabel),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _itemsCard(order)),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _summaryCard(order, paidTotal),
                  const SizedBox(height: 16),
                  _paymentsPreviewCard(order, paidTotal),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerCard(
    StoreOrderDetails order,
    double paidTotal,
    String createdLabel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: _primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OrderStatusBadge(status: order.statusName),
                OrderStatusBadge(
                  status: order.paymentStatus.isEmpty
                      ? context.l10n.statusUnpaid
                      : order.paymentStatus,
                  isPaymentStatus: true,
                ),
                _chip(_displayOrderType(order.orderType)),
                if (order.exported)
                  _chip(context.l10n.commonSynced, tone: Colors.green),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PosCurrency.format(
                  order.finalValue > 0 ? order.finalValue : order.total,
                ),
                style: FontUtility.heading.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                createdLabel,
                style: FontUtility.body.copyWith(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemsCard(StoreOrderDetails order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                color: _primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.commonItems,
                style: FontUtility.heading.copyWith(fontSize: 17),
              ),
              const Spacer(),
              Text(
                '${order.items.length}',
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (order.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                context.l10n.orderNoItems,
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
            )
          else
            ...order.items.map((detail) {
              final item = detail.item;
              final key = item.productVariantId.isNotEmpty
                  ? item.productVariantId
                  : item.productId;
              final name = _itemLabels[key] ?? item.productId;
              final tableLabel = [
                if ((item.floorName ?? '').trim().isNotEmpty) item.floorName,
                if ((item.tableName ?? '').trim().isNotEmpty) item.tableName,
              ].join(' · ');
              final addonLabel = detail.addons
                  .map((addon) => addon.addonItemName.trim())
                  .where((value) => value.isNotEmpty)
                  .join(' · ');
              final offerLabel = detail.appliedOfferLocalIds.isEmpty
                  ? ''
                  : order.appliedOffers
                        .where(
                          (offer) => detail.appliedOfferLocalIds.contains(
                            offer.localId,
                          ),
                        )
                        .map((offer) => offer.name)
                        .where((value) => value.trim().isNotEmpty)
                        .join(' · ');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: FontUtility.subheading.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              _lineQtyPriceLabel(item, key),
                              if (tableLabel.isNotEmpty) tableLabel,
                            ].join(' · '),
                            style: FontUtility.body.copyWith(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          if (addonLabel.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.orderAddonsLabel(addonLabel),
                              style: FontUtility.body.copyWith(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                          if (offerLabel.isNotEmpty ||
                              detail.discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (offerLabel.isNotEmpty)
                                  '${context.l10n.commonOffers}: $offerLabel',
                                if (detail.discountAmount > 0)
                                  '- ${PosCurrency.format(detail.discountAmount)}',
                              ].join(' · '),
                              style: FontUtility.body.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF4A00E0),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      PosCurrency.format(
                        detail.totalAfterDiscount > 0
                            ? detail.totalAfterDiscount
                            : item.finalPrice,
                      ),
                      style: FontUtility.subheading.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          if (order.appliedOffers.isNotEmpty) ...[
            Text(
              context.l10n.orderAppliedOffers,
              style: FontUtility.subheading.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            ...order.appliedOffers.map(
              (offer) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${offer.name} · - ${PosCurrency.format(offer.discountAmount)}',
                  style: FontUtility.body.copyWith(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _customerBlock(order),
          const SizedBox(height: 12),
          _staffBlock(order),
        ],
      ),
    );
  }

  Widget _staffBlock(StoreOrderDetails order) {
    final meta = PosCheckoutMeta.parse(order.createdBy);
    var name = meta.staffName.trim().isNotEmpty
        ? meta.displayStaffName
        : order.createdBy.trim();
    final lower = name.toLowerCase();
    if (lower.isEmpty ||
        lower == 'import' ||
        lower == 'pos' ||
        lower == 'system' ||
        lower == '—') {
      name = '—';
    }
    final reg = meta.displayStaffReg;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.commonStaff,
            style: FontUtility.heading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          _kv(context.l10n.commonName, name),
          if (reg.isNotEmpty) _kv(context.l10n.commonRegNo, reg),
        ],
      ),
    );
  }

  Widget _customerBlock(StoreOrderDetails order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.commonCustomer,
            style: FontUtility.heading.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          _kv(
            context.l10n.commonName,
            order.customerName.isEmpty
                ? context.l10n.commonWalkIn
                : order.customerName,
          ),
          if (order.mobile.trim().isNotEmpty)
            _kv(context.l10n.commonPhone, order.mobile),
          if (order.tables.isNotEmpty)
            _kv(
              context.l10n.commonTable,
              order.tables
                  .map((table) => table.displayLabel)
                  .where((value) => value.trim().isNotEmpty)
                  .join(', '),
            ),
        ],
      ),
    );
  }

  Widget _summaryCard(StoreOrderDetails order, double paidTotal) {
    final total = order.finalValue > 0 ? order.finalValue : order.total;
    final balance = (total - paidTotal).clamp(0, double.infinity).toDouble();
    final meta = PosCheckoutMeta.parse(order.createdBy);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.orderSummary,
            style: FontUtility.heading.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 14),
          if (order.totalDiscount > 0)
            _summaryAmountRow(
              context.l10n.commonDiscount,
              '- ${PosCurrency.format(order.totalDiscount)}',
              color: Colors.green.shade700,
            ),
          if (meta.delivery > 0.0001)
            _summaryAmountRow(
              context.l10n.commonDelivery,
              PosCurrency.format(meta.delivery),
            ),
          if (meta.serviceTax > 0.0001)
            _summaryAmountRow(
              context.l10n.commonServiceTax,
              '+ ${PosCurrency.format(meta.serviceTax)}',
              color: Colors.orange.shade700,
            ),
          if (meta.tips > 0.0001)
            _summaryAmountRow(
              context.l10n.commonTips,
              '+ ${PosCurrency.format(meta.tips)}',
              color: Colors.blue.shade700,
              bold: true,
            ),
          _summaryAmountRow(
            context.l10n.commonTotal,
            PosCurrency.format(total),
            bold: true,
            color: _primary,
          ),
          _summaryAmountRow(
            context.l10n.statusPaid,
            PosCurrency.format(paidTotal),
            bold: true,
            color: Colors.green.shade700,
          ),
          if (balance > 0.0001)
            _summaryAmountRow(
              context.l10n.commonCredit,
              '(${PosCurrency.format(balance)})',
              bold: true,
              color: Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _summaryAmountRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: (bold ? FontUtility.subheading : FontUtility.body)
                  .copyWith(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                  ),
            ),
          ),
          Text(
            value,
            style: FontUtility.subheading.copyWith(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsPreviewCard(StoreOrderDetails order, double paidTotal) {
    final orderTotal = order.finalValue > 0 ? order.finalValue : order.total;
    final remaining = double.parse(
      (orderTotal - paidTotal).clamp(0, orderTotal).toStringAsFixed(2),
    );
    final canRecord =
        remaining > 0.0001 &&
        !StoreOrderStatus.isCancelled(order.statusName) &&
        !StoreOrderStatus.isCompleted(order.statusName);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.commonPayments,
                style: FontUtility.heading.copyWith(fontSize: 17),
              ),
              const Spacer(),
              Text(
                '${order.payments.length}',
                style: FontUtility.body.copyWith(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            order.payments.isEmpty
                ? context.l10n.orderDetailsNoPaymentsRecorded
                : '${context.l10n.orderDetailsTotalPaid(PosCurrency.format(paidTotal))}'
                      '${remaining > 0.0001 ? context.l10n.orderDetailsDueSuffix(PosCurrency.format(remaining)) : ''}',
            style: FontUtility.body.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (canRecord)
                ElevatedButton.icon(
                  onPressed: () => _openPayments(order, openRecord: true),
                  icon: const Icon(Icons.add_card_rounded),
                  label: Text(context.l10n.orderAddRecordPayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _openPayments(order, openRecord: false),
                icon: const Icon(Icons.payments_rounded),
                label: Text(
                  order.payments.isEmpty && !canRecord
                      ? context.l10n.commonPayments
                      : context.l10n.orderDetailsViewPayments,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPayments(
    StoreOrderDetails order, {
    required bool openRecord,
  }) async {
    if (StoreOrderStatus.isDraft(order.statusName)) {
      try {
        await getIt<UiStoreController>().promoteDraftToPending(order.orderId);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.orderCouldNotOpenDraft(error.toString()),
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPaymentsScreen(
          orderId: order.orderId,
          orderLabel: '#${order.orderId}',
          autoOpenRecord: openRecord,
        ),
      ),
    );
    await _load();
  }

  String _lineQtyPriceLabel(StoreOrderItemRecord item, String key) {
    final catalog = _itemCatalogue[key];
    if (catalog != null && catalog.hasSellUnit) {
      final unit = SellUnitInfo(
        unitCode: catalog.sellUnitCode!,
        unitLabel: catalog.sellUnitLabel ?? catalog.sellUnitShort!,
        unitShort: catalog.sellUnitShort!,
        baseQty: catalog.sellUnitBaseQty ?? 1,
      );
      final packages = sellUnitBillableQty(item.quantity.toDouble(), unit);
      return '${formatSellQtyWithUnit(item.quantity.toDouble(), unit)} · '
          '${PosCurrency.format(item.unitPrice)} / ${formatSellQty(unit.baseQty)} ${unit.unitShort}'
          '${packages > 1 ? ' × ${formatSellQty(packages)}' : ''}';
    }
    return '${context.l10n.commonQuantity} ${item.quantity} · '
        '${PosCurrency.format(item.unitPrice)}';
  }

  Widget _kv(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: FontUtility.body.copyWith(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: bold
                  ? FontUtility.subheading.copyWith(fontSize: 14)
                  : FontUtility.body.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {Color tone = _primary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: FontUtility.button.copyWith(color: tone, fontSize: 11),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
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

  String _displayOrderType(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    if (normalized.contains('dine')) return 'Dine In';
    if (normalized.contains('deliver')) return 'Delivery';
    if (normalized.contains('pick')) return 'Pickup';
    return raw.isEmpty ? 'Order' : raw;
  }
}
