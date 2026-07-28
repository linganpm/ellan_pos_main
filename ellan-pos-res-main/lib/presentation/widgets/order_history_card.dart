import 'package:flutter/material.dart';
import 'package:pos_tablet/core/currency_format.dart';
import '../../core/utils/font_utility.dart';
import '../../data/models/order_history_model.dart';
import 'cart_item_tile.dart';

class OrderHistoryCard extends StatelessWidget {
  final OrderHistoryModel order;

  const OrderHistoryCard({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.orderId != null
                      ? '${order.id} · Order #${order.orderId}'
                      : order.id,
                  style: FontUtility.heading.copyWith(fontSize: 18),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Preparing',
                  style: FontUtility.subheading.copyWith(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${order.timestamp.hour.toString().padLeft(2, '0')}:${order.timestamp.minute.toString().padLeft(2, '0')} - ${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}',
            style: FontUtility.body.copyWith(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),
          ...order.items.map((item) {
            return CartItemTile(
              cartItem: item,
              isReadOnly: true,
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: FontUtility.subheading
                    .copyWith(fontSize: 16, color: Colors.grey.shade700),
              ),
              Text(
                PosCurrency.format(order.totalAmount),
                style: FontUtility.heading.copyWith(
                  fontSize: 20,
                  color: const Color(0xFF4A00E0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
