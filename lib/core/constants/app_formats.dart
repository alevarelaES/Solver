import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_currency.dart';

class AppFormats {
  const AppFormats._();

  static AppCurrency _activeCurrency = AppCurrency.chf;

  // Exchange rates: how many of each currency equals 1 CHF.
  static Map<AppCurrency, double> _rates = {
    for (final c in AppCurrency.values) c: 1.0,
  };

  static final _currencyFull = <AppCurrency, NumberFormat>{
    for (final c in AppCurrency.values)
      c: NumberFormat.currency(
        locale: c.locale,
        symbol: c.symbol,
        decimalDigits: 2,
      ),
  };

  static final _currencyCompact = <AppCurrency, NumberFormat>{
    for (final c in AppCurrency.values)
      c: NumberFormat.currency(
        locale: c.locale,
        symbol: c.symbol,
        decimalDigits: 0,
      ),
  };

  static final _currencyRaw = <AppCurrency, NumberFormat>{
    for (final c in AppCurrency.values)
      c: NumberFormat.currency(locale: c.locale, symbol: '', decimalDigits: 0),
  };

  static void setCurrency(AppCurrency currency) {
    _activeCurrency = currency;
  }

  /// Updates the exchange rates used by [fromChf] and [formatFromChf].
  static void setRates(Map<AppCurrency, double> rates) {
    _rates = rates;
  }

  static AppCurrency get activeCurrency => _activeCurrency;
  static String get currencyCode => _activeCurrency.code;
  static String get currencySymbol => _activeCurrency.symbol;

  static NumberFormat get currency => _currencyFull[_activeCurrency]!;
  static NumberFormat get currencyCompact => _currencyCompact[_activeCurrency]!;
  static NumberFormat get currencyRaw => _currencyRaw[_activeCurrency]!;

  /// Converts a CHF amount to the active currency using current exchange rates.
  static double fromChf(double amount) =>
      amount * (_rates[_activeCurrency] ?? 1.0);

  /// Converts a CHF amount to the active currency and formats it (full precision).
  static String formatFromChf(double amount) =>
      currency.format(fromChf(amount));

  /// Converts a CHF amount to the active currency and formats it (compact, 0 decimals).
  static String formatFromChfCompact(double amount) =>
      currencyCompact.format(fromChf(amount));

  /// Returns the exchange rate for a given ISO currency code relative to CHF.
  /// e.g. if rates = {USD: 1.08}, this means 1 CHF = 1.08 USD.
  static double _rateForCode(String code) => switch (code.toUpperCase()) {
        'CHF' => 1.0,
        'EUR' => _rates[AppCurrency.eur] ?? 1.0,
        'USD' => _rates[AppCurrency.usd] ?? 1.0,
        _ => 1.0,
      };

  /// Converts an amount from [sourceCurrencyCode] to the active currency.
  /// First converts to CHF (dividing by source rate), then to active currency.
  static double convertFromCurrency(double amount, String sourceCurrencyCode) {
    final sourceRate = _rateForCode(sourceCurrencyCode);
    final amountInChf = amount / sourceRate;
    return amountInChf * (_rates[_activeCurrency] ?? 1.0);
  }

  /// Converts and formats an amount from [sourceCurrencyCode] to the active currency.
  /// Returns '--' if [amount] is null.
  static String formatFromCurrency(double? amount, String sourceCurrencyCode) {
    if (amount == null) return '--';
    return currency.format(convertFromCurrency(amount, sourceCurrencyCode));
  }
}
