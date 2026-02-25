import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/data/portfolio_cache_policy.dart';
import 'package:solver/features/portfolio/models/time_series_point.dart';

const _historyFreshTtl = Duration(minutes: 15);
const _historyMaxStaleAge = Duration(hours: 12);
const _sparklineFreshTtl = Duration(minutes: 10);
const _sparklineMaxStaleAge = Duration(hours: 6);
const _historyBatchApiMaxSymbols = 30;

final _historyCache = <String, TimedCacheEntry<List<TimeSeriesPoint>>>{};
final _sparklineCache =
    <String, TimedCacheEntry<Map<String, List<TimeSeriesPoint>>>>{};

@immutable
class PriceHistoryRequest {
  final String symbol;
  final String interval;
  final int outputSize;

  const PriceHistoryRequest({
    required this.symbol,
    required this.interval,
    required this.outputSize,
  });

  @override
  bool operator ==(Object other) {
    return other is PriceHistoryRequest &&
        other.symbol == symbol &&
        other.interval == interval &&
        other.outputSize == outputSize;
  }

  @override
  int get hashCode => Object.hash(symbol, interval, outputSize);
}

@immutable
class SparklineBatchRequest {
  final List<String> symbols;
  final String interval;
  final int outputSize;

  const SparklineBatchRequest({
    required this.symbols,
    this.interval = '1day',
    this.outputSize = 7,
  });

  List<String> get normalizedSymbols =>
      symbols
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim().toUpperCase())
          .toSet()
          .toList()
        ..sort();

  @override
  bool operator ==(Object other) {
    return other is SparklineBatchRequest &&
        other.interval == interval &&
        other.outputSize == outputSize &&
        listEquals(other.normalizedSymbols, normalizedSymbols);
  }

  @override
  int get hashCode =>
      Object.hash(interval, outputSize, Object.hashAll(normalizedSymbols));
}

final priceHistoryProvider =
    FutureProvider.autoDispose.family<List<TimeSeriesPoint>, PriceHistoryRequest>((
      ref,
      params,
    ) async {
      final client = ref.read(apiClientProvider);
      final normalized = params.symbol.trim().toUpperCase();
      final cacheKey =
          '$normalized|${params.interval.toLowerCase()}|${params.outputSize}';

      final cached = _historyCache[cacheKey];
      if (isCacheFresh(cached, _historyFreshTtl)) {
        return cached!.value;
      }

      try {
        final response = await client.get<Map<String, dynamic>>(
          '/api/market/history-batch',
          queryParameters: {
            'symbols': normalized,
            'interval': params.interval,
            'outputsize': params.outputSize,
          },
        );

        final histories =
            response.data?['histories'] as Map<String, dynamic>? ?? const {};

        final exact = histories[normalized] as List<dynamic>?;
        final fallback =
            exact ??
            (histories.isNotEmpty
                ? histories.values.first as List<dynamic>?
                : const []);

        final parsed = (fallback ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TimeSeriesPoint.fromJson)
            .toList(growable: false);
        if (parsed.isEmpty) {
          if (isCacheUsable(cached, _historyMaxStaleAge)) {
            return cached!.value;
          }
          return const [];
        }
        _historyCache[cacheKey] = TimedCacheEntry(
          value: parsed,
          storedAt: DateTime.now(),
        );
        return parsed;
      } on DioException catch (_) {
        if (isCacheUsable(cached, _historyMaxStaleAge)) {
          return cached!.value;
        }
        return const [];
      }
    });

final sparklineBatchProvider =
    FutureProvider.family<
      Map<String, List<TimeSeriesPoint>>,
      SparklineBatchRequest
    >((ref, params) async {
      final symbols = params.normalizedSymbols;
      if (symbols.isEmpty) return const {};

      final client = ref.read(apiClientProvider);
      final cacheKey =
          '${symbols.join(',')}|${params.interval.toLowerCase()}|${params.outputSize}';
      final cached = _sparklineCache[cacheKey];
      if (isCacheFresh(cached, _sparklineFreshTtl)) {
        return cached!.value;
      }

      try {
        final result = <String, List<TimeSeriesPoint>>{};
        for (final chunk in _chunkSymbols(symbols, _historyBatchApiMaxSymbols)) {
          final response = await client.get<Map<String, dynamic>>(
            '/api/market/history-batch',
            queryParameters: {
              'symbols': chunk.join(','),
              'interval': params.interval,
              'outputsize': params.outputSize,
            },
          );

          final historiesRaw =
              response.data?['histories'] as Map<String, dynamic>? ?? const {};

          for (final entry in historiesRaw.entries) {
            final list = entry.value as List<dynamic>? ?? const [];
            result[entry.key] = list
                .whereType<Map<String, dynamic>>()
                .map(TimeSeriesPoint.fromJson)
                .toList();
          }
        }

        if (result.isEmpty) {
          if (isCacheUsable(cached, _sparklineMaxStaleAge)) {
            return cached!.value;
          }
          return const {};
        }
        _sparklineCache[cacheKey] = TimedCacheEntry(
          value: result,
          storedAt: DateTime.now(),
        );
        return result;
      } on DioException catch (_) {
        if (isCacheUsable(cached, _sparklineMaxStaleAge)) {
          return cached!.value;
        }
        return const {};
      }
    });

Iterable<List<String>> _chunkSymbols(List<String> symbols, int size) sync* {
  if (size <= 0) {
    yield symbols;
    return;
  }

  for (var i = 0; i < symbols.length; i += size) {
    final end = (i + size < symbols.length) ? i + size : symbols.length;
    yield symbols.sublist(i, end);
  }
}
