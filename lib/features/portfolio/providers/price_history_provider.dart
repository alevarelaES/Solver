import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/services/api_client.dart';
import 'package:solver/features/portfolio/models/time_series_point.dart';

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

final priceHistoryProvider = FutureProvider.autoDispose
    .family<List<TimeSeriesPoint>, PriceHistoryRequest>((ref, params) async {
      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/history/${params.symbol.toUpperCase()}',
        queryParameters: {
          'interval': params.interval,
          'outputsize': params.outputSize,
        },
      );

      final values = response.data?['values'] as List<dynamic>? ?? const [];
      return values
          .whereType<Map<String, dynamic>>()
          .map(TimeSeriesPoint.fromJson)
          .toList();
    });

final sparklineBatchProvider = FutureProvider.autoDispose
    .family<Map<String, List<TimeSeriesPoint>>, SparklineBatchRequest>((
      ref,
      params,
    ) async {
      final symbols = params.normalizedSymbols;
      if (symbols.isEmpty) return const {};

      final client = ref.read(apiClientProvider);
      final response = await client.get<Map<String, dynamic>>(
        '/api/market/history-batch',
        queryParameters: {
          'symbols': symbols.join(','),
          'interval': params.interval,
          'outputsize': params.outputSize,
        },
      );

      final historiesRaw =
          response.data?['histories'] as Map<String, dynamic>? ?? const {};

      final result = <String, List<TimeSeriesPoint>>{};
      for (final entry in historiesRaw.entries) {
        final list = entry.value as List<dynamic>? ?? const [];
        result[entry.key] = list
            .whereType<Map<String, dynamic>>()
            .map(TimeSeriesPoint.fromJson)
            .toList();
      }

      return result;
    });
