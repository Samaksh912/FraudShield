import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class GradientCard extends StatefulWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient? gradient;

  const GradientCard({
    Key? key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)), // Slightly rounder
    this.gradient,
  }) : super(key: key);

  @override
  _GradientCardState createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0), // Lift effect
        padding: widget.padding,
        decoration: BoxDecoration(
          gradient: widget.gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.cardHover.withOpacity(0.4),
                  AppColors.card.withOpacity(0.8),
                ],
              ),
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: _isHovered ? accent.withOpacity(0.5) : AppColors.border.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: accent.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}