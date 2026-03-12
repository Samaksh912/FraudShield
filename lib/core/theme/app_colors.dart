import 'package:flutter/material.dart';

// FraudShield color palette — dark command center aesthetic
class AppColors {
  // Backgrounds (layered depth)
  static const Color bg         = Color(0xFF06090F); // deepest bg
  static const Color surface    = Color(0xFF0D1421); // page surface
  static const Color card       = Color(0xFF111C2E); // cards / panels
  static const Color cardHover  = Color(0xFF162238); // hover state
  static const Color border     = Color(0xFF1E2D45); // dividers

  // Brand / Primary
  static const Color primary    = Color(0xFF0EA5E9); // sky blue
  static const Color primaryDim = Color(0xFF0369A1); // darker blue
  static const Color accent     = Color(0xFF38BDF8); // lighter accent

  // Semantic
  static const Color fraud      = Color(0xFFEF4444); // red — fraud
  static const Color fraudDim   = Color(0xFF7F1D1D); // dark red bg tint
  static const Color suspicious = Color(0xFFF59E0B); // amber — warning
  static const Color suspiciousDim = Color(0xFF78350F);
  static const Color safe       = Color(0xFF10B981); // emerald — safe
  static const Color safeDim    = Color(0xFF064E3B);

  // Text
  static const Color textPrimary   = Color(0xFFF1F5F9); // near-white
  static const Color textSecondary = Color(0xFF94A3B8); // muted blue-gray
  static const Color textMuted     = Color(0xFF475569); // dim

  // Chart palette
  static const List<Color> chartColors = [
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
  ];
}