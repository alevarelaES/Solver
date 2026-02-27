# Analyse — Plan de Refonte

> **Réf. image :** `Analyse.png`
> **Feature path :** `lib/features/analysis/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌──────────────────────────────────────────────────────────────────┐
│  Analyse                         [CHF ▼] [Convertir] [+ Nouvelle]│
├──────────────────────────────────────────────────────────────────┤
│  [KpiAnalyseRow]                                                 │
│  INDICE SANTÉ 88.1% | OBJECTIF GLOBAL | FINANCER PROVISIONS     │
│                        (target + chart)  (date: Sept 2038)       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [MainAnalysisChart]                                             │
│  "Net User Total Income vs Expense Growth"                       │
│  Graphique dual-line avec fills teal/rouge + tooltip + date cible│
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  [PrevisionEpargnCard]          │  [FreeCompressionCard]         │
│  +142.14 CHF | 98.1% p.a.      │  indicateur ratio              │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| KPIs | Standard | 3 cartes avec visualisations intégrées (santé en %), KPIs riches |
| Chart principal | Simple | Grand dual-line area chart avec tooltip riche + ligne cible pointillée |
| Bottom row | Absent | 2 cartes analytics (Prévision + Ratio) |

### 1.3 Éléments "Premium Dark"

- **Indice de Santé** : pourcentage affiché très grand (comme un score), avec code couleur (vert = bon, orange = moyen, rouge = mauvais).
- **Chart principal** : deux aires superposées — teal pour revenus, rouge transparent pour dépenses. Tooltip affiche valeurs au survol.
- **Ligne cible pointillée** : date cible `Sept 2038` marquée d'un indicateur vertical.
- **Prévision Épargne** : accent sur le taux de croissance (`98.1% p.a.`) en vert.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `analysis_view.dart`

```
AnalysisView
├── AppShell
└── Column
    ├── PageHeader("Analyse")
    ├── AnalyseKpiRow                         ← CRÉER
    ├── MainAnalysisChartCard                 ← CRÉER
    └── Row
        ├── PrevisionEpargneCard (flex: 1)    ← CRÉER
        └── FreeCompressionCard (flex: 1)     ← CRÉER
```

### 2.2 `AnalyseKpiRow` *(nouveau)*

**Fichier :** `lib/features/analysis/widgets/analyse_kpi_row.dart`

```
AnalyseKpiRow
└── Row (3 enfants, équirépartis)
    ├── HealthIndexCard                    ← CRÉER
    ├── GlobalObjectifCard                 ← CRÉER
    └── FinancerProvisionsCard             ← CRÉER
```

#### `HealthIndexCard`

```
HealthIndexCard({required double healthScore})
└── PremiumCardBase(variant: kpi, showGlow: true, glowColor: _healthColor)
    ├── Label "INDICE DE SANTÉ"
    ├── PremiumAmountText(variant: standard, amount: healthScore, currency: '%')
    └── HealthScoreBar(score: healthScore)   ← barre linéaire colorée
```

`_healthColor` : vert si score > 80, orange si 60-80, rouge si < 60.

#### `GlobalObjectifCard`

```
GlobalObjectifCard({required ObjectifGlobal objectif})
└── PremiumCardBase(variant: kpi)
    ├── Label "OBJECTIF GLOBAL"
    ├── Text(objectif.target) ex: "Target 989"
    └── MiniSparkline(points: objectif.progression)
```

#### `FinancerProvisionsCard`

```
FinancerProvisionsCard({required DateTime targetDate})
└── PremiumCardBase(variant: kpi)
    ├── Label "FINANCER PROVISIONS"
    ├── Text(targetDate, style: large, format: 'MMM yyyy')   ex: "Sept 2038"
    └── MiniSparkline(points: provisionsProgression)
```

### 2.3 `MainAnalysisChartCard` *(nouveau)*

**Fichier :** `lib/features/analysis/widgets/main_analysis_chart_card.dart`

```
MainAnalysisChartCard({
  required List<ChartDataPoint> incomeData,
  required List<ChartDataPoint> expenseData,
  required DateTime targetDate,
})
└── PremiumCardBase(variant: standard)
    └── Column
        ├── Row
        │   ├── Text("Net User Total Income vs Expense Growth")
        │   └── ChartLegend(items: ['Revenus','Dépenses'])   ← CRÉER
        └── DualLineAreaChart(
              incomeData: incomeData,
              expenseData: expenseData,
              incomeColor: AppColors.primary,
              expensesColor: AppColors.danger,
              incomeFillGradient: p.accentLineGradient,
              expenseFillGradient: p.dangerLineGradient,
              targetDate: targetDate,
              showTargetLine: true,
              showTooltip: true,
              height: 300,
            )
