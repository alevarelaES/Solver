import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/portfolio/models/time_series_point.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

enum PriceChartPeriod {
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  max,
}

extension PriceChartPeriodX on PriceChartPeriod {
  String get label => switch (this) {
    PriceChartPeriod.oneWeek => '1S',
    PriceChartPeriod.oneMonth => '1M',
    PriceChartPeriod.threeMonths => '3M',
    PriceChartPeriod.sixMonths => '6M',
    PriceChartPeriod.oneYear => '1A',
    PriceChartPeriod.max => 'MAX',
  };

  String get interval => switch (this) {
    PriceChartPeriod.oneWeek => '1h',
    PriceChartPeriod.oneMonth => '1day',
    PriceChartPeriod.threeMonths => '1day',
    PriceChartPeriod.sixMonths => '1day',
    PriceChartPeriod.oneYear => '1week',
    PriceChartPeriod.max => '1month',
  };

  int get outputSize => switch (this) {
    PriceChartPeriod.oneWeek => 40,
    PriceChartPeriod.oneMonth => 22,
    PriceChartPeriod.threeMonths => 66,
    PriceChartPeriod.sixMonths => 132,
    PriceChartPeriod.oneYear => 52,
    PriceChartPeriod.max => 120,
  };
}

class PriceChart extends ConsumerWidget {
  final String symbol;
  final PriceChartPeriod period;
  final double height;

  const PriceChart({
    super.key,
    required this.symbol,
    required this.period,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      priceHistoryProvider(
        PriceHistoryRequest(
          symbol: symbol,
          interval: period.interval,
          outputSize: period.outputSize,
        ),
      ),
    );

    return historyAsync.when(
      loading: () => AppPanel(
        child: SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => AppPanel(
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              'Erreur graphique: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (points) {
        if (points.length < 2) {
          return AppPanel(
            child: SizedBox(
              height: height,
              child: const Center(child: Text('Pas assez de donnees.')),
            ),
          );
        }

        return _ChartBody(points: points, height: height);
      },
    );
  }
}

class _ChartBody extends StatelessWidget {
  final List<TimeSeriesPoint> points;
  final double height;

  const _ChartBody({required this.points, required this.height});

  @override
  Widget build(BuildContext context) {
    final first = points.first.close;
    final last = points.last.close;
    final isPositive = last >= first;
    final color = isPositive ? AppColors.success : AppColors.danger;

    final spots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.close))
        .toList();

    final minY = points.map((p) => p.close).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.close).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.08;

    return AppPanel(
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2.6,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.12),
                ),
              ),
            ],
            minY: minY - padding,
            maxY: maxY + padding,
            titlesData: const FlTitlesData(show: false),
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white12
                    : const Color(0xFFE5E7EB),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }
}
