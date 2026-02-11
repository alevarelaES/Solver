import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/analysis/providers/analysis_provider.dart';
import 'package:solver/shared/widgets/kpi_card.dart';

const _monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedAnalysisYearProvider);
    final dataAsync = ref.watch(analysisDataProvider(year));
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        // ── Year nav ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavBtn(
                icon: Icons.chevron_left,
                onTap: year > currentYear - 5
                    ? () => ref.read(selectedAnalysisYearProvider.notifier).state = year - 1
                    : null,
              ),
              const SizedBox(width: 16),
              Text('$year',
                  style: TextStyle(
                    color: year == currentYear
                        ? AppColors.electricBlue
                        : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(width: 16),
              _NavBtn(
                icon: Icons.chevron_right,
                onTap: year < currentYear
                    ? () => ref.read(selectedAnalysisYearProvider.notifier).state = year + 1
                    : null,
              ),
            ],
          ),
        ),
        // ── Content ─────────────────────────────────────────────────────
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('Erreur: $e', style: const TextStyle(color: AppColors.softRed)),
            ),
            data: (data) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiRow(data: data),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Revenus vs Dépenses'),
                  const SizedBox(height: 12),
                  _BarChartCard(data: data),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: 'Répartition des dépenses'),
                  const SizedBox(height: 12),
                  _PieChartCard(data: data),
                  const SizedBox(height: 80),
                ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            color: onTap != null ? AppColors.textPrimary : AppColors.textDisabled,
            size: 22),
      ),
    );
  }
}

// ─── KPI row ──────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final AnalysisData data;
  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final savingsColor = data.savingsRate >= 0 ? AppColors.neonEmerald : AppColors.softRed;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final cards = [
          KpiCard(
            label: 'Total Revenus',
            amount: data.totalIncome,
            color: AppColors.neonEmerald,
            icon: Icons.trending_up,
          ),
          KpiCard(
            label: 'Total Dépenses',
            amount: data.totalExpenses,
            color: AppColors.softRed,
            icon: Icons.trending_down,
          ),
          KpiCard(
            label: 'Taux d\'Épargne',
            amount: data.savingsRate,
            color: savingsColor,
            icon: Icons.savings_outlined,
            isCurrency: false,
            suffix: '%',
          ),
        ];

        if (isNarrow) {
          return Column(
            children: cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: c,
            )).toList(),
          );
        }

        return Row(
          children: cards
              .map((c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: c,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: AppTextStyles.sectionHeader);
  }
}

// ─── Bar chart ────────────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final AnalysisData data;
  const _BarChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final groups = data.byMonth.map((m) {
      return BarChartGroupData(
        x: m.month - 1,
        barRods: [
          BarChartRodData(
            toY: m.income,
            color: AppColors.neonEmerald.withAlpha(200),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
          ),
          BarChartRodData(
            toY: m.expenses,
            color: AppColors.softRed.withAlpha(200),
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
          ),
        ],
        barsSpace: 2,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                barGroups: groups,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.borderSubtle,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) => Text(
                        AppFormats.currencyRaw.format(value),
                        style: const TextStyle(color: AppColors.textDisabled, fontSize: 9),
                      ),
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _monthLabels[value.toInt()],
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
                      '${rodIndex == 0 ? "Rev" : "Dép"}\nCHF ${AppFormats.currencyRaw.format(rod.toY)}',
                      TextStyle(
                        color: rodIndex == 0
                            ? AppColors.neonEmerald
                            : AppColors.softRed,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.neonEmerald, label: 'Revenus'),
              const SizedBox(width: 20),
              _Legend(color: AppColors.softRed, label: 'Dépenses'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pie chart ────────────────────────────────────────────────────────────────
class _PieChartCard extends StatefulWidget {
  final AnalysisData data;
  const _PieChartCard({required this.data});

  @override
  State<_PieChartCard> createState() => _PieChartCardState();
}

class _PieChartCardState extends State<_PieChartCard> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.byGroup.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: Text('Aucune dépense cette année',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final sections = widget.data.byGroup.asMap().entries.map((e) {
      final i = e.key;
      final g = e.value;
      final isTouched = i == _touched;
      return PieChartSectionData(
        value: g.total,
        color: AppColors.chartColors[i % AppColors.chartColors.length],
        radius: isTouched ? 70 : 56,
        title: '${g.percentage.toStringAsFixed(0)}%',
        titleStyle: TextStyle(
          color: Colors.white,
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          final chart = SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 44,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          );

          final legend = Wrap(
            spacing: 12,
            runSpacing: 8,
            children: widget.data.byGroup.asMap().entries.map((e) {
              final i = e.key;
              final g = e.value;
              return _Legend(
                color: AppColors.chartColors[i % AppColors.chartColors.length],
                label: '${g.group} (CHF ${AppFormats.currencyRaw.format(g.total)})',
              );
            }).toList(),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                chart,
                const SizedBox(width: 24),
                Expanded(child: legend),
              ],
            );
          }

          return Column(
            children: [
              chart,
              const SizedBox(height: 16),
              legend,
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }
}
