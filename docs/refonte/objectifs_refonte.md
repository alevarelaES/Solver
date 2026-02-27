# Objectifs — Plan de Refonte

> **Réf. image :** `Objectifs.png`
> **Feature path :** `lib/features/goals/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌──────────────────────────────────────────────────────────────────┐
│  Objectifs         [Tabs: Objectifs | Remboursements]            │
├──────────────────────────────────────────────────────────────────┤
│  [KpiHero Row]                                                   │
│  6502 CHF (CIBLE TOTALE)  |  1700 CHF (CAPITAL ACTUEL)          │
├──────────────────────────────────────────────────────────────────┤
│  [StatsStrip]                                                    │
│  Progression 14.0% | Min annuel 935 CHF | 4 Objectifs | Statuts │
├──────────────────────────────────────────────────────────────────┤
│  [GoalCardsGrid]                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                       │
│  │ no 2027  │  │  maroc   │  │ Épargne  │                       │
│  │  32%     │  │   0%     │  │  10%     │                       │
│  │ (donut)  │  │ (donut)  │  │ (donut)  │                       │
│  └──────────┘  └──────────┘  └──────────┘                       │
└──────────────────────────────────────────────────────────────────┘
```

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| KPIs | Simple | 2 hero KPIs côte à côte (grande fonte) |
| Stats | Intégrées aux cards | Strip horizontal dédié |
| Goal cards | Liste ou layout simple | Grid 3 colonnes avec donut centré et grand |
| Tabs | Absent ou basique | Tabs Objectifs / Remboursements en haut |

### 1.3 Éléments "Premium Dark"

- **KpiHero Row** : 2 grandes cartes avec `PremiumAmountText(variant: hero)`.
- **StatsStrip** : ligne de métriques secondaires sur fond `canvasMid`, séparées par `PremiumDivider(direction: Axis.vertical)`.
- **GoalCard** : grand donut centré dans la carte, badges de statut colorés (Actif / En cours / Réussi).
- **Donut de progression** : coloré selon le statut (vert pour actif, gris pour non démarré, bleu pour réussi).
- Fond des cards variante : légèrement différent selon le statut de l'objectif.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `goals_view.dart`

```
GoalsView
├── AppShell
└── Column
    ├── Row
    │   ├── PageHeader("Objectifs")
    │   └── GoalsTabBar(tabs: ['Objectifs','Remboursements'])  ← CRÉER/MODIFIER
    ├── TabBarView
    │   ├── ObjectifsTab                                       ← CRÉER
    │   └── RemboursementsTab                                  ← (existant ou placeholder)
```

### 2.2 `ObjectifsTab` *(nouveau)*

**Fichier :** `lib/features/goals/views/objectifs_tab.dart`

```
ObjectifsTab
└── Column
    ├── GoalsKpiHeroRow          ← CRÉER
    ├── GoalsStatsStrip          ← CRÉER
    └── GoalCardsGrid            ← CRÉER
```

### 2.3 `GoalsKpiHeroRow` *(nouveau)*

**Fichier :** `lib/features/goals/widgets/goals_kpi_hero_row.dart`

```
GoalsKpiHeroRow({
  required double cibleTotale,
  required double capitalActuel,
})
└── Row (2 enfants, équirépartis)
    └── GoalsKpiHeroCard ×2
        └── PremiumCardBase(variant: hero)
            ├── Label (CIBLE TOTALE / CAPITAL ACTUEL)
            ├── PremiumAmountText(variant: hero, currency: 'CHF')
            └── SubLabel (ex: "+12.00 CHF (+1.5%)" pour capitalActuel)
```

### 2.4 `GoalsStatsStrip` *(nouveau)*

**Fichier :** `lib/features/goals/widgets/goals_stats_strip.dart`

```
GoalsStatsStrip({
  required double progressionPercent,
  required double minimumAnnuel,
  required int objectifsCount,
  required Map<String, int> statusCounts,   // {actif: N, cours: N, réussi: N}
})
└── PremiumCardBase(variant: standard, padding: EdgeInsets compact)
    └── Row (mainAxis: spaceAround)
        ├── StatItem("Progression moyenne", "14.0%")
        ├── PremiumDivider(direction: Axis.vertical, height: 32)
        ├── StatItem("Minimum annuel", "935 CHF")
        ├── PremiumDivider(direction: Axis.vertical, height: 32)
        ├── StatItem("Objectifs", "$objectifsCount Actifs")
        ├── PremiumDivider(direction: Axis.vertical, height: 32)
        └── StatusChipRow(statusCounts)      ← pills : Actif / En cours / Réussi
```

