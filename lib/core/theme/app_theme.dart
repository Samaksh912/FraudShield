import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Display font (headings, metrics) — mono feel for data precision
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.dmMono(fontSize: size, fontWeight: weight, color: color);

  // Body / UI font
  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
  }) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.fraud,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      // Replace existing inputDecorationTheme in app_theme.dart
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg.withOpacity(0.5), // Darker inset feel
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hoverColor: AppColors.cardHover,
        hintStyle: sans(color: AppColors.textMuted),
        labelStyle: sans(color: AppColors.textSecondary),
      ),

      // Replace existing elevatedButtonTheme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0, // We will use custom shadows if needed
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: sans(size: 15, weight: FontWeight.w600, letterSpacing: 0.5),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.hovered)
                ? Colors.white.withOpacity(0.1)
                : null,
          ),
        ),
      ),
      dividerColor: AppColors.border,
      cardColor: AppColors.card,
    );
  }
}