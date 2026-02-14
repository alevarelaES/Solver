import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/features/analysis/providers/analysis_provider.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/dashboard/providers/recent_transactions_provider.dart';
import 'package:solver/features/journal/providers/journal_provider.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';

void invalidateAfterTransactionMutation(WidgetRef ref) {
  ref.invalidate(dashboardDataProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(upcomingTransactionsProvider);
  ref.invalidate(yearlyExpenseProjectionProvider);
  ref.invalidate(budgetStatsProvider);
  ref.invalidate(journalTransactionsProvider);
  ref.invalidate(analysisDataProvider);
}
