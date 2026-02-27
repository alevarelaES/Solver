# Portfolio — Plan de Refonte

> **Réf. images :** `Portofolio.png` (vue détail actif) + `Portofolio2.png` (vue positions)
> **Feature path :** `lib/features/portfolio/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

Le Portfolio expose **deux vues distinctes** accessibles via un **Tab Bar** :

```
Tab 1 : "Mes Positions"   → Vue synthétique portefeuille + détail actif sélectionné
Tab 2 : "Marché"          → Vue détail d'un actif avec grand chart + carnet d'ordres
Tab 3 : "Investissement"  → (à définir — non visible sur les images)
```

En haut des deux vues : **Ticker Scrollbar** horizontal avec les prix live.

### 1.2 Vue "Marché" (Portofolio.png)

```
┌─────────────────────────────────────────────────────┐
│  [TickerScrollbar]  BTC ETH SOL AAPL TSLA NVDA...  │
├─────────────────────────────────────────────────────┤
│  [AssetHeaderCard]  Bitcoin ●  $2,018.61 CHF  +4.38│
│                     Market Cap / Volume / Diluted   │
├─────────────────────────────────────────────────────┤
│                                                     │
│  [AssetDetailChart]  (grand chart area teal)        │
│                                                     │
├─────────────────────────────────────────────────────┤
│  [OrderBookTable]  Niveau / Quantité / Position...  │
└─────────────────────────────────────────────────────┘
```

### 1.3 Vue "Mes Positions" (Portofolio2.png)

```
┌──────────────────────────────────────────────────────────────────┐
│  [TickerScrollbar]                                               │
│  Tabs: Mes Positions | Marché | Investissement                   │
├────────────────────────────────────┬─────────────────────────────┤
│  [KpiRow ×4]                       │                             │
│  Portefeuille Total / Gain Total / │  [AssetDetailPanel]         │
│  Meilleure Performance / Liquidité │  → Chart + time range       │
├────────────────────────────────────┤  → Analyst Forecasts        │
│  [PositionsTable]                  │  → Mini Carnet d'ordres     │
│  Bitcoin / Ethereum / Solana       │  → Performance Metrics      │
└────────────────────────────────────┴─────────────────────────────┘
```

### 1.4 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| Navigation | Inconnue | Tab Bar 3 onglets au-dessus du contenu |
| Header | Simple | Ticker scrollbar live + AssetHeaderCard avec logo |
| Chart | Existant | Grand format, fond ultra-sombre, glow sur courbe, time range selector |
| Données | N/A | Carnet d'ordres, Analyst Forecasts, Performance Metrics |
| KPI row | Variable | 4 KPIs avec couleur codée (gain = vert/rouge) |

### 1.5 Éléments "Premium Dark"

- **TickerScrollbar** : fond `canvasMid`, texte compact, scrolling infini horizontal.
- **AssetHeaderCard** : fond hero avec logo circulaire de l'actif, prix en fonte `w200`.
- **Chart** : même style que Dashboard (teal area + glow), mais plus grand, avec tooltip.
- **OrderBookTable** : colonnes bid/ask, couleurs vert/rouge pour quantités, `PremiumDivider` entre lignes.
- **Gain Total** : `PremiumAmountText(colorCoded: true)` → rouge si négatif.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `portfolio_view.dart`

```
PortfolioView
├── AppShell
└── Column
    ├── TickerScrollbar              ← CRÉER
    ├── PortfolioTabBar              ← CRÉER (Mes Positions | Marché | Investissement)
    └── TabBarView
        ├── PositionsTabContent      ← CRÉER (layout 2 colonnes)
        ├── MarketTabContent         ← CRÉER (asset detail plein écran)
        └── InvestmentTabContent     ← (placeholder pour phase suivante)
```

### 2.2 `TickerScrollbar` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/ticker_scrollbar.dart`

```
TickerScrollbar({
  required List<TickerItem> items,   // {symbol, price, changePercent}
  double height = 36,
  bool autoScroll = true,
})

TickerItem
└── Row
    ├── Text(symbol, bold)
    ├── PremiumAmountText(variant: small, colorCoded: true)
    └── TrendBadge(percentChange)
```

Animation : scroll horizontal continu via `ScrollController` + `Timer`.

### 2.3 `AssetHeaderCard` *(nouveau)*

**Fichier :** `lib/features/portfolio/widgets/asset_header_card.dart`

```
AssetHeaderCard({required Asset asset})
└── PremiumCardBase(variant: hero)
    └── Row
        ├── AssetLogo(asset, size: 48)   ← CircleAvatar + image réseau
        ├── Column
        │   ├── Text(asset.name) + Text(asset.ticker)
        │   ├── PremiumAmountText(variant: hero, amount: price)
        │   └── TrendBadge(asset.change24h)
        └── AssetMetaRow
            ├── MetaChip("Market Cap", value)
            ├── MetaChip("Volume", value)
            └── MetaChip("Fully Diluted", value)
```

### 2.4 `AssetDetailChart` *(nouveau)*

**Fichier :** `lib/features/portfolio/widgets/asset_detail_chart.dart`

