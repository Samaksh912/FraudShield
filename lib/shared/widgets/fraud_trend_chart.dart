import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/gradient_card.dart';

class FraudTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const FraudTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {

    return GradientCard(
      padding: const EdgeInsets.all(20),
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fraud Trend', style: AppTheme.sans(
                    size: 15, weight: FontWeight.w600)),
                Text('7-day transaction vs fraud volume', style: AppTheme.sans(
                    size: 12, color: AppColors.textSecondary)),
              ]),
              // Legend (unchanged)
              Row(children: [
                _legendDot(AppColors.primary, 'Total'),
                const SizedBox(width: 16),
                _legendDot(AppColors.fraud, 'Fraud'),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 3000,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.border.withValues(alpha: 0.5), strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(data[idx]['day'],
                              style: AppTheme.mono(size: 10,
                                  color: AppColors.textSecondary)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Total transactions (scaled to fit with fraud line)
                  _buildLine(
                    data.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), e.value['transactions'] / 100)).toList(),
                    AppColors.primary,
                    filled: true,
                  ),
                  // Fraud count (raw)
                  _buildLine(
                    data.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), (e.value['fraud'] as int).toDouble())).toList(),
                    AppColors.fraud,
                    filled: false,
                  ),
                ],
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: AppColors.border, strokeWidth: 2, dashArray: [4, 4]),
                        FlDotData(
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 6,
                              color: barData.color ?? Colors.white,
                              strokeWidth: 2,
                              strokeColor: AppColors.card,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => AppColors.cardHover.withValues(alpha: 0.95),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    tooltipBorder: const BorderSide(color: AppColors.border, width: 1.5),
                    getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                      final isFraud = spot.barIndex == 1;
                      final label = isFraud
                          ? '${spot.y.toStringAsFixed(0)} fraud alerts'
                          : '${(spot.y * 100).toStringAsFixed(0)} transactions';
                      final color = isFraud ? AppColors.fraud : AppColors.primary;

                      return LineTooltipItem(
                          label,
                          AppTheme.mono(size: 12, weight: FontWeight.w600, color: color)
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color, {required bool filled}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35, // Slightly sharper curves for a tech feel
      color: color,
      barWidth: 3, // Thicker lines
      isStrokeCapRound: true,
      shadow: Shadow(
        color: color.withValues(alpha: 0.5),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
      dotData: const FlDotData(show: false),
      belowBarData: filled
          ? BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0)
          ],
          stops: const [0.0, 1.0], // Smooth fade out
        ),
      )
          : BarAreaData(show: false),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: AppTheme.sans(size: 11, color: AppColors.textSecondary)),
  ]);
}