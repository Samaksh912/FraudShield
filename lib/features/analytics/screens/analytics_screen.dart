import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/provider/analytics_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AnalyticsProvider>();
      if (provider.state == AnalyticsLoadState.idle) {
        provider.loadAnalytics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/analytics',
      pageTitle: 'Analytics',
      child: Consumer<AnalyticsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model Performance',
                    style: AppTheme.sans(size: 20, weight: FontWeight.w700)),
                Text('Evaluation metrics from Kaggle training runs',
                    style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                // Pill-shaped Tab Bar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                        blurStyle: BlurStyle.inner,
                      )
                    ],
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: AppColors.cardHover,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: AppTheme.sans(size: 13, weight: FontWeight.w600),
                    tabs: const [
                      Tab(height: 38, text: 'PaySim (UPI)'),
                      Tab(height: 38, text: 'IEEE-CIS (Card)'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tab Content Area
                Container(
                  height: 650,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _DomainAnalytics(
                        domainKey: 'PaySim (UPI)',
                        featureKey: 'PaySim',
                        modelMetrics: provider.modelMetrics,
                        featureImportance: provider.featureImportance,
                      ),
                      _DomainAnalytics(
                        domainKey: 'IEEE-CIS (Card)',
                        featureKey: 'IEEE-CIS',
                        modelMetrics: provider.modelMetrics,
                        featureImportance: provider.featureImportance,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DomainAnalytics extends StatelessWidget {
  final String domainKey;
  final String featureKey;
  final Map<String, Map<String, dynamic>> modelMetrics;
  final Map<String, List<Map<String, dynamic>>> featureImportance;
  const _DomainAnalytics({
    required this.domainKey,
    required this.featureKey,
    required this.modelMetrics,
    required this.featureImportance,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = modelMetrics[domainKey] ?? {};
    final features = featureImportance[featureKey] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Model info badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text('Model: ${metrics['model']}',
              style: AppTheme.mono(size: 11, color: AppColors.primary)),
        ),
        const SizedBox(height: 20),

        // Metrics row
        Row(
            children: [
              _metricTile('Precision', '${metrics['precision']}%', AppColors.primary),
              _metricTile('Recall', '${metrics['recall']}%', AppColors.safe),
              _metricTile('F1 Score', '${metrics['f1']}%', AppColors.suspicious),
              _metricTile('PR-AUC', '${metrics['pr_auc']}%', const Color(0xFF8B5CF6)),
            ].expand((w) => [w, const SizedBox(width: 10)]).toList()
              ..removeLast()),
        const SizedBox(height: 24),

        // Feature importance
        Text('Feature Importance',
            style: AppTheme.sans(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Top engineered features ranked by model contribution',
            style: AppTheme.sans(size: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // Horizontal bar chart
        SizedBox(
          height: 240,
          child: BarChart(BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 0.35,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) =>
                    AppColors.cardHover.withValues(alpha: 0.95),
                tooltipRoundedRadius: 8,
                tooltipBorder: const BorderSide(color: AppColors.border),
                getTooltipItem: (group, _, rod, __) {
                  final featureName =
                      features[group.x.toInt()]['feature'] as String;
                  return BarTooltipItem(
                    '$featureName\n',
                    AppTheme.sans(size: 11, color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: '${(rod.toY * 100).toStringAsFixed(1)}%',
                        style: AppTheme.mono(
                            size: 13,
                            weight: FontWeight.w700,
                            color: rod.color ?? AppColors.primary),
                      ),
                    ],
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx >= features.length) return const SizedBox();
                    final label = (features[idx]['feature'] as String)
                        .replaceAll('_', '\n');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(label,
                          style: AppTheme.mono(
                              size: 9,
                              color: AppColors.textSecondary,
                              weight: FontWeight.w500),
                          textAlign: TextAlign.center),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              horizontalInterval: 0.1,
              getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [4, 4]),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            barGroups: features.asMap().entries.map((entry) {
              final color = AppColors
                  .chartColors[entry.key % AppColors.chartColors.length];
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value['importance'] as double,
                    color: color,
                    width: 32,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(6)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 0.35,
                      color: AppColors.bg,
                    ),
                  )
                ],
              );
            }).toList(),
          )),
        ),
        const SizedBox(height: 32),

        // Feature table with Hover States
        ...features.asMap().entries.map((entry) {
          final pct =
              ((entry.value['importance'] as double) * 100).toStringAsFixed(1);
          final color = AppColors
              .chartColors[entry.key % AppColors.chartColors.length];
          bool isHovered = false;

          return StatefulBuilder(builder: (context, setState) {
            return MouseRegion(
              onEnter: (_) => setState(() => isHovered = true),
              onExit: (_) => setState(() => isHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isHovered ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isHovered ? AppColors.border : Colors.transparent,
                  ),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 24,
                    child: Text('${entry.key + 1}.',
                        style: AppTheme.mono(
                            size: 12, color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(entry.value['feature'],
                          style: AppTheme.mono(
                              size: 13,
                              weight: isHovered
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isHovered
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary))),
                  Text('$pct%',
                      style: AppTheme.mono(
                          size: 13,
                          color: color,
                          weight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                    color:
                                        color.withValues(alpha: 0.4),
                                    blurRadius: 6)
                              ]
                            : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value['importance'] as double,
                          minHeight: 6,
                          backgroundColor: AppColors.bg,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          });
        }),
      ]),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
    bool isHovered = false;
    return Expanded(
      child: StatefulBuilder(builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform:
                Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
            padding:
                const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            decoration: BoxDecoration(
              color: isHovered
                  ? color.withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isHovered
                    ? color.withValues(alpha: 0.6)
                    : color.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                if (isHovered)
                  BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4)),
              ],
            ),
            child: Column(children: [
              Text(value,
                  style: AppTheme.mono(
                      size: 26, weight: FontWeight.w700, color: color)),
              const SizedBox(height: 8),
              Text(label,
                  style: AppTheme.sans(
                      size: 12,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w600)),
            ]),
          ),
        );
      }),
    );
  }
}

