import 'package:flutter/material.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/shared/widgets/glass_container.dart';

class MyCardsSection extends StatelessWidget {
  const MyCardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: AppSpacing.paddingCardCompact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.dashboard.myCards,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              Text(
                AppStrings.dashboard.addNew,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Cards horizontal scroll
          SizedBox(
            height: AppSizes.bankCardHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _BankCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E5C1B), Color(0xFF143306)],
                  ),
                  lastFour: '4930',
                  validFrom: '02/26',
                  validUntil: '02/32',
                  brand: 'VISA',
                ),
                const SizedBox(width: AppSpacing.md),
                _BankCard(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF374151), Color(0xFF1F2937)],
                  ),
                  lastFour: '8821',
                  validFrom: '05/25',
                  validUntil: '05/30',
                  brand: '',
                  opacity: 0.7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  final LinearGradient gradient;
  final String lastFour;
  final String validFrom;
  final String validUntil;
  final String brand;
  final double opacity;

  const _BankCard({
    required this.gradient,
    required this.lastFour,
    required this.validFrom,
    required this.validUntil,
    required this.brand,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: AppSizes.bankCardWidth,
        height: AppSizes.bankCardHeight,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E2E11).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: contactless + brand
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.contactless, color: Colors.white70, size: 20),
                if (brand.isNotEmpty)
                  Text(
                    brand,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            // Card number
            Text(
              AppStrings.dashboard.cardNumber,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '**** **** **** $lastFour',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            // Bottom: dates + CVV
            Row(
              children: [
                _DateLabel(label: AppStrings.dashboard.validFrom, value: validFrom),
                const SizedBox(width: AppSpacing.lg),
                _DateLabel(label: AppStrings.dashboard.validUntil, value: validUntil),
                const Spacer(),
                // CVV dots
                Row(
                  children: List.generate(3, (_) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: const BoxDecoration(
                      color: Colors.white54,
                      shape: BoxShape.circle,
                    ),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  final String label;
  final String value;

  const _DateLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 7,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
