import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appLocaleProvider = StateNotifierProvider<AppLocaleNotifier, Locale>(
  (ref) => AppLocaleNotifier(),
);

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier() : super(const Locale('fr')) {
    _load();
  }

  static const _storageKey = 'app_language_code';
  static const _supported = ['fr', 'en', 'de'];

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved != null && _supported.contains(saved)) {
      if (state.languageCode != saved) state = Locale(saved);
      return;
    }
    // No manual preference — auto-detect from device locale.
    final code = PlatformDispatcher.instance.locale.languageCode;
    final resolved = _supported.contains(code) ? code : 'fr';
    if (state.languageCode != resolved) state = Locale(resolved);
  }

  Future<void> setLocale(Locale locale) async {
    if (state.languageCode == locale.languageCode) return;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }
}
