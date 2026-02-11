import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_text_styles.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';

class BudgetView extends ConsumerWidget {
  const BudgetView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(budgetStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erreur: $e', style: const TextStyle(color: AppColors.softRed)),
      ),
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Reste à Vivre ──────────────────────────────────────────
            _DisposableIncomeCard(stats: stats),
            const SizedBox(height: 24),

            // ── Suivi ce mois ──────────────────────────────────────────
            const Text(
              'SUIVI CE MOIS',
              style: TextStyle(
                color: AppColors.textDisabled,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            if (stats.currentMonthSpending.isEmpty)
              const Text(
                'Aucun compte de dépenses créé.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...stats.currentMonthSpending.map((s) => _AccountBudgetRow(
                    spending: s,
                    onBudgetUpdated: () {
                      ref.invalidate(budgetStatsProvider);
                      ref.invalidate(accountsProvider);
                    },
                  )),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ─── Disposable income card ───────────────────────────────────────────────────
class _DisposableIncomeCard extends StatelessWidget {
  final BudgetStats stats;
  const _DisposableIncomeCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isPositive = stats.disposableIncome >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reste à Vivre', style: AppTextStyles.bodySmall),
          const SizedBox(height: 6),
          Text(
            AppFormats.currencyCompact.format(stats.disposableIncome),
            style: TextStyle(
              color: isPositive ? AppColors.neonEmerald : AppColors.softRed,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _BudgetDetailRow(
            label: 'Revenu moyen (3 mois)',
            amount: stats.averageIncome,
            color: AppColors.neonEmerald,
          ),
          const SizedBox(height: 6),
          _BudgetDetailRow(
            label: 'Charges fixes',
            amount: stats.fixedExpensesTotal,
            color: AppColors.softRed,
            prefix: '- ',
          ),
        ],
      ),
    );
  }
}

class _BudgetDetailRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final String prefix;

  const _BudgetDetailRow({
    required this.label,
    required this.amount,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        Text(
          '$prefix${AppFormats.currencyCompact.format(amount)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}

// ─── Account budget row ───────────────────────────────────────────────────────
class _AccountBudgetRow extends ConsumerStatefulWidget {
  final AccountSpending spending;
  final VoidCallback onBudgetUpdated;

  const _AccountBudgetRow({
    required this.spending,
    required this.onBudgetUpdated,
  });

  @override
  ConsumerState<_AccountBudgetRow> createState() => _AccountBudgetRowState();
}

class _AccountBudgetRowState extends ConsumerState<_AccountBudgetRow> {
  bool _loading = false;

  void _showBudgetDialog() {
    final ctrl = TextEditingController(
        text: widget.spending.budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(widget.spending.accountName,
            style: const TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: AppColors.textPrimary),
          decoration:
              const InputDecoration(labelText: 'Budget (CHF)', prefixText: 'CHF '),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(ctrl.text);
              if (newBudget == null) return;
              Navigator.pop(ctx);
              await _saveBudget(newBudget);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBudget(double budget) async {
    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.patch(
        '/api/accounts/${widget.spending.accountId}/budget',
        data: {'budget': budget},
      );
      widget.onBudgetUpdated();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.spending;
    final pct = s.budget > 0 ? (s.spent / s.budget).clamp(0.0, 1.0) : 0.0;
    final isOver = s.spent > s.budget && s.budget > 0;
    final barColor = isOver ? AppColors.softRed : AppColors.electricBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isOver ? AppColors.softRed.withAlpha(80) : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.accountName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (s.isFixed)
                      const Text('Fixe', style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              if (_loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                GestureDetector(
                  onTap: _showBudgetDialog,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${AppFormats.currencyCompact.format(s.spent)} / ${AppFormats.currencyCompact.format(s.budget)}',
                            style: TextStyle(
                              color: isOver ? AppColors.softRed : AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (s.budget > 0)
                            Text(
                              '${s.percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: isOver
                                    ? AppColors.softRed
                                    : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_outlined,
                          size: 14, color: AppColors.textDisabled),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.borderSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