```
AssetDetailChart({required Asset asset})
└── PremiumCardBase(variant: standard)
    └── Column
        ├── TimeRangeSelector(ranges: ['1J','1S','1M','YTD','ALL'])  ← CRÉER
        └── AppAreaChart(
              fillGradient: p.accentLineGradient,
              showTooltip: true,
              showGlow: true,
              height: 280,
            )
```

### 2.5 `TimeRangeSelector` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/time_range_selector.dart`

```
TimeRangeSelector({
  required List<String> ranges,
  required int selectedIndex,
  required ValueChanged<int> onChanged,
})
```
Identique à `ChartTabSwitcher` mais avec tailles compactes. Peut être le même widget.

### 2.6 `PositionsTable` *(nouveau)*

**Fichier :** `lib/features/portfolio/widgets/positions_table.dart`

```
PositionsTable({required List<PortfolioPosition> positions})
└── PremiumCardBase(variant: standard)
    └── Column
        ├── TableHeader (Actif | Quantité | Part | P&L)
        ├── PremiumDivider
        └── PositionRow ×N
            └── PremiumCardBase(variant: listItem, onTap: selectAsset)
                ├── AssetLogo(size: 28)
                ├── Column(name + ticker)
                ├── Text(quantité)
                ├── Text(part %)
                └── PremiumAmountText(colorCoded: true)   ← gain/perte
```

### 2.7 `PortfolioKpiRow` *(nouveau)*

**Fichier :** `lib/features/portfolio/widgets/portfolio_kpi_row.dart`

4 cartes KPI : Portefeuille Total / Gain Total / Meilleure Performance / Réserve de liquidités.

```
PortfolioKpiRow
└── Row ×4
    └── PortfolioKpiCard
        └── PremiumCardBase(variant: kpi)
            ├── Label
            ├── PremiumAmountText(colorCoded: true si gain)
            └── SubLabel (ex: "+12.00 CHF (+1.5%)")
```

### 2.8 `AssetDetailPanel` (vue Mes Positions, colonne droite)

**Fichier :** `lib/features/portfolio/widgets/asset_detail_panel.dart`

```
AssetDetailPanel({required Asset selectedAsset})
└── Column
    ├── AssetDetailChart(asset)
    ├── AnalystForecastsCard      ← CRÉER
    │   └── PremiumCardBase(variant: standard)
    │       └── SentimentGauge + FearGreedGauge
    ├── MiniOrderBookCard         ← CRÉER
    │   └── PremiumCardBase(variant: standard)
    │       └── 2 colonnes (Prix / Quantité) avec couleurs bid/ask
    └── PerformanceMetricsCard    ← CRÉER
        └── PremiumCardBase(variant: standard)
            └── MetricRow ×N (Market Cap, Volume, Circulating Supply...)
```

### 2.9 `OrderBookTable` (vue Marché, bas de page)

**Fichier :** `lib/features/portfolio/widgets/order_book_table.dart`

```
OrderBookTable
└── PremiumCardBase(variant: standard)
    └── DataTable avec colonnes :
        Niveau | Order Livre | Quantité | My Position | Analysé | Complété | Budget
```

---

## 3. Checklist Technique

### Batch P-1 : Socle partagé

```
[ ] P-1.1  Créer lib/shared/widgets/ticker_scrollbar.dart
[ ] P-1.2  Créer lib/shared/widgets/time_range_selector.dart
           (ou réutiliser ChartTabSwitcher du Dashboard si compatible)
[ ] P-1.3  Vérifier que AssetLogo gère image réseau + fallback initiales
```

### Batch P-2 : Tab Bar et navigation

```
[ ] P-2.1  Créer PortfolioTabBar (3 tabs)
[ ] P-2.2  Créer la structure portfolio_view.dart avec TabBarView
[ ] P-2.3  État de l'asset sélectionné via provider (selectedAssetProvider)
```

### Batch P-3 : Vue "Mes Positions"

```
[ ] P-3.1  Créer PortfolioKpiRow avec les 4 KPIs
[ ] P-3.2  Créer PositionsTable avec tap → update selectedAssetProvider
[ ] P-3.3  Créer AssetDetailPanel (colonne droite)
           → AssetDetailChart + AnalystForecastsCard + MiniOrderBookCard + PerformanceMetricsCard
[ ] P-3.4  Layout 2 colonnes (40% positions | 60% détail) sur wide screen
```

### Batch P-4 : Vue "Marché"

```
[ ] P-4.1  Créer AssetHeaderCard
[ ] P-4.2  Créer AssetDetailChart grand format (h: 280)
[ ] P-4.3  Créer OrderBookTable
[ ] P-4.4  Assembler MarketTabContent
```

### Batch P-5 : Finitions

```
[ ] P-5.1  Intégrer TickerScrollbar en haut des deux vues
[ ] P-5.2  Smoke test : navigation entre tabs sans erreur
[ ] P-5.3  Smoke test : sélection d'un actif dans PositionsTable → chart se met à jour
[ ] P-5.4  flutter analyze → 0 warning
[ ] P-5.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
