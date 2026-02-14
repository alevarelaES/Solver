import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solver/core/constants/app_currency.dart';
import 'package:solver/core/constants/app_formats.dart';

final appCurrencyProvider =
    StateNotifierProvider<AppCurrencyNotifier, AppCurrency>(
      (ref) => AppCurrencyNotifier(),
    );

class AppCurrencyNotifier extends StateNotifier<AppCurrency> {
  AppCurrencyNotifier() : super(AppCurrency.chf) {
    AppFormats.setCurrency(state);
    _load();
  }

  static const _storageKey = 'app_currency_code';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = AppCurrencyX.fromCode(prefs.getString(_storageKey));
    if (loaded != state) {
      state = loaded;
    }
    AppFormats.setCurrency(state);
  }

  Future<void> setCurrency(AppCurrency currency) async {
    if (state == currency) return;
    state = currency;
    AppFormats.setCurrency(currency);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, currency.code);
  }
}
