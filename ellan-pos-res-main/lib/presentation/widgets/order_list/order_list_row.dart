import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/localization/l10n_context.dart';
import '../../../core/utils/font_utility.dart';
import '../../../data/models/order_list_model.dart';
import 'order_status_badge.dart';

class OrderListRow extends StatefulWidget {
  final OrderListModel order;
  final int index;
  final VoidCallback onInfoTap;
  final VoidCallback onPrintTap;
  final VoidCallback onUpdateTap;
  final VoidCallback onPayNowTap;
  final VoidCallback? onRowTap;

  const OrderListRow({
    super.key,
    required this.order,
    required this.index,
    required this.onInfoTap,
    required this.onPrintTap,
    required this.onUpdateTap,
    required this.onPayNowTap,
    this.onRowTap,
  });

  @override
  State<OrderListRow> createState() => _OrderListRowState();
}

class _OrderListRowState extends State<OrderListRow> {
  bool _isHovered = false;

  static const _grey = Color(0xFF757575);
  static const _black = Color(0xFF212121);

  bool get _needsPayment {
    final status = widget.order.paymentStatus.trim().toLowerCase();
    return status == 'unpaid' || status == 'partial';
  }

  TextStyle get _greyStyle => FontUtility.body.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: _grey,
  );

  TextStyle get _boldBlack => FontUtility.body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: _black,
  );

  IconData _orderTypeIcon() {
    final raw = widget.order.orderType.trim().toLowerCase();
    if (widget.order.isDineIn ||
        raw.contains('dine') ||
        raw.contains('onsite') ||
        raw.contains('on-site') ||
        raw.contains('table')) {
      return Icons.restaurant_rounded;
    }
    if (raw.contains('deliver')) {
      return Icons.delivery_dining_rounded;
    }
    if (raw.contains('pickup') ||
        raw.contains('pick-up') ||
        raw.contains('takeaway') ||
        raw.contains('take-away')) {
      return Icons.takeout_dining_rounded;
    }
    return Icons.receipt_long_rounded;
  }

  String get _orderTypeTooltip {
    final type = widget.order.orderType.trim();
    final table = widget.order.isDineIn
        ? widget.order.formattedTableInfo.trim()
        : '';
    if (type.isEmpty) return table.isEmpty ? 'Order' : table;
    if (table.isEmpty) return type;
    return '$type · $table';
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatter = DateFormat('MMM dd, hh:mm a');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onRowTap ?? widget.onInfoTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.grey.withValues(alpha: 0.05)
                  : (widget.index % 2 == 0
                        ? Colors.white
                        : Colors.grey.withValues(alpha: 0.02)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                // Sl No
                Expanded(
                  flex: 1,
                  child: Text('${widget.index + 1}', style: _greyStyle),
                ),
                // Order ID
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '#${widget.order.orderId}',
                              style: _boldBlack,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: widget.order.syncedToRemote
                                ? context.l10n.orderSyncedRemote
                                : context.l10n.orderNotSyncedRemote,
                            child: Icon(
                              widget.order.syncedToRemote
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_upload_outlined,
                              size: 14,
                              color: widget.order.syncedToRemote
                                  ? Colors.green.shade600
                                  : Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                      if (widget.order.posCode != null &&
                          widget.order.posCode!.isNotEmpty)
                        Text(
                          context.l10n.orderListPosCode(
                            widget.order.posCode ?? '',
                          ),
                          style: _greyStyle.copyWith(fontSize: 10),
                        ),
                      if (widget.order.serveNumber != null)
                        Text(
                          context.l10n.orderListServeNumber(
                            '${widget.order.serveNumber}',
                          ),
                          style: _greyStyle.copyWith(
                            fontSize: 11,
                            color: const Color(0xFF6B5CE7),
                          ),
                        ),
                    ],
                  ),
                ),
                // Type — icon only
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: _orderTypeTooltip,
                      child: Icon(_orderTypeIcon(), size: 20, color: _grey),
                    ),
                  ),
                ),
                // Name
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.order.customerName,
                    style: _greyStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Time
                Expanded(
                  flex: 2,
                  child: Text(
                    timeFormatter.format(widget.order.timestamp),
                    style: _greyStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Order Status — text only
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OrderStatusBadge(
                      status: widget.order.orderStatus,
                      plain: true,
                    ),
                  ),
                ),
                // Payment Status — Paid / Unpaid / Partial
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _needsPayment
                        ? InkWell(
                            onTap: widget.onPayNowTap,
                            borderRadius: BorderRadius.circular(4),
                            child: OrderStatusBadge(
                              status: widget.order.paymentStatus,
                              isPaymentStatus: true,
                              plain: true,
                            ),
                          )
                        : OrderStatusBadge(
                            status: widget.order.paymentStatus,
                            isPaymentStatus: true,
                            plain: true,
                          ),
                  ),
                ),
                // Items
                Expanded(
                  flex: 1,
                  child: Text(
                    '${widget.order.itemCount}',
                    style: _boldBlack,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Total
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        PosCurrency.format(widget.order.totalAmount),
                        style: _boldBlack,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.order.balanceDue > 0.0001)
                        Text(
                          context.l10n.commonBal(
                            PosCurrency.format(widget.order.balanceDue),
                          ),
                          style: FontUtility.body.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade700,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Actions
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(
                            icon: Icons.print_rounded,
                            tooltip: context.l10n.actionPrint,
                            onTap: widget.onPrintTap,
                            color: Colors.grey.shade600,
                          ),
                          _buildActionButton(
                            icon: Icons.edit_rounded,
                            tooltip: context.l10n.actionUpdate,
                            onTap: widget.onUpdateTap,
                            color: Colors.orange.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
