import 'package:flutter_test/flutter_test.dart';
import 'package:solver/core/constants/app_formats.dart';

void main() {
  group('AppFormats', () {
    test('currency formats with CHF symbol and 2 decimals', () {
      // fr_CH: "1 234,56 CHF" (comma decimal, space thousands)
      final result = AppFormats.currency.format(1234.56);
      expect(result, contains('CHF'));
      expect(result, contains('234'));
      expect(result, contains(',56'));
    });

    test('currencyCompact formats with CHF symbol and 0 decimals', () {
      final result = AppFormats.currencyCompact.format(1234.56);
      expect(result, contains('CHF'));
      expect(result, contains('235')); // rounded up
      // Should NOT have a comma with decimals
      expect(result.contains(',56'), isFalse);
    });

    test('currencyRaw formats without symbol', () {
      final result = AppFormats.currencyRaw.format(5000);
      expect(result.contains('CHF'), isFalse);
      expect(result, contains('5'));
      expect(result, contains('000'));
    });
  });
}
