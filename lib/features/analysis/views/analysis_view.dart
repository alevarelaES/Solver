import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/features/analysis/data/analysis_peer_catalog.dart';
import 'package:solver/features/analysis/providers/analysis_provider.dart';
import 'package:solver/shared/widgets/glass_container.dart';
import 'package:solver/shared/widgets/page_header.dart';
import 'package:solver/shared/widgets/page_scaffold.dart';

part 'analysis_view.kpi.part.dart';
part 'analysis_view.charts.part.dart';
part 'analysis_view.peer.part.dart';

const _monthLabels = [
  'J',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];

class AnalysisView extends ConsumerWidget {
  const AnalysisView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appCurrencyProvider);
    final year = ref.watch(selectedAnalysisYearProvider);
    final dataAsync = ref.watch(analysisDataProvider(year));
    final currentYear = DateTime.now().year;

    return AppPageScaffold(
      scrollable: false,
      maxWidth: 1200,
      child: Column(
        children: [
          AppPageHeader(
            title: AppStrings.analysis.title,
            subtitle: AppStrings.analysis.subtitle,
            trailing: _AnalysisYearControls(
              year: year,
              currentYear: currentYear,
              onPrevious: year > currentYear - 5
                  ? () =>
                        ref.read(selectedAnalysisYearProvider.notifier).state =
                            year - 1
                  : null,
              onNext: year < currentYear
                  ? () =>
                        ref.read(selectedAnalysisYearProvider.notifier).state =
                            year + 1
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppStrings.analysis.error(e),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              data: (data) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StrategicKpiRow(data: data, year: year),
                    const SizedBox(height: AppSpacing.xxxl),
                    _YoYLineChartCard(data: data),
                    const SizedBox(height: AppSpacing.xxxl),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 768;
                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _ProjectedSavingsCard(data: data),
                              ),
                              const SizedBox(width: AppSpacing.xxl),
                              Expanded(child: _PeerComparisonCard(data: data)),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _ProjectedSavingsCard(data: data),
                            const SizedBox(height: AppSpacing.xxl),
                            _PeerComparisonCard(data: data),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisYearControls extends StatelessWidget {
  final int year;
  final int currentYear;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _AnalysisYearControls({
    required this.year,
    required this.currentYear,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavBtn(icon: Icons.chevron_left, onTap: onPrevious),
        const SizedBox(width: AppSpacing.md),
        Text(
          '$year',
          style: TextStyle(
            color: year == currentYear
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _NavBtn(icon: Icons.chevron_right, onTap: onNext),
      ],
    );
  }
}
