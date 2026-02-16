import 'package:flutter/material.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/theme/app_theme.dart';
import 'package:solver/core/theme/app_tokens.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';
import 'package:solver/features/portfolio/widgets/mini_sparkline.dart';

class WatchlistTile extends StatelessWidget {
  final WatchlistItem item;
  final List<double>? sparklinePrices;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const WatchlistTile({
    super.key,
    required this.item,
    this.sparklinePrices,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final change = item.changePercent ?? 0;
    final color = change >= 0 ? AppColors.success : AppColors.danger;
    final sign = change >= 0 ? '+' : '';

    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        item.symbol,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: (item.name ?? '').isEmpty
          ? null
          : Text(
              item.name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
      trailing: SizedBox(
        width: 190,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            MiniSparkline(
              prices: sparklinePrices,
              changePercent: change,
              color: color,
              width: 56,
              height: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.currentPrice == null
                      ? '--'
                      : AppFormats.currency.format(item.currentPrice),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '$sign${change.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
