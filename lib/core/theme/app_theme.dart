import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const deepBlack = Color(0xFF050505);
  static const electricBlue = Color(0xFF3B82F6);
  static const neonEmerald = Color(0xFF10B981);
  static const softRed = Color(0xFFEF4444);
  static const coolPurple = Color(0xFFA855F7);
  static const warmAmber = Color(0xFFF59E0B);

  static const textPrimary = Color(0xE6FFFFFF);   // white 90%
  static const textSecondary = Color(0x99FFFFFF); // white 60%
  static const textDisabled = Color(0x4DFFFFFF);  // white 30%
  static const borderSubtle = Color(0x1AFFFFFF);  // white 10%
  static const surfaceCard = Color(0x0DFFFFFF);   // white 5%

  // ── Elevated surfaces ────────────────────────────────────────────────────
  static const surfaceDialog = Color(0xFF0F0F0F);   // dialogs / main modals
  static const surfaceElevated = Color(0xFF1A1A1A); // bottom-sheets, tooltips, dropdowns
  static const surfaceHeader = Color(0xFF0A0A0A);   // table/grid headers

  // ── Chart palette (8 colours, used in order) ────────────────────────────
  static const chartColors = <Color>[
    electricBlue,
    coolPurple,
    warmAmber,
    neonEmerald,
    softRed,
    Color(0xFF00BCD4), // cyan
    Color(0xFFFF5722), // deep-orange
    Color(0xFF9C27B0), // purple
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
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.deepBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.electricBlue,
        secondary: AppColors.coolPurple,
        error: AppColors.softRed,
        surface: AppColors.deepBlack,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.electricBlue, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDialog,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
      ),
    );
  }
}
