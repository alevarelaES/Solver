import 'package:dio/dio.dart';

/// Fetches exchange rates from open.er-api.com (free, no API key).
/// Base currency: CHF — rates give "how many X per 1 CHF".
class ExchangeRateService {
  final Dio _dio;

  ExchangeRateService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  /// Returns rates from CHF (e.g. {"EUR": 1.062, "USD": 1.132}).
  /// Throws on network / parse error.
  Future<Map<String, double>> fetchRatesFromChf() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://open.er-api.com/v6/latest/CHF',
    );

    final data = response.data;
    if (data == null || data['result'] != 'success') {
      throw Exception('Exchange rate API returned an error: $data');
    }

    final rawRates = data['rates'] as Map<String, dynamic>? ?? {};
    return rawRates.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );
  }
}
