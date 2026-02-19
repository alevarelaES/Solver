import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF689E28);
  static const primaryDark = Color(0xFF4C6929);
  static const primaryDarker = Color(0xFF1E2E11);

  static const success = Color(0xFF689E28);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);

  static const backgroundLight = Color(0xFFF7F8F6);
  static const surfaceLight = Colors.white;
  static const borderLight = Color(0xFFE5E7EB);
  static const textPrimaryLight = Color(0xFF1E2E11);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const textDisabledLight = Color(0xFF9CA3AF);

  static const backgroundDark = Color(0xFF121212);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const borderDark = Color(0xFF374151);
  static const textPrimaryDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF9CA3AF);
  static const textDisabledDark = Color(0xFF6B7280);

  // Legacy aliases.
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
  static const surfaceMuted = Color(0xFFF8FAFC);
  static const surfaceSoft = Color(0xFFF4F6F8);
  static const surfaceSoftAlt = Color(0xFFFAFBFC);
  static const surfaceTableHeader = Color(0xFFF6F8FB);
  static const surfaceTablePanel = Color(0xFFF3F5F8);
  static const surfaceTableRowAlt = Color(0xFFFBFCFD);
  static const surfaceTableRowAccent = Color(0xFFF4F7FA);
  static const surfaceTableRowStripe = Color(0xFFF7FAFD);
  static const surfaceHeaderAlt = Color(0xFFEEF2F7);
  static const surfaceSuccessHeader = Color(0xFFEAF2E3);
  static const surfaceSuccess = Color(0xFFF7FBF4);
  static const surfaceSuccessSoft = Color(0xFFF7FAF4);
  static const surfaceDanger = Color(0xFFFEE2E2);
  static const surfaceDangerSoft = Color(0xFFFFF5F5);
  static const surfaceWarningSoft = Color(0xFFFFFAF0);
  static const surfaceNeutralSoft = Color(0xFFFAFCF8);
  static const surfaceInfoSoft = Color(0xFFE7ECF3);
  static const borderStrong = Color(0xFFD7DEE8);
  static const borderTable = Color(0xFFD4DBE5);
  static const borderTableRow = Color(0xFFD9E0EA);
  static const borderInputStrong = Color(0xFFD2DAE6);
  static const borderSuccessSoft = Color(0xFFCCD9BE);
  static const borderSuccess = Color(0xFFDCE7D3);
  static const successStrong = Color(0xFF15803D);
  static const successLime = Color(0xFF84CC16);
  static const warningStrong = Color(0xFFB45309);
  static const warningDeep = Color(0xFFEA580C);
  static const warningAccent = Color(0xFFF97316);
  static const warningBright = Color(0xFFEAB308);
  static const dangerStrong = Color(0xFFB91C1C);
  static const dangerDeep = Color(0xFF7F1D1D);
  static const successTint = Color(0xFFBBF7D0);
  static const successTintSoft = Color(0xFFDCFCE7);
  static const dangerTint = Color(0xFFFCA5A5);
  static const textMutedStrong = Color(0xFF4B5563);
  static const gray300 = Color(0xFFD1D5DB);
  static const shadowGreen = Color(0xFF1E2E11);
  static const cardGradientGreenStart = Color(0xFF2E5C1B);
  static const cardGradientGreenEnd = Color(0xFF143306);
  static const cardGradientSlateStart = Color(0xFF374151);
  static const cardGradientSlateEnd = Color(0xFF1F2937);
  static const promoGradientStart = Color(0xFF243E0F);
  static const promoGradientEnd = Color(0xFF121F08);
  static const portfolioSurfaceDark = Color(0xFF1A2327);
  static const portfolioSurfaceLight = Color(0xFFF0F7EE);
  static const shadowOverlaySm = Color(0x12000000);
  static const shadowOverlayMd = Color(0x14000000);

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

class AppRadius {
  const AppRadius._();

  // Compact corner system: smaller default roundness across the whole app.
  // Names stay stable for backward compatibility.
  static const double r3 = 2;
  static const double r4 = 3;
  static const double r6 = 4;
  static const double r7 = 5;
  static const double r8 = 6;
  static const double r9 = 7;
  static const double r10 = 8;
  static const double r12 = 9;
  static const double r16 = 12;
  static const double r18 = 13;
  static const double r20 = 14;
  static const double r24 = 16;
  static const double r32 = 20;

  static const double xs = r4;
  static const double sm = r8;
  static const double md = r12;
  static const double lg = r16;
  static const double xl = r20;
  static const double xxl = r24;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final background = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final textDisabled = isDark
        ? AppColors.textDisabledDark
        : AppColors.textDisabledLight;
    final fieldFill = isDark
        ? const Color(0xFF2A2A2A)
        : AppColors.surfaceElevated;

    final colorScheme =
        (isDark ? const ColorScheme.dark() : const ColorScheme.light())
            .copyWith(
              primary: AppColors.primary,
              secondary: AppColors.primaryDark,
              error: AppColors.danger,
              surface: surface,
              onPrimary: Colors.white,
              onSurface: textPrimary,
            );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: textPrimary, displayColor: textPrimary);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      cardColor: surface,
      dividerColor: border,
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: border),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        labelStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        dataTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        headingRowColor: WidgetStatePropertyAll(
          isDark ? AppColors.surfaceDark : AppColors.surfaceHeader,
        ),
        dividerThickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
      ),
    );
  }
}
