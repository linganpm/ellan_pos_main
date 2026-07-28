import 'package:flutter/material.dart';
import '../../../core/utils/font_utility.dart';

class CreditOrder {
  final String customerName;
  final double amount;
  final String date;

  CreditOrder({
    required this.customerName,
    required this.amount,
    required this.date,
  });
}

class CreditOrdersTable extends StatelessWidget {
  final List<CreditOrder> orders;

  const CreditOrdersTable({
    super.key,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Credit Orders',
            style: FontUtility.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
               padding: EdgeInsets.zero,
              itemCount: orders.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.black12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final isHighCredit = order.amount > 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF4A00E0).withOpacity(0.1),
                        child: Text(
                          order.customerName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF4A00E0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: FontUtility.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              order.date,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${order.amount.toStringAsFixed(2)}',
                        style: FontUtility.body.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isHighCredit ? Colors.red.shade700 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
