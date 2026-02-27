# Journal des Transactions — Plan de Refonte

> **Réf. image :** `Transactions.png`
> **Feature path :** `lib/features/journal/` (ou `transactions/`)

---

## 1. Analyse Visuelle

### 1.1 Layout Global

```
┌──────────────────────────────────────────────────────────────────┐
│  Journal des Transactions                                        │
│  [Recherche]   [Mois courant (Février) ▼]   [+ Nouvelle écriture]│
├────────────────────────────────────┬─────────────────────────────┤
│  [KPI Banner Row]                  │                             │
│  REVENU +4600 | DÉPENSES -200 | NET│  [FacturesUrgentPanel]      │
├────────────────────────────────────┤                             │
│                                    │  [BlocObjectifsPanel]       │
│  [TransactionsTable]               │                             │
│  Date | Libellé | Groupe | Montant │  [BiosFavorisPanel]         │
│                                    │                             │
└────────────────────────────────────┴─────────────────────────────┘
```

### 1.2 Changements Structurels Majeurs

| Élément | Avant | Après |
|---------|-------|-------|
| Header KPIs | Barre ou cards simples | 3 KPI cards colorées (REVENU vert / DÉPENSES rouge / NET neutre) |
| Table | Standard | Colonnes avec badge "Groupes" colorés + montants colorés |
| Layout | Colonne simple | 2 colonnes : table principale (75%) + right sidebar (25%) |
| Right sidebar | Absent | Factures Urgentes + Bloc Objectifs + Bios Favoris |

### 1.3 Éléments "Premium Dark"

- **KPI Banner** : 3 cartes compactes avec indicateur fléché et montant coloré.
- **Table** : fond alterné via `PremiumCardBase(variant: listItem)`, groupes en pills colorées.
- **Badge Groupes** : `PremiumCardBase(variant: chip)` avec couleur de fond par groupe (Activités = orange, Investissements = vert, Revenus = bleu...).
- **Montants** : `PremiumAmountText(colorCoded: true, showSign: true)`.
- **Right sidebar** : identique au Dashboard — réutilisation directe des mêmes composants.

---

## 2. Arbre des Composants Cibles

### 2.1 Vue principale — `journal_view.dart` (ou `transactions_view.dart`)

```
JournalView
├── AppShell
└── Column
    ├── JournalHeader                    ← MODIFIER
    │   ├── PageHeader("Journal des Transactions")
    │   ├── Row
    │   │   ├── SearchBar
    │   │   ├── PeriodFilterDropdown     ← CRÉER/MODIFIER
    │   │   └── PrimaryButton("+ Nouvelle écriture")
    ├── Row (main + sidebar)
    │   ├── Column (flex: 3)
    │   │   ├── JournalKpiBanner         ← CRÉER
    │   │   └── TransactionsTable        ← MODIFIER
    │   └── JournalRightSidebar (flex: 1) ← CRÉER
    │       ├── FacturesUrgentPanel      ← réutiliser du Dashboard
    │       ├── BlocObjectifsPanel       ← CRÉER
    │       └── BiosFavorisPanel         ← réutiliser du Dashboard (FavoritesMarket)
```

### 2.2 `JournalKpiBanner` *(nouveau)*

**Fichier :** `lib/features/journal/widgets/journal_kpi_banner.dart`

```
JournalKpiBanner({
  required double revenu,
  required double depenses,
  required double net,
})
└── Row (3 enfants, équirépartis)
    └── JournalKpiCard ×3
        └── PremiumCardBase(variant: kpi)
            ├── Label (REVENU / DÉPENSES / NET)
            ├── PremiumAmountText(
            │     variant: standard,
            │     colorCoded: true,
            │     showSign: true,
            │   )
            └── TrendIndicatorIcon (flèche haut/bas)
```

Note : la carte REVENU a une icône flèche verte montante, DÉPENSES rouge descendante, NET neutre.

### 2.3 `TransactionsTable` *(modification)*

**Fichier :** `lib/features/journal/widgets/transactions_table.dart`

