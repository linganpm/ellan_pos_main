import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/controllers/checkout_models.dart';
import '../../../core/utils/font_utility.dart';
import '../../../core/localization/l10n_context.dart';
import 'package:pos_tablet/core/currency_format.dart';
import 'package:pos_tablet/presentation/widgets/rubber_push.dart';

class StaffSalesTable extends StatelessWidget {
  final String title;
  final List<PosDashboardStaffSales> rows;

  const StaffSalesTable({super.key, required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: PosCurrency.symbol());
    final empty = rows.isEmpty;
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
            Text(title, style: FontUtility.heading.copyWith(fontSize: 20)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      context.l10n.commonStaff,
                      style: FontUtility.body.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.commonOrders,
                      textAlign: TextAlign.right,
                      style: FontUtility.body.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      context.l10n.commonAmount,
                      textAlign: TextAlign.right,
                      style: FontUtility.body.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      context.l10n.commonCredit,
                      textAlign: TextAlign.right,
                      style: FontUtility.body.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: empty
                  ? Center(
                      child: Text(
                        context.l10n.dashboardNoStaffSales,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: rows.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: colors.outlineVariant, height: 1),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final initial = row.staffName.trim().isNotEmpty
                            ? row.staffName.trim().substring(0, 1).toUpperCase()
                            : '?';
                        return Container(
                          color: index.isOdd
                              ? colors.surfaceContainerLow
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(
                                        0xFF0F766E,
                                      ).withValues(alpha: 0.12),
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          color: Color(0xFF0F766E),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.staffName,
                                            style: FontUtility.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (row.staffReg.isNotEmpty)
                                            Text(
                                              '${context.l10n.commonRegNo} '
                                              '${row.staffReg}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${row.orderCount}',
                                  textAlign: TextAlign.right,
                                  style: FontUtility.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  currency.format(row.amount),
                                  textAlign: TextAlign.right,
                                  style: FontUtility.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  row.creditAmount > 0.0001
                                      ? currency.format(row.creditAmount)
                                      : '—',
                                  textAlign: TextAlign.right,
                                  style: FontUtility.body.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
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
