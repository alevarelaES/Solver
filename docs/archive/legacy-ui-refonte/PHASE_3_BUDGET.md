# Phase 3 : Budget (Vue Cartes + Vue Liste)

**Maquettes :**
- `Stitch maquete/Budget/stitch_Budget_cartes/` (vue grille)
- `Stitch maquete/Budget/stitch_Budget_cartes_longues/` (vue liste)

## Fichier a modifier

`lib/features/budget/views/budget_view.dart`

## Layout Stitch

### Hero Section (commun aux 2 vues)

```
[ Reste a Vivre : 6,700 CHF (gros, primary)                        ]
[ |  Barre: Total Income 10,000 CHF  ==================== 100%     ]
[ |  Barre: Charges fixes  -3,300 CHF  ======             33%      ]
[                                                                    ]
[ Toggle: [Grille] [Liste]                    Bouton "Add Category"  ]
```

### Vue Grille (stitch_Budget_cartes)

Grid 3 colonnes de cards arrondies :

```
[ Card categorie                          ]
[ [icone coloree]  Nom         Max: XXX   ]
[                  Sous-titre  CHF        ]
[ Allocation: XX%                          ]
[ [========= slider range =========]       ]
[ Spent: XXX CHF               XX%        ]
[ [======= progress bar ======]            ]
```

### Vue Liste (stitch_Budget_cartes_longues)

Lignes horizontales :

```
[ [barre couleur] Nom categorie | Allocation: X/Y CHF  XX% | [10%][20%][50%] | edit ]
[                 Type           | [======= progress ====]  |                 |      ]
```

### Footer CTA (commun)

```
[ [icone] Zero-Base Optimization                        [Reset] [Apply] ]
[         You have X CHF (X%) remaining to allocate.                     ]
```

## Mapping donnees existantes -> UI Stitch

| Element Stitch | Provider / Source | Champ |
|----------------|-------------------|-------|
| Reste a Vivre | `budgetStatsProvider` | `disposableIncome` |
| Total Income | `budgetStatsProvider` | Revenu moyen 3 mois |
| Charges fixes | `budgetStatsProvider` | Total charges fixes |
| Categories/Cards | `budgetStatsProvider` | `accountBudgets` (budgets par compte) |
| Allocation % | Calcul | `budget / totalDisposable * 100` |
| Spent / Progress | `budgetStatsProvider` | `spent` par compte |
| Max Spend | `accountBudgets` | `budgetLimit` par compte |

## Ce qu'il faut faire

1. Creer le hero section "Reste a Vivre" avec les 2 barres de progression
2. Ajouter un toggle Grille/Liste (`StateProvider<bool>`)
3. **Vue Grille** : grid 3 colonnes de SolverCards avec icone, nom, slider, progress bar
4. **Vue Liste** : lignes horizontales avec barre couleur, nom, progress bar inline
5. Footer CTA dark (fond primaryDarker) avec message et boutons
6. Les sliders sont visuels (non-interactifs) sauf si on veut permettre l'edition inline

## Mapping categories -> comptes

Les maquettes Stitch montrent des categories (Shopping, Investment, Lifestyle...) mais le backend gere des comptes (Carte Visa, Compte courant...).

**Approche** : chaque compte avec un budget defini = une "categorie" dans la vue budget.
- Nom du compte = nom de la categorie
- Icone = Material icon generique ou basee sur le nom du compte
- Couleur = assignee automatiquement (cycle de couleurs)

## Responsive

- **Desktop** (>1024px) : Hero + grid 3 colonnes
- **Tablet** (768-1024px) : Hero + grid 2 colonnes
- **Mobile** (<768px) : Hero empile + grid 1 colonne / liste pleine largeur

## Points d'attention

- Les boutons d'allocation rapide [10%] [20%] [50%] -> decoratifs sauf si on veut modifier le budget inline
- Le slider `input[type=range]` -> widget `Slider` Flutter
- Le bouton "Apply Smart Allocation" -> decoratif (pas de logique backend)
- Le bouton "Add Category" -> pourrait ouvrir `AccountFormModal` pour creer un nouveau compte avec budget

## Checklist

- [x] Hero "Reste a Vivre" avec vraies donnees
- [x] Toggle Grid/Liste fonctionnel
- [x] Vue Grille avec cards
- [x] Vue Liste avec lignes
- [x] Progress bars correctes (spent / budget)
- [x] Footer CTA
- [x] Responsive 3 breakpoints
