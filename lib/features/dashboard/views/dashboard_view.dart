import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/widgets/account_form_modal.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';
import 'package:solver/features/transactions/widgets/transactions_list_modal.dart';
import 'package:solver/shared/widgets/glass_container.dart';

// ─── Month labels ─────────────────────────────────────────────────────────────
const _months = [
  'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
  'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
];

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider(year));

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur de chargement\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) => _DashboardContent(data: data, year: year, ref: ref),
    );
  }
}

// ─── Main content ────────────────────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final int year;
  final WidgetRef ref;

  const _DashboardContent({
    required this.data,
    required this.year,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1024;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Year nav + greeting ───────────────────────────────────
              _YearNavBar(year: year, ref: ref),
              const SizedBox(height: 24),

              if (isWide)
                // ── Desktop: 2-column layout ────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column (balance + donut + accounts)
                    SizedBox(
                      width: 340,
                      child: _LeftColumn(data: data, ref: ref),
                    ),
                    const SizedBox(width: 24),
                    // Right column (KPIs + chart + activities)
                    Expanded(
                      child: _RightColumn(data: data, year: year, ref: ref),
                    ),
                  ],
                )
              else
                // ── Mobile/Tablet: stacked ──────────────────────────────
                Column(
                  children: [
                    _BalanceCard(data: data),
                    const SizedBox(height: 16),
                    _KpiRow(data: data),
                    const SizedBox(height: 16),
                    const _UpcomingBanner(),
                    const SizedBox(height: 16),
                    _BarChartCard(data: data, year: year),
                    const SizedBox(height: 16),
                    _ExpenseDonut(data: data),
                    const SizedBox(height: 16),
                    _AccountsList(data: data, year: year, ref: ref),
                  ],
                ),
            ],
          ),
        ),
        // ── FABs ──────────────────────────────────────────────────────
        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'fab_account',
                backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                onPressed: () => showAccountFormModal(context, ref),
                tooltip: 'Nouveau compte',
                child: Icon(Icons.folder_outlined,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    size: 18),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'fab_transaction',
                backgroundColor: AppColors.primary,
                onPressed: () => showTransactionFormModal(context, ref),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Transaction',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Left column (desktop) ───────────────────────────────────────────────────
class _LeftColumn extends StatelessWidget {
  final DashboardData data;
  final WidgetRef ref;

  const _LeftColumn({required this.data, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BalanceCard(data: data),
        const SizedBox(height: 16),
        _ExpenseDonut(data: data),
        const SizedBox(height: 16),
        _SpendingLimit(data: data),
      ],
    );
  }
}

// ─── Right column (desktop) ──────────────────────────────────────────────────
class _RightColumn extends StatelessWidget {
  final DashboardData data;
  final int year;
  final WidgetRef ref;

  const _RightColumn({required this.data, required this.year, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KpiRow(data: data),
        const SizedBox(height: 16),
        const _UpcomingBanner(),
        const SizedBox(height: 16),
        _BarChartCard(data: data, year: year),
        const SizedBox(height: 16),
        _AccountsList(data: data, year: year, ref: ref),
      ],
    );
  }
}

// ─── Year nav bar ────────────────────────────────────────────────────────────
class _YearNavBar extends StatelessWidget {
  final int year;
  final WidgetRef ref;

  const _YearNavBar({required this.year, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 22),
          onPressed: year > currentYear - 5
              ? () => ref.read(selectedYearProvider.notifier).state = year - 1
              : null,
        ),
        Text(
          '$year',
          style: TextStyle(
            color: year == currentYear
                ? AppColors.primary
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 22),
          onPressed: year < currentYear + 5
              ? () => ref.read(selectedYearProvider.notifier).state = year + 1
              : null,
        ),
      ],
    );
  }
}

// ─── Balance card (gradient green) ───────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final DashboardData data;

  const _BalanceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mon Solde',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormats.currency.format(data.currentBalance),
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Projected end-of-month
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.projectedEndOfMonth >= 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Fin de mois: ${AppFormats.currencyCompact.format(data.projectedEndOfMonth)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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

// ─── KPI row (3 cards) ───────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final DashboardData data;

  const _KpiRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final savings = data.currentMonthIncome - data.currentMonthExpenses;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 600;

    final cards = [
      _MiniKpi(
        label: 'Revenus',
        amount: data.currentMonthIncome,
        color: AppColors.success,
        isUp: true,
      ),
      _MiniKpi(
        label: 'Dépenses',
        amount: data.currentMonthExpenses,
        color: AppColors.danger,
        isUp: false,
      ),
      _MiniKpi(
        label: 'Épargne',
        amount: savings,
        color: savings >= 0 ? AppColors.success : AppColors.danger,
        isUp: savings >= 0,
      ),
    ];

    if (isNarrow) {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
  }
}

