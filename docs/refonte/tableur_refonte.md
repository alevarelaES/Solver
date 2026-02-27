# Plan Stratégique (Tableur) — Plan de Refonte

> **Réf. image :** `Tableur.png`
> **Feature path :** `lib/features/spreadsheet/`

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌──────────────────────────────────────────────────────────────────┐
│  Plan stratégique    [Produit | Prévision | 2026]  [◄ 2025 ►]   │
│  S/B — Prévision annuelle                                        │
├──────────────────────────────────────────────────────────────────┤
│  [SpreadsheetGrid]                                               │
│                                                                  │
│  Catégorie  Jan  Fév★  Mar  Avr  Mai  Jun  Jul  Aug...  Total  │
│  ▼ INVESTISSEMENTS                                               │
│    ■ AAPL           +2 851                               +2 851 │
│    ■ Autres inv.    0                                          0 │
│    ■ BTC/USD        0                                          0 │
│    ...                                                           │
│  TOTAL INVEST.      +4 955                               +4 955 │
│                                                                  │
│  ▼ REVENUS                                                       │
│    ■ Salaire        +1 700                               +1 700 │
│    ...                                                           │
│  TOTAL REVENUS      +14 700                              +14 700 │
└──────────────────────────────────────────────────────────────────┘
```

La colonne active (Fév) est mise en surbrillance avec fond vert.

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| Navigation | Simple | Tabs Produit / Prévision + sélecteur d'année |
| Colonne active | Aucune | Colonne du mois courant surlignée en vert |
| Groupes | Liste plate | Groupes collapsibles (▼ INVESTISSEMENTS, ▼ REVENUS) |
| Lignes totaux | Simple | Style distinct (gras, fond différent) |
| Icônes lignes | Absentes | Icônes de couleur par actif/catégorie |

### 1.3 Éléments "Premium Dark"

- **Header colonne active** : fond `primaryGreen`, texte blanc, `PremiumCardBase` pour la cellule header.
- **Cellule active** : fond `glassBorderAccent` subtil (vert très transparent).
- **Lignes de groupe (TOTAL)** : fond légèrement plus clair, texte gras, pas d'icône.
- **Lignes normales** : `PremiumCardBase(variant: listItem)` alternant avec `PremiumDivider`.
- **Valeurs positives** : `PremiumAmountText(colorCoded: true, showSign: true)`.
- **Valeurs zéro** : couleur secondaire (désaturée), pas de signe.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `spreadsheet_view.dart`

```
SpreadsheetView
├── AppShell
└── Column
    ├── SpreadsheetHeader                    ← CRÉER/MODIFIER
    │   ├── PageHeader("Plan stratégique")
    │   ├── SpreadsheetTabBar(tabs: [Produit, Prévision])
    │   └── YearNavigator                   ← CRÉER
    └── SpreadsheetGrid                     ← CRÉER/MODIFIER (composant principal)
```

### 2.2 `YearNavigator` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/year_navigator.dart`

```
YearNavigator({
  required int selectedYear,
  required ValueChanged<int> onChanged,
})
└── Row
    ├── IconButton(chevron_left) → décrémente
    ├── PremiumCardBase(variant: chip)
    │   └── Text("$selectedYear")
    └── IconButton(chevron_right) → incrémente
```

### 2.3 `SpreadsheetGrid` *(refonte majeure)*

**Fichier :** `lib/features/spreadsheet/widgets/spreadsheet_grid.dart`

C'est le composant le plus complexe. Il utilise un `ScrollController` horizontal + vertical pour permettre le défilement avec colonnes et lignes figées.

```
SpreadsheetGrid({
  required List<SpreadsheetGroup> groups,   // groupes de lignes
  required List<String> columnLabels,       // Jan..Déc + Total
  required int activeColumnIndex,           // mois courant
})
└── Stack
    ├── SpreadsheetColumnHeader             ← CRÉER (barre de colonnes)
    │   └── Row (figée en haut)
    │       ├── CategoryHeaderCell("Catégorie") [figée à gauche]
    │       └── MonthHeaderCell ×13 (12 mois + Total)
    │           └── [si active] → fond primaryGreen
    └── SpreadsheetBody                     ← CRÉER
        └── ListView (vertical, scroll)
            └── SpreadsheetGroupBlock ×N    ← CRÉER
```

### 2.4 `SpreadsheetColumnHeader` *(nouveau)*

**Fichier :** `lib/features/spreadsheet/widgets/spreadsheet_column_header.dart`

```
SpreadsheetColumnHeader({
  required List<String> months,         // ['Jan','Fév','Mar',...,'Total']
  required int activeMonthIndex,        // index de la colonne active
  required double cellWidth,
})
└── Row
    ├── CategoryHeaderCell               ← cellule figée
    └── SingleChildScrollView (horizontal, lié au scroll du body)
        └── Row
            └── MonthHeaderCell ×N
                └── Container(
                      color: isActive ? primaryGreen : transparent,
                      child: Text(month)
                    )
```

### 2.5 `SpreadsheetGroupBlock` *(nouveau)*

**Fichier :** `lib/features/spreadsheet/widgets/spreadsheet_group_block.dart`

