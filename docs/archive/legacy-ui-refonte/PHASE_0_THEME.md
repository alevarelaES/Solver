# Phase 0 : Theme + Composants Partages

**Prerequis pour toutes les autres phases.** A faire en premier.

## Fichiers a modifier

| Fichier | Action |
|---------|--------|
| `lib/core/theme/app_theme.dart` | Refonte palette + light mode |
| `lib/core/theme/app_text_styles.dart` | Adapter poids/couleurs |
| `lib/shared/widgets/app_shell.dart` | Ajouter header top, adapter layout |
| `lib/shared/widgets/desktop_sidebar.dart` | Sidebar icon-only fixe (64-80px) |
| `lib/shared/widgets/mobile_bottom_bar.dart` | Adapter couleurs |
| `lib/shared/widgets/glass_container.dart` | Remplacer par SolverCard (ou renommer) |
| `lib/shared/widgets/kpi_card.dart` | Nouveau style clean |
| `lib/shared/widgets/nav_items.dart` | Verifier icones |

## Nouvelle palette de couleurs

```
primary:        #689e28  (vert olive)
primaryDark:    #4c6929  (vert fonce)
primaryDarker:  #1e2e11  (vert tres fonce)

background:     #f7f8f6  (light) / #121212 (dark)
surface:        #FFFFFF  (light) / #1e1e1e (dark)
border:         #e5e7eb  (light) / #374151 (dark)

textMain:       #1e2e11  (light) / #e5e7eb (dark)
textMuted:      #6b7280  (light) / #9ca3af (dark)

success:        #689e28 (meme que primary)
danger:         #ef4444
warning:        #f59e0b
```

## Layout Shell

### Actuel
```
[ Sidebar (64-220px) ][ Content ]
```

### Nouveau (Stitch)
```
[ Header top: Logo | Nav tabs | Search | Notifications | Avatar ]
[ Sidebar icon-only (64px) ][ Content area ]
```

Le header top contient :
- Logo "S" (carre vert arrondi) + texte "Solver"
- Navigation tabs horizontale (Overview, Transactions, Analytics, Payments, Budgets)
- Barre de recherche (decorative)
- Icone notifications avec badge rouge
- Avatar utilisateur

La sidebar :
- Largeur fixe 64-80px, icon-only (pas de texte)
- Boutons icones Material Symbols avec etat actif (fond primary/10 + couleur primary)
- En bas : toggle theme (light/dark) + logout
- Pas de mode "expanded"

## Remplacement GlassContainer -> SolverCard

Le GlassContainer actuel utilise backdrop-blur et transparence. Le design Stitch utilise des cards propres.

Nouveau widget `SolverCard` :
- Background : blanc (light) / surface-dark (dark)
- Border : 1px solid border color
- Border radius : 16px (md) ou 24px (lg)
- Shadow : subtile (`boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]`)
- Padding interne configurable
- Pas de blur, pas de transparence

## KPI Card

Nouveau style :
- Fond SolverCard (blanc + border)
- Label : 12px, gris muted, fontWeight 500
- Montant : 24px, bold, textMain
- Badge tendance : petit chip colore (vert up / rouge down) avec icone fleche

## Risques et precautions

- Changer la palette impacte TOUTES les pages d'un coup -> tester chaque page apres
- Le mode glassmorphic est supprime -> les animations blur sont perdues (acceptable)
- Verifier que le dark mode reste fonctionnel
- Les modals existants (TransactionFormModal, AccountFormModal) heritent du theme -> verifier qu'ils restent lisibles

## Checklist de validation

- [x] `flutter analyze` OK
- [x] App compile et s'affiche
- [x] Chaque page s'affiche sans crash
- [x] Dark mode fonctionne
- [x] Sidebar et header fonctionnent
- [x] Navigation entre pages fonctionne
- [x] Modals s'ouvrent correctement
