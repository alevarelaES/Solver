# Dashboard — Plan de Refonte

> **Réf. image :** `Dashboard.png`
> **Feature path :** `lib/features/dashboard/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

Structure **Bento Grid 3 colonnes** sur écran large (≥1280px) :

```
┌─────────────────────────────────────────────────────────────────┐
│  SIDEBAR  │          COLONNE PRINCIPALE           │  SIDEBAR D  │
│  (icônes) │                                       │             │
│           │  [BalanceHeroCard]                    │ FactUrgent  │
│           │  [KPI Row ×3]                         │             │
│           │  [FinancialOverviewChart]             │ MesFavoris  │
│           │  [RecentActivities] [GoalsPriority]   │             │
│           │                                       │             │
└─────────────────────────────────────────────────────────────────┘
```

En dessous de la colonne principale (ou en bas-gauche) : bloc profil utilisateur.

### 1.2 Changements Structurels Majeurs

| Élément | Avant (supposé) | Après (image) |
|---------|-----------------|---------------|
| Carte balance | Card simple | Carte style bancaire (gradient dark, numéro masqué, expiry) |
| KPI row | 4 KPIs | 3 KPIs avec mini-sparkline par carte |
| Chart | Chart standard | Chart vert avec tab switcher (Mois / Trimestre / Année / Opérations) |
| Layout bas | Stack vertical | Ligne 60/40 (Transactions + Objectifs) |
| Sidebar droite | Absente ou intégrée | Panneau fixe (Factures Urgentes + Mes Favoris stocks) |

### 1.3 Éléments "Premium Dark"

- `BalanceHeroCard` : fond gradient `#0D1A0B → #1C3016`, texture subtile en filigrane, chiffre en fonte `w200` très fine.
- `KPI row` : 3 cartes avec indicateur de tendance (flèche colorée + mini-sparkline 7 points).
- Chart : aire remplie d'un gradient vert → transparent, glow diffus sur la courbe.
- Right sidebar : fond `canvasMid`, séparation `PremiumDivider` vertical.
- Icône "sparkle" ✦ (bottom-right, décorative, premium indicator).

---

## 2. Arbre des Composants Cibles

### 2.1 Vue Principale — `dashboard_view.dart`

```
DashboardView
├── AppShell (existant, fond → canvasDeep)
└── Responsive layout (Column ou Row selon breakpoint)
    ├── BalanceHeroCard           ← CRÉER
    ├── DashboardKpiRow           ← MODIFIER (KpiCard → PremiumCardBase)
    ├── FinancialOverviewCard     ← MODIFIER (ajouter TabSwitcher)
    ├── Row(
    │   ├── RecentActivitiesCard  ← MODIFIER
    │   └── PriorityGoalsCard     ← MODIFIER
    │   )
    └── UserProfileCard           ← MODIFIER (optionnel, en bas)

+ RightSidebar (sur wide screen) :
    ├── UrgentInvoicesSidebar     ← CRÉER (ou extraire de widget existant)
    └── FavoritesMarketSidebar    ← CRÉER
```

### 2.2 `BalanceHeroCard` *(nouveau)*

**Fichier :** `lib/features/dashboard/widgets/balance_hero_card.dart`

```
BalanceHeroCard
└── PremiumCardBase(variant: hero, showGlow: true, glowColor: primaryGreen)
    └── Column
        ├── Row
        │   ├── Label "MON SOLDE"
        │   └── AccountNumberMask (●●●● ●●●● 3025 / exp 04/22 3221)
        ├── PremiumAmountText(variant: hero, amount: solde, currency: 'CHF')
        ├── Row (Dépôt + Div)
        │   ├── SmallKpiChip("Dépôt")
        │   └── SmallKpiChip("Div")
        └── Row
            ├── MiniDonutChart(percent: 4, size: 64)  ← widget réutilisable
            └── CategoryChipList(chips: [...])        ← liste de pills texte
```

**Données :** bind sur le provider existant de solde principal.

### 2.3 `DashboardKpiRow` — modification

**Fichier :** `lib/features/dashboard/widgets/kpi_row.dart` *(existant à modifier)*

Remplacer `GlassContainer`/`KpiCard` par :

```
DashboardKpiRow
└── Row (3 enfants, équirépartis)
    └── DashboardKpiItem ×3     ← CRÉER (remplace KpiCard dashboard)
        └── PremiumCardBase(variant: kpi)
            └── Column
                ├── Row
                │   ├── Icon(variant coloré)
                │   └── TrendBadge(delta, direction)   ← CRÉER
                ├── PremiumAmountText(variant: standard)
                └── MiniSparkline(points: List<double>)  ← CRÉER
```

### 2.4 `MiniSparkline` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/mini_sparkline.dart`

```
MiniSparkline({
  required List<double> points,   // 7 derniers points
  required Color color,
  double width = 64,
  double height = 24,
})
```
Basé sur `fl_chart` (LineChart), sans axes, sans labels, stroke 1.5px.

### 2.5 `TrendBadge` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/trend_badge.dart`

```
TrendBadge({
  required double percentChange,
  bool showArrow = true,
})
```
Affiche `+X.X%` vert ou `-X.X%` rouge. Lecture couleur via `AppColors.success/danger`.

