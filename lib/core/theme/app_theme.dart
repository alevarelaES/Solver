import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Primary palette (Stitch green) ──────────────────────────────────────
  static const primary = Color(0xFF689E28);
  static const primaryDark = Color(0xFF4C6929);
  static const primaryDarker = Color(0xFF1E2E11);

  // ── Semantic colours ────────────────────────────────────────────────────
  static const success = Color(0xFF689E28);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  // ── Light mode ──────────────────────────────────────────────────────────
  static const backgroundLight = Color(0xFFF7F8F6);
  static const surfaceLight = Colors.white;
  static const borderLight = Color(0xFFE5E7EB);
  static const textPrimaryLight = Color(0xFF1E2E11);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textDisabledLight = Color(0xFF9CA3AF);

  // ── Dark mode ───────────────────────────────────────────────────────────
  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const borderDark = Color(0xFF374151);
  static const textPrimaryDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF9CA3AF);
  static const textDisabledDark = Color(0xFF6B7280);

  // ── Legacy aliases (keeps existing views compiling) ────────────────────
  static const electricBlue = primary;
  static const neonEmerald = success;
  static const softRed = danger;
  static const warmAmber = warning;
  static const coolPurple = Color(0xFFA855F7);
  static const deepBlack = backgroundDark;

  static const textPrimary = textPrimaryLight;
  static const textSecondary = textSecondaryLight;
  static const textDisabled = textDisabledLight;
  static const borderSubtle = borderLight;
  static const surfaceCard = surfaceLight;
  static const surfaceDialog = surfaceLight;
  static const surfaceElevated = Color(0xFFF9FAFB);
  static const surfaceHeader = Color(0xFFF3F4F6);

  // ── Chart palette ──────────────────────────────────────────────────────
  static const chartColors = <Color>[
    primary,
    primaryDark,
    warning,
    info,
    danger,
    Color(0xFF00BCD4),
    Color(0xFFFF5722),
    coolPurple,
  ];
}

// ── Border radius scale ──────────────────────────────────────────────────────
class AppRadius {
  const AppRadius._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppTheme {
  // ── Light theme (default) ──────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        error: AppColors.danger,
        surface: AppColors.surfaceLight,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
        hintStyle: const TextStyle(color: AppColors.textDisabledLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      ),
      dividerColor: AppColors.borderLight,
      cardColor: AppColors.surfaceLight,
    );
  }

  // ── Dark theme ─────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        error: AppColors.danger,
        surface: AppColors.surfaceDark,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimaryDark,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
        hintStyle: const TextStyle(color: AppColors.textDisabledDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      ),
      dividerColor: AppColors.borderDark,
      cardColor: AppColors.surfaceDark,
    );
  }
}
