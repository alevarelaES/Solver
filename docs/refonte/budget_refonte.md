# Budget — Plan de Refonte

> **Réf. image :** `Budget.png`
> **Feature path :** `lib/features/budget/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌─────────────────────────────────────────────────────────────────┐
│  Budget  [Fevr. 2026 ▼]                    [tabs Officiel/Cours]│
├───────────────────────────────┬─────────────────────────────────┤
│  [BudgetGaugeHero]            │  [AbonnementsCard]              │
│  CHF 8350 (jauge circulaire)  │  liste d'abonnements            │
│  1.0% utilisé                 │                                 │
│  Épargne mensuelle            │                                 │
├───────────────────────────────┴─────────────────────────────────┤
│  [ActivitesCard]              │  [AlouementsCard]               │
│  mini charts par catégorie    │  (allocations budgétaires)      │
├───────────────────────────────┴─────────────────────────────────┤
│  [InvestissementsCard]                                          │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| Visualisation budget | Barre de progression ou chiffres | Grande jauge circulaire (donut) centrée |
| Header | Simple | Toggle Officiel / En cours |
| Sections | Liste linéaire | Grid 2 colonnes (Activités + Abonnements, etc.) |
| Activités | Simple liste | Avec mini charts intégrés par catégorie |

### 1.3 Éléments "Premium Dark"

- `BudgetGaugeHero` : grand donut (130px radius), fond `glassSurfaceHero`, graduation en arc vert.
- `BudgetStatusToggle` : pill switch Officiel / En cours, lecture couleur active depuis AppColors.
- Sections : cartes compactes avec `PremiumCardBase(variant: standard)`, séparateurs `PremiumDivider`.
- Mini charts dans Activités : sparklines ou mini-barres, couleur par catégorie.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `budget_view.dart`

```
BudgetView
├── AppShell
└── Column
    ├── PageHeader(title: 'Budget') + PeriodSelector + BudgetStatusToggle
    ├── BudgetGaugeHero                          ← CRÉER
    └── BudgetSectionsGrid                       ← CRÉER
        ├── Row
        │   ├── ActivitesCard (flex: 1)          ← MODIFIER
        │   └── AbonnementsCard (flex: 1)        ← CRÉER
        └── Row
            ├── InvestissementsCard (flex: 1)    ← CRÉER/MODIFIER
            └── AlouementsCard (flex: 1)         ← CRÉER
```

### 2.2 `BudgetGaugeHero` *(nouveau ou refonte)*

**Fichier :** `lib/features/budget/widgets/budget_gauge_hero.dart`

```
BudgetGaugeHero({
  required double budgetTotal,
  required double budgetUsed,
  required double epargne,
})
└── PremiumCardBase(variant: hero)
    └── Row
        ├── Column (textes gauche)
        │   ├── PremiumAmountText(variant: hero, amount: budgetTotal, currency: 'CHF')
        │   ├── Text("X% du budget utilisé")
        │   └── Text("Épargne mensuelle")
        └── LargeBudgetDonut(          ← widget dédié
              percent: usedPercent,
              radius: 60,
              strokeWidth: 10,
              color: primaryGreen si OK, danger si dépassé
            )
```

`LargeBudgetDonut` est distinct de `MiniDonutChart` (taille et style différents).

### 2.3 `LargeBudgetDonut` *(nouveau)*

**Fichier :** `lib/features/budget/widgets/large_budget_donut.dart`

```
LargeBudgetDonut({
  required double percent,
  double radius = 60,
  double strokeWidth = 10,
  Color? color,            // défaut: primaryGreen, danger si >100%
  String? centerLabel,     // texte au centre (optionnel)
})
```
Basé sur `fl_chart` (PieChart ou CustomPainter). Fond de l'arc = `glassBorder` (arc vide visible).

### 2.4 `BudgetStatusToggle` *(nouveau)*

**Fichier :** `lib/features/budget/widgets/budget_status_toggle.dart`

```
BudgetStatusToggle({
  required bool isOfficiel,
  required ValueChanged<bool> onChanged,
})
```
Pill switch 2 états. Fond actif = `primaryGreen`. Même style que `ChartTabSwitcher`.

### 2.5 `ActivitesCard` *(modification)*

**Fichier :** `lib/features/budget/widgets/activites_card.dart`

```
ActivitesCard
└── PremiumCardBase(variant: standard)
    ├── SectionHeader("Activités")
    ├── PremiumDivider
    └── ActiviteItem ×N
        └── PremiumCardBase(variant: listItem)
            ├── CategoryIcon (couleur catégorie)
            ├── Column(name + date range)
            ├── MiniSparkline(points, color)   ← widget partagé
            └── PremiumAmountText(variant: small)
