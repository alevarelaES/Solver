import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/widgets/account_form_modal.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';
import 'package:solver/features/transactions/widgets/transactions_list_modal.dart';
import 'package:solver/shared/widgets/kpi_card.dart';

// ─── Column dimensions ────────────────────────────────────────────────────────
const double _kNameColWidth = 200.0;
const double _kMonthColWidth = 90.0;

// ─── Month labels ─────────────────────────────────────────────────────────────
const _months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];


// ─── DashboardView ────────────────────────────────────────────────────────────
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider(year));

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _YearNavBar(year: year, ref: ref),
            dashboardAsync.when(
              loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Expanded(
                child: Center(
                  child: Text(
                    'Erreur de chargement\n$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.softRed),
                  ),
                ),
              ),
              data: (data) => Expanded(
                child: Column(
                  children: [
                    _KpiSection(data: data),
                    const _UpcomingBanner(),
                    Expanded(child: _DashboardGrid(data: data, year: year)),
                  ],
                ),
              ),
            ),
          ],
        ),
        // FAB Transaction
        Positioned(
          bottom: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Bouton compte
              FloatingActionButton.small(
                heroTag: 'fab_account',
                backgroundColor: const Color(0xFF1A1A1A),
                onPressed: () => showAccountFormModal(context, ref),
                tooltip: 'Nouveau compte',
                child: const Icon(Icons.folder_outlined, color: AppColors.textSecondary, size: 18),
              ),
              const SizedBox(height: 12),
              // Bouton transaction
              FloatingActionButton.extended(
                heroTag: 'fab_transaction',
                backgroundColor: AppColors.electricBlue,
                onPressed: () => showTransactionFormModal(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Transaction'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Year navigation bar ──────────────────────────────────────────────────────
class _YearNavBar extends StatelessWidget {
  final int year;
  final WidgetRef ref;

  const _YearNavBar({required this.year, required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            onTap: year > currentYear - 5
                ? () => ref.read(selectedYearProvider.notifier).state = year - 1
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            '$year',
            style: TextStyle(
              color: year == currentYear ? AppColors.electricBlue : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          _NavButton(
            icon: Icons.chevron_right,
            onTap: year < currentYear + 5
                ? () => ref.read(selectedYearProvider.notifier).state = year + 1
                : null,
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          color: onTap != null ? AppColors.textPrimary : AppColors.textDisabled,
          size: 22,
        ),
      ),
    );
  }
}

// ─── KPI section ─────────────────────────────────────────────────────────────
class _KpiSection extends StatelessWidget {
  final DashboardData data;

  const _KpiSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final endOfMonthColor =
        data.projectedEndOfMonth >= 0 ? AppColors.coolPurple : AppColors.softRed;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          final cards = [
            KpiCard(
              label: 'Solde Actuel',
              amount: data.currentBalance,
              color: AppColors.electricBlue,
              icon: Icons.account_balance_wallet_outlined,
            ),
            KpiCard(
              label: 'Revenus du Mois',
              amount: data.currentMonthIncome,
              color: AppColors.neonEmerald,
              icon: Icons.trending_up,
            ),
            KpiCard(
              label: 'Dépenses du Mois',
              amount: data.currentMonthExpenses,
              color: AppColors.softRed,
              icon: Icons.trending_down,
            ),
            KpiCard(
              label: 'Fin de Mois Estimée',
              amount: data.projectedEndOfMonth,
              color: endOfMonthColor,
              icon: Icons.show_chart,
            ),
          ];

          if (isNarrow) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: cards,
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

    return upcomingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.grandTotal == 0) return const SizedBox.shrink();
        final totalCount = data.auto.length + data.manual.length;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warmAmber.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.warmAmber.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.warmAmber, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$totalCount échéance${totalCount > 1 ? 's' : ''} dans les 30 prochains jours',
                  style: const TextStyle(
                      color: AppColors.warmAmber, fontSize: 12),
                ),
              ),
              Text(
                AppFormats.currencyCompact.format(data.grandTotal),
                style: AppTextStyles.amountSmall(AppColors.warmAmber),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Main grid ────────────────────────────────────────────────────────────────
class _DashboardGrid extends StatelessWidget {
  final DashboardData data;
  final int year;

  const _DashboardGrid({required this.data, required this.year});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthlyBalances = data.computeMonthlyBalances();

    if (data.groups.isEmpty) {
      return const Center(
        child: Text(
          'Aucun compte créé.\nCommencez par ajouter un compte.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MonthHeaderRow(
              year: year,
              currentYear: now.year,
              currentMonth: now.month,
            ),
            for (final group in data.groups) ...[
              _GroupHeaderRow(groupName: group.groupName),
              for (final account in group.accounts)
                _AccountRow(
                  account: account,
                  year: year,
                  currentYear: now.year,
                  currentMonth: now.month,
                ),
            ],
            _FooterRow(
              monthlyBalances: monthlyBalances,
              year: year,
              currentYear: now.year,
              currentMonth: now.month,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Month header row ─────────────────────────────────────────────────────────
class _MonthHeaderRow extends StatelessWidget {
  final int year;
  final int currentYear;
  final int currentMonth;

  const _MonthHeaderRow({
    required this.year,
    required this.currentYear,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceHeader,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kNameColWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Compte',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (int m = 1; m <= 12; m++)
            _MonthHeaderCell(
              label: _months[m - 1],
              isCurrent: year == currentYear && m == currentMonth,
            ),
        ],
      ),
    );
  }
}

class _MonthHeaderCell extends StatelessWidget {
  final String label;
  final bool isCurrent;

  const _MonthHeaderCell({required this.label, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kMonthColWidth,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isCurrent
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.electricBlue, width: 2),
              ),
            )
          : null,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isCurrent ? AppColors.electricBlue : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Group header row ─────────────────────────────────────────────────────────
class _GroupHeaderRow extends StatelessWidget {
  final String groupName;

  const _GroupHeaderRow({required this.groupName});

  @override
  Widget build(BuildContext context) {
    const totalWidth = _kNameColWidth + (_kMonthColWidth * 12);
    return Container(
      width: totalWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surfaceCard,
      child: Text(
        groupName.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Account row ─────────────────────────────────────────────────────────────
class _AccountRow extends ConsumerWidget {
  final AccountMonthlyData account;
  final int year;
  final int currentYear;
  final int currentMonth;

  const _AccountRow({
    required this.account,
    required this.year,
    required this.currentYear,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kNameColWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                account.accountName,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          for (int m = 1; m <= 12; m++)
            _CellWidget(
              cell: account.months[m] ??
                  const MonthCell(total: 0, pendingCount: 0, completedCount: 0),
              isIncome: account.isIncome,
              isPast: year < currentYear ||
                  (year == currentYear && m < currentMonth),
              isCurrent: year == currentYear && m == currentMonth,
              onTap: () => showTransactionsListModal(
                context,
                ref,
                accountId: account.accountId,
                accountName: account.accountName,
                isIncome: account.isIncome,
                month: m,
                year: year,
              ),
            ),
        ],
      ),
    );
  }
}

class _CellWidget extends StatelessWidget {
  final MonthCell cell;
  final bool isIncome;
  final bool isPast;
  final bool isCurrent;
  final VoidCallback onTap;

  const _CellWidget({
    required this.cell,
    required this.isIncome,
    required this.isPast,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final amountColor = cell.isEmpty
        ? AppColors.textDisabled
        : (isIncome ? AppColors.neonEmerald : AppColors.softRed);

    Color bgColor = Colors.transparent;
    if (isCurrent) bgColor = AppColors.electricBlue.withAlpha(10);
    if (isPast) bgColor = Colors.white.withAlpha(4);

    final textOpacity = isPast ? 0.45 : (cell.isEmpty ? 0.35 : 1.0);

    return InkWell(
      onTap: onTap,
      child: Container(
      width: _kMonthColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (cell.hasPending)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                Icons.schedule,
                size: 10,
                color: AppColors.warmAmber.withAlpha((textOpacity * 255).round()),
              ),
            ),
          Flexible(
            child: Text(
              cell.isEmpty ? '—' : AppFormats.currencyRaw.format(cell.total),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.robotoMono(
                color: amountColor.withAlpha((textOpacity * 255).round()),
                fontSize: 12,
                fontStyle: (!isPast && !isCurrent) ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─── Footer row ───────────────────────────────────────────────────────────────
class _FooterRow extends StatelessWidget {
  final List<double> monthlyBalances;
  final int year;
  final int currentYear;
  final int currentMonth;

  const _FooterRow({
    required this.monthlyBalances,
    required this.year,
    required this.currentYear,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deepBlack,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kNameColWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Solde Fin de Mois',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (int m = 1; m <= 12; m++)
            _FooterCell(
              balance: monthlyBalances[m - 1],
              isPast: year < currentYear ||
                  (year == currentYear && m < currentMonth),
              isCurrent: year == currentYear && m == currentMonth,
            ),
        ],
      ),
    );
  }
}

class _FooterCell extends StatelessWidget {
  final double balance;
  final bool isPast;
  final bool isCurrent;

  const _FooterCell({
    required this.balance,
    required this.isPast,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final color = balance >= 0 ? AppColors.neonEmerald : AppColors.softRed;
    final opacity = isPast ? 0.5 : 1.0;

    return Container(
      width: _kMonthColWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      color: isCurrent ? AppColors.electricBlue.withAlpha(10) : Colors.transparent,
      child: Text(
        AppFormats.currencyRaw.format(balance),
        textAlign: TextAlign.right,
        style: AppTextStyles.amountSmall(color.withAlpha((opacity * 255).round())),
      ),
    );
  }
}