### 2.5 `StatusChipRow` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/status_chip_row.dart`

```
StatusChipRow({
  required Map<GoalStatus, int> counts,
})
└── Row (wrap si nécessaire)
    └── StatusChip ×N
        └── PremiumCardBase(variant: chip)
            ├── ColorDot(color: statusColor)
            └── Text("$count Statut")
```

Couleurs : `Actif` → primaryGreen, `En cours` → warning, `Réussi` → info.
**Toutes les couleurs lues depuis AppColors.**

### 2.6 `GoalCardsGrid` *(nouveau)*

**Fichier :** `lib/features/goals/widgets/goal_cards_grid.dart`

```
GoalCardsGrid({required List<SavingGoal> goals})
└── Wrap (spacing: AppSpacing.md, runSpacing: AppSpacing.md)
    └── GoalCard ×N    ← CRÉER/MODIFIER
```

Sur wide screen : 3 colonnes. Sur desktop : 2. Sur mobile : 1.

### 2.7 `GoalCard` *(refonte du widget existant)*

**Fichier :** `lib/features/goals/widgets/goal_card.dart`

```
GoalCard({required SavingGoal goal})
└── PremiumCardBase(
      variant: standard,
      width: 280,   // fixe pour le grid
      showGlow: goal.isCompleted,
      glowColor: AppColors.success,
    )
    └── Column
        ├── Row
        │   ├── Text(goal.name, style: title)
        │   └── GoalStatusChip(goal.status)
        ├── Center
        │   └── GoalProgressDonut(
        │         percent: goal.progressPercent,
        │         size: 100,
        │         color: _colorForStatus(goal.status),
        │         centerLabel: "${goal.progressPercent.round()}%",
        │       )         ← utilise LargeBudgetDonut
        ├── PremiumDivider
        ├── Row (raised / target)
        │   ├── LabelValue("Atteint", goal.currentAmount)
        │   └── LabelValue("Cible", goal.targetAmount)
        └── Row (action buttons)
            ├── OutlineButton("Modifier")
            └── PrimaryButton("Alimenter") si actif
```

### 2.8 `GoalProgressDonut`

Réutilise `LargeBudgetDonut` (défini dans `budget_refonte.md`). Même widget, paramètres adaptés.

---

## 3. Checklist Technique

### Batch G-1 : Composants partagés

```
[ ] G-1.1  Vérifier disponibilité LargeBudgetDonut (Budget)
[ ] G-1.2  Créer StatusChipRow
[ ] G-1.3  Vérifier PremiumDivider vertical disponible
```

### Batch G-2 : Section Hero + Stats

```
[ ] G-2.1  Créer GoalsKpiHeroRow (bind sur goals provider totaux)
[ ] G-2.2  Créer GoalsStatsStrip (bind sur goals stats provider)
[ ] G-2.3  Test : stats reflètent les goals actifs en base
```

### Batch G-3 : Goal Cards Grid

```
[ ] G-3.1  Refondre GoalCard → PremiumCardBase + GoalProgressDonut
[ ] G-3.2  GoalCard : couleur du donut déterminée par statut (via AppColors)
[ ] G-3.3  GoalCard : glow si objectif complété
[ ] G-3.4  Créer GoalCardsGrid (Wrap responsive)
[ ] G-3.5  Test : grid s'adapte en 3/2/1 colonnes selon breakpoints
```

### Batch G-4 : Tab Bar + Remboursements

```
[ ] G-4.1  Créer GoalsTabBar (Objectifs / Remboursements)
[ ] G-4.2  Assembler ObjectifsTab dans TabBarView
[ ] G-4.3  RemboursementsTab : conserver l'implémentation existante ou stub
```

### Batch G-5 : Finitions

```
[ ] G-5.1  Smoke test : ajout d'un objectif → card apparaît dans la grille
[ ] G-5.2  Smoke test : objectif à 100% → glow actif + badge Réussi
[ ] G-5.3  flutter analyze → 0 warning
[ ] G-5.4  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
