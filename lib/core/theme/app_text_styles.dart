import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/theme/app_theme.dart';

class AppTextStyles {
  const AppTextStyles._();

  // ── Static styles (const-compatible) ────────────────────────────────────
  static const label = TextStyle(color: AppColors.textSecondary, fontSize: 12);
  static const labelSmall = TextStyle(color: AppColors.textDisabled, fontSize: 11);
  static const body = TextStyle(color: AppColors.textPrimary, fontSize: 14);
  static const bodySmall = TextStyle(color: AppColors.textSecondary, fontSize: 13);
  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const sectionHeader = TextStyle(
    color: AppColors.textDisabled,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  // ── Monospace amount styles (dynamic color) ──────────────────────────────
  /// Roboto Mono 18 w600 — KPI cards, main amounts
  static TextStyle amount(Color color) =>
      GoogleFonts.robotoMono(color: color, fontSize: 18, fontWeight: FontWeight.w600);

  /// Roboto Mono 13 w600 — compact amounts (table cells, banners)
  static TextStyle amountSmall(Color color) =>
      GoogleFonts.robotoMono(color: color, fontSize: 13, fontWeight: FontWeight.w600);
}
