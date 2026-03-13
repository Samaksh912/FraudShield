// lib/features/alerts/screens/alerts_screen.dart
// Now reads from AlertsProvider (real API + Gemini) instead of MockData.
// Loading, error, and empty states are all handled gracefully.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/provider/alerts_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String? _priorityFilter;
  String? _statusFilter;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    // Trigger load on first visit; provider guards against double-load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AlertsProvider>();
      if (provider.state == AlertsLoadState.idle) {
        provider.loadAlerts();
      }
    });
  }

  List<FraudAlert> _filtered(List<FraudAlert> all) => all.where((a) {
    final matchPriority =
        _priorityFilter == null || a.priority == _priorityFilter;
    final matchStatus =
        _statusFilter == null || a.status == _statusFilter;
    return matchPriority && matchStatus;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/alerts',
      pageTitle: 'Alerts',
      child: Consumer<AlertsProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(provider),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 16),

              // ── Loading state ───────────────────────────────────────────
              if (provider.isLoading) _buildLoadingState(),

              // ── Error state ─────────────────────────────────────────────
              if (provider.state == AlertsLoadState.error)
                _buildErrorState(provider),

              // ── Loaded: render filtered alert cards ─────────────────────
              if (provider.hasData)
                ..._filtered(provider.alerts).map((a) => _AlertCard(
                  alert: a,
                  isExpanded: _expandedId == a.alertId,
                  onTap: () => setState(() => _expandedId =
                  _expandedId == a.alertId ? null : a.alertId),
                )),

              if (provider.hasData && _filtered(provider.alerts).isEmpty)
                _buildEmptyState(),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AlertsProvider provider) {
    final openCount = provider.openCount;
    final subtitle = provider.isLoading
        ? 'Loading alerts…'
        : provider.state == AlertsLoadState.error
        ? 'Could not reach /v1/alerts'
        : '$openCount open alert${openCount == 1 ? '' : 's'}  ·  /v1/alerts';

    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Suspicious Activity Alerts',
            style: AppTheme.sans(size: 20, weight: FontWeight.w700)),
        Text(subtitle,
            style: AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      ]),
      const Spacer(),
      // Refresh button
      IconButton(
        icon: provider.isLoading
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_outlined,
            size: 18, color: AppColors.textSecondary),
        tooltip: 'Refresh',
        onPressed: provider.isLoading ? null : provider.refresh,
      ),
    ]);
  }

  Widget _buildFilters() {
    return Wrap(spacing: 8, children: [
      ...[null, 'high', 'medium', 'low'].map((p) => FilterChip(
        label: Text(p == null ? 'All Priority' : p.toUpperCase()),
        selected: _priorityFilter == p,
        onSelected: (_) => setState(() => _priorityFilter = p),
        labelStyle: AppTheme.mono(
            size: 10,
            color: _priorityFilter == p
                ? AppColors.textPrimary
                : AppColors.textSecondary),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        side: BorderSide(
            color: _priorityFilter == p
                ? AppColors.primary
                : AppColors.border),
        visualDensity: VisualDensity.compact,
      )),
      ...[null, 'open', 'resolved', 'dismissed'].map((s) => FilterChip(
        label: Text(s == null ? 'All Status' : s.toUpperCase()),
        selected: _statusFilter == s,
        onSelected: (_) => setState(() => _statusFilter = s),
        labelStyle: AppTheme.mono(
            size: 10,
            color: _statusFilter == s
                ? AppColors.textPrimary
                : AppColors.textSecondary),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        side: BorderSide(
            color:
            _statusFilter == s ? AppColors.primary : AppColors.border),
        visualDensity: VisualDensity.compact,
      )),
    ]);
  }

  Widget _buildLoadingState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Fetching alerts + generating AI insights…',
            style:
            AppTheme.sans(size: 13, color: AppColors.textSecondary)),
      ]),
    ),
  );

  Widget _buildErrorState(AlertsProvider provider) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.fraudDim,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.fraud.withValues(alpha: 0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.fraud, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Failed to load alerts: ${provider.errorMessage}',
          style: AppTheme.sans(size: 13, color: AppColors.fraud),
        ),
      ),
      TextButton(
        onPressed: provider.refresh,
        child: Text('Retry',
            style: AppTheme.sans(size: 12, color: AppColors.fraud)),
      ),
    ]),
  );

  Widget _buildEmptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Text('No alerts match the current filters.',
          style: AppTheme.sans(size: 14, color: AppColors.textSecondary)),
    ),
  );
}

