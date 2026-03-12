import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

// Colored pill badge — all factories now take plain strings matching the API contract.
// risk.level:    "low" | "medium" | "high"
// risk.decision: "allow" | "review" | "block"
// domain:        "paysim" | "ieee_cis"
// alert.priority:"low" | "medium" | "high"
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  // Risk level: "low" | "medium" | "high"
  factory StatusBadge.level(String level) {
    switch (level) {
      case 'high':
        return StatusBadge(label: 'HIGH', color: AppColors.fraud, bgColor: AppColors.fraudDim);
      case 'medium':
        return StatusBadge(label: 'MEDIUM', color: AppColors.suspicious, bgColor: AppColors.suspiciousDim);
      default: // "low"
        return StatusBadge(label: 'LOW', color: AppColors.safe, bgColor: AppColors.safeDim);
    }
  }

  // Risk decision: "allow" | "review" | "block"
  factory StatusBadge.decision(String decision) {
    switch (decision) {
      case 'block':
        return StatusBadge(label: 'BLOCKED', color: AppColors.fraud, bgColor: AppColors.fraudDim);
      case 'review':
        return StatusBadge(label: 'REVIEW', color: AppColors.suspicious, bgColor: AppColors.suspiciousDim);
      default: // "allow"
        return StatusBadge(label: 'ALLOWED', color: AppColors.safe, bgColor: AppColors.safeDim);
    }
  }

  // Alert priority: "low" | "medium" | "high"  (same colors as level)
  factory StatusBadge.priority(String priority) => StatusBadge.level(priority);

  // Domain string: "paysim" | "ieee_cis"
  factory StatusBadge.domainStr(String domain) {
    if (domain == 'paysim') {
      return const StatusBadge(label: 'UPI', color: AppColors.primary, bgColor: Color(0xFF0C2340));
    }
    return const StatusBadge(label: 'CARD', color: Color(0xFF8B5CF6), bgColor: Color(0xFF1E1040));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTheme.mono(size: 10, weight: FontWeight.w600, color: color),
      ),
    );
  }
}