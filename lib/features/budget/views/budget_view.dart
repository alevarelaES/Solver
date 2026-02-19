import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';
import 'package:solver/features/budget/providers/goals_provider.dart';
import 'package:solver/shared/widgets/app_panel.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

part 'budget_view.models.part.dart';
part 'budget_view.summary.part.dart';
part 'budget_view.groups.part.dart';

part 'budget_view.logic.part.dart';

final _viewModeProvider = StateProvider<bool>(
  (ref) => true,
); // true = cards, false = list

class BudgetView extends ConsumerStatefulWidget {
  const BudgetView({super.key});

  @override
  ConsumerState<BudgetView> createState() => _BudgetViewState();
}

class _BudgetViewState extends ConsumerState<BudgetView> {
  final Map<String, _GroupDraft> _drafts = {};
  String? _draftToken;
  bool _dirty = false;
  bool _savingPlan = false;
  bool _useGrossIncomeBase = false;
  double? _draftDisposableIncome;
  String? _draftError;
  void _withState(VoidCallback cb) => setState(cb);

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final monthKey = BudgetMonthKey(
      year: selectedMonth.year,
      month: selectedMonth.month,
    );
    final statsAsync = ref.watch(budgetStatsProvider(monthKey));
    final isCards = ref.watch(_viewModeProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          AppStrings.budget.errorBudget(e),
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (stats) {
        _syncDraft(stats);
        final grossReferenceIncome = _recommendedDisposableInput(
          stats,
          gross: true,
        );
        final manualCommittedAmount = _manualCommittedAmount(stats);
        final disposable =
            (_draftDisposableIncome ??
                    _recommendedDisposableInput(
                      stats,
                      gross: _useGrossIncomeBase,
                    ))
                .clamp(0, double.infinity);
        final rows = _buildRenderedGroups(stats);
        final totals = _computeTotals(
          rows,
          disposable.toDouble(),
          stats.budgetPlan.autoReserveAmount,
        );
        final autoByGroups = [...stats.budgetPlan.groups]
          ..removeWhere((g) => g.autoPlannedAmount <= 0)
          ..sort((a, b) => b.autoPlannedAmount.compareTo(a.autoPlannedAmount));
        final inputVersion =
            _draftToken ?? '${stats.selectedYear}-${stats.selectedMonth}';
        final disposableForSavings = totals.manualCapacityAmount
            .clamp(0, double.infinity)
            .toDouble();

        return AppPageScaffold(
          maxWidth: 1380,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.s18,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageHeader(
                title: AppStrings.budget.title,
                subtitle: AppStrings.budget.subtitleFull,
              ),
              const SizedBox(height: AppSpacing.md),
              _PlannerTopBar(
                selectedMonth: selectedMonth,
                dirty: _dirty,
                saving: _savingPlan,
                onPrevMonth: () => _changeMonth(-1),
                onNextMonth: () => _changeMonth(1),
                onSave: totals.overLimit
                    ? null
                    : () => _savePlan(stats, totals),
                onReset: () => setState(() => _syncDraft(stats, force: true)),
              ),
              const SizedBox(height: 12),
              _PlannerHero(
                inputVersion: inputVersion,
                disposable: disposable.toDouble(),
                manualPercent: totals.manualPercent,
                manualAmount: totals.manualAmount,
                manualCapacityPercent: totals.manualCapacityPercent,
                manualCapacityAmount: totals.manualCapacityAmount,
                autoPercent: totals.autoPercent,
                autoAmount: totals.autoAmount,
                totalPercent: totals.totalPercent,
                totalAmount: totals.totalAmount,
                remainingPercent: totals.remainingPercent,
                remainingAmount: totals.remainingAmount,
                copiedFrom: stats.budgetPlan.copiedFrom,
                grossReferenceIncome: grossReferenceIncome,
                manualCommittedAmount: manualCommittedAmount,
                useGrossIncomeBase: _useGrossIncomeBase,
                onUseGrossIncomeBaseChanged: (value) =>
                    _applyDisposablePreset(stats, grossMode: value),
                onDisposableChanged: (raw) {
                  setState(() {
                    _dirty = true;
                    _draftError = null;
                    _draftDisposableIncome = _parseNumber(
                      raw,
                    ).clamp(0, double.infinity).toDouble();
                  });
                },
              ),
              const SizedBox(height: 10),
              _SavingsQuickCard(
                disposableIncome: disposableForSavings,
                onCreateGoal: () => _createSavingsGoalFromBudget(
                  selectedMonth: selectedMonth,
                  disposableIncome: disposableForSavings,
                ),
                onOpenGoals: () => context.go('/goals'),
              ),
              if (totals.autoAmount > 0) ...[
                const SizedBox(height: 10),
                _AutoReserveCard(
                  autoAmount: totals.autoAmount,
                  autoPercent: totals.autoPercent,
                  groups: autoByGroups,
                ),
              ],
              if (_draftError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _draftError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    AppStrings.budget.allocationByGroup(rows.length),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDisabled,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHeader,
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ToggleButton(
                          icon: Icons.grid_view_rounded,
                          isActive: isCards,
                          onTap: () =>
                              ref.read(_viewModeProvider.notifier).state = true,
                        ),
                        _ToggleButton(
                          icon: Icons.format_list_bulleted,
                          isActive: !isCards,
                          onTap: () =>
                              ref.read(_viewModeProvider.notifier).state =
                                  false,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    totals.overLimit
                        ? AppStrings.budget.overLimitMsg
                        : AppStrings.budget.manualPctLabel(
                            totals.manualPercent.toStringAsFixed(1),
                            totals.manualCapacityPercent.toStringAsFixed(1),
                          ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: totals.overLimit
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (isCards)
                _CardsLayout(
                  inputVersion: inputVersion,
                  rows: rows,
                  onModeChanged: _setGroupMode,
                  onValueChanged: _setGroupValue,
                )
              else
                _ListLayout(
                  inputVersion: inputVersion,
                  rows: rows,
                  onModeChanged: _setGroupMode,
                  onValueChanged: _setGroupValue,
                ),
            ],
          ),
        );
      },
    );
  }
}
