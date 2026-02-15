import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';

class AppButtonStyles {
  const AppButtonStyles._();

  static ButtonStyle primary({
    EdgeInsetsGeometry? padding,
    double radius = AppRadius.md,
    Size? minimumSize,
    Color? backgroundColor,
    Color foregroundColor = Colors.white,
    BorderSide? side,
    double? elevation,
    Color? shadowColor,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: foregroundColor,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      minimumSize: minimumSize,
      elevation: elevation,
      shadowColor: shadowColor,
      side: side,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle outline({
    EdgeInsetsGeometry? padding,
    double radius = AppRadius.md,
    Size? minimumSize,
    Color? foregroundColor,
    BorderSide? side,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foregroundColor ?? AppColors.textPrimary,
      side: side ?? const BorderSide(color: AppColors.borderSubtle),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      minimumSize: minimumSize,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle tonal({
    EdgeInsetsGeometry? padding,
    double radius = AppRadius.md,
    Size? minimumSize,
    Color? foregroundColor,
    Color? backgroundColor,
    BorderSide? side,
  }) {
    return TextButton.styleFrom(
      foregroundColor: foregroundColor ?? AppColors.textPrimary,
      backgroundColor: backgroundColor ?? AppColors.surfaceElevated,
      minimumSize: minimumSize,
      side: side,
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle dangerOutline({
    EdgeInsetsGeometry? padding,
    double radius = AppRadius.sm,
  }) {
    return TextButton.styleFrom(
      foregroundColor: AppColors.danger,
      side: BorderSide(color: AppColors.danger.withAlpha(50)),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    );
  }

  static ButtonStyle inline({
    Color foregroundColor = AppColors.primary,
  }) {
    return TextButton.styleFrom(
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: foregroundColor,
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  static ButtonStyle iconSurface({
    Color? backgroundColor,
    double radius = AppRadius.sm,
  }) {
    return IconButton.styleFrom(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.zero,
    );
  }
}

class AppInputStyles {
  const AppInputStyles._();

  static InputDecoration search({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool square = false,
  }) {
    final radius = square ? BorderRadius.zero : BorderRadius.circular(AppRadius.md);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textDisabled),
      prefixIcon:
          prefixIcon ??
          const Icon(Icons.search, size: 18, color: AppColors.textDisabled),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
