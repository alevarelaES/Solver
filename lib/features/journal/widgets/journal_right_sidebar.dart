import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/dashboard/widgets/market_popular_card.dart';
import 'package:solver/features/dashboard/widgets/pending_invoices_section.dart';
import 'package:solver/features/journal/widgets/bloc_objectifs_panel.dart';

/// Desktop right-sidebar for the Journal view.
/// Stacks: pending invoices → top-priority goals → bios favoris (market).
/// Visible only at ≥ 1280 px (gated by [JournalView]).
class JournalRightSidebar extends StatelessWidget {
  const JournalRightSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          PendingInvoicesSection(),
          SizedBox(height: AppSpacing.md),
          BlocObjectifsPanel(),
          SizedBox(height: AppSpacing.md),
          MarketPopularCard(),
        ],
      ),
    );
  }
}
