import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/features/accounts/providers/accounts_provider.dart';
import 'package:solver/features/budget/providers/budget_provider.dart';

// ── Toggle provider ─────────────────────────────────────────────────────────
final _viewModeProvider = StateProvider<bool>((ref) => true); // true = grid

// ── Category colours & icons (cycle) ────────────────────────────────────────
const _catColors = <Color>[
  Color(0xFFF97316), // orange
  Color(0xFF3B82F6), // blue
  Color(0xFFA855F7), // purple
  Color(0xFF14B8A6), // teal
  Color(0xFF10B981), // emerald
  Color(0xFFEF4444), // red
  Color(0xFF06B6D4), // cyan
  Color(0xFFF59E0B), // amber
];

const _catBgColors = <Color>[
  Color(0xFFFFF7ED), // orange-50
  Color(0xFFEFF6FF), // blue-50
  Color(0xFFFAF5FF), // purple-50
  Color(0xFFF0FDFA), // teal-50
  Color(0xFFECFDF5), // emerald-50
  Color(0xFFFEF2F2), // red-50
  Color(0xFFECFEFF), // cyan-50
  Color(0xFFFFFBEB), // amber-50
];

const _catIcons = <IconData>[
  Icons.shopping_bag_outlined,
  Icons.trending_up,
  Icons.restaurant_outlined,
  Icons.flight_takeoff,
  Icons.fitness_center,
  Icons.home_outlined,
  Icons.directions_car_outlined,
  Icons.local_hospital_outlined,
];

class BudgetView extends ConsumerWidget {
  const BudgetView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(budgetStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Erreur: $e',
            style: const TextStyle(color: AppColors.danger)),
      ),
      data: (stats) => LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSection(stats: stats, maxWidth: constraints.maxWidth),
                    const SizedBox(height: 12),
                    _ToolBar(stats: stats),
                    const SizedBox(height: 24),
                    _BudgetBody(stats: stats, maxWidth: constraints.maxWidth),
                    const SizedBox(height: 32),
                    _FooterCta(stats: stats),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO SECTION
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  final BudgetStats stats;
  final double maxWidth;
  const _HeroSection({required this.stats, required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final isPositive = stats.disposableIncome >= 0;
    final incomeRatio = stats.averageIncome > 0 ? 1.0 : 0.0;
    final fixedRatio = stats.averageIncome > 0
        ? (stats.fixedExpensesTotal / stats.averageIncome).clamp(0.0, 1.0)
        : 0.0;
    final isWide = maxWidth > 700;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: isWide
          ? Row(
              children: [
                _heroAmount(isPositive),
                const SizedBox(width: 48),
                Container(width: 1, height: 64, color: AppColors.borderSubtle),
                const SizedBox(width: 48),
                Expanded(
                    child:
                        _heroBars(incomeRatio, fixedRatio)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroAmount(isPositive),
                const SizedBox(height: 24),
                _heroBars(incomeRatio, fixedRatio),
              ],
            ),
    );
  }

  Widget _heroAmount(bool isPositive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESTE A VIVRE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textDisabled,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              AppFormats.currencyRaw.format(stats.disposableIncome),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: isPositive ? AppColors.primary : AppColors.danger,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'CHF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isPositive ? AppColors.primary : AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroBars(double incomeRatio, double fixedRatio) {
    return Column(
      children: [
        _HeroBar(
          label: 'Revenu moyen (3 mois)',
          ratio: incomeRatio,
          amount: AppFormats.currencyCompact.format(stats.averageIncome),
          color: AppColors.primary,
          amountColor: AppColors.textPrimary,
        ),
        const SizedBox(height: 16),
        _HeroBar(
          label: 'Charges fixes',
          ratio: fixedRatio,
          amount: '- ${AppFormats.currencyCompact.format(stats.fixedExpensesTotal)}',
          color: AppColors.primaryDark,
          amountColor: AppColors.textDisabled,
        ),
      ],
    );
  }
}

