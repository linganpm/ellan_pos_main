import 'package:flutter/material.dart';
import '../../../core/localization/l10n_context.dart';
import '../../../core/utils/font_utility.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

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

  const CreditOrdersTable({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RubberPush(
      radius: 24,
      trackFocus: false,
      child: Container(
        padding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.dashboardCreditOrders,
              style: FontUtility.heading.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: orders.length,
                separatorBuilder: (context, index) =>
                    Divider(color: colors.outlineVariant, height: 1),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final isHighCredit = order.amount > 100;
                  return Container(
                    color: index.isOdd ? colors.surfaceContainerLow : null,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(
                            0xFF4A00E0,
                          ).withOpacity(0.1),
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
                                style: FontUtility.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                order.date,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          PosCurrency.format(order.amount),
                          style: FontUtility.body.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isHighCredit
                                ? Colors.red.shade700
                                : Colors.black87,
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
      ),
    );
  }
}
