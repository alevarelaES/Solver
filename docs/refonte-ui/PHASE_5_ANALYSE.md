# Phase 5 : Analyse Strategique

**Maquette :** `Stitch maquete/Analyse/stitch_Analyse/`

## Fichier a modifier

`lib/features/analysis/views/analysis_view.dart`

## Layout Stitch

```
[ 3 KPI Cards en ligne                                              ]
[ Growth +18.2% | Savings Velocity 52.4% | Freedom Date Sept 2038  ]
[                                                                    ]
[ Grand graphique ligne : YoY Income vs Expense Growth              ]
[ (2022 -> 2026 YTD -> Projected)                                   ]
[                                                                    ]
[ Card: Projected Savings    ][ Card: Peer Comparison Index          ]
[ Growth (5YR)               ][ - Variable Food (-12.4% optimal)    ]
[ [progress bar 75%]         ][ - Transport Costs (+5.8% above)     ]
[ Monthly Yield: +1,240      ][ - Fixed Utilities (-8.2% optimal)   ]
[ Projected ROI: 7.2% p.a.  ][ Efficiency Index: 88/100            ]
[ Compound Effect note       ][                                      ]
```

## Mapping donnees existantes -> UI Stitch

| Element Stitch | Provider / Source | Champ |
|----------------|-------------------|-------|
| KPI Growth vs Prev Year | `analysisDataProvider` | Calcul: (income_annee - income_annee_prec) / income_annee_prec |
| KPI Savings Velocity | `analysisDataProvider` | Calcul: savings / income * 100 |
| KPI Freedom Date | Mockee | Pas de donnees backend |
| Line chart YoY | `analysisDataProvider` | `monthlyComparison` adapte en yearly |
| Projected Savings | Mockee / calcul | Projection basee sur tendance actuelle |
| Peer Comparison | Mockee | Pas de donnees backend |
| Efficiency Index | Mockee | Pas de donnees backend |

## Ce qu'il faut faire

1. 3 KPI cards en haut (grid 3 colonnes) avec mini-chart/progress/icone
2. Grand graphique en ligne (`fl_chart` LineChart) : 2 courbes (income growth vert, expense trend rouge pointille)
3. Zone ombrée entre les 2 courbes (fill area)
4. Badge "+24% Spread Growth" positionne sur le chart
5. Card Projected Savings : progress bar + grid 2x1 (Monthly Yield + ROI) + note compound
6. Card Peer Comparison : liste de categories avec barres de progression et labels optimal/above

## Donnees disponibles vs mockees

**Disponibles (via `analysisDataProvider`):**
- Income et expenses mensuels par annee
- Breakdown des depenses par type/compte
- KPIs de base (totaux, moyennes)

**A mocker (pas de backend):**
- "Financial Freedom Date" -> valeur statique
- "Peer Comparison Index" -> valeurs statiques
- "Projected ROI" -> calcul simple ou statique
- "Compound Effect" -> texte statique

## Responsive

- **Desktop** (>1024px) : 3 KPI cards + chart pleine largeur + 2 cards cote a cote
- **Tablet** (768-1024px) : 3 KPI cards (plus etroites) + chart + 2 cards cote a cote
- **Mobile** (<768px) : KPI cards empilees + chart pleine largeur + cards empilees

## Points d'attention

- Le line chart avec zone ombrée demande une config specifique de `fl_chart` (LineChartBarData avec belowBarData)
- Les mini-charts SVG dans les KPI cards -> utiliser un petit `LineChart` ou `CustomPaint`
- La maquette est tres "investisseur" -> garder le design mais adapter les labels au contexte de l'app (finances perso)
- Le selecteur d'annee existant (`selectedAnalysisYearProvider`) doit rester fonctionnel

## Checklist

- [ ] 3 KPI cards avec donnees (meme partiellement mockees)
- [ ] Line chart avec 2 courbes et zone ombrée
- [ ] Card Projected Savings avec progress bar et stats
- [ ] Card Peer Comparison avec liste et barres
- [ ] Selecteur d'annee fonctionnel
- [ ] Responsive 3 breakpoints
