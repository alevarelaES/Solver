# Phase 2 — Frontend : Page Portfolio Flutter

## Objectif
Créer la page Portfolio dans l'app Flutter avec navigation, providers Riverpod, et widgets d'affichage des positions et de la watchlist.

## Prérequis
- Phase 1 terminée (endpoints backend fonctionnels)
- Les endpoints `/api/portfolio`, `/api/watchlist`, `/api/market/*` répondent correctement

## 1. Structure des fichiers

```
lib/features/portfolio/
├── models/
│   ├── holding.dart              # Modèle holding (position)
│   ├── watchlist_item.dart       # Modèle watchlist
│   ├── portfolio_summary.dart    # Résumé (total value, gain/loss)
│   ├── symbol_search_result.dart # Résultat recherche
│   ├── company_profile.dart      # Profil entreprise (Finnhub)
│   ├── company_news.dart         # Article de news (Finnhub)
│   └── analyst_recommendation.dart # Recommandation analyste (Finnhub)
├── providers/
│   ├── portfolio_provider.dart   # Holdings + summary
│   ├── watchlist_provider.dart   # Watchlist items
│   ├── market_search_provider.dart # Recherche symboles
│   ├── company_profile_provider.dart # Profil entreprise
│   └── company_news_provider.dart    # News + recommandations
├── views/
│   └── portfolio_view.dart       # Page principale
└── widgets/
    ├── portfolio_summary_card.dart    # Carte résumé en haut
    ├── holding_card.dart              # Carte d'une position
    ├── holding_list.dart              # Liste des positions
    ├── watchlist_section.dart         # Section watchlist
    ├── watchlist_tile.dart            # Ligne watchlist
    ├── add_holding_dialog.dart        # Dialog ajout position
    ├── add_watchlist_dialog.dart      # Dialog ajout watchlist
    ├── symbol_search_field.dart       # Champ de recherche avec autocomplete
    ├── mini_sparkline.dart            # Mini graphique inline
    ├── company_profile_header.dart    # En-tête avec logo, secteur, market cap
    ├── news_list.dart                 # Liste des news récentes
    └── analyst_gauge.dart             # Jauge buy/hold/sell analystes
```

## 2. Routing — ajouter la route

### `core/router/app_router.dart`
```dart
// Ajouter dans les routes du ShellRoute :
GoRoute(
  path: '/portfolio',
  pageBuilder: (context, state) => buildFadeTransition(
    state: state,
    child: const PortfolioView(),
  ),
),
```

### `shared/widgets/nav_items.dart`
```dart
// Ajouter l'item de navigation :
NavItem(
  path: '/portfolio',
  label: 'Portfolio',
  icon: Icons.candlestick_chart_outlined,    // ou Icons.show_chart
  selectedIcon: Icons.candlestick_chart,
),
```

**Position dans la nav** : après "Goals" et avant "Analysis", car c'est une extension logique du suivi financier.

## 3. Modèles Dart

### `models/holding.dart`
```dart
class Holding {
  final String id;
  final String symbol;
  final String? name;
  final String? exchange;
  final String assetType;
  final double quantity;
  final double? averageBuyPrice;
  final DateTime? buyDate;
  final String currency;
  final String? notes;

  // Enrichi par le backend (prix live)
  final double? currentPrice;
  final double? changePercent;
  final double? totalValue;
  final double? totalGainLoss;
  final double? totalGainLossPercent;

  Holding({...});

  factory Holding.fromJson(Map<String, dynamic> json) => ...;
}
```

### `models/portfolio_summary.dart`
```dart
class PortfolioSummary {
  final double totalValue;
  final double totalInvested;
  final double totalGainLoss;
  final double totalGainLossPercent;
  final int holdingsCount;

  PortfolioSummary({...});

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) => ...;
}
```

## 4. Providers Riverpod

### `providers/portfolio_provider.dart`
```dart
// Holdings + summary — fetch enrichi avec prix live
final portfolioProvider = FutureProvider.autoDispose<PortfolioData>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/api/portfolio');
  return PortfolioData.fromJson(response.data);
});

// Mutations
final addHoldingProvider = FutureProvider.family.autoDispose<void, AddHoldingRequest>(
  (ref, request) async {
    final client = ref.read(apiClientProvider);
    await client.post('/api/portfolio', data: request.toJson());
    ref.invalidate(portfolioProvider); // refresh la liste
  },
);

final deleteHoldingProvider = FutureProvider.family.autoDispose<void, String>(
  (ref, id) async {
    final client = ref.read(apiClientProvider);
    await client.delete('/api/portfolio/$id');
    ref.invalidate(portfolioProvider);
  },
);
```

### `providers/market_search_provider.dart`
```dart
// Recherche de symboles avec debounce
final symbolSearchQueryProvider = StateProvider<String>((ref) => '');

final symbolSearchProvider = FutureProvider.autoDispose<List<SymbolSearchResult>>((ref) async {
  final query = ref.watch(symbolSearchQueryProvider);
  if (query.length < 2) return [];

  // Debounce 300ms
  await Future.delayed(const Duration(milliseconds: 300));
  if (ref.read(symbolSearchQueryProvider) != query) return [];

  final client = ref.read(apiClientProvider);
  final response = await client.get('/api/market/search', queryParameters: {'q': query});
  return (response.data['results'] as List)
      .map((e) => SymbolSearchResult.fromJson(e))
      .toList();
});
```

