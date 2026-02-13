# Phase 1 : Dashboard

**Maquette :** `Stitch maquete/Dashboard/stitch_Dashboard/`

## Fichier a modifier

`lib/features/dashboard/views/dashboard_view.dart`

## Layout Stitch

Grid 12 colonnes :

```
[ Colonne gauche (4/12) ]         [ Colonne droite (8/12)              ]
[                        ]         [                                     ]
[ Balance card gradient  ]         [ 3 KPI cards (Income/Expense/Savings)]
[ Expense Breakdown      ]         [ Financial Overview bar chart        ]
[ (donut chart)          ]         [                                     ]
[ My Cards (comptes)     ]         [ Recent Activities | CTA sidebar     ]
[ Monthly Spending Limit ]         [ (table)           | (promo cards)   ]
```

## Mapping donnees existantes -> UI Stitch

| Element Stitch | Provider / Source | Champ |
|----------------|-------------------|-------|
| "My Balance" (montant total) | `dashboardDataProvider` | Somme des soldes comptes |
| KPI Income | `dashboardDataProvider` | `totalIncome` |
| KPI Expense | `dashboardDataProvider` | `totalExpenses` |
| KPI Savings | Calcul | `totalIncome - totalExpenses` |
| Bar chart "Financial Overview" | `dashboardDataProvider` | `monthlyBalances` |
| Donut "Expense Breakdown" | `dashboardDataProvider` | A deriver ou mocker |
| "My Cards" | `accountsProvider` | Liste des comptes |
| Recent Activities | `dashboardDataProvider` | Dernieres transactions du mois |
| Monthly Spending Limit | `budgetStatsProvider` | `disposableIncome` + total depenses |

## Ce qu'il faut faire

1. Remplacer le layout actuel (grille de comptes + KPIs + bar chart) par le grid 12-col Stitch
2. Creer le widget "Balance Card" avec gradient vert (`primary` -> `primaryDark`)
3. Creer 3 KPI cards (Income, Expense, Savings) avec badge tendance
4. Adapter le bar chart existant (`fl_chart`) avec les nouvelles couleurs vertes
5. Ajouter un donut chart (`fl_chart` PieChart) pour l'expense breakdown
6. Creer la section "My Cards" qui affiche les comptes comme des cartes bancaires visuelles
7. Creer la table "Recent Activities" (5 dernieres transactions)
8. Ajouter la barre "Monthly Spending Limit" (progress bar)

## Interactions a conserver

- Clic sur un compte -> ouvre `TransactionsListModal` (existe deja)
- Selecteur d'annee -> `selectedYearProvider` (existe deja)
- Bouton "+" pour ajouter un compte -> `AccountFormModal` (existe deja)

## Points d'attention

- Les boutons "Transfer" / "Received" de Stitch n'ont pas de backend -> mettre en decoratif ou masquer
- La section "Try Solver AI" / "Upgrade to Pro" -> ignorer (pas pertinent)
- Le donut chart : si pas de donnees de categories, utiliser les depenses par compte comme proxy
- Le dashboard actuel a des comptes cliquables dans une grille -> cette interaction doit migrer dans "My Cards"

## Checklist

- [ ] Balance card avec gradient et montant total
- [ ] 3 KPI cards fonctionnels avec vraies donnees
- [ ] Bar chart avec couleurs vertes
- [ ] Donut chart (meme mockee)
- [ ] Section My Cards avec les comptes reels
- [ ] Table Recent Activities
- [ ] Progress bar spending limit
- [ ] Responsive (mobile : colonnes empilees)
