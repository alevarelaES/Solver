import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/schedule/widgets/schedule_empty_state.dart';
import 'package:solver/features/schedule/widgets/schedule_hero_card.dart';
import 'package:solver/features/schedule/widgets/schedule_left_panel.dart';
import 'package:solver/features/schedule/widgets/schedule_main_content.dart';
import 'package:solver/features/schedule/widgets/schedule_header_controls.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

// Calendar part files
// ignore_for_file: unused_element
part 'schedule_view.calendar.part.dart';
part 'schedule_view.calendar_widgets.part.dart';

// -- State providers ---------------------------------------------------------
final _periodScopeProvider =
    StateProvider<SchedulePeriodScope>((ref) => SchedulePeriodScope.month);

final _calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// 0 = Stat, 1 = Calendrier
final _viewTabProvider = StateProvider<int>((ref) => 0);

// -- Section colours (used by part files) ------------------------------------
const _autoColor = AppColors.primary;
const _manualColor = AppColors.warning;
const _overdueColor = AppColors.danger;
const _calendarAccent = AppColors.primary;
const _calendarAutoColor = AppColors.primary;
const _calendarManualColor = AppColors.warning;

// -- Scoped data model -------------------------------------------------------
class _ScopedUpcomingData {
  final List<Transaction> autoAll;
  final List<Transaction> manualAll;
  final List<Transaction> autoList;
  final List<Transaction> manualList;
  final int hiddenAuto;
  final int hiddenManual;
  final double totalAuto;
  final double totalManual;
  final double grandTotal;
  final double visibleTotalAuto;
  final double visibleTotalManual;
  final double visibleGrandTotal;

  const _ScopedUpcomingData({
    required this.autoAll,
    required this.manualAll,
    required this.autoList,
    required this.manualList,
    required this.hiddenAuto,
    required this.hiddenManual,
    required this.totalAuto,
    required this.totalManual,
    required this.grandTotal,
    required this.visibleTotalAuto,
    required this.visibleTotalManual,
    required this.visibleGrandTotal,
  });
}

_ScopedUpcomingData _scopeUpcomingData(
  UpcomingData data,
  SchedulePeriodScope scope,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  bool isPast(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
  }

  bool isCurrentMonth(Transaction t) =>
      t.date.year == now.year && t.date.month == now.month;

  var autoAll = data.auto.where((t) => !t.isIncome).toList();
  var manualAll = data.manual.where((t) => !t.isIncome).toList();

  // Hide overdue auto debits from list mode.
  autoAll = autoAll
      .where((t) => !(t.isAuto && t.isPending && isPast(t.date)))
      .toList();

  autoAll.sort((a, b) => a.date.compareTo(b.date));
  manualAll.sort((a, b) => a.date.compareTo(b.date));

  if (scope == SchedulePeriodScope.month) {
    autoAll = autoAll.where(isCurrentMonth).toList();
    manualAll = manualAll.where(isCurrentMonth).toList();
  }

  final totalAuto = autoAll.fold<double>(0, (sum, t) => sum + t.amount);
  final totalManual = manualAll.fold<double>(0, (sum, t) => sum + t.amount);

  List<Transaction> autoList = autoAll;
  List<Transaction> manualList = manualAll;
  var hiddenAuto = 0;
  var hiddenManual = 0;

  if (scope == SchedulePeriodScope.all) {
    if (autoList.length > 10) {
      hiddenAuto = autoList.length - 10;
      autoList = autoList.take(10).toList();
    }
    if (manualList.length > 10) {
      hiddenManual = manualList.length - 10;
      manualList = manualList.take(10).toList();
    }
  }

  final visibleTotalAuto =
      autoList.fold<double>(0, (sum, t) => sum + t.amount);
  final visibleTotalManual =
      manualList.fold<double>(0, (sum, t) => sum + t.amount);

  return _ScopedUpcomingData(
    autoAll: autoAll,
    manualAll: manualAll,
    autoList: autoList,
    manualList: manualList,
    hiddenAuto: hiddenAuto,
    hiddenManual: hiddenManual,
    totalAuto: totalAuto,
    totalManual: totalManual,
    grandTotal: totalAuto + totalManual,
    visibleTotalAuto: visibleTotalAuto,
    visibleTotalManual: visibleTotalManual,
    visibleGrandTotal: visibleTotalAuto + visibleTotalManual,
  );
}

