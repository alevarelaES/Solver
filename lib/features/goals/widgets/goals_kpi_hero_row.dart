import 'package:flutter/material.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';

class GoalsKpiHeroRow extends StatelessWidget {
  final double cibleTotale;
  final double capitalActuel;

  const GoalsKpiHeroRow({
    super.key,
    required this.cibleTotale,
    required this.capitalActuel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroCard(
            label: 'CIBLE TOTALE',
            amount: cibleTotale,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _HeroCard(
            label: 'CAPITAL ACTUEL',
            amount: capitalActuel,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String label;
  final double amount;

  const _HeroCard({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PremiumAmountText(
            amount: amount,
            currency: 'CHF', // On suppose CHF par défaut ou on pourrait utiliser AppFormats.currencyCode
            variant: PremiumAmountVariant.hero,
            colorCoded: false,
            compact: true,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
