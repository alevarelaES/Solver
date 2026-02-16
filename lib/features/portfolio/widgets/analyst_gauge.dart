import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/analyst_recommendation.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class AnalystGauge extends StatelessWidget {
  final AnalystRecommendation recommendation;

  const AnalystGauge({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final total = recommendation.total;
    final buy = recommendation.buy + recommendation.strongBuy;
    final hold = recommendation.hold;
    final sell = recommendation.sell + recommendation.strongSell;

    final buyRatio = total == 0 ? 0.0 : buy / total;
    final holdRatio = total == 0 ? 0.0 : hold / total;
    final sellRatio = total == 0 ? 0.0 : sell / total;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consensus analystes (${recommendation.period})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            child: Row(
              children: [
                _GaugeBlock(
                  flex: (buyRatio * 1000).round(),
                  color: AppColors.success,
                ),
                _GaugeBlock(
                  flex: (holdRatio * 1000).round(),
                  color: AppColors.warning,
                ),
                _GaugeBlock(
                  flex: (sellRatio * 1000).round(),
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Buy: $buy   Hold: $hold   Sell: $sell (Total: $total)'),
        ],
      ),
    );
  }
}

class _GaugeBlock extends StatelessWidget {
  final int flex;
  final Color color;

  const _GaugeBlock({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) {
    final safeFlex = flex <= 0 ? 1 : flex;
    return Expanded(
      flex: safeFlex,
      child: Container(height: 14, color: color),
    );
  }
}
