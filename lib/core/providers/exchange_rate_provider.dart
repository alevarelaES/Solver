import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/services/exchange_rate_service.dart';

final rawExchangeRateSnapshotProvider = FutureProvider<ExchangeRateSnapshot>((
  ref,
) async {
  try {
    final service = ExchangeRateService();
    final snapshot = await service.fetchSnapshotFromChf();
    return ExchangeRateSnapshot(
      rates: {'CHF': 1.0, ...snapshot.rates},
      updatedAtUtc: snapshot.updatedAtUtc,
      source: snapshot.source,
    );
  } catch (_) {
    return const ExchangeRateSnapshot(
      rates: {'CHF': 1.0, 'EUR': 1.0, 'USD': 1.0},
      updatedAtUtc: null,
      source: 'open.er-api.com',
    );
  }
});

/// Raw exchange rates from CHF keyed by ISO currency code.
/// Example: {"EUR": 1.06, "USD": 1.12}
final rawExchangeRateProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  final snapshot = await ref.watch(rawExchangeRateSnapshotProvider.future);
  return snapshot.rates;
});

/// Provides exchange rates indexed by [AppCurrency].
/// Base: CHF (value = how many of that currency per 1 CHF).
/// Falls back to 1.0 for all currencies if fetch fails (no conversion).
final exchangeRateProvider = FutureProvider<Map<AppCurrency, double>>((
  ref,
) async {
  final raw = await ref.watch(rawExchangeRateProvider.future);
  return {
    AppCurrency.chf: 1.0,
    AppCurrency.eur: raw['EUR'] ?? 1.0,
    AppCurrency.usd: raw['USD'] ?? 1.0,
  };
});
