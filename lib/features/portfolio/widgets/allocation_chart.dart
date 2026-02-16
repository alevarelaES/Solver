import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class AllocationChart extends StatelessWidget {
  final List<Holding> holdings;

  const AllocationChart({super.key, required this.holdings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final allocations = _computeAllocations();
    if (allocations.isEmpty) {
      return AppPanel(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Aucune position',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALLOCATION',
            style: TextStyle(
              color: textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSizes.donutSize,
            child: Row(
              children: [
                SizedBox(
                  width: AppSizes.donutSize,
                  height: AppSizes.donutSize,
                  child: PieChart(
                    PieChartData(
                      sections: allocations
                          .map(
                            (a) => PieChartSectionData(
                              value: a.percent,
                              color: a.color,
                              radius: AppSizes.donutRingWidth,
                              showTitle: false,
                            ),
                          )
                          .toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: AppSizes.donutCutout,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: allocations
                        .take(6)
                        .map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: a.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    a.symbol,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${a.percent.toStringAsFixed(1)}%',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_Allocation> _computeAllocations() {
    final withValue =
        holdings.where((h) => h.totalValue != null && h.totalValue! > 0);
    final totalValue = withValue.fold<double>(0, (s, h) => s + h.totalValue!);
    if (totalValue <= 0) return [];

    final sorted = withValue.toList()
      ..sort((a, b) => (b.totalValue ?? 0).compareTo(a.totalValue ?? 0));

    return sorted.asMap().entries.map((entry) {
      final h = entry.value;
      final colorIndex = entry.key % AppColors.chartColors.length;
      return _Allocation(
        symbol: h.symbol,
        percent: (h.totalValue! / totalValue) * 100,
        color: AppColors.chartColors[colorIndex],
      );
    }).toList();
  }
}

class _Allocation {
  final String symbol;
  final double percent;
  final Color color;

  const _Allocation({
    required this.symbol,
    required this.percent,
    required this.color,
  });
}
