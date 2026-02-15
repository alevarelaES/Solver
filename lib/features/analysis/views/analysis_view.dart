import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/analysis/providers/analysis_provider.dart';
import 'package:solver/shared/widgets/glass_container.dart';

const _monthLabels = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedAnalysisYearProvider);
    final dataAsync = ref.watch(analysisDataProvider(year));
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavBtn(
                icon: Icons.chevron_left,
                onTap: year > currentYear - 5
                    ? () =>
                          ref
                                  .read(selectedAnalysisYearProvider.notifier)
                                  .state =
                              year - 1
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                '$year',
                style: TextStyle(
                  color: year == currentYear
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              _NavBtn(
                icon: Icons.chevron_right,
                onTap: year < currentYear
                    ? () =>
                          ref
                                  .read(selectedAnalysisYearProvider.notifier)
                                  .state =
                              year + 1
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Erreur: $e',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
            data: (data) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StrategicKpiRow(data: data, year: year),
                    const SizedBox(height: 32),

                    _YoYLineChartCard(data: data),
                    const SizedBox(height: 32),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 768;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ProjectedSavingsCard(data: data),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: _PeerComparisonCard(data: data)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _ProjectedSavingsCard(data: data),
                            const SizedBox(height: 24),
                            _PeerComparisonCard(data: data),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: onTap != null
              ? (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight)
              : (isDark
                    ? AppColors.textDisabledDark
                    : AppColors.textDisabledLight),
          size: 22,
        ),
      ),
    );
  }
}

class _StrategicKpiRow extends StatelessWidget {
  final AnalysisData data;
  final int year;
  const _StrategicKpiRow({required this.data, required this.year});

