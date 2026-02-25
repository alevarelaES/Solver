import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/time_series_point.dart';
import 'package:solver/features/portfolio/providers/price_history_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';

// ─── Period enum ──────────────────────────────────────────────────────────────

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
    PriceChartPeriod.max => 5000,
  };
}

// ─── Period selector — Google Finance tab style ───────────────────────────────

class PriceChartPeriodBar extends StatelessWidget {
  final PriceChartPeriod selected;
  final ValueChanged<PriceChartPeriod> onChanged;

  const PriceChartPeriodBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    const activeColor = AppColors.primary;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: PriceChartPeriod.values.map((period) {
          final isSelected = period == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(period),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    period.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    width: isSelected ? 18.0 : 0.0,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Main chart widget ────────────────────────────────────────────────────────

class PriceChart extends ConsumerWidget {
  final String symbol;
  final PriceChartPeriod period;
  final double height;
  final bool framed;
  final String currencyCode;

  const PriceChart({
    super.key,
    required this.symbol,
    required this.period,
    this.height = 220,
    this.framed = true,
    this.currencyCode = 'USD',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider); // rebuild when display currency changes
    final displayCurrencyCode = AppFormats.currencyCode;
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
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
            .toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a.datetime);
            final db = DateTime.tryParse(b.datetime);
            if (da == null || db == null) return 0;
            return da.compareTo(db);
          });

        if (ordered.length < 2) {
          return _wrap(_NoDataChart(height: height));
        }

        return _wrap(
          _ChartBody(
            points: ordered,
            height: height,
            period: period,
            nativeCurrencyCode: currencyCode,
            displayCurrencyCode: displayCurrencyCode,
          ),
        );
      },
    );
  }

  Widget _wrap(Widget child) {
    if (!framed) return child;
    return AppPanel(child: child);
  }
}

// ─── Stateful chart body with hover ──────────────────────────────────────────

class _ChartBody extends StatefulWidget {
  final List<TimeSeriesPoint> points;
  final double height;
  final PriceChartPeriod period;
  final String nativeCurrencyCode;
  final String displayCurrencyCode;

  const _ChartBody({
    required this.points,
    required this.height,
    required this.period,
    this.nativeCurrencyCode = 'USD',
    this.displayCurrencyCode = 'USD',
  });

  @override
  State<_ChartBody> createState() => _ChartBodyState();
}

