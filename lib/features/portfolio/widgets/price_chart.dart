import 'dart:math' as math;

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
  oneDay,
  oneWeek,
  oneMonth,
  threeMonths,
  sixMonths,
  oneYear,
  max,
}

extension PriceChartPeriodX on PriceChartPeriod {
  String get label => switch (this) {
    PriceChartPeriod.oneDay => '1J',
    PriceChartPeriod.oneWeek => '1S',
    PriceChartPeriod.oneMonth => '1M',
    PriceChartPeriod.threeMonths => '3M',
    PriceChartPeriod.sixMonths => '6M',
    PriceChartPeriod.oneYear => '1A',
    PriceChartPeriod.max => 'MAX',
  };

  String get interval => switch (this) {
    PriceChartPeriod.oneDay => '1h',
    PriceChartPeriod.oneWeek => '1day',
    PriceChartPeriod.oneMonth => '1day',
    PriceChartPeriod.threeMonths => '1day',
    PriceChartPeriod.sixMonths => '1day',
    PriceChartPeriod.oneYear => '1week',
    PriceChartPeriod.max => '1month',
  };

  int get outputSize => switch (this) {
    PriceChartPeriod.oneDay => 24,
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
        final ordered = points
            .where(
              (p) =>
                  p.close.isFinite &&
                  p.close > 0 &&
                  DateTime.tryParse(p.datetime) != null,
            )
            .toList();
        ordered.sort((a, b) {
          final da = DateTime.tryParse(a.datetime);
          final db = DateTime.tryParse(b.datetime);
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });

        if (ordered.length < 2) {
          return _wrap(_NoDataChartState(height: height));
        }

        return _wrap(
          _ChartBody(points: ordered, height: height, period: period),
        );
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
  final PriceChartPeriod period;

  const _ChartBody({
    required this.points,
    required this.height,
    required this.period,
  });

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
    final safeRange = range <= 0 ? 1.0 : range;
    final yInterval = _computeNiceInterval(safeRange / 3.5);
    final padding = safeRange * 0.08;
    final chartMinY = math.max(0.0, minY - padding).toDouble();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: chartMinY,
          maxY: maxY + padding,
          clipData: const FlClipData.all(),
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
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white12
                  : AppColors.borderLight,
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
                reservedSize: 70,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  final nearBottom =
                      (value - chartMinY).abs() < (yInterval * 0.4);
                  final nearTop =
                      (value - (maxY + padding)).abs() < (yInterval * 0.4);
                  if (nearBottom || nearTop) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Text(
                      _formatYAxisValue(value, yInterval),
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) =>
                    _buildBottomTitle(value, meta, textSecondary),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipBorder: BorderSide(color: color.withValues(alpha: 0.25)),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
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

  Widget _buildBottomTitle(double value, TitleMeta meta, Color textSecondary) {
    final index = value.round();
    if (index < 0 || index >= points.length) {
      return const SizedBox.shrink();
    }

    final last = points.length - 1;
    final markers = <int>{
      0,
      (last * 0.25).round(),
      (last * 0.5).round(),
      (last * 0.75).round(),
      last,
    };
    if (!markers.contains(index)) {
      return const SizedBox.shrink();
    }

    final raw = points[index].datetime;
    final parsed = DateTime.tryParse(raw);
    final label = parsed == null
        ? ''
        : (period == PriceChartPeriod.oneDay
              ? DateFormat('HH:mm').format(parsed.toLocal())
              : DateFormat('dd MMM').format(parsed));
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  double _computeNiceInterval(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalized = raw / magnitude;

    if (normalized <= 1) return 1 * magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 2.5) return 2.5 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }

  String _formatYAxisValue(double value, double interval) {
    if (interval >= 1) return '\$${value.toStringAsFixed(0)}';
    if (interval >= 0.1) return '\$${value.toStringAsFixed(1)}';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _NoDataChartState extends StatelessWidget {
  final double height;

  const _NoDataChartState({required this.height});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return SizedBox(
      height: height,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 26, color: secondary),
            const SizedBox(height: 6),
            Text(
              'Donnees de prix indisponibles pour cette periode.',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}
