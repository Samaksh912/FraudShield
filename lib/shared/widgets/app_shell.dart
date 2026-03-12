import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'app_sidebar.dart';

// Wraps every authenticated screen with the sidebar layout
class AppShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String pageTitle;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.pageTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,  // fallback
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.bg,
              AppColors.bg,
            ],
          ),
        ),
        child: Row(
          children: [
            AppSidebar(currentRoute: currentRoute),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: pageTitle),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(title, style: AppTheme.sans(
              size: 16, weight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          // Live indicator
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
                color: AppColors.safe, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('Live', style: AppTheme.mono(size: 11, color: AppColors.safe)),
          const SizedBox(width: 20),
          // Alert bell
          Stack(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 20, color: AppColors.textSecondary),
              Positioned(
                right: 0, top: 0,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.fraud, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}