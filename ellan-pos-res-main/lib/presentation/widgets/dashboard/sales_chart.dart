import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/controllers/checkout_models.dart';
import '../../../core/utils/font_utility.dart';

class SalesChart extends StatelessWidget {
  final String filterSelected;
  final List<PosDashboardSalesPoint> points;

  const SalesChart({
    super.key,
    required this.filterSelected,
    this.points = const [],
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount =
        points.fold<double>(0, (max, point) => point.amount > max ? point.amount : max);
    final maxCount =
        points.fold<int>(0, (max, point) => point.count > max ? point.count : max);
    final amountMax = maxAmount <= 0 ? 100.0 : (maxAmount * 1.2);
    final countMax = maxCount <= 0 ? 4.0 : (maxCount * 1.2);
    final hasSales = points.any((point) => point.amount > 0 || point.count > 0);

    final amountSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].amount),
    ];
    final countSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          countMax <= 0 ? 0 : (points[i].count / countMax) * amountMax,
        ),
    ];

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales trend',
                style: FontUtility.heading.copyWith(fontSize: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A00E0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filterSelected,
                  style: const TextStyle(
                    color: Color(0xFF4A00E0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              _LegendDot(color: Color(0xFF4A00E0), label: 'Order total'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF00C9FF), label: 'Order count'),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: !hasSales
                ? Center(
                    child: Text(
                      'No sales in this period',
                      style: FontUtility.body.copyWith(color: Colors.black45),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (points.length - 1).clamp(0, 23).toDouble(),
                      minY: 0,
                      maxY: amountMax,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Colors.black87,
                          tooltipPadding: const EdgeInsets.all(8),
                          getTooltipItems: (touchedSpots) {
                            if (touchedSpots.isEmpty) return [];
                            final index = touchedSpots.first.x.round();
                            if (index < 0 || index >= points.length) {
                              return [];
                            }
                            final point = points[index];
                            return [
                              LineTooltipItem(
                                '${point.label}\n\$${point.amount.toStringAsFixed(2)}\n${point.count} orders',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              for (var i = 1; i < touchedSpots.length; i++)
                                null,
                            ];
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final index = value.toInt();
                              // Show every 3rd hour so 24 labels stay readable.
                              if (index < 0 ||
                                  index >= points.length ||
                                  index % 3 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  points[index].label,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                            reservedSize: 28,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value == 0) return const SizedBox();
                              return Text(
                                '\$${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value == 0 || countMax <= 0) {
                                return const SizedBox();
                              }
                              final countValue =
                                  ((value / amountMax) * countMax).round();
                              if (countValue <= 0) return const SizedBox();
                              return Text(
                                '$countValue',
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 11,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withValues(alpha: 0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: amountSpots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: const Color(0xFF4A00E0),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, _) =>
                                points[spot.x.toInt()].amount > 0,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 3.5,
                                color: const Color(0xFF4A00E0),
                                strokeWidth: 0,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF4A00E0).withValues(alpha: 0.08),
                          ),
                        ),
                        LineChartBarData(
                          spots: countSpots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: const Color(0xFF00C9FF),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, _) =>
                                points[spot.x.toInt()].count > 0,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: const Color(0xFF00C9FF),
                                strokeWidth: 0,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: FontUtility.body.copyWith(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}