### 2.6 `FinancialOverviewCard` — modification

**Fichier :** `lib/features/dashboard/widgets/financial_overview_chart.dart` *(existant)*

```
FinancialOverviewCard
└── PremiumCardBase(variant: standard)
    └── Column
        ├── Row
        │   ├── Text "Aperçu Financier"
        │   └── ChartTabSwitcher(tabs: ['Mois','Trimestre','Année','Opérations'])  ← CRÉER
        └── AppAreaChart(
              lineColor: primaryGreen,
              fillGradient: accentLineGradient,     ← depuis PremiumThemeExtension
              showGlow: true
            )
```

### 2.7 `ChartTabSwitcher` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/chart_tab_switcher.dart`

```
ChartTabSwitcher({
  required List<String> tabs,
  required int selectedIndex,
  required ValueChanged<int> onChanged,
})
```
Style : pills compacts, fond `glassSurface`, sélectionné → fond vert primaire.

### 2.8 Right Sidebar

**Fichier :** `lib/features/dashboard/widgets/dashboard_right_sidebar.dart` *(nouveau)*

```
DashboardRightSidebar
└── Column
    ├── UrgentInvoicesPanel       ← CRÉER
    │   └── PremiumCardBase(variant: standard)
    │       ├── SectionHeader "Factures Urgent"
    │       └── UrgentInvoiceItem ×N
    │           └── PremiumCardBase(variant: listItem)
    │               → icon RETARD badge rouge + nom + montant
    └── FavoritesMarketPanel      ← CRÉER
        └── PremiumCardBase(variant: standard)
            ├── SectionHeader "Mes Favoris"
            ├── MarketTickerRow ×N    ← CRÉER
            │   → logo + ticker + prix + sparkline + %change
            └── PremiumDivider (entre items)
```

---

## 3. Checklist Technique

### Batch D-1 : Socle (dépend de Batch 0 architecture)

```
[ ] D-1.1  Vérifier que PremiumCardBase, PremiumAmountText, PremiumDivider sont disponibles
[ ] D-1.2  Vérifier que PremiumThemeExtension est injecté dans ThemeData
```

### Batch D-2 : Nouveaux widgets partagés

```
[ ] D-2.1  Créer lib/shared/widgets/mini_sparkline.dart
           → Test : affiche 7 points sans erreur
[ ] D-2.2  Créer lib/shared/widgets/trend_badge.dart
           → Test : vert pour positif, rouge pour négatif
[ ] D-2.3  Créer lib/shared/widgets/chart_tab_switcher.dart
           → Test : tab sélectionné change la couleur de fond
```

### Batch D-3 : `BalanceHeroCard`

```
[ ] D-3.1  Créer balance_hero_card.dart
           → bind sur le provider de solde existant
           → AccountNumberMask : afficher les 4 derniers chiffres uniquement
           → PremiumAmountText(variant: hero)
           → PremiumCardBase(variant: hero, showGlow: true)
[ ] D-3.2  Remplacer l'ancien widget de balance dans dashboard_view.dart
[ ] D-3.3  Test visuel : gradient visible, glow discret, chiffre en fonte fine
```

### Batch D-4 : KPI Row

```
[ ] D-4.1  Créer DashboardKpiItem (wrapper de PremiumCardBase(variant: kpi))
[ ] D-4.2  Intégrer MiniSparkline et TrendBadge dans DashboardKpiItem
[ ] D-4.3  Modifier kpi_row.dart pour utiliser DashboardKpiItem ×3
           → Revenus / Dépenses / Épargne (retirer le 4ème si existant)
[ ] D-4.4  Vérifier que les données sparkline sont disponibles via provider
           (si non : stub avec données statiques en attente)
```

### Batch D-5 : Chart & Layout bas

```
[ ] D-5.1  Modifier financial_overview_chart.dart
           → Ajouter ChartTabSwitcher
           → Remplacer le container par PremiumCardBase(variant: standard)
           → Adapter les couleurs du chart → accentLineGradient
[ ] D-5.2  Restructurer le bas de dashboard_view.dart
           → Row(children: [RecentActivitiesCard(flex: 3), PriorityGoalsCard(flex: 2)])
[ ] D-5.3  Wrapper RecentActivitiesCard et PriorityGoalsCard dans PremiumCardBase
```

### Batch D-6 : Right Sidebar

```
[ ] D-6.1  Créer dashboard_right_sidebar.dart
[ ] D-6.2  Créer UrgentInvoicesPanel (bind sur le provider schedule/invoices existant)
[ ] D-6.3  Créer FavoritesMarketPanel + MarketTickerRow
           (bind sur les assets favoris du portfolio provider)
[ ] D-6.4  Intégrer DashboardRightSidebar dans dashboard_view.dart
           → Visible uniquement sur wide screen (≥1280px)
           → Masqué/replié sur desktop standard
```

### Batch D-7 : Finitions

```
[ ] D-7.1  Ajouter l'icône décorative ✦ (SparkleIcon) en bottom-right
[ ] D-7.2  Vérifier UserProfileCard en bas-gauche
[ ] D-7.3  Smoke test responsive : 1440px / 1280px / 768px / 375px
[ ] D-7.4  flutter analyze → 0 warning
[ ] D-7.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
