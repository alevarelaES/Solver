part of 'analysis_view.dart';

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
      incomeSpots.add(FlSpot(i.toDouble(), AppFormats.fromChf(m.income)));
      expenseSpots.add(FlSpot(i.toDouble(), AppFormats.fromChf(m.expenses)));
    }

    // Calculate spread growth
    final totalSavings = data.totalIncome - data.totalExpenses;
    final spreadGrowth = data.totalIncome > 0
        ? (totalSavings / data.totalIncome * 100)
        : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.s28),
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
                      AppStrings.analysis.yoyChartTitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryDarker,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.analysis.yoyChartSubtitle,
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
                    label: AppStrings.analysis.netIncomeGrowth,
                    isDashed: false,
                  ),
                  const SizedBox(width: 16),
                  _ChartLegendItem(
                    color: AppColors.danger,
                    label: AppStrings.analysis.expenseTrend,
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
                            : AppColors.surfaceHeader,
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
                            '${isIncome ? AppStrings.analysis.incomeLabel : AppStrings.analysis.expenseLabel}\n${AppFormats.currencySymbol} ${AppFormats.currencyRaw.format(spot.y)}',
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
                      AppStrings.analysis.spreadGrowthBadge(spreadGrowth.toStringAsFixed(0)),
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