class _HeroBar extends StatelessWidget {
  final String label;
  final double ratio;
  final String amount;
  final Color color;
  final Color amountColor;

  const _HeroBar({
    required this.label,
    required this.ratio,
    required this.amount,
    required this.color,
    required this.amountColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(amount,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: amountColor)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOOLBAR (toggle + add button)
// ═══════════════════════════════════════════════════════════════════════════════
class _ToolBar extends ConsumerWidget {
  final BudgetStats stats;
  const _ToolBar({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGrid = ref.watch(_viewModeProvider);

    return Row(
      children: [
        Text(
          'SUIVI CE MOIS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textDisabled,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 16),
        // Toggle Grid / List
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToggleButton(
                icon: Icons.grid_view_rounded,
                isActive: isGrid,
                onTap: () =>
                    ref.read(_viewModeProvider.notifier).state = true,
              ),
              _ToggleButton(
                icon: Icons.format_list_bulleted,
                isActive: !isGrid,
                onTap: () =>
                    ref.read(_viewModeProvider.notifier).state = false,
              ),
            ],
          ),
        ),
        const Spacer(),
        // Add category placeholder
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ajouter une catégorie',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Icon(icon,
            size: 20,
            color: isActive ? AppColors.primary : AppColors.textDisabled),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUDGET BODY (switches between grid and list)
// ═══════════════════════════════════════════════════════════════════════════════
class _BudgetBody extends ConsumerWidget {
  final BudgetStats stats;
  final double maxWidth;
  const _BudgetBody({required this.stats, required this.maxWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGrid = ref.watch(_viewModeProvider);
    final accounts = stats.currentMonthSpending;

    if (accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: const Text(
          'Aucun compte de dépenses avec budget défini.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    if (isGrid) {
      return _GridView(accounts: accounts, maxWidth: maxWidth, stats: stats);
    } else {
      return _ListView(accounts: accounts, stats: stats);
    }
  }
}

// ── GRID VIEW ────────────────────────────────────────────────────────────────
class _GridView extends StatelessWidget {
  final List<AccountSpending> accounts;
  final double maxWidth;
  final BudgetStats stats;
  const _GridView(
      {required this.accounts, required this.maxWidth, required this.stats});

  @override
  Widget build(BuildContext context) {
    final crossCount = maxWidth > 1024 ? 3 : (maxWidth > 700 ? 2 : 1);

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (int i = 0; i < accounts.length; i++)
          SizedBox(
            width: (maxWidth - 64 - (crossCount - 1) * 20) / crossCount,
            child: _GridCard(
              spending: accounts[i],
              index: i,
              disposableIncome: stats.disposableIncome,
            ),
          ),
      ],
    );
  }
}

class _GridCard extends ConsumerWidget {
  final AccountSpending spending;
  final int index;
  final double disposableIncome;
  const _GridCard(
      {required this.spending, required this.index, required this.disposableIncome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _catColors[index % _catColors.length];
    final bgColor = _catBgColors[index % _catBgColors.length];
    final icon = _catIcons[index % _catIcons.length];
    final allocationPct =
        disposableIncome > 0 ? (spending.budget / disposableIncome * 100) : 0.0;
    final spentPct =
        spending.budget > 0 ? (spending.spent / spending.budget * 100) : 0.0;
    final isOver = spending.spent > spending.budget && spending.budget > 0;
    final barColor = isOver ? AppColors.primaryDarker : AppColors.primary;
    final barRatio = spending.budget > 0
        ? (spending.spent / spending.budget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + name + max spend
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spending.accountName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(spending.isFixed ? 'Charge fixe' : spending.group,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDisabled)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('MAX SPEND',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDisabled,
                          letterSpacing: -0.5)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        AppFormats.currency.format(spending.budget),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Allocation slider (visual only)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Allocation',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              Text('${allocationPct.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: const Color(0xFFF3F4F6),
              thumbColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: allocationPct.clamp(0, 100),
              min: 0,
              max: 100,
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: 16),

          // Spent progress
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF9FAFB))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Spent: ${AppFormats.currency.format(spending.spent)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          color: isOver
                              ? AppColors.primaryDarker
                              : AppColors.textDisabled),
                    ),
                    Text(
                      '${spentPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOver
                              ? AppColors.primaryDarker
                              : AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barRatio,
                    backgroundColor: const Color(0xFFF9FAFB),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
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

// ── LIST VIEW ────────────────────────────────────────────────────────────────
class _ListView extends StatelessWidget {
  final List<AccountSpending> accounts;
  final BudgetStats stats;
  const _ListView({required this.accounts, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < accounts.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ListRow(
              spending: accounts[i],
              index: i,
              stats: stats,
            ),
          ),
      ],
    );
  }
}

class _ListRow extends ConsumerWidget {
  final AccountSpending spending;
  final int index;
  final BudgetStats stats;
  const _ListRow(
      {required this.spending, required this.index, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _catColors[index % _catColors.length];
    final spentPct =
        spending.budget > 0 ? (spending.spent / spending.budget * 100) : 0.0;
    final isOver = spending.spent > spending.budget && spending.budget > 0;
    final barColor = isOver ? AppColors.primaryDarker : AppColors.primary;
    final barRatio = spending.budget > 0
        ? (spending.spent / spending.budget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Colour bar
          Container(
            width: 5,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 24),
          // Name + type
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spending.accountName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(
                  spending.isFixed
                      ? 'CHARGE FIXE'
                      : spending.group.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDisabled,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Progress bar section
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Allocation: ${AppFormats.currencyCompact.format(spending.spent)} / ${AppFormats.currencyCompact.format(spending.budget)}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOver
                              ? AppColors.primaryDarker
                              : AppColors.textDisabled),
                    ),
                    Text(
                      '${spentPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOver
                              ? AppColors.primaryDarker
                              : AppColors.textDisabled),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barRatio,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Quick allocation buttons (decorative)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickPctBtn(label: '10%'),
              const SizedBox(width: 6),
              _QuickPctBtn(label: '20%'),
              const SizedBox(width: 6),
              _QuickPctBtn(label: '50%'),
            ],
          ),
          const SizedBox(width: 16),
          // Edit button
          GestureDetector(
            onTap: () => _showBudgetDialog(context, ref),
            child: const Text('edit',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDisabled)),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref) {
    final ctrl =
        TextEditingController(text: spending.budget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        title: Text(spending.accountName),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
              labelText: 'Budget (CHF)', prefixText: 'CHF '),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newBudget = double.tryParse(ctrl.text);
              if (newBudget == null) return;
              Navigator.pop(ctx);
              final client = ref.read(apiClientProvider);
              await client.patch(
                '/api/accounts/${spending.accountId}/budget',
                data: {'budget': newBudget},
              );
              ref.invalidate(budgetStatsProvider);
              ref.invalidate(accountsProvider);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }
}

class _QuickPctBtn extends StatelessWidget {
  final String label;
  const _QuickPctBtn({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textDisabled)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER CTA
// ═══════════════════════════════════════════════════════════════════════════════
class _FooterCta extends StatelessWidget {
  final BudgetStats stats;
  const _FooterCta({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalBudgeted = stats.currentMonthSpending.fold<double>(
        0.0, (sum, s) => sum + s.budget);
    final remaining = stats.disposableIncome - totalBudgeted;
    final remainingPct = stats.disposableIncome > 0
        ? (remaining / stats.disposableIncome * 100)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.primaryDarker,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(75)),
            ),
            child: const Icon(Icons.auto_awesome,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Équilibre du budget',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF)),
                    children: [
                      const TextSpan(text: 'Il reste '),
                      TextSpan(
                        text:
                            '${AppFormats.currency.format(remaining)} (${remainingPct.toStringAsFixed(0)}%)',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ' à allouer.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withAlpha(25)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reset',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Auto-Allocation',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