class _MiniKpi extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool isUp;

  const _MiniKpi({
    required this.label,
    required this.amount,
    required this.color,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppFormats.currency.format(amount),
            style: GoogleFonts.robotoMono(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUp ? Icons.north : Icons.south,
                  size: 10,
                  color: color,
                ),
                const SizedBox(width: 2),
                Text(
                  'Ce mois',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming banner ─────────────────────────────────────────────────────────
class _UpcomingBanner extends ConsumerWidget {
  const _UpcomingBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return upcomingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.grandTotal == 0) return const SizedBox.shrink();
        final totalCount = data.auto.length + data.manual.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$totalCount échéance${totalCount > 1 ? 's' : ''} dans les 30 prochains jours',
                  style: TextStyle(
                    color: isDark ? AppColors.warning : AppColors.primaryDarker,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                AppFormats.currencyCompact.format(data.grandTotal),
                style: GoogleFonts.robotoMono(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Bar chart card (Financial Overview) ─────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final DashboardData data;
  final int year;

  const _BarChartCard({required this.data, required this.year});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    // Compute income & expense per month from groups
    final incomes = List<double>.filled(12, 0);
    final expenses = List<double>.filled(12, 0);
    for (final group in data.groups) {
      for (final account in group.accounts) {
        for (int m = 1; m <= 12; m++) {
          final cell = account.months[m];
          if (cell == null) continue;
          if (account.isIncome) {
            incomes[m - 1] += cell.total;
          } else {
            expenses[m - 1] += cell.total;
          }
        }
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aperçu Financier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Row(
                children: [
                  _ChartLegendDot(color: AppColors.primary, label: 'Revenus'),
                  const SizedBox(width: 12),
                  _ChartLegendDot(color: AppColors.primaryDarker, label: 'Dépenses'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxY(incomes, expenses),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Revenus' : 'Dépenses';
                      return BarTooltipItem(
                        '$label\n${AppFormats.currencyCompact.format(rod.toY)}',
                        TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _months[value.toInt()],
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                          ),
                        ),
                      ),
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text(
                        '${(value / 1000).toStringAsFixed(0)}k',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _maxY(incomes, expenses) / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final isCurrentMonth = year == currentYear && (i + 1) == currentMonth;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: incomes[i],
                        color: isCurrentMonth ? AppColors.primary : (isDark ? const Color(0xFF4B5563) : const Color(0xFFE5E7EB)),
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: expenses[i],
                        color: isCurrentMonth ? AppColors.primaryDarker : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _maxY(List<double> a, List<double> b) {
    double max = 1;
    for (int i = 0; i < 12; i++) {
      if (a[i] > max) max = a[i];
      if (b[i] > max) max = b[i];
    }
    return max * 1.15;
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

// ─── Expense breakdown donut ─────────────────────────────────────────────────
class _ExpenseDonut extends StatelessWidget {
  final DashboardData data;

  const _ExpenseDonut({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;

    // Collect expense accounts with their current month totals
    final entries = <_ExpenseEntry>[];
    for (final group in data.groups) {
      for (final account in group.accounts) {
        if (account.isIncome) continue;
        final cell = account.months[currentMonth];
        if (cell == null || cell.total == 0) continue;
        entries.add(_ExpenseEntry(account.accountName, cell.total));
      }
    }

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      AppColors.primary,
      AppColors.primaryDark,
      AppColors.primaryDarker,
      const Color(0xFFD1D5DB),
      AppColors.warning,
      AppColors.info,
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Répartition Dépenses',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 35,
                    sections: List.generate(entries.length, (i) {
                      return PieChartSectionData(
                        value: entries[i].amount,
                        color: colors[i % colors.length],
                        radius: 20,
                        showTitle: false,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entries[i].name,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            AppFormats.currencyCompact.format(entries[i].amount),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseEntry {
  final String name;
  final double amount;
  const _ExpenseEntry(this.name, this.amount);
}

// ─── Spending limit bar ──────────────────────────────────────────────────────
class _SpendingLimit extends StatelessWidget {
  final DashboardData data;

  const _SpendingLimit({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spent = data.currentMonthExpenses;
    final income = data.currentMonthIncome;
    final ratio = income > 0 ? (spent / income).clamp(0.0, 1.0) : 0.0;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Limite Mensuelle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation(
                ratio > 0.9 ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppFormats.currencyCompact.format(spent),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                AppFormats.currencyCompact.format(income),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Accounts list (replaces the big grid) ───────────────────────────────────
class _AccountsList extends StatelessWidget {
  final DashboardData data;
  final int year;
  final WidgetRef ref;

  const _AccountsList({required this.data, required this.year, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonth = DateTime.now().month;

    if (data.groups.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Aucun compte créé.\nCommencez par ajouter un compte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    // Flatten all accounts with their current month data
    final rows = <_AccountRowData>[];
    for (final group in data.groups) {
      for (final account in group.accounts) {
        final cell = account.months[currentMonth];
        rows.add(_AccountRowData(
          accountId: account.accountId,
          name: account.accountName,
          isIncome: account.isIncome,
          total: cell?.total ?? 0,
        ));
      }
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activité Récente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 16),
          // Table header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compte',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  'Ce mois',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Divider(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          // Rows
          ...rows.map((row) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showTransactionsListModal(
                  context,
                  ref,
                  accountId: row.accountId,
                  accountName: row.name,
                  isIncome: row.isIncome,
                  month: currentMonth,
                  year: year,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          row.isIncome ? Icons.trending_up : Icons.shopping_cart_outlined,
                          size: 16,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      Text(
                        row.total == 0
                            ? '—'
                            : '${row.isIncome ? '+' : '-'}${AppFormats.currencyCompact.format(row.total)}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: row.total == 0
                              ? (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight)
                              : (row.isIncome ? AppColors.success : AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _AccountRowData {
  final String accountId;
  final String name;
  final bool isIncome;
  final double total;

  const _AccountRowData({
    required this.accountId,
    required this.name,
    required this.isIncome,
    required this.total,
  });
}