// ── Alert card (unchanged logic, identical to original) ─────────────────────
class _AlertCard extends StatelessWidget {
  final FraudAlert alert;
  final bool isExpanded;
  final VoidCallback onTap;
  const _AlertCard(
      {required this.alert, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('MMM d, HH:mm:ss');
    final accentColor = _priorityColor(alert.priority);
    final timeStr =
    alert.timestamp != null ? timeFmt.format(alert.timestamp!) : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isExpanded
                    ? accentColor.withValues(alpha: 0.5)
                    : AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Left priority bar
                  Container(
                    width: 3,
                    height: 42,
                    decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  // Pulsing dot for open alerts
                  if (alert.isOpen)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.5, end: 1.0),
                      duration: const Duration(seconds: 1),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          width: 8 * value,
                          height: 8 * value,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4 * value),
                                  blurRadius: 6 * value,
                                  spreadRadius: 1 * value,
                                )
                              ]),
                        );
                      },
                      onEnd: () {},
                    ),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(alert.alertId,
                                style: AppTheme.mono(
                                    size: 13, weight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            StatusBadge.priority(alert.priority),
                            const SizedBox(width: 6),
                            StatusBadge.domainStr(alert.domain),
                            const Spacer(),
                            Text(timeStr,
                                style: AppTheme.mono(
                                    size: 11, color: AppColors.textMuted)),
                          ]),
                          const SizedBox(height: 5),
                          // signalMessage is now AI-generated by Gemini
                          Text(alert.signalMessage ?? alert.type,
                              style: AppTheme.sans(
                                  size: 13,
                                  color: AppColors.textSecondary),
                              maxLines: isExpanded ? null : 1,
                              overflow: isExpanded
                                  ? null
                                  : TextOverflow.ellipsis),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  // Risk score chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border:
                      Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Text('${alert.riskPercent}',
                        style: AppTheme.mono(
                            size: 16,
                            weight: FontWeight.w700,
                            color: accentColor)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                      isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: AppColors.textMuted,
                      size: 18),
                ]),
              ),
              if (isExpanded) ...[
                Container(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildExpandedDetail(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetail() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('alert_id', alert.alertId),
                _detailRow('transaction_id', alert.transactionId),
                _detailRow('domain',
                    alert.domain == 'paysim' ? 'UPI / PaySim' : 'Card / IEEE-CIS'),
                _detailRow('risk_score',
                    '${alert.riskPercent} / 100  (raw: ${alert.riskScore.toStringAsFixed(3)})'),
                _detailRow('status', alert.status.toUpperCase()),
                _detailRow('recommended_action', alert.recommendedAction),
                _detailRow('type', alert.type),
                if (alert.signalMessage != null) ...[
                  const SizedBox(height: 4),
                  _detailRow('ai_reason', alert.signalMessage!),
                ],
              ])),
      const SizedBox(width: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Actions',
            style: AppTheme.sans(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        _actionBtn(
            'Mark Resolved', Icons.check_circle_outline, AppColors.safe),
        const SizedBox(height: 6),
        _actionBtn('Dismiss', Icons.cancel_outlined, AppColors.textMuted),
        const SizedBox(height: 6),
        _actionBtn('Block & Review', Icons.block_outlined, AppColors.fraud),
        const SizedBox(height: 6),
        _actionBtn(
            'View Details', Icons.open_in_new_outlined, AppColors.primary),
      ]),
    ]);
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(
          width: 160,
          child: Text(label,
              style: AppTheme.mono(
                  size: 11, color: AppColors.textMuted))),
      Expanded(
          child: Text(value,
              style: AppTheme.mono(size: 12, weight: FontWeight.w500))),
    ]),
  );

  Widget _actionBtn(String label, IconData icon, Color color) =>
      OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 14, color: color),
        label: Text(label, style: AppTheme.sans(size: 12, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
        ),
      );

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