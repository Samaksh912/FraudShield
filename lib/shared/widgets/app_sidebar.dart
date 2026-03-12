import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

// Sidebar nav item definition
class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  const _NavItem(this.label, this.icon, this.route);
}

const _navItems = [
  _NavItem('Dashboard',     Icons.dashboard_outlined,      '/dashboard'),
  _NavItem('Transactions',  Icons.swap_horiz_outlined,     '/transactions'),
  _NavItem('Alerts',        Icons.notifications_outlined,  '/alerts'),
  _NavItem('Score',         Icons.search_outlined,         '/score'),
  _NavItem('Analytics',     Icons.bar_chart_outlined,      '/analytics'),
];

class AppSidebar extends StatelessWidget {
  final String currentRoute;
  const AppSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surface.withOpacity(0.95),
            AppColors.bg,
          ],
        ),
        border: const Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Logo / brand
          _buildLogo(),
          const SizedBox(height: 8),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _navItems.map((item) => _NavTile(
                item: item,
                isActive: currentRoute.startsWith(item.route),
              )).toList(),
            ),
          ),
          // Footer: user info
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FraudShield', style: AppTheme.sans(
                  size: 15, weight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('AI Detection', style: AppTheme.mono(
                  size: 10, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryDim,
            child: Icon(Icons.person_outline, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analyst', style: AppTheme.sans(
                    size: 13, weight: FontWeight.w600)),
                Text('admin@fraudshield.ai', style: AppTheme.sans(
                    size: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout, size: 16, color: AppColors.textMuted),
            onPressed: () => context.go('/login'),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  const _NavTile({required this.item, required this.isActive});

  @override
  __NavTileState createState() => __NavTileState();
}

class __NavTileState extends State<_NavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // slightly more breathing room
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: widget.isActive
                ? LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.15),
                Colors.transparent,
              ],
            )
                : _isHovered
                ? LinearGradient(
              colors: [
                AppColors.surface.withOpacity(0.8),
                Colors.transparent,
              ],
            )
                : null,
            borderRadius: BorderRadius.circular(8),
            // Left border indicator for active state
            border: Border(
              left: BorderSide(
                color: widget.isActive ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => context.go(widget.item.route),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      size: 20,
                      color: widget.isActive
                          ? AppColors.primary
                          : _isHovered
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.item.label,
                      style: AppTheme.sans(
                        size: 14,
                        weight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                        color: widget.isActive
                            ? AppColors.textPrimary
                            : _isHovered
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}