```
SpreadsheetGroupBlock({
  required SpreadsheetGroup group,
  required int activeColumnIndex,
  required bool isCollapsed,
  required VoidCallback onToggleCollapse,
})
└── Column
    ├── GroupHeaderRow(group.name, isCollapsed, onToggle)   ← CRÉER
    ├── [si !isCollapsed]
    │   └── SpreadsheetDataRow ×N    ← CRÉER
    └── GroupTotalRow(group.totals)  ← CRÉER
```

### 2.6 `GroupHeaderRow` *(nouveau)*

```
GroupHeaderRow({
  required String name,
  required bool isCollapsed,
  required VoidCallback onTap,
})
└── PremiumCardBase(variant: listItem, onTap: onTap)
    └── Row
        ├── Icon(isCollapsed ? chevron_right : expand_more, size: 14)
        ├── Text(name.toUpperCase(), style: sectionHeader)
        └── [cells vides × 13]
```

### 2.7 `SpreadsheetDataRow` *(nouveau)*

```
SpreadsheetDataRow({
  required SpreadsheetItem item,
  required int activeColumnIndex,
  required double cellWidth,
})
└── PremiumCardBase(variant: listItem)
    └── Row
        ├── CategoryCell(item)              ← icon + label (figée)
        └── SingleChildScrollView(horizontal)
            └── Row
                └── AmountCell ×13
                    └── Container(
                          color: isActive ? glassBorderAccent : transparent,
                          child: item.value != 0
                            ? PremiumAmountText(variant: table, colorCoded: true)
                            : Text("0", style: labelSmall, color: disabled)
                        )
```

### 2.8 `GroupTotalRow` *(nouveau)*

```
GroupTotalRow({
  required String label,          // ex: "TOTAL INVESTISSEMENTS"
  required List<double> totals,   // valeur par colonne
  required int activeColumnIndex,
})
└── Container(
      color: glassSurface lighter,  // fond légèrement différent
      child: Row
          ├── Text(label, style: body bold)   [figée]
          └── AmountCell ×13 (même scroll que le body)
    )
```

### 2.9 Modèle de données — `SpreadsheetGroup`

```
SpreadsheetGroup {
  String name                      // "INVESTISSEMENTS"
  List<SpreadsheetItem> items
  List<double> monthlyTotals       // 12 mois + 1 total
}

SpreadsheetItem {
  String label                     // "AAPL"
  IconData? icon
  Color? iconColor
  List<double> monthlyValues       // 12 valeurs
  double total
}
```

---

## 3. Checklist Technique

### Batch SH-1 : Navigation

```
[ ] SH-1.1  Créer YearNavigator
[ ] SH-1.2  Créer SpreadsheetTabBar (Produit / Prévision)
[ ] SH-1.3  Bind YearNavigator + TabBar sur le provider spreadsheet existant
```

### Batch SH-2 : Header colonnes

```
[ ] SH-2.1  Créer SpreadsheetColumnHeader
[ ] SH-2.2  Implémenter synchronisation du scroll horizontal (header ↔ body)
[ ] SH-2.3  Test : colonne du mois courant surlignée en vert
```

### Batch SH-3 : Lignes et groupes

```
[ ] SH-3.1  Créer GroupHeaderRow (cliquable, toggle collapse)
[ ] SH-3.2  Créer SpreadsheetDataRow (cellule active surlignée)
[ ] SH-3.3  Créer GroupTotalRow (fond distinct, gras)
[ ] SH-3.4  Créer SpreadsheetGroupBlock
[ ] SH-3.5  Test : groupe collapsible fonctionne sans erreur de layout
```

### Batch SH-4 : Assemblage

```
[ ] SH-4.1  Créer SpreadsheetGrid avec scroll horizontal/vertical synchronisé
[ ] SH-4.2  Colonne "Catégorie" figée à gauche (sticky)
[ ] SH-4.3  Intégrer dans spreadsheet_view.dart
[ ] SH-4.4  Test : scroll horizontal ne casse pas la colonne figée
[ ] SH-4.5  Test : 100+ lignes → pas de jank (utiliser ListView.builder)
```

### Batch SH-5 : Finitions

```
[ ] SH-5.1  PremiumAmountText(variant: table) pour tous les montants
[ ] SH-5.2  Vérifier chiffres tabulaires alignés dans les colonnes
[ ] SH-5.3  Smoke test : navigation entre années → données rechargées
[ ] SH-5.4  flutter analyze → 0 warning
[ ] SH-5.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```

---

## 4. Note Architecture — Scroll Synchronisé

Le challenge principal du tableur est la synchronisation du scroll horizontal entre :
1. Le header des colonnes (en haut, figé verticalement)
2. Les lignes de données (scrollables verticalement ET horizontalement)

La colonne "Catégorie" doit rester figée à gauche lors du scroll horizontal.

**Approche recommandée :** `LinkedScrollControllerGroup` (package `linked_scroll_controller`) ou implémentation manuelle avec deux `ScrollController` partageant la même position X.

Toute la logique de synchronisation réside dans `SpreadsheetGrid`, jamais dans les widgets enfants.
