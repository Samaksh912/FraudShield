import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

// Left branding panel shown on desktop
class BrandPanel extends StatelessWidget {
  const BrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF06090F), Color(0xFF0C1A30)],
        ),
      ),
      child: Stack(
        children: [
          // Background grid pattern
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          // Content
          Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Headline
                Text('Real-Time\nFraud Detection',
                    style: AppTheme.sans(
                        size: 44,
                        weight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Text(
                  'AI-powered risk scoring across UPI\nand card transaction domains.',
                  style: AppTheme.sans(size: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 48),
                // Feature bullets
                ...[
                  ('XGBoost ML models', Icons.model_training_outlined),
                  ('Transaction anomaly detection', Icons.search_outlined),
                  ('Real-time risk alerts', Icons.notifications_active_outlined),
                  ('PaySim UPI + IEEE-CIS Card', Icons.payments_outlined),
                ].map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(item.$2, size: 16, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Text(item.$1,
                            style: AppTheme.sans(
                                size: 15, color: AppColors.textSecondary)),
                      ]),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Subtle dot grid background
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const gap = 32.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

