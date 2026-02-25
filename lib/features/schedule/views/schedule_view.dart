import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

part 'schedule_view.header.part.dart';
part 'schedule_view.list.part.dart';
part 'schedule_view.card.part.dart';
part 'schedule_view.calendar.part.dart';
part 'schedule_view.calendar_widgets.part.dart';

// -- View toggle -------------------------------------------------------------
final _calendarModeProvider = StateProvider<bool>(
  (ref) => false,
); // false = list

enum _InvoiceScope { month, all }

final _invoiceScopeProvider = StateProvider<_InvoiceScope>(
  (ref) => _InvoiceScope.month,
);
final _calendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

// -- Colours -----------------------------------------------------------------
const _autoColor = AppColors.primary;
const _manualColor = AppColors.warning;
const _overdueColor = AppColors.danger;
const _calendarAccent = AppColors.primary;
const _calendarAutoColor = AppColors.primary;
const _calendarManualColor = AppColors.warning;

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

_ScopedUpcomingData _scopeUpcomingData(UpcomingData data, _InvoiceScope scope) {
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

  // Safety net: keep only expenses and hide overdue auto debits in list mode.
  autoAll = autoAll
      .where((t) => !(t.isAuto && t.isPending && isPast(t.date)))
      .toList();

  autoAll.sort((a, b) => a.date.compareTo(b.date));
  manualAll.sort((a, b) => a.date.compareTo(b.date));

  if (scope == _InvoiceScope.month) {
    autoAll = autoAll.where(isCurrentMonth).toList();
    manualAll = manualAll.where(isCurrentMonth).toList();
  }

  final totalAuto = autoAll.fold<double>(0, (sum, t) => sum + t.amount);
  final totalManual = manualAll.fold<double>(0, (sum, t) => sum + t.amount);

  List<Transaction> autoList = autoAll;
  List<Transaction> manualList = manualAll;
  var hiddenAuto = 0;
  var hiddenManual = 0;

  if (scope == _InvoiceScope.all) {
    if (autoList.length > 10) {
      hiddenAuto = autoList.length - 10;
      autoList = autoList.take(10).toList();
    }
    if (manualList.length > 10) {
      hiddenManual = manualList.length - 10;
      manualList = manualList.take(10).toList();
    }
  }

  final visibleTotalAuto = autoList.fold<double>(0, (sum, t) => sum + t.amount);
  final visibleTotalManual = manualList.fold<double>(
    0,
    (sum, t) => sum + t.amount,
  );

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

_ScopedUpcomingData _scopeUpcomingDataToMonth(
  _ScopedUpcomingData data,
  DateTime month,
) {
  bool inMonth(Transaction t) =>
      t.date.year == month.year && t.date.month == month.month;

  final auto = data.autoAll.where(inMonth).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final manual = data.manualAll.where(inMonth).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final totalAuto = auto.fold<double>(0, (sum, t) => sum + t.amount);
  final totalManual = manual.fold<double>(0, (sum, t) => sum + t.amount);

  return _ScopedUpcomingData(
    autoAll: auto,
    manualAll: manual,
    autoList: auto,
    manualList: manual,
    hiddenAuto: 0,
    hiddenManual: 0,
    totalAuto: totalAuto,
    totalManual: totalManual,
    grandTotal: totalAuto + totalManual,
    visibleTotalAuto: totalAuto,
    visibleTotalManual: totalManual,
    visibleGrandTotal: totalAuto + totalManual,
  );
}

class ScheduleView extends ConsumerWidget {
  const ScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);
    final isCalendar = ref.watch(_calendarModeProvider);
    final scope = ref.watch(_invoiceScopeProvider);
    final calendarMonth = ref.watch(_calendarMonthProvider);

    return upcomingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          'Erreur: $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) {
        final listData = _scopeUpcomingData(data, scope);
        final calendarData = _scopeUpcomingData(data, _InvoiceScope.all);
        final headerData = isCalendar
            ? _scopeUpcomingDataToMonth(calendarData, calendarMonth)
            : listData;
        final bodyData = isCalendar ? calendarData : listData;
        return LayoutBuilder(
          builder: (context, constraints) {
            return AppPageScaffold(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppPageHeader(
                    title: 'Échéancier',
                    subtitle:
                        'Suivez vos factures, prélèvements et échéances à payer.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _HeroHeader(data: headerData),
                  const SizedBox(height: 24),
                  _Body(data: bodyData, maxWidth: constraints.maxWidth),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
