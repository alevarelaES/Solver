part of 'analysis_view.dart';

class _ProjectedSavingsCard extends StatelessWidget {
  final AnalysisData data;
  const _ProjectedSavingsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthlySavings = data.byMonth.isNotEmpty
        ? data.byMonth.map((m) => m.savings).reduce((a, b) => a + b) /
              data.byMonth.length
        : 0.0;
    final projectedTotal = monthlySavings * 60; // 5 years projection
    final progressVal = projectedTotal > 0
        ? (projectedTotal / 245000).clamp(0.0, 1.0)
        : 0.0;
    final roi = data.totalIncome > 0
        ? ((data.totalIncome - data.totalExpenses) / data.totalIncome * 100)
        : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.s28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.analysis.projectedSavingsTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Progress bar section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.r20),
                ),
                child: Text(
                  AppStrings.analysis.aggressiveStrategy,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Text(
                '${AppFormats.currencyRaw.format(projectedTotal)} ${AppFormats.currencySymbol}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white12
                  : AppColors.surfaceHeader,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 2-col stats
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.analysis.monthlyYield,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '+${AppFormats.formatFromChf(monthlySavings)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.analysis.projectedRoi,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${roi.toStringAsFixed(1)}% p.a.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : AppColors.primaryDarker,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compound effect note
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.surfaceHeader,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppRadius.r16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_graph,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.analysis.compoundEffect,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : AppColors.primaryDarker,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.analysis.compoundNote(AppFormats.currencyRaw.format(projectedTotal * 0.17)),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerComparisonCard extends StatelessWidget {
  final AnalysisData data;
  const _PeerComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build comparison items from expense groups or use static fallbacks
    final items = data.byGroup.isNotEmpty
        ? data.byGroup.take(3).toList()
        : <GroupExpense>[];

    // Comparison data: map real groups or use centralized fallback catalog
    final comparisons = items.isNotEmpty
        ? items.asMap().entries.map((e) {
            final g = e.value;
            final icons = [Icons.restaurant, Icons.commute, Icons.bolt];
            final bgColors = [Colors.blue, Colors.orange, AppColors.primary];
            final idx = e.key % 3;
            final isOptimal = g.percentage < 35;
            return _PeerItem(
              icon: icons[idx],
              iconBg: bgColors[idx].withValues(alpha: 0.1),
              iconColor: bgColors[idx],
              title: g.group,
              subtitle: AppStrings.analysis.vsMedianPeers(
                  AppFormats.currencyRaw.format(g.total * 0.85)),
              percent: isOptimal
                  ? '-${(100 - g.percentage).toStringAsFixed(1)}%'
                  : '+${(g.percentage - 25).toStringAsFixed(1)}%',
              isOptimal: isOptimal,
              barValue: g.percentage / 100,
            );
          }).toList()
        : analysisPeerFallbackItems
              .asMap()
              .entries
              .map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final icons = [Icons.restaurant, Icons.commute, Icons.bolt];
                final colors = [Colors.blue, Colors.orange, AppColors.primary];
                final icon = icons[idx % icons.length];
                final color = colors[idx % colors.length];
                return _PeerItem(
                  icon: icon,
                  iconBg: color.withValues(alpha: 0.1),
                  iconColor: color,
                  title: item.title,
                  subtitle: item.subtitle,
                  percent: item.percent,
                  isOptimal: item.isOptimal,
                  barValue: item.barValue,
                );
              })
              .toList(growable: false);

    // Efficiency score from savings rate
    final efficiency = data.savingsRate > 0
        ? (data.savingsRate * 1.5).clamp(0, 100).toInt()
        : 88;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.s28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.analysis.peerComparisonTitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.surfaceHeader,
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Text(
                  AppStrings.analysis.topSegment,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textDisabledDark
                        : AppColors.textDisabledLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Comparison items
          ...comparisons.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: _PeerComparisonRow(item: item),
            ),
          ),

          // Footer: Efficiency Index
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.borderDark
                      : AppColors.surfaceHeader,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.analysis.efficiencyScore,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '$efficiency/100',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String percent;
  final bool isOptimal;
  final double barValue;

  const _PeerItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.isOptimal,
    required this.barValue,
  });
}

class _PeerComparisonRow extends StatelessWidget {
  final _PeerItem item;
  const _PeerComparisonRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = item.isOptimal ? AppColors.primary : AppColors.danger;

    return Row(
      children: [
        // Icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: item.iconBg,
            borderRadius: BorderRadius.circular(AppRadius.r12),
          ),
          child: Icon(item.icon, color: item.iconColor, size: 20),
        ),
        const SizedBox(width: 16),

        // Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryDarker,
                ),
              ),
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),

        // Percent + bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${item.percent} ${item.isOptimal ? AppStrings.analysis.peerOptimal : AppStrings.analysis.peerAbove}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.r4),
                child: LinearProgressIndicator(
                  value: item.barValue.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: isDark
                      ? Colors.white12
                      : AppColors.surfaceHeader,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
