import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/core/sell_unit.dart';
import '../../core/utils/font_utility.dart';
import '../../core/controllers/checkout_models.dart';
import '../../bloc/cart/cart_bloc.dart';
import '../../bloc/cart/cart_state.dart';
import '../../bloc/cart/cart_event.dart';
import 'home_screen.dart';

class InvoiceScreen extends StatelessWidget {
  final CheckoutCompletionResult? checkoutResult;

  const InvoiceScreen({super.key, this.checkoutResult});

  @override
  Widget build(BuildContext context) {
    final paidTotal = checkoutResult?.totalPaid;
    final paymentLabel = checkoutResult?.paymentMode ?? 'Unknown';
    final orderLabel = checkoutResult == null
        ? 'Invoice #INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
        : 'Order #${checkoutResult!.orderId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Invoice / Receipt',
          style: FontUtility.heading.copyWith(fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black87),
            onPressed: () => _finishOrder(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.withValues(alpha: 0.2), height: 1.0),
        ),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          final displayTotal = paidTotal ?? state.netTotal;
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 600,
                        constraints: const BoxConstraints(maxWidth: 600),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              orderLabel,
                              style: FontUtility.heading.copyWith(fontSize: 22),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Method: $paymentLabel'
                              '${checkoutResult != null ? ' · ${checkoutResult!.statusName}' : ''}',
                              style: FontUtility.body.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Order Summary',
                              style:
                                  FontUtility.heading.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 12),
                            const Divider(thickness: 1.5),
                            ...state.cartItems.map((item) {
                              final qtyLabel = item.sellUnit == null
                                  ? '${item.quantity == item.quantity.roundToDouble() ? item.quantity.toInt() : item.quantity}×'
                                  : formatSellQtyWithUnit(
                                      item.quantity,
                                      item.sellUnit,
                                    );
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      child: Text(
                                        qtyLabel,
                                        style: FontUtility.subheading
                                            .copyWith(fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: FontUtility.body
                                                .copyWith(fontSize: 15),
                                          ),
                                          if (item.sellUnit != null)
                                            Text(
                                              '${PosCurrency.format(item.product.price)} / '
                                              '${formatSellQty(item.sellUnit!.baseQty)} '
                                              '${item.sellUnit!.unitShort}',
                                              style: FontUtility.body.copyWith(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          for (final addon in item.addons)
                                            Text(
                                              '+ ${addon.addonItemName}'
                                              '${addon.quantity > 1 ? ' ×${addon.quantity}' : ''}'
                                              '  ${PosCurrency.format(addon.unitPrice * addon.quantity)}',
                                              style: FontUtility.body.copyWith(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      PosCurrency.format(item.totalPrice),
                                      style: FontUtility.subheading
                                          .copyWith(fontSize: 15),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(thickness: 1.5),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'Sub Total',
                              PosCurrency.format(state.subTotal),
                            ),
                            if (state.deliveryCharge > 0.0001) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Delivery Charge',
                                PosCurrency.format(state.deliveryCharge),
                              ),
                            ],
                            if (state.offerAppliedAmount > 0.0001) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                state.offerLabels.isEmpty
                                    ? 'Offer applied'
                                    : 'Offer · ${state.offerLabels.take(2).join(', ')}',
                                '-${PosCurrency.format(state.offerAppliedAmount)}',
                                color: Colors.green.shade700,
                              ),
                            ],
                            if (state.discounts.isNotEmpty) ...[
                              for (final discount in state.discounts) ...[
                                const SizedBox(height: 8),
                                _buildSummaryRow(
                                  '${discount.title} (${discount.percentage.toStringAsFixed(0)}%)',
                                  '-${PosCurrency.format(state.amountForDiscount(discount))}',
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ],
                            if (state.serviceTaxPercentage > 0) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Service Tax (${state.serviceTaxPercentage}%)',
                                '+${PosCurrency.format(state.serviceTaxValue)}',
                                color: Colors.orange.shade700,
                              ),
                            ],
                            if (state.tipsAmount > 0) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Tips',
                                '+${PosCurrency.format(state.tipsAmount)}',
                                color: Colors.blue.shade700,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Net Total',
                              PosCurrency.format(state.netTotal),
                              bold: true,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A00E0)
                                    .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Amount Paid',
                                    style: FontUtility.heading
                                        .copyWith(fontSize: 18),
                                  ),
                                  Text(
                                    PosCurrency.format(displayTotal),
                                    style: FontUtility.heading.copyWith(
                                      fontSize: 22,
                                      color: const Color(0xFF4A00E0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: _FatActionButton(
                                    label: 'Orders',
                                    icon: Icons.list_alt_rounded,
                                    outlined: true,
                                    onPressed: () => _goToOrders(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _FatActionButton(
                                    label: 'New Order',
                                    icon: Icons.add_rounded,
                                    outlined: true,
                                    onPressed: () => _newOrder(context),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: _FatActionButton(
                                    label: 'Print',
                                    icon: Icons.print_rounded,
                                    onPressed: () {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Printing to Thermal Printer...',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _finishOrder(BuildContext context) {
    context.read<CartBloc>().add(ClearCart());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _newOrder(BuildContext context) {
    context.read<CartBloc>().add(ClearCart());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(openNewOrderSheet: true),
      ),
      (route) => false,
    );
  }

  void _goToOrders(BuildContext context) {
    context.read<CartBloc>().add(ClearCart());
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(openOrders: true),
      ),
      (route) => false,
    );
  }

  Widget _buildSummaryRow(
    String title,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: (bold ? FontUtility.heading : FontUtility.body).copyWith(
            fontSize: bold ? 16 : 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: FontUtility.subheading.copyWith(
            fontSize: bold ? 18 : 15,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _FatActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  const _FatActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: FontUtility.subheading.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4A00E0),
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: const BorderSide(color: Color(0xFF4A00E0), width: 1.8),
          shape: shape,
          elevation: 0,
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white, size: 22),
      label: Text(
        label,
        style: FontUtility.heading.copyWith(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A00E0),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: shape,
        elevation: 3,
      ),
    );
  }
}
