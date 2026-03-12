import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_data.dart';
import '../../../shared/models/alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/status_badge.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // priority filter: null = all  (contract values: "low" | "medium" | "high")
  String? _priorityFilter;
  // status filter: null = all  (contract values: "open" | "resolved" | "dismissed")
  String? _statusFilter;
  String? _expandedId;

  List<FraudAlert> get _filtered => MockData.alerts.where((a) {
    final matchPriority = _priorityFilter == null || a.priority == _priorityFilter;
    final matchStatus   = _statusFilter == null   || a.status   == _statusFilter;
    return matchPriority && matchStatus;
  }).toList();

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/alerts',
      pageTitle: 'Alerts',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 16),
          ..._filtered.map((a) => _AlertCard(
            alert: a,
            isExpanded: _expandedId == a.alertId,
            onTap: () => setState(() =>
            _expandedId = _expandedId == a.alertId ? null : a.alertId),
          )),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final openCount = MockData.alerts.where((a) => a.isOpen).length;
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Suspicious Activity Alerts', style: AppTheme.sans(
            size: 20, weight: FontWeight.w700)),
        Text('$openCount open alerts  ·  /v1/alerts endpoint', style: AppTheme.sans(
            size: 13, color: AppColors.textSecondary)),
      ]),
    ]);
  }

  Widget _buildFilters() {
    return Wrap(spacing: 8, children: [
      // Priority filters — contract enum: low | medium | high
      ...[null, 'high', 'medium', 'low'].map((p) => FilterChip(
        label: Text(p == null ? 'All Priority' : p.toUpperCase()),
        selected: _priorityFilter == p,
        onSelected: (_) => setState(() => _priorityFilter = p),
        labelStyle: AppTheme.mono(size: 10,
            color: _priorityFilter == p ? AppColors.textPrimary : AppColors.textSecondary),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary.withOpacity(0.15),
        side: BorderSide(color: _priorityFilter == p ? AppColors.primary : AppColors.border),
        visualDensity: VisualDensity.compact,
      )),
      // Status filters — contract enum: open | resolved | dismissed
      ...[null, 'open', 'resolved', 'dismissed'].map((s) => FilterChip(
        label: Text(s == null ? 'All Status' : s.toUpperCase()),
        selected: _statusFilter == s,
        onSelected: (_) => setState(() => _statusFilter = s),
        labelStyle: AppTheme.mono(size: 10,
            color: _statusFilter == s ? AppColors.textPrimary : AppColors.textSecondary),
        backgroundColor: AppColors.card,
        selectedColor: AppColors.primary.withOpacity(0.15),
        side: BorderSide(color: _statusFilter == s ? AppColors.primary : AppColors.border),
        visualDensity: VisualDensity.compact,
      )),
    ]);
  }
}

class _AlertCard extends StatelessWidget {
  final FraudAlert alert;
  final bool isExpanded;
  final VoidCallback onTap;
  const _AlertCard({required this.alert, required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeFmt     = DateFormat('MMM d, HH:mm:ss');
    final accentColor = _priorityColor(alert.priority);
    final timeStr     = alert.timestamp != null ? timeFmt.format(alert.timestamp!) : '—';

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
                color: isExpanded ? accentColor.withOpacity(0.5) : AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  // Left edge priority bar
                  Container(
                    width: 3, height: 42,
                    decoration: BoxDecoration(
                        color: accentColor, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  // Blue dot = open alert
                  // Pulsing Blue dot = open alert
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
                                  color: AppColors.primary.withOpacity(0.4 * value),
                                  blurRadius: 6 * value,
                                  spreadRadius: 1 * value,
                                )
                              ]
                          ),
                        );
                      },
                      onEnd: () {
                        // To make it loop infinitely, you would normally use an AnimationController,
                        // but for a quick pulse effect on load, this draws immediate attention.
                      },
                    ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        // alert_id from API
                        Text(alert.alertId, style: AppTheme.mono(
                            size: 13, weight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        // priority badge ("high"/"medium"/"low")
                        StatusBadge.priority(alert.priority),
                        const SizedBox(width: 6),
                        // domain badge ("paysim"/"ieee_cis")
                        StatusBadge.domainStr(alert.domain),
                        const Spacer(),
                        Text(timeStr, style: AppTheme.mono(
                            size: 11, color: AppColors.textMuted)),
                      ]),
                      const SizedBox(height: 5),
                      Text(alert.signalMessage ?? alert.type, style: AppTheme.sans(
                          size: 13, color: AppColors.textSecondary),
                          maxLines: isExpanded ? null : 1,
                          overflow: isExpanded ? null : TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  // Risk score chip: riskScore (0–1) → display as 0–100
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withOpacity(0.3)),
                    ),
                    child: Text('${alert.riskPercent}', style: AppTheme.mono(
                        size: 16, weight: FontWeight.w700, color: accentColor)),
                  ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted, size: 18),
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
      // Detail rows — all field names match /v1/alerts contract
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailRow('alert_id',            alert.alertId),
        _detailRow('transaction_id',      alert.transactionId),
        _detailRow('domain',              alert.domain == 'paysim' ? 'UPI / PaySim' : 'Card / IEEE-CIS'),
        _detailRow('risk_score',          '${alert.riskPercent} / 100  (raw: ${alert.riskScore.toStringAsFixed(3)})'),
        _detailRow('status',              alert.status.toUpperCase()),
        _detailRow('recommended_action',  alert.recommendedAction),
        _detailRow('type',                alert.type),
      ])),
      const SizedBox(width: 24),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Actions', style: AppTheme.sans(
            size: 11, weight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        _actionBtn('Mark Resolved',  Icons.check_circle_outline, AppColors.safe),
        const SizedBox(height: 6),
        _actionBtn('Dismiss',        Icons.cancel_outlined,       AppColors.textMuted),
        const SizedBox(height: 6),
        _actionBtn('Block & Review', Icons.block_outlined,        AppColors.fraud),
        const SizedBox(height: 6),
        _actionBtn('View Details',   Icons.open_in_new_outlined,  AppColors.primary),
      ]),
    ]);
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 160, child: Text(label, style: AppTheme.mono(
          size: 11, color: AppColors.textMuted))),
      Expanded(child: Text(value, style: AppTheme.mono(
          size: 12, weight: FontWeight.w500))),
    ]),
  );

  Widget _actionBtn(String label, IconData icon, Color color) => OutlinedButton.icon(
    onPressed: () {},
    icon: Icon(icon, size: 14, color: color),
    label: Text(label, style: AppTheme.sans(size: 12, color: color)),
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: color.withOpacity(0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: Size.zero,
    ),
  );

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':   return AppColors.fraud;
      case 'medium': return AppColors.suspicious;
      default:       return AppColors.safe;
    }
  }
}