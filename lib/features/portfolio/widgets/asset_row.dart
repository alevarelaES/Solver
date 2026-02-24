import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/features/portfolio/widgets/mini_sparkline.dart';

class AssetRow extends ConsumerWidget {
  final String symbol;
  final String? name;
  final String assetType;
  final String? logoUrl;
  final double? price;
  final String currency;
  final double? changePercent;
  final List<double>? sparklineData;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? trailing;
  final Widget? trailingWidget;

  const AssetRow({
    super.key,
    required this.symbol,
    this.name,
    this.assetType = 'stock',
    this.logoUrl,
    this.price,
    this.currency = 'USD',
    this.changePercent,
    this.sparklineData,
    this.isSelected = false,
    this.onTap,
    this.trailing,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final hasChange = changePercent != null;
    final pct = changePercent ?? 0;
    final isPositive = pct >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.danger;

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            border: isSelected
                ? Border(left: BorderSide(color: AppColors.primary, width: 2))
                : null,
          ),
          child: Row(
            children: [
              // Symbol circle
              AssetLogo(
                symbol: symbol,
                assetType: assetType,
                logoUrl: logoUrl,
                size: 28,
                borderRadius: 999,
              ),
              const SizedBox(width: AppSpacing.sm),

              // Symbol + name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (name != null && name!.isNotEmpty)
                      Text(
                        name!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: textSecondary),
                      ),
                  ],
                ),
              ),

              // Sparkline
              MiniSparkline(
                prices: sparklineData,
                changePercent: changePercent,
                width: 44,
                height: 16,
              ),
              const SizedBox(width: AppSpacing.sm),

              // Price + change
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppFormats.formatFromCurrency(price, currency),
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: (hasChange ? changeColor : textSecondary)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      hasChange
                          ? '${isPositive ? '+' : ''}${pct.toStringAsFixed(2)}%'
                          : '--',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: hasChange ? changeColor : textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  trailing!,
                  style: TextStyle(fontSize: 10, color: textSecondary),
                ),
              ],
              if (trailingWidget != null) ...[
                const SizedBox(width: AppSpacing.xs),
                trailingWidget!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
