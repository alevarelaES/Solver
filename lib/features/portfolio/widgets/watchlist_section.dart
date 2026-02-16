import 'package:flutter/material.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/widgets/watchlist_tile.dart';
import 'package:solver/shared/widgets/app_panel.dart';

class WatchlistSection extends StatelessWidget {
  final List<WatchlistItem> items;
  final Map<String, List<double>> sparklineBySymbol;
  final VoidCallback? onAdd;
  final void Function(WatchlistItem)? onTap;
  final void Function(WatchlistItem)? onDelete;

  const WatchlistSection({
    super.key,
    required this.items,
    this.sparklineBySymbol = const {},
    this.onAdd,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Watchlist',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (onAdd != null)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: Text('Aucun symbole en watchlist.')),
            )
          else
            ...items.map(
              (item) => WatchlistTile(
                item: item,
                sparklinePrices: sparklineBySymbol[item.symbol],
                onTap: onTap == null ? null : () => onTap!(item),
                onDelete: onDelete == null ? null : () => onDelete!(item),
              ),
            ),
        ],
      ),
    );
  }
}
