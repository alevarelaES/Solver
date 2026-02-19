# Phase 2 : Journal des Transactions

**Maquette :** `Stitch maquete/Journal/stitch_Journal/`

## Fichier a modifier

`lib/features/journal/views/journal_view.dart`

## Layout Stitch

Layout master-detail horizontal :

```
[ Header : titre + search bar + bouton "Add Entry" + bouton export ]
[ Filtres : Date | Category | Account | Status | Sort              ]
[                                                                   ]
[ Panneau gauche (w-80) ][ Panneau droit (flex-1)                  ]
[ Liste transactions    ][ Detail transaction selectionnee          ]
[ scrollable            ][                                          ]
[ avec pagination       ][ - Logo/icone marchand                   ]
[                       ][ - Nom + ref transaction                  ]
[                       ][ - Montant + badge verified               ]
[                       ][ - Grille: Date, Category, Account, Status]
[                       ][ - Actions: edit, print, share, flag      ]
[                       ][ - Notes section                          ]
]
```

## Mapping donnees existantes -> UI Stitch

| Element Stitch | Provider / Source | Champ |
|----------------|-------------------|-------|
| Filtres (Date, Account, Status) | `journalFiltersProvider` | `year`, `month`, `accountId`, `status` |
| Liste transactions | `journalTransactionsProvider` | Liste de `Transaction` |
| Detail transaction | Selection locale | `Transaction` selectionne |
| Bouton "Add Entry" | Ouvre `TransactionFormModal` | Existe deja |
| Montant colore | `Transaction.type` | `income` = vert, `expense` = rouge |
| Status "Verified" | `Transaction.status` | `completed` = verified, `pending` = pending |
| Pagination | A ajouter | Provider actuel charge tout |

## Ce qu'il faut faire

1. Transformer le layout actuel (liste simple) en master-detail horizontal
2. **Panneau gauche** : liste compacte de transactions (date, nom, montant) dans des cartes cliquables
3. **Panneau droit** : fiche detaillee de la transaction selectionnee
4. Ajouter un `StateProvider<Transaction?>` pour la transaction selectionnee
5. Adapter les filtres existants en chips horizontaux (au lieu de dropdowns)
6. Ajouter une pagination basique (Page X of Y) dans le panneau gauche
7. Header avec titre, barre de recherche, bouton "Add Entry"

## Structure panneau gauche (par transaction)

```
[ Date (petit, gris, uppercase)     Montant (bold) ]
[ [icone] Nom de la transaction                     ]
```

- Transaction selectionnee : fond `primary/5` + bordure gauche `primary`
- Autres : fond blanc + bordure bottom subtile
- Montant vert pour income, noir/fonce pour expense

## Structure panneau droit

```
[ [Avatar/icone 64px]  Nom transaction     Montant en gros ]
[                       Ref #TRX-XXXXX      Badge Verified  ]
[ --------------------------------------------------------- ]
[ Date             | Category (chip)                         ]
[ Account          | Status toggle                           ]
[ --------------------------------------------------------- ]
[ Actions: edit | print | share      Flag Transaction (rouge)]
[ --------------------------------------------------------- ]
[ Notes section (placeholder si vide)                        ]
```

## Responsive

- **Desktop** (>1024px) : master-detail cote a cote
- **Tablet** (768-1024px) : idem mais panneau gauche plus etroit
- **Mobile** (<768px) : liste seule, clic ouvre le detail en plein ecran ou bottom sheet

## Points d'attention

- Le champ "Category" (Food & Drink, etc.) n'existe pas dans le modele `Transaction` actuel. Afficher le nom du compte associe a la place, ou laisser vide.
- La pagination n'existe pas dans le provider actuel -> soit ajouter un offset/limit au provider, soit paginer cote client.
- Le bouton "Flag Transaction" -> ignorer ou mapper sur la suppression.
- Les icones de marchands (Starbucks, Amazon) dans Stitch sont decoratives -> utiliser une icone Material generique basee sur le type (income/expense).

## Checklist

- [ ] Layout master-detail fonctionnel
- [ ] Panneau gauche : liste cliquable
- [ ] Panneau droit : detail complet
- [ ] Filtres en chips
- [ ] Bouton Add Entry ouvre le modal existant
- [ ] Couleurs montant (vert/rouge)
- [ ] Responsive mobile (liste seule)
