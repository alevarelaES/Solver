import 'package:intl/intl.dart';
import 'package:solver/core/constants/app_currency.dart';

class AppFormats {
  const AppFormats._();

  static AppCurrency _activeCurrency = AppCurrency.chf;

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

  static AppCurrency get activeCurrency => _activeCurrency;
  static String get currencyCode => _activeCurrency.code;
  static String get currencySymbol => _activeCurrency.symbol;

  static NumberFormat get currency => _currencyFull[_activeCurrency]!;
  static NumberFormat get currencyCompact => _currencyCompact[_activeCurrency]!;
  static NumberFormat get currencyRaw => _currencyRaw[_activeCurrency]!;
}
