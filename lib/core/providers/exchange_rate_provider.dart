import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/services/exchange_rate_service.dart';

/// Provides exchange rates indexed by [AppCurrency].
/// Base: CHF (value = how many of that currency per 1 CHF).
/// Falls back to 1.0 for all currencies if fetch fails (no conversion).
final exchangeRateProvider =
    FutureProvider<Map<AppCurrency, double>>((ref) async {
  try {
    final service = ExchangeRateService();
    final raw = await service.fetchRatesFromChf();

    return {
      AppCurrency.chf: 1.0,
      AppCurrency.eur: raw['EUR'] ?? 1.0,
      AppCurrency.usd: raw['USD'] ?? 1.0,
    };
  } catch (_) {
    // Offline or API error: no conversion applied.
    return {
      for (final c in AppCurrency.values) c: 1.0,
    };
  }
});