```

### 2.6 `AbonnementsCard` *(nouveau)*

**Fichier :** `lib/features/budget/widgets/abonnements_card.dart`

```
AbonnementsCard
└── PremiumCardBase(variant: standard)
    ├── Row
    │   ├── SectionHeader("Abonnements")
    │   └── TotalAmount
    ├── PremiumDivider
    └── AbonnementItem ×N
        └── PremiumCardBase(variant: listItem)
            ├── ServiceIcon (logo abonnement)
            ├── Column(name + fréquence)
            └── PremiumAmountText(variant: small)
```

### 2.7 `InvestissementsCard` *(nouveau/modification)*

**Fichier :** `lib/features/budget/widgets/investissements_card.dart`

```
InvestissementsCard
└── PremiumCardBase(variant: standard)
    ├── SectionHeader("Investissements")
    ├── PremiumDivider
    └── InvestItem ×N
        └── PremiumCardBase(variant: listItem)
            ├── AssetLogo(size: 24)
            ├── Column(name + catégorie)
            ├── LinearProgressCompact(percent)   ← CRÉER
            └── PremiumAmountText(variant: small)
```

### 2.8 `AlouementsCard` *(nouveau)*

**Fichier :** `lib/features/budget/widgets/alouements_card.dart`

```
AlouementsCard
└── PremiumCardBase(variant: standard)
    ├── SectionHeader("Alouements")
    └── AllocationRow ×N
        ├── ColorDot (couleur catégorie)
        ├── Text(catégorie)
        ├── LinearProgressCompact(percent)
        └── Text(amount)
```

### 2.9 `LinearProgressCompact` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/linear_progress_compact.dart`

```
LinearProgressCompact({
  required double percent,   // 0.0 → 1.0
  Color? color,              // défaut: primaryGreen
  double height = 4,
  double borderRadius = 2,
})
```
Fond = `glassBorder`. Remplissage = couleur paramètre. Aucune valeur en dur.

---

## 3. Checklist Technique

### Batch B-1 : Composants partagés nécessaires

```
[ ] B-1.1  Vérifier disponibilité MiniSparkline (Dashboard)
[ ] B-1.2  Créer LinearProgressCompact
[ ] B-1.3  Créer LargeBudgetDonut
```

### Batch B-2 : Hero Section

```
[ ] B-2.1  Créer BudgetGaugeHero
[ ] B-2.2  Créer BudgetStatusToggle
[ ] B-2.3  Intégrer dans budget_view.dart (remplace header existant)
[ ] B-2.4  Test : jauge passe au rouge si budget dépassé (>100%)
```

### Batch B-3 : Sections grid

```
[ ] B-3.1  Modifier ActivitesCard → PremiumCardBase + MiniSparkline
[ ] B-3.2  Créer AbonnementsCard
[ ] B-3.3  Créer InvestissementsCard
[ ] B-3.4  Créer AlouementsCard
[ ] B-3.5  Assembler BudgetSectionsGrid dans budget_view.dart
           → Responsive : 2 colonnes (≥900px) / 1 colonne (mobile)
```

### Batch B-4 : Finitions

```
[ ] B-4.1  Period selector → lier au provider de période existant
[ ] B-4.2  Toggle Officiel/En cours → lier au provider budget
[ ] B-4.3  Smoke test : changement de mois → valeurs mises à jour
[ ] B-4.4  flutter analyze → 0 warning
[ ] B-4.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