## 5. Page principale — `portfolio_view.dart`

### Layout desktop (> 900px)
```
┌──────────────────────────────────────────────────┐
│ Portfolio                               [+ Ajouter] │
├──────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐ │
│ │ RÉSUMÉ : Valeur totale | Gain/Perte | Nb pos │ │
│ └──────────────────────────────────────────────┘ │
├────────────────────────┬─────────────────────────┤
│                        │                         │
│  MES POSITIONS         │  WATCHLIST              │
│                        │                         │
│  ┌──────────────────┐  │  ┌───────────────────┐  │
│  │ AAPL    +2.3%    │  │  │ TSLA    $245.20   │  │
│  │ 10 × $178.50     │  │  │         -1.1%     │  │
│  │ = $1,785  +19%   │  │  ├───────────────────┤  │
│  ├──────────────────┤  │  │ NVDA    $890.50   │  │
│  │ MSFT    +0.8%    │  │  │         +3.2%     │  │
│  │ 5 × $415.20      │  │  └───────────────────┘  │
│  │ = $2,076  +12%   │  │                         │
│  └──────────────────┘  │  [+ Ajouter à la watch]  │
│                        │                         │
└────────────────────────┴─────────────────────────┘
```

### Layout mobile (< 900px)
```
┌──────────────────────┐
│ Portfolio    [+ Ajouter] │
├──────────────────────┤
│ RÉSUMÉ               │
│ $15,420  +28.5%      │
├──────────────────────┤
│ Positions | Watchlist │  ← Tabs
├──────────────────────┤
│ AAPL    10 × $178.50 │
│ $1,785     +19%  +2% │
├──────────────────────┤
│ MSFT     5 × $415.20 │
│ $2,076     +12%  +1% │
└──────────────────────┘
```

### Structure du code
```dart
class PortfolioView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioProvider);

    return portfolio.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur: $err')),
      data: (data) => LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return Column(
            children: [
              // Header avec titre + bouton ajouter
              _buildHeader(context, ref),
              // Carte résumé
              PortfolioSummaryCard(summary: data.summary),
              // Corps : positions + watchlist
              Expanded(
                child: isDesktop
                    ? _buildDesktopLayout(data)
                    : _buildMobileLayout(data),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

## 6. Widgets clés

### `portfolio_summary_card.dart`
Affiche en un coup d'oeil :
- **Valeur totale** du portefeuille (formatée avec devise)
- **Gain/perte total** en valeur et en % (vert/rouge)
- **Nombre de positions**

Utiliser le composant `AppPanel` existant + `KpiCard` pattern pour rester cohérent avec le dashboard.

### `holding_card.dart`
Chaque position affiche :
- Symbole + nom de l'entreprise
- Quantité × prix actuel
- Valeur totale de la position
- Gain/perte depuis l'achat (%, valeur)
- Variation du jour (badge vert/rouge)
- Menu contextuel : Modifier | Archiver | Supprimer

### `symbol_search_field.dart`
Champ de recherche avec autocomplete pour ajouter un symbole :
- Debounce de 300ms
- Affiche symbole, nom, exchange, type
- Sélection → pré-remplit le dialog d'ajout

### `add_holding_dialog.dart`
Dialog pour ajouter une position :
- **Recherche symbole** (obligatoire) — utilise `symbol_search_field`
- **Quantité** (obligatoire)
- **Prix d'achat moyen** (optionnel)
- **Date d'achat** (optionnel)
- **Notes** (optionnel)

## 7. Couleurs et conventions visuelles

```dart
// Réutiliser les patterns existants du projet
// Vert pour gain positif
Color gainColor = AppTokens.success;  // ou Colors.green
// Rouge pour perte
Color lossColor = AppTokens.error;    // ou Colors.red

// Format des variations
String formatChange(double percent) =>
    '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
```

## 8. Gestion du refresh

```dart
// Pull-to-refresh sur mobile
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(portfolioProvider);
    ref.invalidate(watchlistProvider);
  },
  child: ...
)

// Auto-refresh toutes les 5 min (aligné avec le cache backend)
// Utiliser un Timer dans un ConsumerStatefulWidget
Timer.periodic(Duration(minutes: 5), (_) {
  ref.invalidate(portfolioProvider);
});
```

## Checklist Phase 2

- [ ] Créer les modèles Dart (`holding.dart`, `portfolio_summary.dart`, etc.)
- [ ] Créer les providers Riverpod (portfolio, watchlist, search)
- [ ] Ajouter la route `/portfolio` dans `app_router.dart`
- [ ] Ajouter l'item nav dans `nav_items.dart`
- [ ] Créer `portfolio_view.dart` avec layout responsive
- [ ] Créer `portfolio_summary_card.dart`
- [ ] Créer `holding_card.dart` + `holding_list.dart`
- [ ] Créer `watchlist_section.dart` + `watchlist_tile.dart`
- [ ] Créer `symbol_search_field.dart` avec autocomplete
- [ ] Créer `add_holding_dialog.dart`
- [ ] Créer `add_watchlist_dialog.dart`
- [ ] Tester le flow complet : recherche → ajout → affichage avec prix live
- [ ] Vérifier le responsive (desktop + mobile)
