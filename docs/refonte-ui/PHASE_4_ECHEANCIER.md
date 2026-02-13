# Phase 4 : Echeancier (Vue Liste + Vue Calendrier)

**Maquettes :**
- `Stitch maquete/Echeancier/stitch_Echeancier_cartes/` (vue liste)
- `Stitch maquete/Echeancier/stitch_Echeancier_calendrier/` (vue calendrier)

## Fichier a modifier

`lib/features/schedule/views/schedule_view.dart`

## Layout Stitch

### Header sticky (commun)

```
[ Total a payer ce mois : 1,800 CHF                                ]
[ Auto: 1,650.00 (point vert)    Manuel: 150.00 (point orange)     ]
[                                                                    ]
[ Toggle: [Liste] [Calendrier]     [Filtres] [+ Nouvelle echeance]  ]
```

### Vue Liste (stitch_Echeancier_cartes)

2 colonnes cote a cote :

```
[ Prelevements Auto          ][ Factures Manuelles           ]
[ (icone bolt, vert)         ][ (icone description, orange)  ]
[ Total: 1,650.00 CHF       ][ Total: 150.00 CHF            ]
[                            ][                               ]
[ Card: Loyer                ][ Card: Swisscom               ]
[   [home] 01 mars           ][   [wifi] 01 mars              ]
[   1,500.00 CHF             ][   150.00 CHF  [Valider]       ]
[                            ][                               ]
[ Card: Transport            ][ Card: Impots (ROUGE)          ]
[   [bus] 01 mars             ][   [warning] En retard         ]
[   150.00 CHF               ][   1,200.00 CHF  [Payer]       ]
[                            ][                               ]
[ Card: Assur. (grise, paye) ][ [+ Ajouter facture manuelle]  ]
[   Paye, barre              ][                               ]
```

### Vue Calendrier (stitch_Echeancier_calendrier)

```
[ Mars 2026    < mois >     3 factures en attente ]
[ Lun | Mar | Mer | Jeu | Ven | Sam | Dim        ]
[ ... | ... | ... | ... | ... | ... | 01          ]
[     |     |     |     |     |     | [Loyer]     ]
[     |     |     |     |     |     | [Transport] ]
[     |     |     |     |     |     | [Swisscom]  ]
[ ... | ... | ... | ... | 12  | ... | ...         ]
[                         auj.                     ]
[ ... | ... | 25  | ... | ... | ... | ...         ]
[             [Netflix]                            ]
```

Chaque event est un chip colore :
- Vert (`primary`) = prelevements automatiques
- Orange = factures manuelles
- Rouge = en retard

## Mapping donnees existantes -> UI Stitch

| Element Stitch | Provider / Source | Champ |
|----------------|-------------------|-------|
| Total a payer | `upcomingTransactionsProvider` | Somme montants |
| Split auto/manuel | `Transaction.status` ou logique | A determiner |
| Liste transactions | `upcomingTransactionsProvider` | `List<Transaction>` |
| Navigation mois | A ajouter | Provider actuel = 30 jours |
| Bouton "Valider" | API `PUT /api/transactions/{id}` | Changer status -> completed |
| Vue calendrier | Construire depuis les transactions | Grouper par date |

## Ce qu'il faut faire

1. Header sticky avec total + split auto/manuel
2. Toggle Liste/Calendrier (`StateProvider<bool>`)
3. **Vue Liste** : 2 colonnes avec cards par transaction
4. **Vue Calendrier** : widget grille 7 colonnes x 5-6 lignes
5. Navigation par mois (precedent/suivant)
6. Bouton "Valider" pour les factures manuelles -> appel API PATCH
7. Bouton "+ Nouvelle echeance" -> ouvre `TransactionFormModal`

## Vue Calendrier - Implementation

- Utiliser un `GridView` custom de 7 colonnes
- Calculer le premier jour du mois et le nombre de jours
- Pour chaque jour, filtrer les transactions qui tombent a cette date
- Afficher les transactions comme des chips colores empiles
- Marquer "aujourd'hui" avec un fond primary/5
- Les jours hors du mois courant sont grises (mois precedent/suivant)

## Distinction auto / manuel

Le modele `Transaction` actuel n'a pas explicitement un champ `isAutomatic`. Approches possibles :
- Utiliser le champ `status` : `pending` = manuel (a valider), `completed` = auto (deja traite)
- Ou se baser sur la presence d'une recurrence
- **Decision a prendre avec l'equipe**

## Responsive

- **Desktop** (>1024px) : 2 colonnes (liste) / grille 7 cols (calendrier)
- **Tablet** (768-1024px) : 2 colonnes plus etroites / grille 7 cols compacte
- **Mobile** (<768px) : 1 colonne empilee (liste) / grille 7 cols tres compacte (juste les chiffres + points de couleur)

## Points d'attention

- Le mode calendrier est le **plus gros ajout UI** de toute la refonte
- Tester avec des mois qui commencent un lundi vs dimanche
- Le hover sur un jour (Stitch montre un popover avec les details) -> peut etre un tooltip ou un bottom sheet sur mobile
- Les transactions "payees" (barrees, grisees) dans la vue liste

## Checklist

- [ ] Header sticky avec totaux
- [ ] Toggle Liste/Calendrier
- [ ] Vue Liste : 2 colonnes auto/manuel
- [ ] Cards avec icone, date, montant
- [ ] Bouton Valider fonctionnel
- [ ] Vue Calendrier : grille 7 jours
- [ ] Events affiches sur les bons jours
- [ ] Navigation mois (prev/next)
- [ ] Aujourd'hui marque
- [ ] Responsive 3 breakpoints
