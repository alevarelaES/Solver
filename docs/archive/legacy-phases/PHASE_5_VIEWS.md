# Phase 5 — Vues Secondaires

> Références : [PROJECT_OVERVIEW.md](../../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../../CONVENTIONS.md)
>
> **Statut :** ✅ Complète
>
> **Prérequis :** Phase 4 complète (moteur de récurrence, modal transaction)
>
> **Bloque :** Phase 6 (Polish)

---

## Objectif

Implémenter les 4 vues secondaires de Solver :
1. **Journal** — Liste chronologique de toutes les transactions avec filtres
2. **Échéancier** — Prochaines échéances non encore payées
3. **Budget** — Planification zero-based et monitoring des dépenses
4. **Analyse** — Charts et tendances financières

Ces vues réutilisent les endpoints existants (avec nouveaux paramètres) et les composants déjà créés.

---

## Vue 5.1 — Journal

### Rôle

Le Journal est la vue "livre de comptes" : toutes les transactions de l'utilisateur, triées du plus récent au plus ancien, avec possibilité de filtrer et de valider les pending.

### Backend

**Endpoint existant** `GET /api/transactions` — enrichir avec ces filtres supplémentaires :

| Paramètre | Type | Description |
|---|---|---|
| `accountId` | uuid? | Filtrer par compte |
| `status` | string? | `completed` ou `pending` |
| `month` | int? | Numéro du mois (1-12) |
| `year` | int? | Année (ex: 2026) |
| `showFuture` | bool | Si false : masquer les pending dont la date est > aujourd'hui (défaut: false) |
| `page` | int | Pagination (défaut: 1) |
| `pageSize` | int | Taille de page (défaut: 50, max: 100) |

**Ajouter la pagination** à la réponse :

```
{
  items: Transaction[],
  totalCount: int,
  page: int,
  pageSize: int
}
```

### Frontend

**Providers Riverpod :**
- `journalFiltersProvider` — State provider pour les filtres actifs
- `journalTransactionsProvider` — AsyncProvider dépendant des filtres

**Layout :**

```
Colonne verticale
├── Barre de filtres (sticky en haut)
│   ├── Dropdown "Compte" (tous par défaut)
│   ├── Dropdown "Statut" (tous par défaut)
│   ├── Month/Year picker
│   └── Toggle "Inclure futurs"
└── Liste groupée par mois
    ├── Header "Janvier 2026" (sticky)
    └── Transaction items
```

**Item de transaction :**

| Élément | Description |
|---|---|
| Icône compte | Selon type (income/expense) |
| Nom du compte | Texte principal |
| Note | Texte secondaire si présente |
| Date | Format court "15 jan" |
| Montant | Roboto Mono, couleur selon type |
| Badge statut | Vert "Payé" ou bouton orange "À valider" |
| Indicateur auto | Icône éclair si `is_auto = true` |

**Action sur transaction pending :**
- Tap → BottomSheet avec options : "Valider", "Modifier", "Supprimer"
- "Valider" : PUT avec `status = completed`, option de modifier le montant

### Checklist 5.1

- [x] Backend : pagination ajoutée
- [x] Backend : filtre `showFuture` implémenté
- [x] Provider avec filtres créé
- [x] Barre de filtres UI fonctionnelle
- [x] Groupement par mois
- [x] Actions sur transaction pending (valider, modifier, supprimer)
- [x] Scroll infini ou pagination (pageSize: 100 par défaut)
- [x] Vide state (aucune transaction)

---

## Vue 5.2 — Échéancier

### Rôle

Vue concentrée sur les **prochains paiements à venir** — factures qui n't pas encore été payées. Divisée en deux colonnes : prélèvements automatiques vs factures manuelles.

### Contexte

L'échéancier aide l'utilisateur à anticiper ce qu'il doit payer dans les prochains jours/semaines. Il ne montre que les transactions `pending` dont la date est ≥ aujourd'hui.