class _ChartBodyState extends State<_ChartBody> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final points = widget.points;
    final period = widget.period;
    final native = widget.nativeCurrencyCode;
    final display = widget.displayCurrencyCode;

    // Convert all close values to the display currency once.
    final closes = (native.toUpperCase() == display.toUpperCase())
        ? points.map((p) => p.close).toList(growable: false)
        : points
              .map((p) => AppFormats.convertFromCurrency(p.close, native))
              .toList(growable: false);

    final first = closes.first;
    final last = closes.last;
    final isPositive = last >= first;
    final color = isPositive ? AppColors.success : AppColors.danger;

    final spots = List.generate(
      closes.length,
      (i) => FlSpot(i.toDouble(), closes[i]),
      growable: false,
    );

    final minY = closes.reduce(math.min);
    final maxY = closes.reduce(math.max);
    final safeRange = (maxY - minY).abs().clamp(1.0, double.infinity);
    final yInterval = _niceInterval(safeRange / 3.5);
    final padding = safeRange * 0.08;
    final chartMinY = math.max(0.0, minY - padding);

    // Header: show hovered or latest value
    final displayIdx = (_touchedIndex ?? (points.length - 1)).clamp(
      0,
      points.length - 1,
    );
    final displayPoint = points[displayIdx];
    final displayDate = DateTime.tryParse(displayPoint.datetime)?.toLocal();

    final labelIndices = _labelIndices(points.length);

    return SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Price + date header ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatPrice(closes[displayIdx], display),
                style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              if (displayDate != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatHeaderDate(displayDate, period),
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // ── Line chart ──────────────────────────────────────────────────────
          Expanded(
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
                    curveSmoothness: 0.3,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.18),
                          color.withValues(alpha: 0.0),
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
                    color: isDark ? Colors.white10 : AppColors.borderLight,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 72,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        final nearBottom =
                            (value - chartMinY).abs() < (yInterval * 0.4);
                        final nearTop =
                            (value - (maxY + padding)).abs() <
                            (yInterval * 0.4);
                        if (nearBottom || nearTop) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            _formatYLabel(
                              value,
                              yInterval,
                              display,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        if (index < 0 || index >= points.length) {
                          return const SizedBox.shrink();
                        }
                        if (!labelIndices.contains(index)) {
                          return const SizedBox.shrink();
                        }
                        final parsed = DateTime.tryParse(
                          points[index].datetime,
                        );
                        if (parsed == null) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 6,
                          child: Text(
                            _formatXAxisLabel(parsed.toLocal(), period),
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (!mounted) return;
                    final spot = response?.lineBarSpots?.firstOrNull;
                    if (event is FlPanEndEvent ||
                        event is FlPointerExitEvent ||
                        event is FlTapUpEvent) {
                      setState(() => _touchedIndex = null);
                    } else if (spot != null) {
                      final idx = spot.x.round();
                      if (_touchedIndex != idx) {
                        setState(() => _touchedIndex = idx);
                      }
                    }
                  },
                  getTouchedSpotIndicator: (barData, spotIndexes) =>
                      spotIndexes.map((_) {
                        return TouchedSpotIndicatorData(
                          FlLine(
                            color: textSecondary.withValues(alpha: 0.45),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                          FlDotData(
                            getDotPainter: (p, pct, bar, idx) =>
                                FlDotCirclePainter(
                                  radius: 4,
                                  color: color,
                                  strokeWidth: 2,
                                  strokeColor: isDark
                                      ? const Color(0xFF1E1E2E)
                                      : Colors.white,
                                ),
                          ),
                        );
                      }).toList(),
                  touchTooltipData: LineTouchTooltipData(
                    // Transparent tooltip — data shown in the header instead.
                    getTooltipColor: (_) => Colors.transparent,
                    tooltipBorder: BorderSide.none,
                    getTooltipItems: (spots) =>
                        spots
                            .map((_) => const LineTooltipItem('', TextStyle()))
                            .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Label helpers ──────────────────────────────────────────────────────────

  Set<int> _labelIndices(int total) {
    if (total <= 1) return {0};
    const count = 5;
    final result = <int>{};
    final step = (total - 1) / (count - 1);
    for (int i = 0; i < count; i++) {
      result.add((i * step).round().clamp(0, total - 1));
    }
    return result;
  }

  String _formatXAxisLabel(DateTime dt, PriceChartPeriod period) {
    return switch (period) {
      PriceChartPeriod.oneDay => DateFormat('HH:mm').format(dt),
      PriceChartPeriod.oneWeek => DateFormat('EEE d').format(dt),
      PriceChartPeriod.oneMonth => DateFormat('d MMM').format(dt),
      PriceChartPeriod.threeMonths => DateFormat('d MMM').format(dt),
      PriceChartPeriod.sixMonths => DateFormat('MMM').format(dt),
      PriceChartPeriod.oneYear => DateFormat("MMM ''yy").format(dt),
      PriceChartPeriod.max => DateFormat('yyyy').format(dt),
    };
  }

  String _formatHeaderDate(DateTime dt, PriceChartPeriod period) {
    return switch (period) {
      PriceChartPeriod.oneDay => DateFormat('d MMM, HH:mm').format(dt),
      PriceChartPeriod.oneWeek ||
      PriceChartPeriod.oneMonth ||
      PriceChartPeriod.threeMonths =>
        DateFormat('d MMM yyyy').format(dt),
      PriceChartPeriod.sixMonths ||
      PriceChartPeriod.oneYear ||
      PriceChartPeriod.max =>
        DateFormat('MMM yyyy').format(dt),
    };
  }

  // ── Price formatting ───────────────────────────────────────────────────────

  static String _formatPrice(double value, String currency) {
    final prefix = _currencyPrefix(currency);
    if (value >= 10000) {
      return '$prefix${NumberFormat('#,##0').format(value)}';
    }
    if (value >= 100) {
      return '$prefix${NumberFormat('#,##0.00').format(value)}';
    }
    if (value >= 1) return '$prefix${value.toStringAsFixed(4)}';
    return '$prefix${value.toStringAsFixed(6)}';
  }

  static String _formatYLabel(double value, double interval, String currency) {
    final prefix = _currencyPrefix(currency);
    if (value >= 1000000) {
      return '$prefix${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '$prefix${NumberFormat('#,##0').format(value)}';
    if (interval >= 1) return '$prefix${value.toStringAsFixed(0)}';
    if (interval >= 0.1) return '$prefix${value.toStringAsFixed(1)}';
    return '$prefix${value.toStringAsFixed(2)}';
  }

  static String _currencyPrefix(String code) {
    return switch (code.toUpperCase()) {
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'JPY' => '¥',
      'CAD' => 'CA\$',
      'AUD' => 'A\$',
      'CHF' => 'CHF\u00A0',
      _ => '${code.toUpperCase()}\u00A0',
    };
  }

  static double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final magnitude =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    if (normalized <= 1) return 1 * magnitude;
    if (normalized <= 2) return 2 * magnitude;
    if (normalized <= 2.5) return 2.5 * magnitude;
    if (normalized <= 5) return 5 * magnitude;
    return 10 * magnitude;
  }
}

// ─── No data placeholder ──────────────────────────────────────────────────────

class _NoDataChart extends StatelessWidget {
  final double height;

  const _NoDataChart({required this.height});

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
              'Données de prix indisponibles pour cette période.',
              style: TextStyle(fontSize: 12, color: secondary),
            ),
          ],
        ),
      ),
    );
  }
}
