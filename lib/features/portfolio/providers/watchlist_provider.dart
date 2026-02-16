import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/watchlist_item.dart';

final watchlistProvider = FutureProvider.autoDispose<List<WatchlistItem>>((
  ref,
) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/api/watchlist/');
  final items = response.data?['items'] as List<dynamic>? ?? const [];
  return items
      .whereType<Map<String, dynamic>>()
      .map(WatchlistItem.fromJson)
      .toList();
});

final watchlistMutationsProvider = Provider<WatchlistMutations>(
  (ref) => WatchlistMutations(ref),
);

class WatchlistMutations {
  final Ref _ref;

  const WatchlistMutations(this._ref);

  Future<void> add(AddWatchlistRequest request) async {
    final client = _ref.read(apiClientProvider);
    await client.post('/api/watchlist/', data: request.toJson());
    _ref.invalidate(watchlistProvider);
  }

  Future<void> remove(String id) async {
    final client = _ref.read(apiClientProvider);
    await client.delete('/api/watchlist/$id');
    _ref.invalidate(watchlistProvider);
  }

  Future<void> reorder(List<String> order) async {
    final client = _ref.read(apiClientProvider);
    await client.put('/api/watchlist/reorder', data: {'order': order});
    _ref.invalidate(watchlistProvider);
  }
}

class AddWatchlistRequest {
  final String symbol;
  final String? exchange;
  final String? name;
  final String assetType;

  const AddWatchlistRequest({
    required this.symbol,
    required this.exchange,
    required this.name,
    required this.assetType,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'exchange': exchange,
    'name': name,
    'assetType': assetType,
  };
}