### Backend

**Nouvel endpoint** `GET /api/transactions/upcoming` :
- Transactions `pending` avec date ≥ aujourd'hui
- Triées par date croissante
- Limite : 30 jours par défaut, paramètre `days` optionnel (max: 90)

**Structure de réponse :**
```
{
  auto: Transaction[],        ← is_auto = true
  manual: Transaction[],      ← is_auto = false
  totalAuto: decimal,
  totalManual: decimal,
  grandTotal: decimal
}
```

### Frontend

**Layout :**

```
Header
├── Total à payer : [montant] (grand, centré)
└── Sous-total auto + manuel

Corps en deux colonnes (ou deux onglets sur mobile)
├── Colonne "Prélèvements Auto" (icône éclair, bleu)
│   └── Cards de transactions triées par date
└── Colonne "Factures Manuelles" (icône alerte, orange)
    └── Cards de transactions triées par date
```

**Card de transaction dans l'échéancier :**

| Élément | Description |
|---|---|
| Nom du compte | Titre |
| Date | Mis en évidence si dans les 7 prochains jours |
| Montant | Grand, Roboto Mono |
| Note | Si présente |
| Bouton "Valider" | Uniquement sur les factures manuelles |

**Highlight "7 prochains jours" :**
Les transactions dont la date est dans les 7 prochains jours sont mises en évidence avec une bordure `warmAmber`.

**Widget sur le Dashboard :**
Un mini-widget "Prochaines échéances" affichant les 3 prochaines transactions doit être visible sur le Dashboard (en bas, avant le footer). Il est un lien vers la vue Échéancier.

### Checklist 5.2

- [x] Endpoint `/api/transactions/upcoming` créé
- [x] Séparation auto/manuel dans la réponse
- [x] Layout deux colonnes (desktop) / deux onglets (mobile)
- [x] Highlight 7 prochains jours
- [x] Totaux affichés en header
- [x] Bouton "Valider" sur factures manuelles
- [x] Mini-widget sur le Dashboard

---

## Vue 5.3 — Budget (Planification)

### Rôle

Vue de planification financière qui aide l'utilisateur à allouer son revenu disponible (après charges fixes) aux différentes catégories de dépenses variables.

### Logique métier

```
Revenu Moyen (calculé sur les 3 derniers mois)
  - Charges Fixes (somme des budgets des comptes is_fixed = true)
  = Reste à Vivre

Le Reste à Vivre est alloué aux groupes de dépenses variables
en pourcentages et/ou montants absolus (bidirectionnel).
```

### Backend

**Nouvel endpoint** `GET /api/budget/stats` :

```
{
  averageIncome: decimal,         ← Moyenne des revenus des 3 derniers mois
  fixedExpensesTotal: decimal,    ← Somme des budgets fixed
  disposableIncome: decimal,      ← averageIncome - fixedExpensesTotal
  currentMonthSpending: [         ← Dépenses réelles du mois actuel par compte
    {
      accountId: uuid,
      accountName: string,
      budget: decimal,
      spent: decimal,
      percentage: decimal         ← spent / budget * 100
    }
  ]
}
```

**Endpoint de sauvegarde des budgets** `PUT /api/accounts/{id}/budget` :
- Modifie uniquement le champ `budget` d'un compte
- Retourne le compte mis à jour

### Frontend

**Layout :**

```
Section 1 : Reste à Vivre
└── Grande valeur centrée (Roboto Mono, vert)
    └── Sous-détail : Revenus - Charges fixes

Section 2 : Allocateur (dépenses variables)
└── Pour chaque groupe de dépenses variables :
    ├── Label du groupe
    ├── Slider ou champ CHF (éditable)
    ├── Champ % (bidirectionnel avec CHF)
    └── Barre de progression

Section 3 : Barre totale
└── Total alloué / Reste à vivre
    └── Rouge si > 100%, vert sinon

Section 4 : Monitoring du mois courant
└── Cards par compte :
    ├── Nom du compte
    ├── Budget défini
    ├── Dépensé ce mois
    ├── Reste
    └── Barre de progression (rouge si dépassé)
```