/// Monthly expense totals for the next 6 months — used as sparkline data.
List<double> _computeSparklineData(UpcomingData data) {
  final now = DateTime.now();
  return List.generate(6, (i) {
    final m = DateTime(now.year, now.month + i);
    return [...data.auto, ...data.manual]
        .where(
          (t) =>
              t.date.year == m.year &&
              t.date.month == m.month &&
              !t.isIncome,
        )
        .fold<double>(0, (s, t) => s + t.amount);
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ScheduleView
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCode = ref.watch(appCurrencyProvider).code;
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);
    final scope = ref.watch(_periodScopeProvider);
    final viewTab = ref.watch(_viewTabProvider);

    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          AppStrings.schedule.error(e),
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) {
        final listData = _scopeUpcomingData(data, scope);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        var overdueCount = 0;
        for (final t in listData.manualAll) {
          if (!t.isPending) continue;
          final due = DateTime(t.date.year, t.date.month, t.date.day);
          if (due.isBefore(today)) overdueCount++;
        }

        final monthLabel =
            DateFormat('MMMM yyyy', 'fr_FR').format(now).toUpperCase();
        final allUpcoming = [...data.auto, ...data.manual];

        final heroCard = ScheduleHeroCard(
          totalDue: listData.visibleGrandTotal,
          period: monthLabel,
          overdueCount: overdueCount,
          hasOverdue: overdueCount > 0,
          currencyCode: currencyCode,
        );

        final leftPanel = ScheduleLeftPanel(
          totalManual: listData.totalManual,
          totalAuto: listData.totalAuto,
          currencyCode: currencyCode,
          allTransactions: allUpcoming,
        );

        return AppPageScaffold(
          scrollable: false,
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: AppStrings.schedule.title,
                      subtitle: AppStrings.schedule.subtitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // ── TOP ROW: HeroCard & Toggles ─────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: heroCard,
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _ScheduleToggleGroup(
                                title: 'Vue',
                                label1: 'Liste',
                                label2: 'Calendrier',
                                current: viewTab,
                                onChanged: (t) =>
                                    ref.read(_viewTabProvider.notifier).state = t,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              _ScheduleToggleGroup(
                                title: 'Période',
                                label1: 'Mois',
                                label2: 'Toutes',
                                current: scope == SchedulePeriodScope.month ? 0 : 1,
                                onChanged: (idx) => ref
                                    .read(_periodScopeProvider.notifier)
                                    .state = idx == 0
                                        ? SchedulePeriodScope.month
                                        : SchedulePeriodScope.all,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // ── BOTTOM ROW: LeftPanel & StatView ────────────
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Left column: Upcoming + Calendar ───────────────
                          SizedBox(
                            width: 320,
                            child: leftPanel,
                          ),
                          const SizedBox(width: AppSpacing.xl),
                          // ── Right column: Stat or Calendar (fill height) ───
                          Expanded(
                            child: viewTab == 0
                                ? _StatView(
                                    autoList: listData.autoList,
                                    manualList: listData.manualList,
                                    totalAuto: listData.totalAuto,
                                    totalManual: listData.totalManual,
                                    currencyCode: currencyCode,
                                    onChanged: () => ref.invalidate(
                                        upcomingTransactionsProvider),
                                  )
                                : SingleChildScrollView(
                                    child: _CalendarView(
                                      data: listData,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // ── Narrow layout ─────────────────────────────────────────────
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: AppStrings.schedule.title,
                      subtitle: AppStrings.schedule.subtitle,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    heroCard,
                    const SizedBox(height: AppSpacing.md),
                    ScheduleMainContent(
                      autoList: listData.autoList,
                      manualList: listData.manualList,
                      totalAuto: listData.totalAuto,
                      totalManual: listData.totalManual,
                      currencyCode: currencyCode,
                      periodScope: scope,
                      onPeriodChanged: (s) =>
                          ref.read(_periodScopeProvider.notifier).state = s,
                      onChanged: () =>
                          ref.invalidate(upcomingTransactionsProvider),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatView – two full-height invoice card columns
// ─────────────────────────────────────────────────────────────────────────────

class _StatView extends StatelessWidget {
  final List<Transaction> autoList;
  final List<Transaction> manualList;
  final double totalAuto;
  final double totalManual;
  final String currencyCode;
  final VoidCallback onChanged;

  const _StatView({
    required this.autoList,
    required this.manualList,
    required this.totalAuto,
    required this.totalManual,
    required this.currencyCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _InvoiceColumn(
            title: AppStrings.schedule.sectionManual,
            icon: Icons.description_outlined,
            accentColor: AppColors.warning,
            transactions: manualList,
            totalAmount: totalManual,
            showValidate: true,
            currencyCode: currencyCode,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _InvoiceColumn(
            title: AppStrings.schedule.sectionAuto,
            icon: Icons.bolt,
            accentColor: AppColors.primary,
            transactions: autoList,
            totalAmount: totalAuto,
            showValidate: false,
            currencyCode: currencyCode,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InvoiceColumn – full-height card with scrollable list inside
// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Transaction> transactions;
  final double totalAmount;
  final bool showValidate;
  final String currencyCode;
  final VoidCallback onChanged;

  const _InvoiceColumn({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.transactions,
    required this.totalAmount,
    required this.showValidate,
    required this.currencyCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCardBase(
      variant: PremiumCardVariant.standard,
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                    if (transactions.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${transactions.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                AppFormats.formatFromCurrency(totalAmount, currencyCode),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: AppSpacing.md),
          // List (scrollable inside fixed card)
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: ScheduleEmptyState(accentColor: accentColor),
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => ScheduleInvoiceCard(
                      transaction: transactions[i],
                      accentColor: accentColor,
                      showValidate: showValidate,
                      currencyCode: currencyCode,
                      onChanged: onChanged,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toggles (Vue / Période)
// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleToggleGroup extends StatelessWidget {
  final String title;
  final String label1;
  final String label2;
  final int current;
  final ValueChanged<int> onChanged;

  const _ScheduleToggleGroup({
    required this.title,
    required this.label1,
    required this.label2,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 8, right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(AppRadius.lg + 6),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withAlpha(40) : Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(AppRadius.lg + 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Tab(
                  label: label1,
                  index: 0,
                  current: current,
                  onTap: onChanged,
                  isDark: isDark,
                ),
                const SizedBox(width: 2),
                _Tab(
                  label: label2,
                  index: 1,
                  current: current,
                  onTap: onChanged,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _Tab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