```
TransactionsTable({required List<Transaction> transactions})
└── PremiumCardBase(variant: standard)
    └── Column
        ├── TableHeader (Date | Libellé | Groupes | Montant)
        ├── PremiumDivider
        └── TransactionRow ×N
            └── PremiumCardBase(variant: listItem)
                ├── Text(date, style: labelSmall)
                ├── Row
                │   ├── TransactionIcon (couleur par type)
                │   └── Text(libellé)
                ├── GroupBadge(group)               ← CRÉER
                └── PremiumAmountText(
                      variant: small,
                      colorCoded: true,
                      showSign: true,
                    )
```

### 2.4 `GroupBadge` *(nouveau, réutilisable)*

**Fichier :** `lib/shared/widgets/group_badge.dart`

```
GroupBadge({
  required String label,
  Color? color,        // si null → dérive de la couleur de groupe depuis un Map centralisé
})
└── PremiumCardBase(variant: chip)
    └── Text(label, style: labelSmall)
```

La map `groupColors` est centralisée dans `lib/core/constants/group_colors.dart` ou dans le catalogue de catégories. **Jamais en dur dans le widget.**

### 2.5 `JournalRightSidebar` *(nouveau)*

**Fichier :** `lib/features/journal/widgets/journal_right_sidebar.dart`

```
JournalRightSidebar
└── Column
    ├── FacturesUrgentPanel    ← réutiliser le composant créé pour le Dashboard
    ├── SizedBox(height: AppSpacing.md)
    ├── BlocObjectifsPanel     ← CRÉER
    │   └── PremiumCardBase(variant: standard)
    │       ├── SectionHeader("Bloc Objectifs")
    │       └── ObjectifProgressRow ×N
    │           ├── Text(objectif.name)
    │           ├── LinearProgressCompact(percent)
    │           └── Text("X/Y")
    └── BiosFavorisPanel       ← réutiliser FavoritesMarketSidebar (Dashboard)
```

### 2.6 `PeriodFilterDropdown` *(modification/création)*

**Fichier :** `lib/shared/widgets/period_filter_dropdown.dart`

```
PeriodFilterDropdown({
  required String selectedLabel,
  required VoidCallback onTap,
})
└── PremiumCardBase(variant: chip, onTap: onTap)
    └── Row
        ├── Text(selectedLabel)
        └── Icon(chevron_down, size: AppTokens.iconSizeSmall)
```

---

## 3. Checklist Technique

### Batch T-1 : Widgets partagés nécessaires

```
[ ] T-1.1  Vérifier disponibilité LinearProgressCompact (Budget)
[ ] T-1.2  Créer GroupBadge
[ ] T-1.3  Créer/vérifier FacturesUrgentPanel (Dashboard) — réutilisable
[ ] T-1.4  Créer/vérifier FavoritesMarketSidebar (Dashboard) — réutilisable
```

### Batch T-2 : KPI Banner

```
[ ] T-2.1  Créer JournalKpiBanner
[ ] T-2.2  Bind sur le provider journal (totaux revenu/dépenses/net par période)
[ ] T-2.3  Test : changement de mois → valeurs recalculées
```

### Batch T-3 : Table principale

```
[ ] T-3.1  Modifier TransactionsTable → PremiumCardBase + GroupBadge + PremiumAmountText
[ ] T-3.2  Vérifier le tri par date (actuel) conservé
[ ] T-3.3  Test : transactions positives en vert, négatives en rouge
```

### Batch T-4 : Right Sidebar + Layout

```
[ ] T-4.1  Créer BlocObjectifsPanel (bind sur goals provider)
[ ] T-4.2  Créer JournalRightSidebar
[ ] T-4.3  Intégrer le layout 2 colonnes dans journal_view.dart
           → Sidebar visible uniquement ≥1024px
[ ] T-4.4  Créer/modifier PeriodFilterDropdown
```

### Batch T-5 : Finitions

```
[ ] T-5.1  Smoke test : filtrage par période fonctionne
[ ] T-5.2  Smoke test : "Nouvelle écriture" ouvre le bon formulaire
[ ] T-5.3  Smoke test : recherche filtre les lignes
[ ] T-5.4  flutter analyze → 0 warning
[ ] T-5.5  Vérifier : aucun hardcode couleur dans les nouveaux fichiers
```
