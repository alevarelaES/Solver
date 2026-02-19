import 'package:dio/dio.dart';

class ExchangeRateSnapshot {
  final Map<String, double> rates;
  final DateTime? updatedAtUtc;
  final String source;

  const ExchangeRateSnapshot({
    required this.rates,
    required this.updatedAtUtc,
    required this.source,
  });
}

/// Fetches exchange rates from open.er-api.com (free, no API key).
/// Base currency: CHF - rates give "how many X per 1 CHF".
class ExchangeRateService {
  final Dio _dio;

  ExchangeRateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  /// Returns rates from CHF (e.g. {"EUR": 1.062, "USD": 1.132}).
  /// Throws on network / parse error.
  Future<Map<String, double>> fetchRatesFromChf() async {
    final snapshot = await fetchSnapshotFromChf();
    return snapshot.rates;
  }

  /// Returns rates + metadata from CHF.
  Future<ExchangeRateSnapshot> fetchSnapshotFromChf() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://open.er-api.com/v6/latest/CHF',
    );

    final data = response.data;
    if (data == null || data['result'] != 'success') {
      throw Exception('Exchange rate API returned an error: $data');
    }

    final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
    final rates = rawRates.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    DateTime? updatedAtUtc;
    final unixTs = data['time_last_update_unix'];
    if (unixTs is num) {
      updatedAtUtc = DateTime.fromMillisecondsSinceEpoch(
        unixTs.toInt() * 1000,
        isUtc: true,
      );
    }

    return ExchangeRateSnapshot(
      rates: rates,
      updatedAtUtc: updatedAtUtc,
      source: 'open.er-api.com',
    );
  }
}
