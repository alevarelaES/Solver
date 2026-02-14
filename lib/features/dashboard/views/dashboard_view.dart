import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/l10n/app_strings.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/models/dashboard_data.dart';
import 'package:solver/features/dashboard/providers/dashboard_provider.dart';
import 'package:solver/features/dashboard/widgets/balance_card.dart';
import 'package:solver/features/dashboard/widgets/expense_breakdown.dart';
import 'package:solver/features/dashboard/widgets/financial_overview_chart.dart';
import 'package:solver/features/dashboard/widgets/kpi_row.dart';
import 'package:solver/features/dashboard/widgets/pending_invoices_section.dart';
import 'package:solver/features/dashboard/widgets/promo_cards.dart';
import 'package:solver/features/dashboard/widgets/recent_activities.dart';
import 'package:solver/features/dashboard/widgets/year_nav_bar.dart';
import 'package:solver/features/transactions/widgets/transaction_form_modal.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(selectedYearProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider(year));

    return dashboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '${AppStrings.dashboard.loadingError}\n$e',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (data) => _DashboardContent(data: data, year: year, ref: ref),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final int year;
  final WidgetRef ref;

  const _DashboardContent({
    required this.data,
    required this.year,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;
    final isCompact = width < AppBreakpoints.tablet;

    return SingleChildScrollView(
      padding: AppSpacing.paddingPage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const YearNavBar(),
              if (isCompact)
                const SizedBox(width: AppSpacing.md)
              else
                ElevatedButton.icon(
                  onPressed: () => showTransactionFormModal(context, ref),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: Text(AppStrings.dashboard.transaction),
                ),
            ],
          ),
          if (isCompact) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showTransactionFormModal(context, ref),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: Text(AppStrings.dashboard.transaction),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          if (isDesktop) _buildDesktopLayout(width) else _buildMobileLayout(),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(double screenWidth) {
    const gap = SizedBox(height: AppSpacing.lg);
    const hGap = SizedBox(width: AppSpacing.xxl);
    final isWide = screenWidth >= AppBreakpoints.wide;

    return Column(
      children: [
        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.leftColumnWidth,
                  child: BalanceCard(data: data),
                ),
                hGap,
                Expanded(child: KpiRow(data: data)),
              ],
            )
            .animate()
            .fadeIn(duration: AppDurations.normal)
            .slideY(begin: 0.05, end: 0),
        gap,
        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.leftColumnWidth,
                  child: ExpenseBreakdown(data: data),
                ),
                hGap,
                Expanded(
                  child: FinancialOverviewChart(data: data, year: year),
                ),
              ],
            )
            .animate()
            .fadeIn(duration: AppDurations.normal, delay: AppDurations.stagger)
            .slideY(begin: 0.05, end: 0),
        gap,
        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.leftColumnWidth,
                  child: const PendingInvoicesSection(),
                ),
                hGap,
                const Expanded(child: RecentActivities()),
                if (isWide) ...[
                  hGap,
                  SizedBox(
                    width: AppSizes.rightSidebarWidth,
                    child: Column(
                      children: const [
                        SolverAiCard(),
                        SizedBox(height: AppSpacing.lg),
                        UpgradeProCard(),
                      ],
                    ),
                  ),
                ],
              ],
            )
            .animate()
            .fadeIn(
              duration: AppDurations.normal,
              delay: AppDurations.stagger * 2,
            )
            .slideY(begin: 0.05, end: 0),
        if (!isWide) ...[
          gap,
          Row(
                children: const [
                  Expanded(child: SolverAiCard()),
                  SizedBox(width: AppSpacing.xxl),
                  Expanded(child: UpgradeProCard()),
                ],
              )
              .animate()
              .fadeIn(
                duration: AppDurations.normal,
                delay: AppDurations.stagger * 3,
              )
              .slideY(begin: 0.05, end: 0),
        ],
      ],
    );
  }

  Widget _buildMobileLayout() {
    const gap = SizedBox(height: AppSpacing.lg);
    int i = 0;

    Widget animated(Widget child) {
      final delay = AppDurations.stagger * i++;
      return child
          .animate()
          .fadeIn(duration: AppDurations.normal, delay: delay)
          .slideY(begin: 0.05, end: 0);
    }

    return Column(
      children: [
        animated(BalanceCard(data: data)),
        gap,
        animated(KpiRow(data: data)),
        gap,
        animated(FinancialOverviewChart(data: data, year: year)),
        gap,
        animated(ExpenseBreakdown(data: data)),
        gap,
        animated(const PendingInvoicesSection()),
        gap,
        animated(const RecentActivities()),
        gap,
        animated(const SolverAiCard()),
        gap,
        animated(const UpgradeProCard()),
      ],
    );
  }
}
