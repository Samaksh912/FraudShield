import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class DomainSplitChart extends StatefulWidget {
  final Map<String, double> data;
  const DomainSplitChart({super.key, required this.data});

  @override
  State<DomainSplitChart> createState() => _DomainSplitChartState();
}

class _DomainSplitChartState extends State<DomainSplitChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Domain Split', style: AppTheme.sans(size: 15, weight: FontWeight.w700)),
          Text('Fraud by transaction type', style: AppTheme.sans(
              size: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Row(
              children: [
                // Interactive Donut chart
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      sectionsSpace: 4, // More breathing room
                      centerSpaceRadius: 36,
                      sections: _buildSections(),
                    ),
                    swapAnimationDuration: const Duration(milliseconds: 250),
                    swapAnimationCurve: Curves.easeOutBack,
                  ),
                ),
                // Legend
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildLegend(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _sectionColors = [AppColors.primary, Color(0xFF8B5CF6)];

  List<PieChartSectionData> _buildSections() {
    final entries = widget.data.entries.toList();
    return entries.asMap().entries.map((e) {
      final color = _sectionColors[e.key % _sectionColors.length];
      return _buildSection(e.key, e.value.value, color);
    }).toList();
  }

  List<Widget> _buildLegend() {
    final entries = widget.data.entries.toList();
    final widgets = <Widget>[];
    for (int i = 0; i < entries.length; i++) {
      final color = _sectionColors[i % _sectionColors.length];
      widgets.add(_legendRow(color, entries[i].key, '${entries[i].value}%', isHovered: _touchedIndex == i));
      if (i < entries.length - 1) widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }

  PieChartSectionData _buildSection(int index, double value, Color color) {
    final isTouched = index == _touchedIndex;
    final radius = isTouched ? 34.0 : 28.0;

    return PieChartSectionData(
      value: value,
      color: color.withValues(alpha: isTouched ? 1.0 : 0.8),
      title: '',
      radius: radius,
      borderSide: isTouched ? BorderSide(color: color, width: 2) : BorderSide.none,
    );
  }

  Widget _legendRow(Color color, String label, String pct, {required bool isHovered}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _touchedIndex == -1 || isHovered ? 1.0 : 0.4, // Dims non-hovered legend items
      child: Row(children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isHovered ? 12 : 10,
            height: isHovered ? 12 : 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              boxShadow: isHovered ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)] : [],
            )
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTheme.sans(
              size: 12,
              color: isHovered ? AppColors.textPrimary : AppColors.textSecondary,
              weight: isHovered ? FontWeight.w600 : FontWeight.w400)),
          Text(pct, style: AppTheme.mono(
              size: 14,
              weight: isHovered ? FontWeight.w700 : FontWeight.w600,
              color: isHovered ? color : AppColors.textPrimary)),
        ]),
      ]),
    );
  }
}