import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/gradient_card.dart';  // <-- import

class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final String? trend;
  final bool trendPositive;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.subtitle,
    this.trend,
    this.trendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.all(14),
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon + title row (unchanged)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                        size: 11, color: AppColors.textSecondary, weight: FontWeight.w500)),
              ),
              const SizedBox(width: 6),
              // Replace the existing Container for the icon with this:
              Container(
                width: 32, // Slightly larger
                height: 32,
                decoration: BoxDecoration(
                    color: AppColors.surface, // Dark inner background
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withOpacity(0.3)),
                    boxShadow: [
                      // Inner ambient glow
                      BoxShadow(
                        color: accentColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                ),
                child: Center(
                    child: Icon(icon, size: 16, color: accentColor)
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Value
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppTheme.mono(
                size: 24, weight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTheme.sans(size: 10, color: AppColors.textMuted)),
          ],
          if (trend != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(
                trendPositive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: trendPositive ? AppColors.safe : AppColors.fraud,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(trend!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.sans(
                        size: 10,
                        color: trendPositive ? AppColors.safe : AppColors.fraud)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}