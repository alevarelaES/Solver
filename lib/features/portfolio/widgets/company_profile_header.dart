import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/company_profile.dart';
import 'package:solver/features/portfolio/widgets/asset_logo.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class CompanyProfileHeader extends StatelessWidget {
  final CompanyProfile profile;

  const CompanyProfileHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        children: [
          AssetLogo(
            symbol: profile.ticker,
            assetType: 'stock',
            logoUrl: profile.logo,
            size: 40,
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
              'MCAP: ${_formatMarketCap(profile.marketCap!)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  String _formatMarketCap(double valueInMillions) {
    final absoluteUsd = valueInMillions * 1000000;
    if (absoluteUsd >= 1000000000000) {
      return '\$${(absoluteUsd / 1000000000000).toStringAsFixed(2)}T';
    }
    if (absoluteUsd >= 1000000000) {
      return '\$${(absoluteUsd / 1000000000).toStringAsFixed(2)}B';
    }
    if (absoluteUsd >= 1000000) {
      return '\$${(absoluteUsd / 1000000).toStringAsFixed(1)}M';
    }
    return '\$${absoluteUsd.toStringAsFixed(0)}';
  }
}
