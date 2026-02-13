# Refonte UI Solver - Index

Remplacement du visuel actuel (dark glassmorphic bleu) par les maquettes Stitch (light-first vert olive).

## Phases

| # | Fichier | Page | Effort | Statut |
|---|---------|------|--------|--------|
| 0 | [PHASE_0_THEME.md](PHASE_0_THEME.md) | Theme + Shell + Composants partages | Moyen | Fait |
| 1 | [PHASE_1_DASHBOARD.md](PHASE_1_DASHBOARD.md) | Dashboard | Moyen | Fait |
| 2 | [PHASE_2_JOURNAL.md](PHASE_2_JOURNAL.md) | Journal des Transactions | Eleve | A faire |
| 3 | [PHASE_3_BUDGET.md](PHASE_3_BUDGET.md) | Budget (Grid + Liste) | Moyen | Fait |
| 4 | [PHASE_4_ECHEANCIER.md](PHASE_4_ECHEANCIER.md) | Echeancier (Liste + Calendrier) | Eleve | Fait |
| 5 | [PHASE_5_ANALYSE.md](PHASE_5_ANALYSE.md) | Analyse Strategique | Moyen | Fait |
| 6 | [PHASE_6_TABLEAU.md](PHASE_6_TABLEAU.md) | Tableau Spreadsheet (nouvelle page) | Eleve | Fait |

## Instructions Gemini

Le fichier [GEMINI_CONTEXT.md](GEMINI_CONTEXT.md) contient le contexte partage a donner a Gemini Pro avant chaque phase.

## Ordre d'execution

**Phase 0 en premier obligatoirement** (le theme impacte tout).
Ensuite les pages sont independantes, dans l'ordre recommande : 1 > 3 > 4 > 2 > 5 > 6.

## Regles

- **1 phase = 1 PR ou 1 commit isole**
- Tester apres chaque phase (`flutter analyze` + run)
- Ne jamais modifier providers, modeles, API client ou auth
- Travailler uniquement sur views, widgets et theme

## Maquettes de reference

Dossier : `Stitch maquete/` a la racine du projet. Chaque sous-dossier contient `code.html` + `screen.png`.