**Bidirectionnalité CHF ↔ %** :
- Modifier le montant CHF → recalcule le % automatiquement
- Modifier le % → recalcule le CHF automatiquement
- Modification en temps réel sans validation

### Checklist 5.3

- [x] Endpoint `budget/stats` créé avec calculs corrects
- [x] Endpoint `PATCH /accounts/{id}/budget` créé
- [x] Section "Reste à Vivre" affichée
- [x] Allocateur bidirectionnel fonctionnel (édition via dialog par compte)
- [x] Barre de progression totale avec alerte si > 100%
- [x] Monitoring cards avec barres de progression
- [x] Sauvegarde des budgets fonctionnelle
- [x] Recalcul automatique après sauvegarde

---

## Vue 5.4 — Analyse

### Rôle

Vue de visualisation avec charts pour comprendre les tendances financières sur l'année.

### Backend

**Nouvel endpoint** `GET /api/analysis?year={year}` :

```
{
  byGroup: [                       ← Pour le donut chart
    { group: string, total: decimal, percentage: decimal }
  ],
  byMonth: [                       ← Pour le bar chart
    { month: int, income: decimal, expenses: decimal, savings: decimal }
  ],
  topExpenseAccounts: [            ← Top 5 comptes les plus dépensés
    { accountName: string, total: decimal, budget: decimal }
  ],
  savingsRate: decimal             ← (revenus - dépenses) / revenus * 100
}
```

Uniquement les transactions `completed` sont incluses dans les calculs.

### Package Flutter recommandé

`fl_chart` — Charts performants et personnalisables pour Flutter.

### Frontend

**Charts à implémenter :**

**1. Donut Chart — Répartition des dépenses par groupe**
- Chaque segment = un groupe de dépenses
- Couleur distincte par groupe (utiliser la palette définie dans CONVENTIONS.md)
- Tap sur segment → détail du groupe
- Légende en dessous

**2. Bar Chart — Revenus vs Dépenses par mois**
- Barres groupées : une barre verte (revenus) + une barre rouge (dépenses) par mois
- Axe X : 12 mois
- Axe Y : montants

**3. Line Chart — Évolution du solde**
- Ligne continue sur 12 mois
- Montre l'évolution du solde au fil de l'année
- Mois futurs en pointillés

**4. KPI de synthèse annuelle**
- Total revenus de l'année
- Total dépenses de l'année
- Taux d'épargne
- Mois le plus dépensier

### Checklist 5.4

- [x] Endpoint `/api/analysis` créé
- [x] `fl_chart` ajouté aux dépendances
- [x] Donut chart fonctionnel
- [x] Bar chart fonctionnel
- [ ] Line chart fonctionnel (reporté en Phase 6)
- [x] KPIs de synthèse affichés
- [x] Navigation année disponible (réutiliser le pattern du Dashboard)
- [x] Responsive (charts redimensionnés)

---

## Validation Finale de la Phase 5

### Checklist globale

**Journal :**
- [x] Filtres fonctionnels
- [x] Groupement par mois
- [x] Actions pending fonctionnelles
- [x] Pagination

**Échéancier :**
- [x] Split auto/manuel
- [x] Highlight 7 jours
- [x] Mini-widget dashboard

**Budget :**
- [x] Calculs corrects (revenu moyen, reste à vivre)
- [x] Allocateur bidirectionnel
- [x] Sauvegarde budgets

**Analyse :**
- [x] 2/3 types de charts (bar + donut ; line chart reporté Phase 6)
- [x] Données cohérentes avec les autres vues

---

## Passage à la Phase Suivante

- **→ Phase 6** : Polish, responsive, tests, optimisations

