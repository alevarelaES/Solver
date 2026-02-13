# Contexte Partage pour Gemini Pro

Copier ce bloc au debut de chaque session Gemini avant de donner la phase specifique.

---

## Projet

App Flutter Web "Solver" - gestion financiere personnelle (budget, transactions, echeancier).

## Stack technique

- Flutter Web (Dart)
- Riverpod (state management, providers fonctionnels)
- GoRouter (routing avec ShellRoute)
- fl_chart (graphiques : bar, line, pie)
- google_fonts (Plus Jakarta Sans)
- Dio (HTTP client avec JWT interceptor)
- Supabase (auth uniquement cote Flutter)

## Structure du projet

```
lib/
  core/
    theme/app_theme.dart          <- palette, ThemeData
    theme/app_text_styles.dart    <- styles texte
    router/app_router.dart        <- GoRouter config
    services/api_client.dart      <- Dio + auth token
    config/app_config.dart        <- env vars
  features/
    dashboard/views/              <- dashboard_view.dart
    dashboard/providers/          <- dashboard_provider.dart
    journal/views/                <- journal_view.dart
    journal/providers/            <- journal_provider.dart
    schedule/views/               <- schedule_view.dart
    schedule/providers/           <- schedule_provider.dart
    budget/views/                 <- budget_view.dart
    budget/providers/             <- budget_provider.dart
    analysis/views/               <- analysis_view.dart
    analysis/providers/           <- analysis_provider.dart
    auth/views/                   <- login_view.dart
    auth/providers/               <- auth_provider.dart
    transactions/models/          <- transaction.dart
    transactions/providers/       <- transactions_provider.dart
    transactions/widgets/         <- modals (form, list)
    accounts/models/              <- account.dart
    accounts/providers/           <- accounts_provider.dart
    accounts/widgets/             <- account_form_modal.dart
  shared/widgets/
    app_shell.dart                <- layout wrapper responsive
    desktop_sidebar.dart          <- sidebar navigation
    mobile_bottom_bar.dart        <- bottom nav mobile
    glass_container.dart          <- a remplacer par SolverCard
    kpi_card.dart                 <- card indicateur
    nav_items.dart                <- items navigation
    staggered_fade_in.dart        <- animation
  main.dart
```

## Routes

```
/login      (public)
/dashboard  (protege, ShellRoute)
/journal    (protege, ShellRoute)
/schedule   (protege, ShellRoute)
/budget     (protege, ShellRoute)
/analysis   (protege, ShellRoute)
```

## Regles CRITIQUES

1. **NE PAS modifier** : providers, modeles, API client, auth, router (sauf ajout de route)
2. **Travailler UNIQUEMENT** sur les fichiers views/, widgets/ et theme/
3. **Garder** les memes appels providers (`ref.watch`, `ref.read`, `ref.invalidate`)
4. **Garder** la meme logique d'interaction (modals, filtres, navigation)
5. **Utiliser** les couleurs du theme (`Theme.of(context)`) pas de couleurs en dur
6. **Garder** le responsive (mobile <768px / tablet 768-1024px / desktop >1024px)
7. **Garder** le dark mode fonctionnel
8. **Formatage** : CHF (Franc Suisse), locale fr_FR, mois/jours en francais
9. **Tester** apres chaque modification : `flutter analyze` + `flutter run -d chrome`

## Palette de couleurs (apres Phase 0)

```dart
primary:        Color(0xFF689E28)  // vert olive
primaryDark:    Color(0xFF4C6929)  // vert fonce
primaryDarker:  Color(0xFF1E2E11)  // vert tres fonce

// Light mode
background:     Color(0xFFF7F8F6)
surface:        Colors.white
border:         Color(0xFFE5E7EB)
textMain:       Color(0xFF1E2E11)
textMuted:      Color(0xFF6B7280)

// Dark mode
backgroundDark: Color(0xFF121212)
surfaceDark:    Color(0xFF1E1E1E)
borderDark:     Color(0xFF374151)
textDark:       Color(0xFFE5E7EB)
textMutedDark:  Color(0xFF9CA3AF)
```

## Maquettes de reference

Les maquettes HTML Stitch sont dans `Stitch maquete/[NomPage]/stitch_*/code.html`.
Chaque maquette a aussi un `screen.png` pour reference visuelle.

## Comment utiliser ce contexte

1. Copier ce bloc entier au debut de la conversation Gemini
2. Donner ensuite la phase specifique (le fichier PHASE_X.md correspondant)
3. Coller le code HTML de la maquette Stitch
4. Coller le fichier Flutter actuel a modifier
5. Coller les providers pertinents (signatures et types de retour)
6. Demander a Gemini de recrire le widget de la vue

## Breakpoints responsive

```dart
// Dans app_shell.dart et dans chaque view
final width = MediaQuery.of(context).size.width;
final isMobile = width < 768;
final isTablet = width >= 768 && width < 1024;
final isDesktop = width >= 1024;
```

Comportement par breakpoint :
- **Mobile (<768px)** : colonnes empilees, sidebar masquee, bottom nav, modals en bottom sheet
- **Tablet (768-1024px)** : sidebar icon-only, layout adapte (2 colonnes max), modals en dialog
- **Desktop (>1024px)** : sidebar icon-only, layout complet (3+ colonnes), modals en dialog
