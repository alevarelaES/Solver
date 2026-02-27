import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/transactions/models/transaction.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';
import 'package:solver/shared/widgets/premium_card_base.dart';

/// Three KPI cards: Revenus / Dépenses / Net.
/// Layout: label top-left, amount bottom, trend icon top-right.
/// Matches the design reference (large amounts, tinted glassmorphic cards).
class JournalKpiBanner extends ConsumerWidget {
  final List<Transaction> transactions;

  const JournalKpiBanner({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyCode = ref.watch(appCurrencyProvider).code;

    double income = 0;
    double expense = 0;
    for (final tx in transactions) {
      if (tx.isVoided) continue;
      final isEffectivelyIncome = tx.isIncome || tx.amount < 0;
      if (isEffectivelyIncome) {
        income += tx.amount.abs();
      } else {
        expense += tx.amount.abs();
      }
    }
    final net = income - expense;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _KpiCard(
                label: AppStrings.journal.filterIncome,
                amount: income,
                currency: currencyCode,
                icon: Icons.trending_up_rounded,
                accentColor: AppColors.primary,
                showSign: true,
                overrideColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                label: AppStrings.journal.filterExpense,
                amount: -expense,
                currency: currencyCode,
                icon: Icons.trending_down_rounded,
                accentColor: AppColors.danger,
                showSign: true,
                overrideColor: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                label: AppStrings.journal.kpiNet,
                amount: net,
                currency: currencyCode,
                icon: net >= 0
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                accentColor: net >= 0 ? AppColors.primary : AppColors.danger,
                showSign: true,
                colorCoded: true,
                showNetBadge: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final IconData icon;
  final Color accentColor;
  final bool showSign;
  final bool colorCoded;
  final Color? overrideColor;
  final bool showNetBadge;

  const _KpiCard({
    required this.label,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.accentColor,
    this.showSign = false,
    this.colorCoded = false,
    this.overrideColor,
    this.showNetBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCardBase(
      variant: PremiumCardVariant.kpi,
      overrideSurface: accentColor.withAlpha(18),
      overrideBorder: accentColor.withAlpha(46),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: label + icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accentColor.withAlpha(190),
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (showNetBadge) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppStrings.journal.kpiNet.toLowerCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: accentColor.withAlpha(200),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Amount — uses kpi variant = 22 px, w600
          PremiumAmountText(
            amount: amount,
            currency: currency,
            variant: PremiumAmountVariant.standard,
            showSign: showSign,
            colorCoded: colorCoded,
            overrideColor: overrideColor,
          ),
        ],
      ),
    );
  }
}
