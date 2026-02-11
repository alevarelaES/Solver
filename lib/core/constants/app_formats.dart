import 'package:intl/intl.dart';

class AppFormats {
  const AppFormats._();

  /// CHF 1'234.56  — full precision, for transaction amounts
  static final currency =
      NumberFormat.currency(locale: 'fr_CH', symbol: 'CHF', decimalDigits: 2);

  /// CHF 1'235  — compact, for totals / KPIs
  static final currencyCompact =
      NumberFormat.currency(locale: 'fr_CH', symbol: 'CHF', decimalDigits: 0);

  /// 1'235  — no symbol, for chart axis labels
  static final currencyRaw =
      NumberFormat.currency(locale: 'fr_CH', symbol: '', decimalDigits: 0);
}
