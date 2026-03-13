// lib/features/dashboard/screens/dashboard_screen.dart
// Changes vs original:
//  • DashboardScreen is now StatefulWidget (to trigger alerts load in initState)
//  • "Open Alerts" KPI card value comes from AlertsProvider.openCount
//  • RecentAlertsList reads from AlertsProvider instead of MockData.alerts
//  • Other 5 KPI cards still use MockData.dashboardStats (no /v1/dashboard endpoint yet)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/provider/alerts_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_data.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/domain_split_chart.dart';
import '../../../shared/widgets/fraud_trend_chart.dart';
import '../../../shared/widgets/gradient_card.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off alert fetch once; provider is idempotent while loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AlertsProvider>();
      if (provider.state == AlertsLoadState.idle) {
        provider.loadAlerts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats  = MockData.dashboardStats;
    final numFmt = NumberFormat('#,###');

    return AppShell(
      currentRoute: '/dashboard',
      pageTitle: 'Dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildKpiRow(stats, numFmt),
            const SizedBox(height: 20),
            _buildChartsRow(),
            const SizedBox(height: 20),
            _buildBottomRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateFormat('EEEE, MMM d • HH:mm').format(DateTime.now());
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Fraud Intelligence Center',
            style: AppTheme.sans(size: 20, weight: FontWeight.w700)),
        Text(now,
            style:
            AppTheme.mono(size: 12, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  Widget _buildKpiRow(Map<String, dynamic> stats, NumberFormat fmt) {
    // "Open Alerts" is the only KPI sourced from the real API right now.
    // The rest come from MockData until /v1/dashboard is implemented.
    return Consumer<AlertsProvider>(
      builder: (context, alertsProvider, _) {
        final openAlertsValue = alertsProvider.hasData
            ? alertsProvider.openCount.toString()
            : alertsProvider.isLoading
            ? '…'
            : stats['alerts_open'].toString();

        final openAlertsTrend = alertsProvider.hasData
            ? '${alertsProvider.openCount} requiring action'
            : '5 critical';

        return LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 900 ? 6 : 3;
          return GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              MetricCard(
                title: 'Total Today',
                value: fmt.format(stats['total_today']),
                icon: Icons.receipt_long_outlined,
                accentColor: AppColors.primary,
                trend: '+8.3% vs yesterday',
                trendPositive: false,
              ),
              MetricCard(
                title: 'Fraud Detected',
                value: stats['fraud_detected'].toString(),
                icon: Icons.gpp_bad_outlined,
                accentColor: AppColors.fraud,
                trend: '+12% vs yesterday',
                trendPositive: false,
              ),
              MetricCard(
                title: 'Fraud Rate',
                value: '${stats['fraud_rate']}%',
                icon: Icons.percent_outlined,
                accentColor: AppColors.suspicious,
                subtitle: 'of all transactions',
              ),
              MetricCard(
                title: 'Avg Risk Score',
                value: stats['avg_risk_score'].toString(),
                icon: Icons.speed_outlined,
                accentColor: AppColors.primary,
                subtitle: 'out of 100',
              ),
              // ── LIVE: open alerts count from AlertsProvider ─────────────
              MetricCard(
                title: 'Open Alerts',
                value: openAlertsValue,
                icon: Icons.notifications_active_outlined,
                accentColor: AppColors.fraud,
                trend: openAlertsTrend,
                trendPositive: false,
              ),
              MetricCard(
                title: 'Model Accuracy',
                value: '${stats['model_accuracy']}%',
                icon: Icons.model_training_outlined,
                accentColor: AppColors.safe,
                trend: '+0.3% this week',
                trendPositive: true,
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildChartsRow() {
    return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: FraudTrendChart()),
          SizedBox(width: 16),
          Expanded(flex: 2, child: DomainSplitChart()),
        ]);
  }

  Widget _buildBottomRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: _RiskDistributionChart()),
      const SizedBox(width: 16),
      const Expanded(flex: 3, child: RecentAlertsList()),
    ]);
  }
}

// ── Risk distribution chart (unchanged) ─────────────────────────────────────
class _RiskDistributionChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = MockData.riskDistribution;
    const total = 12847;

    return GradientCard(
      padding: const EdgeInsets.all(20),
      accentColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk Distribution',
              style: AppTheme.sans(size: 15, weight: FontWeight.w600)),
          Text('Transactions by score band',
              style:
              AppTheme.sans(size: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ...data.map((band) {
            final pct = (band['count'] as int) / total;
            final color = _bandColor(band['color'] as String);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(band['label'],
                          style: AppTheme.sans(
                              size: 12,
                              color: AppColors.textSecondary)),
                      Text('${band['count']}',
                          style: AppTheme.mono(
                              size: 12, weight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _bandColor(String key) {
    switch (key) {
      case 'safe':
        return AppColors.safe;
      case 'suspicious':
        return AppColors.suspicious;
      case 'fraud':
        return AppColors.fraud;
      default:
        return AppColors.fraud.withValues(alpha: 0.7);
    }
  }
}

// ── RecentAlertsList — now reads from AlertsProvider ─────────────────────────
class RecentAlertsList extends StatelessWidget {
  const RecentAlertsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertsProvider>(
      builder: (context, provider, _) {
        // Show at most 4 alerts (same as before)
        final alerts = provider.alerts.take(4).toList();
        final timeFmt = DateFormat('MMM d, HH:mm');

        return GradientCard(
          padding: const EdgeInsets.all(20),
          accentColor: AppColors.fraud,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Recent Alerts',
                    style:
                    AppTheme.sans(size: 15, weight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/alerts'),
                  child: Text('View all',
                      style: AppTheme.sans(
                          size: 12, color: AppColors.primary)),
                ),
              ]),
              Text('Latest suspicious activity',
                  style: AppTheme.sans(
                      size: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),

              // ── Loading skeleton ────────────────────────────────────────
              if (provider.isLoading)
                Column(
                  children: List.generate(
                    3,
                        (_) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                  ),
                ),

              // ── Error state ─────────────────────────────────────────────
              if (provider.state == AlertsLoadState.error)
                Text(
                  'Could not load alerts.',
                  style: AppTheme.sans(
                      size: 12, color: AppColors.textSecondary),
                ),

              // ── Populated list ──────────────────────────────────────────
              if (!provider.isLoading)
                ...alerts.map((alert) {
                  final accentColor = _priorityColor(alert.priority);
                  final timeStr = alert.timestamp != null
                      ? timeFmt.format(alert.timestamp!)
                      : '—';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: accentColor, width: 3),
                        top: const BorderSide(color: AppColors.border),
                        right: const BorderSide(color: AppColors.border),
                        bottom: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(alert.alertId,
                                    style: AppTheme.mono(
                                        size: 12,
                                        weight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                StatusBadge.priority(alert.priority),
                                const SizedBox(width: 6),
                                StatusBadge.domainStr(alert.domain),
                              ]),
                              const SizedBox(height: 4),
                              // signalMessage is Gemini-generated reason
                              Text(
                                alert.signalMessage ?? alert.type,
                                style: AppTheme.sans(
                                    size: 12,
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]),
                      ),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${alert.riskPercent}',
                                style: AppTheme.mono(
                                    size: 18,
                                    weight: FontWeight.w700,
                                    color: accentColor)),
                            Text(timeStr,
                                style: AppTheme.mono(
                                    size: 10,
                                    color: AppColors.textMuted)),
                          ]),
                    ]),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.fraud;
      case 'medium':
        return AppColors.suspicious;
      default:
        return AppColors.safe;
    }
  }
}