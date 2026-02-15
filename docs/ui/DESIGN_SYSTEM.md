# Design System (Solver)

Objectif: garder une UI homogene et modifiable rapidement depuis quelques fichiers centraux.

## Fichiers source de verite

- `lib/core/theme/app_theme.dart`
  - `AppColors`
  - `AppRadius`
  - theme global Material (`AppTheme.light` / `AppTheme.dark`)
- `lib/core/theme/app_tokens.dart`
  - `AppSpacing`, `AppSizes`, `AppShadows`, `AppDurations`, `AppBreakpoints`
- `lib/core/theme/app_component_styles.dart`
  - `AppButtonStyles`
  - `AppInputStyles`
- `lib/shared/widgets/app_panel.dart`
  - `AppPanel` (conteneur layout commun)

## Regles de dev UI

- Ne pas hardcoder de `styleFrom(...)` dans les features.
  - Utiliser `AppButtonStyles.*`.
- Ne pas hardcoder les rayons.
  - Utiliser `AppRadius.*`.
- Ne pas hardcoder les espacements.
  - Utiliser `AppSpacing.*`.
- Ne pas recréer un style de champ de recherche.
  - Utiliser `AppInputStyles.search(...)`.
- Ne pas recréer des conteneurs de carte avec `Container + BoxDecoration`.
  - Utiliser `AppPanel`.

## Changer le look global rapidement

- Couleurs: modifier `AppColors` dans `app_theme.dart`.
- Rondeur: modifier `AppRadius` dans `app_theme.dart`.
- Densite (padding boutons/champs): modifier `AppButtonStyles` / `AppInputStyles`.
- Typographie globale: modifier `textTheme` dans `AppTheme._build`.
- Layout cards/panels: modifier `AppPanel` (ou ses params par defaut).
