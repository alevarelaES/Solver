import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solver/core/config/app_config.dart';
import 'package:solver/core/constants/app_formats.dart';
import 'package:solver/core/providers/exchange_rate_provider.dart';
import 'package:solver/core/router/app_router.dart';
import 'package:solver/core/settings/currency_settings_provider.dart';
import 'package:solver/core/theme/app_theme.dart';

/// Provider for theme mode toggle (light / dark).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env.local');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  if (kIsWeb) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
  }

  runApp(const ProviderScope(child: SolverApp()));
}

class SolverApp extends ConsumerWidget {
  const SolverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currency = ref.watch(appCurrencyProvider);
    AppFormats.setCurrency(currency);

    // Apply exchange rates whenever they load (or currency changes triggers a refresh).
    ref.watch(exchangeRateProvider).whenData(AppFormats.setRates);

    return MaterialApp.router(
      title: 'Solver',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
    );
  }
}
