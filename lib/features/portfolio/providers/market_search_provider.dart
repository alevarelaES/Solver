import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/data/portfolio_trending_catalog.dart';
import 'package:solver/features/portfolio/models/symbol_search_result.dart';

final symbolSearchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final symbolSearchProvider =
    FutureProvider.autoDispose<List<SymbolSearchResult>>((ref) async {
      final query = ref.watch(symbolSearchQueryProvider).trim();
      if (query.isEmpty) return const [];

      final localFallback = _localFallbackMatches(query);
      // Keep a set of local symbols so they are never filtered out by price check.
      final localSymbolKeys =
          localFallback.map((l) => l.symbol.toUpperCase()).toSet();
      if (query.length < 2) {
        return localFallback;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (ref.read(symbolSearchQueryProvider).trim() != query) {
        return const [];
      }

      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/search',
        queryParameters: {'q': query, 'limit': 100},
      );

      final list = response.data?['results'] as List<dynamic>? ?? const [];
      final parsed = list
          .whereType<Map<String, dynamic>>()
          .map(SymbolSearchResult.fromJson)
          .toList();

      final merged = _mergeAndDedupe([
        ..._sanitizeSearchResults(parsed),
        ...localFallback,
      ]);
      if (merged.isEmpty) return const [];

      final quoteCandidates = merged.take(35).toList();
      final quoteSymbols = quoteCandidates.map((item) => item.symbol).join(',');
      try {
        final quoteResponse = await client.get<Map<String, dynamic>>(
          '/api/market/quote',
          queryParameters: {'symbols': quoteSymbols},
        );
        final quoteMap =
            quoteResponse.data?['quotes'] as Map<String, dynamic>? ?? const {};
        final quoteBySymbol = <String, ({double price, String? currency})>{};
        for (final entry in quoteMap.entries) {
          final payload = entry.value;
          if (payload is! Map<String, dynamic>) continue;
          final price = _toDouble(payload['price']);
          if (price == null || price <= 0) continue;
          final currency = payload['currency']?.toString();
          quoteBySymbol[entry.key.trim().toUpperCase()] = (
            price: price,
            currency: currency,
          );
        }
        final enriched = merged
            .map((item) {
              final quote = quoteBySymbol[item.symbol.toUpperCase()];
              if (quote == null) return item;
              return item.copyWith(
                lastPrice: quote.price,
                currency: quote.currency,
              );
            })
            .toList(growable: false);

        final symbolsWithPrice = quoteBySymbol.keys.toSet();

        final filtered = enriched
            .where(
              (item) =>
                  // Local catalog hits are always shown (even without live price).
                  localSymbolKeys.contains(item.symbol.toUpperCase()) ||
                  // API-only results only shown when price is confirmed.
                  symbolsWithPrice.contains(item.symbol.toUpperCase()),
            )
            .take(30)
            .toList();
        if (filtered.isNotEmpty) {
          return filtered;
        }
      } catch (_) {
        // Fallback on sanitized list only when quote filtering is unavailable.
      }

      return merged.take(30).toList();
    });

List<SymbolSearchResult> _sanitizeSearchResults(
  List<SymbolSearchResult> input,
) {
  final seen = <String>{};
  final output = <SymbolSearchResult>[];

  for (final item in input) {
    final symbol = item.symbol.trim().toUpperCase();
    final name = item.name.trim();
    if (symbol.isEmpty || name.isEmpty) continue;
    if (symbol.length > 16) continue;
    if (!RegExp(r'^[A-Z0-9._/-]+$').hasMatch(symbol)) continue;
    if (_countChar(symbol, '.') > 1) continue;

    final type = item.type.trim().toLowerCase();
    final keepType =
        type.contains('stock') ||
        type.contains('equity') ||
        type.contains('etf') ||
        type.contains('crypto') ||
        type.contains('forex') ||
        type.contains('fund') ||
        type.contains('index');
    if (!keepType) continue;

    if (!seen.add(symbol)) continue;
    output.add(item);
  }

  return output;
}

List<SymbolSearchResult> _localFallbackMatches(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return const [];

  // Strip to alphanumeric only: "sp500" / "msciworld" / "nasdaq100"
  final stripped = _stripNonAlnum(normalized);
  // Split into words for multi-word queries: "msci world" → ["msci","world"]
  final words = normalized
      .split(RegExp(r'[\s&._\-]+'))
      .where((w) => w.length >= 2)
      .toList();

  final seeds = buildTrendingFallbackAssets();
  final matches = seeds
      .where((seed) {
        final symbol = seed.symbol.toLowerCase();
        final name = (seed.name ?? '').toLowerCase();
        final strippedName = _stripNonAlnum(name);

        // 1. Symbol prefix or contains
        if (symbol.contains(normalized)) return true;
        // 2. Full normalized query in name
        if (name.contains(normalized)) return true;
        // 3. Alphanumeric-stripped match ("sp500" → "spdrsp500etf")
        if (stripped.length >= 3 && strippedName.contains(stripped)) {
          return true;
        }
        // 4. All query words found in name ("msci world" / "s p 500")
        if (words.length >= 2 && words.every((w) => name.contains(w))) {
          return true;
        }
        return false;
      })
      .map(
        (seed) => SymbolSearchResult(
          symbol: seed.symbol,
          name: seed.name ?? seed.symbol,
          exchange: null,
          type: seed.assetType,
          country: null,
        ),
      )
      .toList();

  matches.sort((a, b) {
    final aScore = _searchScore(a, normalized);
    final bScore = _searchScore(b, normalized);
    return bScore.compareTo(aScore);
  });
  return matches.take(15).toList();
}

/// Keeps only lowercase alphanumeric characters — used for fuzzy matching.
String _stripNonAlnum(String text) =>
    text.replaceAll(RegExp(r'[^a-z0-9]'), '');

List<SymbolSearchResult> _mergeAndDedupe(List<SymbolSearchResult> input) {
  final output = <SymbolSearchResult>[];
  final seen = <String>{};
  for (final item in input) {
    final key = item.symbol.trim().toUpperCase();
    if (key.isEmpty || !seen.add(key)) continue;
    output.add(item);
  }
  return output;
}

int _searchScore(SymbolSearchResult item, String query) {
  final symbol = item.symbol.toLowerCase();
  final name = item.name.toLowerCase();
  if (symbol == query) return 100;
  if (name == query) return 95;
  if (symbol.startsWith(query)) return 90;
  if (name.startsWith(query)) return 85;
  if (symbol.contains(query)) return 70;
  if (name.contains(query)) return 60;
  return 0;
}

int _countChar(String text, String charToCount) {
  var count = 0;
  for (final rune in text.runes) {
    if (String.fromCharCode(rune) == charToCount) {
      count++;
    }
  }
  return count;
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
