import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
    PriceChartPeriod.oneWeek => '1day',
    PriceChartPeriod.oneMonth => '1day',
    PriceChartPeriod.threeMonths => '1day',
    PriceChartPeriod.sixMonths => '1day',
    PriceChartPeriod.oneYear => '1week',
    PriceChartPeriod.max => '1month',
  };

  int get outputSize => switch (this) {
    PriceChartPeriod.oneWeek => 7,
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
  final bool framed;

  const PriceChart({
    super.key,
    required this.symbol,
    required this.period,
    this.height = 220,
    this.framed = true,
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
      loading: () => _wrap(
        SizedBox(
          height: height,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _wrap(
        SizedBox(
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
          return _wrap(
            SizedBox(
              height: height,
              child: const Center(child: Text('Pas assez de donnees.')),
            ),
          );
        }

        return _wrap(_ChartBody(points: points, height: height));
      },
    );
  }

  Widget _wrap(Widget child) {
    if (!framed) return child;
    return AppPanel(child: child);
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
    final textSecondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final spots = points
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.close))
        .toList();

    final minY = points.map((p) => p.close).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.close).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range == 0 ? maxY.abs() * 0.02 : range * 0.08;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            horizontalInterval: range <= 0 ? 1 : range / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : const Color(0xFFE5E7EB),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: range <= 0 ? 1 : range / 4,
                getTitlesWidget: (value, _) => Text(
                  '\$${value.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, _) =>
                    _buildBottomTitle(value, textSecondary),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipBorder: BorderSide(color: color.withValues(alpha: 0.25)),
              getTooltipItems: (touchedSpots) => touchedSpots
                  .map(
                    (spot) => LineTooltipItem(
                      '\$${spot.y.toStringAsFixed(2)}',
                      GoogleFonts.robotoMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTitle(double value, Color textSecondary) {
    final index = value.round();
    if (index < 0 || index >= points.length) {
      return const SizedBox.shrink();
    }

    final last = points.length - 1;
    final middle = (last / 2).round();
    if (index != 0 && index != middle && index != last) {
      return const SizedBox.shrink();
    }

    final raw = points[index].datetime;
    final parsed = DateTime.tryParse(raw);
    final label = parsed == null ? '' : DateFormat('dd MMM').format(parsed);
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
