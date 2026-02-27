import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/providers/navigation_providers.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_component_styles.dart';
import 'package:solver/core/theme/app_premium_theme.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/journal/providers/journal_provider.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/features/transactions/providers/transaction_refresh.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';
import 'package:solver/features/journal/widgets/journal_kpi_banner.dart';
import 'package:solver/features/journal/widgets/journal_right_sidebar.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

part 'journal_view.header.part.dart';
part 'journal_view.filters.part.dart';
part 'journal_view.table.part.dart';
part 'journal_view.detail.part.dart';

final _selectedTxIdProvider = StateProvider<String?>((ref) => null);

enum _JournalSortColumn { date, label, account, status, amount }

class _JournalSortState {
  final _JournalSortColumn column;
  final bool ascending;

  const _JournalSortState({required this.column, required this.ascending});

  _JournalSortState copyWith({_JournalSortColumn? column, bool? ascending}) =>
      _JournalSortState(
        column: column ?? this.column,
        ascending: ascending ?? this.ascending,
      );
}

final _journalSortProvider = StateProvider<_JournalSortState>(
  (ref) => const _JournalSortState(
    column: _JournalSortColumn.date,
    ascending: false,
  ),
);

List<Transaction> _sortJournalTransactions(
  List<Transaction> source,
  _JournalSortState sort,
) {
  final sorted = [...source];
  sorted.sort((a, b) {
    final cmp = switch (sort.column) {
      _JournalSortColumn.date => a.date.compareTo(b.date),
      _JournalSortColumn.label => _displayLabel(
        a,
      ).toLowerCase().compareTo(_displayLabel(b).toLowerCase()),
      _JournalSortColumn.account =>
        (a.accountName ?? a.accountId).toLowerCase().compareTo(
          (b.accountName ?? b.accountId).toLowerCase(),
        ),
      _JournalSortColumn.status => _statusSortRank(
        a,
      ).compareTo(_statusSortRank(b)),
      _JournalSortColumn.amount => a.amount.compareTo(b.amount),
    };

    var resolvedCmp = cmp;
    if (resolvedCmp == 0) {
      resolvedCmp = b.date.compareTo(a.date);
    }
    if (resolvedCmp == 0) {
      resolvedCmp = a.id.compareTo(b.id);
    }
    return sort.ascending ? resolvedCmp : -resolvedCmp;
  });
  return sorted;
}

int _statusSortRank(Transaction tx) {
  if (tx.isCompleted) return 0;
  if (tx.isAuto) return 1;
  return 2;
}

class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final txAsync = ref.watch(journalVisibleTransactionsProvider);
    final transactions = txAsync.valueOrNull ?? const <Transaction>[];

    if (txAsync.hasError && transactions.isEmpty) {
      return Center(
        child: Text(
          AppStrings.journal.error(txAsync.error!),
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }
    if (txAsync.isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check for pending navigation from dashboard
    final pendingTxId = ref.read(pendingJournalTxIdProvider);
    if (pendingTxId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pendingJournalTxIdProvider.notifier).state = null;
        ref.read(_selectedTxIdProvider.notifier).state = pendingTxId;
      });
    }

    final selectedId = ref.watch(_selectedTxIdProvider);
    final selected = selectedId == null
        ? null
        : transactions.where((t) => t.id == selectedId).firstOrNull;

    if (selectedId != null && selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_selectedTxIdProvider.notifier).state = null;
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final showSidebar = constraints.maxWidth >= 1280;

        return Stack(
          children: [
            Padding(
              padding: isMobile
                  ? const EdgeInsets.all(AppSpacing.md)
                  : AppSpacing.paddingPage,
              child: Column(
                children: [
                  _JournalHeader(isMobile: isMobile),
                  const SizedBox(height: 16),
                  Expanded(
                    child: showSidebar
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _JournalBody(
                                  transactions: transactions,
                                  selected: selected,
                                  isMobile: false,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              const SizedBox(
                                width: 280,
                                child: JournalRightSidebar(),
                              ),
                            ],
                          )
                        : _JournalBody(
                            transactions: transactions,
                            selected: selected,
                            isMobile: isMobile,
                          ),
                  ),
                ],
              ),
            ),
            if (txAsync.isLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!isMobile && selected != null)
              Positioned.fill(
                child: _DesktopDetailOverlay(
                  transaction: selected,
                  onClose: () =>
                      ref.read(_selectedTxIdProvider.notifier).state = null,
                ),
              ),
          ],
        );
      },
    );
  }
}