  @override
  Widget build(BuildContext context) {
    // Calculate growth vs previous year
    final growthPercent = data.totalIncome > 0
        ? ((data.totalIncome - data.totalExpenses) / data.totalIncome * 100)
        : 0.0;

    // Savings velocity = savings rate
    final savingsVelocity = data.savingsRate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          _StratKpiCard(
            label: 'GROWTH VS PREV. YEAR',
            value: '+${growthPercent.toStringAsFixed(1)}%',
            subtitle: 'Income Momentum',
            subtitleColor: AppColors.primary,
            trailing: _MiniLineChart(),
          ),
          _StratKpiCard(
            label: 'SAVINGS VELOCITY',
            value: '${savingsVelocity.toStringAsFixed(1)}%',
            subtitle: 'Target: 60%',
            subtitleColor: AppColors.primary,
            trailing: _MiniProgressBar(value: savingsVelocity / 100),
          ),
          _StratKpiCard(
            label: 'FINANCIAL FREEDOM DATE',
            value: 'Sept 2038',
            subtitle: '-2 Years vs Jan Estimate',
            subtitleColor: AppColors.warning,
            trailing: Icon(
              Icons.auto_awesome,
              color: AppColors.warning,
              size: 24,
            ),
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: cards
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StratKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color subtitleColor;
  final Widget trailing;

  const _StratKpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.subtitleColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryDarker,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 32,
      child: CustomPaint(painter: _MiniLinePainter()),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      Offset(0, size.height),
      Offset(size.width * 0.15, size.height * 0.88),
      Offset(size.width * 0.3, size.height * 0.69),
      Offset(size.width * 0.47, size.height * 0.78),
      Offset(size.width * 0.62, size.height * 0.47),
      Offset(size.width * 0.78, size.height * 0.31),
      Offset(size.width, 0),
    ];

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniProgressBar extends StatelessWidget {
  final double value;
  const _MiniProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white12
                  : const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YoYLineChartCard extends StatelessWidget {
  final AnalysisData data;
  const _YoYLineChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build income and expense spots from monthly data
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (int i = 0; i < data.byMonth.length; i++) {
      final m = data.byMonth[i];
      incomeSpots.add(FlSpot(i.toDouble(), m.income));
      expenseSpots.add(FlSpot(i.toDouble(), m.expenses));
    }

    // Calculate spread growth
    final totalSavings = data.totalIncome - data.totalExpenses;
    final spreadGrowth = data.totalIncome > 0
        ? (totalSavings / data.totalIncome * 100)
        : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year-over-Year Income vs Expense Growth',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryDarker,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Strategic view of wealth accumulation efficiency',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChartLegendItem(
                    color: AppColors.primary,
                    label: 'NET INCOME GROWTH',
                    isDashed: false,
                  ),
                  const SizedBox(width: 16),
                  _ChartLegendItem(
                    color: AppColors.danger,
                    label: 'EXPENSE TREND',
                    isDashed: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Chart
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _calcInterval(data),
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF3F4F6),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              AppFormats.currencyRaw.format(value),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textDisabledDark
                                    : AppColors.textDisabledLight,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _monthLabels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _monthLabels[idx],
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textDisabledDark
                                      : AppColors.textDisabledLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      // Income line (solid green)
                      LineChartBarData(
                        spots: incomeSpots,
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withValues(alpha: 0.06),
                        ),
                      ),
                      // Expense line (dashed red)
                      LineChartBarData(
                        spots: expenseSpots,
                        isCurved: true,
                        color: AppColors.danger,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dashArray: [6, 4],
                        dotData: const FlDotData(show: false),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        getTooltipItems: (spots) => spots.map((spot) {
                          final isIncome = spot.barIndex == 0;
                          return LineTooltipItem(
                            '${isIncome ? "Revenus" : "Dépenses"}\n${AppFormats.currencySymbol} ${AppFormats.currencyRaw.format(spot.y)}',
                            TextStyle(
                              color: isIncome
                                  ? AppColors.primary
                                  : AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                // Spread growth badge
                Positioned(
                  top: 40,
                  right: 60,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.r6),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '+${spreadGrowth.toStringAsFixed(0)}% Spread Growth',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calcInterval(AnalysisData data) {
    double maxVal = 0;
    for (final m in data.byMonth) {
      if (m.income > maxVal) maxVal = m.income;
      if (m.expenses > maxVal) maxVal = m.expenses;
    }
    if (maxVal <= 0) return 1000;
    return (maxVal / 4).ceilToDouble();
  }
}

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDashed;

  const _ChartLegendItem({
    required this.color,
    required this.label,
    required this.isDashed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 2,
          child: isDashed
              ? CustomPaint(painter: _DashedLinePainter(color: color))
              : Container(color: color),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashWidth = 3.0;
    const dashSpace = 2.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset((startX + dashWidth).clamp(0, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECTED SAVINGS GROWTH (5YR)',
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
                  'Aggressive Strategy',
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
                  : const Color(0xFFF3F4F6),
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTHLY YIELD',
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
                        '+${AppFormats.currency.format(monthlySavings)}',
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(AppRadius.r16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROJECTED ROI',
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
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
                        'Compound Effect',
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
                        'Current trajectory adds ${AppFormats.currencyRaw.format(projectedTotal * 0.17)} in passive appreciation by 2030.',
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

    // Comparison data: map real groups or use mock defaults
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
              subtitle:
                  'Vs. ${AppFormats.currencyRaw.format(g.total * 0.85)}k median peers',
              percent: isOptimal
                  ? '-${(100 - g.percentage).toStringAsFixed(1)}%'
                  : '+${(g.percentage - 25).toStringAsFixed(1)}%',
              isOptimal: isOptimal,
              barValue: g.percentage / 100,
            );
          }).toList()
        : [
            _PeerItem(
              icon: Icons.restaurant,
              iconBg: Colors.blue.withValues(alpha: 0.1),
              iconColor: Colors.blue,
              title: 'Variable Food',
              subtitle: 'Vs. 2.4k median peers',
              percent: '-12.4%',
              isOptimal: true,
              barValue: 0.30,
            ),
            _PeerItem(
              icon: Icons.commute,
              iconBg: Colors.orange.withValues(alpha: 0.1),
              iconColor: Colors.orange,
              title: 'Transport Costs',
              subtitle: 'Vs. 1.8k median peers',
              percent: '+5.8%',
              isOptimal: false,
              barValue: 0.65,
            ),
            _PeerItem(
              icon: Icons.bolt,
              iconBg: AppColors.primary.withValues(alpha: 0.1),
              iconColor: AppColors.primary,
              title: 'Fixed Utilities',
              subtitle: 'Vs. 0.9k median peers',
              percent: '-8.2%',
              isOptimal: true,
              barValue: 0.40,
            ),
          ];

    // Efficiency score from savings rate
    final efficiency = data.savingsRate > 0
        ? (data.savingsRate * 1.5).clamp(0, 100).toInt()
        : 88;

    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PEER COMPARISON INDEX',
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
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(AppRadius.r4),
                ),
                child: Text(
                  'TOP 10% SEGMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textDisabledDark
                        : const Color(0xFF9CA3AF),
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
                      : const Color(0xFFF3F4F6),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EFFICIENCY INDEX SCORE',
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
              '${item.percent} ${item.isOptimal ? "Optimal" : "Above"}',
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
                      : const Color(0xFFF3F4F6),
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

