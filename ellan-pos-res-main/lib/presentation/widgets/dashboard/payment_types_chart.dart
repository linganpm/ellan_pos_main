import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/localization/l10n_context.dart';
import '../../../core/utils/font_utility.dart';

class PaymentTypesChart extends StatelessWidget {
  final double cashPercentage;
  final double cardPercentage;
  final double onlinePercentage;
  final double creditPercentage;

  const PaymentTypesChart({
    super.key,
    required this.cashPercentage,
    required this.cardPercentage,
    this.onlinePercentage = 0,
    this.creditPercentage = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasData =
        cashPercentage + cardPercentage + onlinePercentage + creditPercentage >
        0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.dashboardPaymentTypes,
            style: FontUtility.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: !hasData
                ? Center(
                    child: Text(
                      context.l10n.dashboardNoPaymentsYet,
                      style: FontUtility.body.copyWith(color: Colors.black45),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                            sections: [
                              if (cardPercentage > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF4A00E0),
                                  value: cardPercentage,
                                  title: '${cardPercentage.toInt()}%',
                                  radius: 40,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              if (cashPercentage > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF00C9FF),
                                  value: cashPercentage,
                                  title: '${cashPercentage.toInt()}%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              if (onlinePercentage > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF92FE9D),
                                  value: onlinePercentage,
                                  title: '${onlinePercentage.toInt()}%',
                                  radius: 35,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              if (creditPercentage > 0)
                                PieChartSectionData(
                                  color: const Color(0xFFFFA751),
                                  value: creditPercentage,
                                  title: '${creditPercentage.toInt()}%',
                                  radius: 35,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIndicator(
                              const Color(0xFF00C9FF),
                              context.l10n.commonCash,
                            ),
                            const SizedBox(height: 12),
                            _buildIndicator(
                              const Color(0xFF4A00E0),
                              context.l10n.commonCard,
                            ),
                            if (onlinePercentage > 0) ...[
                              const SizedBox(height: 12),
                              _buildIndicator(
                                const Color(0xFF92FE9D),
                                context.l10n.commonOnline,
                              ),
                            ],
                            if (creditPercentage > 0) ...[
                              const SizedBox(height: 12),
                              _buildIndicator(
                                const Color(0xFFFFA751),
                                context.l10n.commonCredit,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: FontUtility.body.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
