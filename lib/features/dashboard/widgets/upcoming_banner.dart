import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/schedule/providers/schedule_provider.dart';

class UpcomingBanner extends ConsumerWidget {
  const UpcomingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingTransactionsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return upcomingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.grandTotal == 0) return const SizedBox.shrink();
        final totalCount = data.auto.length + data.manual.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.warning, size: AppSizes.iconSizeSm),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppStrings.dashboard.upcomingBanner(totalCount),
                  style: TextStyle(
                    color: isDark ? AppColors.warning : AppColors.primaryDarker,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                AppFormats.currencyCompact.format(data.grandTotal),
                style: GoogleFonts.robotoMono(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
