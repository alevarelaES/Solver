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
import 'package:solver/features/schedule/widgets/schedule_left_panel.dart';
import 'package:solver/features/schedule/widgets/schedule_main_content.dart';
import 'package:solver/features/schedule/widgets/schedule_header_controls.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

// Calendar part files
// ignore_for_file: unused_element
part 'schedule_view.calendar.part.dart';
part 'schedule_view.calendar_widgets.part.dart';

// -- State providers ---------------------------------------------------------
final _viewTypeProvider = StateProvider<ScheduleViewType>((ref) => ScheduleViewType.list);
final _periodScopeProvider = StateProvider<SchedulePeriodScope>((ref) => SchedulePeriodScope.month);

final _calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

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
    final viewType = ref.watch(_viewTypeProvider);
    final scope = ref.watch(_periodScopeProvider);

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
        final calendarData = _scopeUpcomingData(data, SchedulePeriodScope.all);
        final sparklineData = _computeSparklineData(data);

        // Overdue count for the hero badge
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        int overdueCount = 0;
        for (final t in listData.manualList) {
          if (!t.isPending) continue;
          final due = DateTime(t.date.year, t.date.month, t.date.day);
          if (due.isBefore(today)) overdueCount++;
        }

        final monthLabel =
            DateFormat('MMMM yyyy', 'fr_FR').format(now).toUpperCase();
        final allUpcoming = [...data.auto, ...data.manual];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 960;
            return AppPageScaffold(
              scrollable: false,
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppPageHeader(
                    title: AppStrings.schedule.title,
                    subtitle: AppStrings.schedule.subtitle,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 330,
                                child: ScheduleLeftPanel(
                                  totalManual: listData.totalManual,
                                  totalAuto: listData.totalAuto,
                                  currencyCode: currencyCode,
                                  allTransactions: allUpcoming,
                                  totalDue: listData.visibleGrandTotal,
                                  period: monthLabel,
                                  overdueCount: overdueCount,
                                  hasOverdue: overdueCount > 0,
                                  sparklineData: sparklineData,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(
                                child: viewType == ScheduleViewType.calendar
                                    ? _CalendarView(data: calendarData)
                                    : ScheduleMainContent(
                                        autoList: listData.autoList,
                                        manualList: listData.manualList,
                                        totalAuto: listData.totalAuto,
                                        totalManual: listData.totalManual,
                                        currencyCode: currencyCode,
                                        viewType: viewType,
                                        onViewChanged: (v) => ref.read(_viewTypeProvider.notifier).state = v,
                                        periodScope: scope,
                                        onPeriodChanged: (s) => ref.read(_periodScopeProvider.notifier).state = s,
                                        onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                                      ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ScheduleLeftPanel(
                                  totalManual: listData.totalManual,
                                  totalAuto: listData.totalAuto,
                                  currencyCode: currencyCode,
                                  allTransactions: allUpcoming,
                                  totalDue: listData.visibleGrandTotal,
                                  period: monthLabel,
                                  overdueCount: overdueCount,
                                  hasOverdue: overdueCount > 0,
                                  sparklineData: sparklineData,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                if (viewType == ScheduleViewType.calendar)
                                  SizedBox(
                                    height: 500,
                                    child: _CalendarView(data: calendarData),
                                  )
                                else
                                  ScheduleMainContent(
                                    autoList: listData.autoList,
                                    manualList: listData.manualList,
                                    totalAuto: listData.totalAuto,
                                    totalManual: listData.totalManual,
                                    currencyCode: currencyCode,
                                    viewType: viewType,
                                    onViewChanged: (v) => ref.read(_viewTypeProvider.notifier).state = v,
                                    periodScope: scope,
                                    onPeriodChanged: (s) => ref.read(_periodScopeProvider.notifier).state = s,
                                    onChanged: () => ref.invalidate(upcomingTransactionsProvider),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder tab (Mob, Tableur)
// ─────────────────────────────────────────────────────────────────────────────

class _SchedulePlaceholderTab extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SchedulePlaceholderTab({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$label – bientôt disponible',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