```

### 2.4 `DualLineAreaChart` *(nouveau, potentiellement réutilisable)*

**Fichier :** `lib/shared/widgets/dual_line_area_chart.dart`

```
DualLineAreaChart({
  required List<ChartDataPoint> line1Data,
  required List<ChartDataPoint> line2Data,
  required Color line1Color,
  required Color line2Color,
  Gradient? line1FillGradient,
  Gradient? line2FillGradient,
  DateTime? targetDate,          // ligne verticale pointillée
  bool showTargetLine = false,
  bool showTooltip = true,
  double height = 240,
})
```

Basé sur `fl_chart` (LineChart avec `LineTouchData`). Toutes les couleurs passées en paramètre.

### 2.5 `ChartLegend` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/chart_legend.dart`

```
ChartLegend({
  required List<ChartLegendItem> items,  // {label, color}
})
└── Row
    └── ChartLegendItem ×N
        ├── ColorDot(color)
        └── Text(label, style: labelSmall)
```

### 2.6 `PrevisionEpargneCard` *(nouveau)*

**Fichier :** `lib/features/analysis/widgets/prevision_epargne_card.dart`

```
PrevisionEpargneCard({
  required double monthlyChange,
  required double annualRate,
})
└── PremiumCardBase(variant: standard)
    ├── Label "PRÉVISION ÉPARGNE TOTALE"
    ├── PremiumAmountText(
    │     variant: standard,
    │     amount: monthlyChange,
    │     showSign: true,
    │     colorCoded: true,
    │   )
    └── Row
        ├── Text("${annualRate.toStringAsFixed(1)}% p.a.", color: success)
        └── SubLabel("rendement annualisé")
```

### 2.7 `FreeCompressionCard` *(nouveau)*

**Fichier :** `lib/features/analysis/widgets/free_compression_card.dart`

```
FreeCompressionCard({required double ratio})
└── PremiumCardBase(variant: standard)
    ├── Label "FREE COMPRESSION RATIO"
    ├── PremiumAmountText(variant: standard, amount: ratio, currency: '%')
    └── RatioGaugeBar(ratio: ratio)   ← LinearProgressCompact
```

---

## 3. Checklist Technique

### Batch A-1 : Composants partagés

```
[ ] A-1.1  Créer DualLineAreaChart (fl_chart, ligne verticale cible)
[ ] A-1.2  Créer ChartLegend
[ ] A-1.3  Vérifier disponibilité MiniSparkline et LinearProgressCompact
```

### Batch A-2 : KPI Row

```
[ ] A-2.1  Créer HealthIndexCard avec HealthScoreBar
[ ] A-2.2  Créer GlobalObjectifCard
[ ] A-2.3  Créer FinancerProvisionsCard avec date formatée
[ ] A-2.4  Assembler AnalyseKpiRow
[ ] A-2.5  Test : couleur HealthIndexCard change selon le score
```

### Batch A-3 : Chart Principal

```
[ ] A-3.1  Créer MainAnalysisChartCard avec DualLineAreaChart
[ ] A-3.2  Bind sur le provider analysis (données historiques income/expense)
[ ] A-3.3  Implémenter ligne pointillée cible (targetDate)
[ ] A-3.4  Test : tooltip s'affiche au hover/tap
[ ] A-3.5  Test : chart affiché correctement sur 10+ années de données
```

### Batch A-4 : Cards Bottom

```
[ ] A-4.1  Créer PrevisionEpargneCard
[ ] A-4.2  Créer FreeCompressionCard
[ ] A-4.3  Assembler le layout bottom Row
```

### Batch A-5 : Finitions

```
[ ] A-5.1  Smoke test : page se charge sans erreur (données vides = état vide gracieux)
[ ] A-5.2  Smoke test : responsive 1440px / 1024px / 768px
[ ] A-5.3  flutter analyze → 0 warning
[ ] A-5.4  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
