import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/widgets/market_popular_card.dart';
import 'package:solver/features/dashboard/widgets/pending_invoices_section.dart';

class DashboardRightSidebar extends StatelessWidget {
  const DashboardRightSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PendingInvoicesSection(),
        const SizedBox(height: AppSpacing.lg),
        const MarketPopularCard(),
      ],
    );
  }
}
