import 'package:flutter/material.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/widgets/holding_card.dart';

class HoldingList extends StatelessWidget {
  final List<Holding> holdings;
  final Map<String, List<double>> sparklineBySymbol;
  final void Function(Holding)? onTap;
  final void Function(Holding)? onDelete;
  final void Function(Holding)? onArchive;

  const HoldingList({
    super.key,
    required this.holdings,
    this.sparklineBySymbol = const {},
    this.onTap,
    this.onDelete,
    this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    if (holdings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('Aucune position pour le moment.')),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: holdings.length,
      itemBuilder: (context, index) {
        final holding = holdings[index];
        return HoldingCard(
          holding: holding,
          sparklinePrices: sparklineBySymbol[holding.symbol],
          onTap: onTap == null ? null : () => onTap!(holding),
          onDelete: onDelete == null ? null : () => onDelete!(holding),
          onArchive: onArchive == null ? null : (_) => onArchive!(holding),
        );
      },
    );
  }
}
