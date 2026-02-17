import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/features/portfolio/models/trending_stock.dart';
import 'package:solver/features/portfolio/widgets/mini_sparkline.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class TrendingCard extends StatelessWidget {
  final TrendingStock stock;
  final List<double>? sparklineData;
  final VoidCallback? onTap;

  const TrendingCard({
    super.key,
    required this.stock,
    this.sparklineData,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final hasChange = stock.changePercent != null;
    final pct = stock.changePercent ?? 0;
    final isPositive = pct >= 0;
    final changeColor = isPositive ? AppColors.success : AppColors.danger;

    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      variant: AppPanelVariant.elevated,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetLogo(
                symbol: stock.symbol,
                assetType: stock.assetType,
                size: 30,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.symbol,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      stock.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  stock.price != null
                      ? '\$${stock.price!.toStringAsFixed(2)}'
                      : '--',
                  style: GoogleFonts.robotoMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (hasChange ? changeColor : textSecondary).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  hasChange
                      ? '${isPositive ? '+' : ''}${pct.toStringAsFixed(2)}%'
                      : '--',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasChange ? changeColor : textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          MiniSparkline(
            prices: sparklineData,
            changePercent: stock.changePercent,
            width: double.infinity,
            height: 24,
          ),
        ],
      ),
    );
  }
}
