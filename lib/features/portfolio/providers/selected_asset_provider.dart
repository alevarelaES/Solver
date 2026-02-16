import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/features/portfolio/models/holding.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';

@immutable
class SelectedAsset {
  final String symbol;
  final Holding? holding;
  final WatchlistItem? watchlistItem;

  const SelectedAsset({
    required this.symbol,
    this.holding,
    this.watchlistItem,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedAsset &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

final selectedAssetProvider = StateProvider<SelectedAsset?>((ref) => null);
