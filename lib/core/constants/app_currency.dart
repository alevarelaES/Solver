enum AppCurrency { chf, eur, usd }

extension AppCurrencyX on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.chf:
        return 'CHF';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.usd:
        return 'USD';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.chf:
        return 'CHF';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.usd:
        return '\$';
    }
  }

  String get locale {
    switch (this) {
      case AppCurrency.chf:
        return 'fr_CH';
      case AppCurrency.eur:
        return 'fr_FR';
      case AppCurrency.usd:
        return 'en_US';
    }
  }

  static AppCurrency fromCode(String? code) {
    final normalized = code?.trim().toUpperCase();
    switch (normalized) {
      case 'EUR':
        return AppCurrency.eur;
      case 'USD':
        return AppCurrency.usd;
      case 'CHF':
      default:
        return AppCurrency.chf;
    }
  }
}
