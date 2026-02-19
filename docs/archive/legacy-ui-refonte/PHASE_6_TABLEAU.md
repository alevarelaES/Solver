# Phase 6 : Tableau Spreadsheet Annuel (Nouvelle Page)

**Maquette :** `Stitch maquete/Tableau/stitch_Tableau/`

**NOTE : Cette page n'existe pas actuellement. C'est un ajout.**

## Fichiers a creer

| Fichier | Description |
|---------|-------------|
| `lib/features/spreadsheet/views/spreadsheet_view.dart` | Vue principale |
| `lib/features/spreadsheet/providers/spreadsheet_provider.dart` | Provider donnees |

## Fichiers a modifier

| Fichier | Modification |
|---------|-------------|
| `lib/core/router/app_router.dart` | Ajouter route `/spreadsheet` |
| `lib/shared/widgets/nav_items.dart` | Ajouter entree navigation |

## Layout Stitch

```
[ Header: "Strategic Plan / 2024 Annual Forecast" [v1.2 Draft]     ]
[         Last autosave | Export | Share | Save Changes              ]
[                                                                    ]
[ Toolbar: Undo/Redo | Zoom | EUR | Formula bar                    ]
[                                                                    ]
[ Table scrollable horizontale + verticale                           ]
[ Category (sticky) | Jan | Feb | ... | Dec | Total                 ]
[ ---------------------------------------------------------         ]
[ NET INCOME         | 4500| 4500| ... |6500 | 56,700              ]
[                                                                    ]
[ OBLIGATOIRE (Fixed)                                                ]
[   Rent / Mortgage  | 1200| 1200| ... |1200 | 14,400              ]
[   Utilities        | 145 | 160 | ... | 180 | 1,445               ]
[   Insurance        | 45  | 45  | ... | 45  | 540                 ]
[   TOTAL OBLIGATOIRE| 1390| 1405| ... |1425 | 16,385 (highlight)  ]
[                                                                    ]
[ SORTIE (Variable)                                                  ]
[   Groceries        | 400 | 380 | ... | 600 | 5,130               ]
[   Transport        | 120 | 120 | ... | 150 | 1,620               ]
[   TOTAL SORTIE     | 520 | 500 | ... | 750 | 6,750 (highlight)   ]
[                                                                    ]
[ EPARGNE (Savings)                                                  ]
[   ETF / Stock      | 500 | 500 | ... |1500 | 7,500               ]
[   TOTAL EPARGNE    | 500 | 500 | ... |1500 | 7,500 (highlight)   ]
[                                                                    ]
[ NET CASH FLOW      | 2090| 2095| ... |2825 | 26,065 (primary bg) ]
[                                                                    ]
[ Footer: Online | Sheet: Annual2024 | Sum: 26,065 | Count | Avg   ]
```

## Approche de donnees

**Option A : Donnees mockees / locales (recommande pour V1)**
- Hardcoder des donnees initiales dans le provider
- Permettre l'edition locale (state management)
- Pas de persistence backend

**Option B : Donnees derivees du backend (V2)**
- Construire le tableau depuis les donnees existantes (transactions groupees par mois/categorie)
- Read-only dans un premier temps

## Ce qu'il faut faire

1. Creer la route `/spreadsheet` dans GoRouter + ajouter dans la ShellRoute
2. Ajouter l'entree dans nav_items (icone `table_view`)
3. Widget principal : ScrollView horizontal + vertical
4. Colonne gauche sticky (`category`) avec un `Positioned` ou `StickyHeader`
5. 12 colonnes mois + 1 colonne Total
6. Cellules editables : `TextField` inline
7. Lignes de section (OBLIGATOIRE, SORTIE, EPARGNE) en gras avec fond colore
8. Lignes de total avec fond `primary/20`
9. Ligne NET CASH FLOW en fond `primaryDarker` texte blanc
10. Toolbar en haut : undo/redo, zoom selector, formule bar
11. Footer status bar : online indicator, sheet name, sum/count/avg

## Implementation technique

- Utiliser un `SingleChildScrollView` horizontal wrappant un `Column` avec sticky header
- Ou utiliser le package `two_dimensional_scrollables` / `linked_scroll_controller`
- La colonne sticky peut etre un `Row` avec un `Container` fixe + `Expanded` scrollable
- Les inputs sont des `TextEditingController` avec un `Map<String, Map<int, double>>` pour stocker les valeurs

## Responsive

- **Desktop** (>1024px) : Tableau complet avec toutes les colonnes visibles (scroll horizontal si necessaire)
- **Tablet** (768-1024px) : Scroll horizontal avec colonne category sticky
- **Mobile** (<768px) : Scroll horizontal obligatoire, possibilite de pivoter, ou vue alternative simplifiee (une seule colonne mois a la fois)

## Points d'attention

- Le scroll horizontal avec colonne sticky est techniquement complexe en Flutter Web
- Les performances avec beaucoup de TextField editables peuvent poser probleme -> utiliser `ListView.builder` si possible
- La formule bar (affiche la formule de la cellule selectionnee) -> peut etre simplifiee ou ignoree en V1
- L'autosave -> pas de backend pour ca, peut etre juste un label decoratif

## Priorite

Cette phase est la plus lourde (nouvelle page, nouveau provider, UI complexe).
**Peut etre reportee** a apres les 5 premieres phases. L'app est fonctionnelle sans cette page.

## Checklist

- [x] Route /spreadsheet ajoutee
- [x] Navigation : icone dans sidebar + header
- [x] Tableau scrollable avec colonne sticky
- [x] Sections avec headers colores
- [x] Cellules editables
- [x] Totaux calcules dynamiquement
- [x] Ligne NET CASH FLOW en surbrillance
- [x] Toolbar (meme simplifiee)
- [x] Footer status bar
- [x] Responsive avec scroll horizontal
