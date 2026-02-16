import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/company_profile.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class CompanyProfileHeader extends StatelessWidget {
  final CompanyProfile profile;

  const CompanyProfileHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: (profile.logo ?? '').isNotEmpty
                ? NetworkImage(profile.logo!)
                : null,
            child: (profile.logo ?? '').isEmpty
                ? Text(
                    profile.ticker.isEmpty ? '?' : profile.ticker[0],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    profile.ticker,
                    profile.sector,
                    profile.exchange,
                  ].where((v) => (v ?? '').isNotEmpty).join(' | '),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          if (profile.marketCap != null)
            Text(
              'MCAP: ${profile.marketCap!.toStringAsFixed(0)}B',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
