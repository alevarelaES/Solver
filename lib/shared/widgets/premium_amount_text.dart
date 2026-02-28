import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_premium_theme.dart';

enum PremiumAmountVariant { hero, standard, small, table }

class PremiumAmountText extends StatelessWidget {
  final double amount;
  final String currency;
  final PremiumAmountVariant variant;
  final bool showSign;
  final bool colorCoded;
  final Color? overrideColor;
  final String? overrideFontFamily;
  final bool compact;

  const PremiumAmountText({
    super.key,
    required this.amount,
    required this.currency,
    this.variant = PremiumAmountVariant.standard,
    this.showSign = false,
    this.colorCoded = false,
    this.overrideColor,
    this.overrideFontFamily,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = theme.extension<PremiumThemeExtension>()!;

    double size;
    FontWeight weight;
    List<FontFeature> features = p.fontFeatureTabular;

    switch (variant) {
      case PremiumAmountVariant.hero:
        size = p.heroAmountSize;
        weight = p.heroAmountWeight;
        break;
      case PremiumAmountVariant.standard:
        size = p.kpiAmountSize;
        weight = p.kpiAmountWeight;
        break;
      case PremiumAmountVariant.small:
        size = 14.0;
        weight = FontWeight.w500;
        break;
      case PremiumAmountVariant.table:
        size = p.tableAmountSize;
        weight = FontWeight.w500;
        break;
    }

    Color? finalColor = overrideColor;
    if (finalColor == null && colorCoded) {
      if (amount > 0) {
        finalColor = theme.colorScheme.primary; 
      } else if (amount < 0) {
        finalColor = theme.colorScheme.error; 
      }
    }

    String formatted = AppFormats.formatFromCurrency(amount, currency, compact: compact);
    if (showSign && amount > 0) {
      if (!formatted.startsWith('+')) {
        formatted = '+$formatted';
      }
    }

    TextStyle style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: finalColor ?? theme.textTheme.bodyMedium?.color,
      fontFeatures: features,
    );

    if (overrideFontFamily != null) {
      style = style.copyWith(fontFamily: overrideFontFamily);
    } else if (variant == PremiumAmountVariant.table) {
      style = GoogleFonts.robotoMono(
        textStyle: style,
      );
    }

    return Text(
      formatted,
      style: style,
    );
  }
}
