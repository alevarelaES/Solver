import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/shared/widgets/premium_amount_text.dart';

/// Single compact dashboard bar showing all KPI + stats in one row.
/// Design 2026: glassmorphic panel, accent dots, tight layout.
class GoalsDashboard extends StatelessWidget {
  final double cibleTotale;
  final double capitalActuel;
  final double progressionPercent;
  final double mensuelCumule;
  final int objectifsAtteints;
  final Map<String, int> alertCounts; // e.g. {'Urgence': 1, 'Attention': 2}

  const GoalsDashboard({
    super.key,
    required this.cibleTotale,
    required this.capitalActuel,
    required this.progressionPercent,
    required this.mensuelCumule,
    required this.objectifsAtteints,
    required this.alertCounts,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final progress = (capitalActuel / cibleTotale).clamp(0.0, 1.0);
    final labelColor = isDark ? Colors.white38 : Colors.black38;

    final urgences = alertCounts['Urgence'] ?? 0;
    final attentions = alertCounts['Attention'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.black.withAlpha(6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─── CIBLE TOTALE ───────────────────────────────
          _KpiBlock(
            label: 'Cible totale',
            isDark: isDark,
            child: PremiumAmountText(
              amount: cibleTotale,
              currency: 'CHF',
              variant: PremiumAmountVariant.hero,
              colorCoded: false,
              compact: true,
            ),
          ),
          _Separator(isDark: isDark),

          // ─── CAPITAL ACTUEL ─────────────────────────────
          _KpiBlock(
            label: 'Capital actuel',
            isDark: isDark,
            child: PremiumAmountText(
              amount: capitalActuel,
              currency: 'CHF',
              variant: PremiumAmountVariant.hero,
              colorCoded: false,
              compact: true,
            ),
          ),
          _Separator(isDark: isDark),

          // ─── PROGRESSION BAR ────────────────────────────
          Expanded(
            flex: 3,
            child: _ProgressBlock(
              progress: progress,
              percent: progressionPercent,
              isDark: isDark,
              labelColor: labelColor,
            ),
          ),
          _Separator(isDark: isDark),

          // ─── MENSUEL CUMULÉ ─────────────────────────────
          _StatBlock(
            label: 'Mensuel',
            value: '${mensuelCumule.toInt()} CHF',
            isDark: isDark,
          ),
          _Separator(isDark: isDark),

          // ─── ALERTES ────────────────────────────────────
          _AlertBlock(
            urgences: urgences,
            attentions: attentions,
            isDark: isDark,
          ),
          _Separator(isDark: isDark),

          // ─── ATTEINTS ───────────────────────────────────
          _StatBlock(
            label: 'Atteints',
            value: '$objectifsAtteints',
            isDark: isDark,
            accent: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ─── INTERNAL WIDGETS ──────────────────────────────────────────────────────────

class _Separator extends StatelessWidget {
  final bool isDark;
  const _Separator({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(12),
    );
  }
}

class _KpiBlock extends StatelessWidget {
  final String label;
  final bool isDark;
  final Widget child;

  const _KpiBlock({required this.label, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? accent;

  const _StatBlock({required this.label, required this.value, required this.isDark, this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: accent ?? (isDark ? Colors.white : Colors.black87),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final double progress;
  final double percent;
  final bool isDark;
  final Color labelColor;

  const _ProgressBlock({
    required this.progress,
    required this.percent,
    required this.isDark,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PROGRESSION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: labelColor,
              ),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _AlertBlock extends StatelessWidget {
  final int urgences;
  final int attentions;
  final bool isDark;

  const _AlertBlock({required this.urgences, required this.attentions, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ALERTES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(count: urgences, color: AppColors.danger),
            const SizedBox(width: 10),
            _Dot(count: attentions, color: AppColors.warning),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final int count;
  final Color color;

  const _Dot({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
