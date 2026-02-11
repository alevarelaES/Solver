# Phase 2 — Fondations Flutter

> Références : [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../CONVENTIONS.md) | [SECURITY.md](../SECURITY.md)
>
> **Statut :** ✅ Terminé
>
> **Prérequis :** Phase 0 complète — SUPABASE_URL et SUPABASE_ANON_KEY disponibles
>
> **Bloque :** Phase 3, 4, 5 (toutes les features)

---

## Objectif

Établir toutes les fondations techniques Flutter :
- Thème visuel "Deep Glass" complet
- Navigation multi-plateforme avec GoRouter
- State management avec Riverpod
- Client HTTP configuré avec authentification automatique
- Authentification Supabase fonctionnelle
- Structure de fichiers respectée

À la fin de cette phase, l'application Flutter doit afficher une structure vide mais navigable, avec le thème appliqué et la connexion à Supabase fonctionnelle.

---

## Contexte

Le projet Flutter a déjà été initialisé avec `flutter_dotenv` et `supabase_flutter`. Il faut **compléter** les dépendances manquantes et **structurer** le code correctement avant de commencer les features.

---

## Étape 2.1 — Dépendances Complètes

### Dépendances à ajouter dans `pubspec.yaml`

**Dependencies :**

| Package | Dernière version stable | Usage |
|---|---|---|
| `flutter_riverpod` | `^2.x` | State management |
| `riverpod_annotation` | `^2.x` | Annotations Riverpod |
| `go_router` | `^14.x` | Navigation |
| `dio` | `^5.x` | Client HTTP |
| `google_fonts` | `^6.x` | Typographies (Plus Jakarta Sans, Roboto Mono) |
| `url_strategy` | `^0.3.x` | Supprime le `#` des URLs web |
| `flutter_localizations` | SDK | Support multilingue |
| `intl` | `^0.19.x` | Formatage dates et monnaies |

**Dev Dependencies :**

| Package | Usage |
|---|---|
| `riverpod_generator` | Génération de code Riverpod |
| `build_runner` | Exécution des générateurs de code |

### Assets à déclarer dans `pubspec.yaml`

- `.env.local` — déjà déclaré (vérifier)

### ⚠️ Note sur `flutter_dotenv` et les assets

Le fichier `.env.local` est bundlé dans l'application car déclaré comme asset. Cela est **acceptable pour développement** avec la clé `anon` uniquement. Ne jamais y ajouter des secrets supplémentaires. Pour la production, la stratégie de build devra être revue (voir Phase 6).

### Checklist 2.1

- [x] Toutes les dépendances ajoutées dans `pubspec.yaml`
- [x] `flutter pub get` s'exécute sans erreur
- [x] `dart run build_runner build` s'exécute sans erreur

---

## Étape 2.2 — Structure des Dossiers

Créer la structure de dossiers suivante dans `lib/` :

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart          ← Constantes (URLs, clés)
│   ├── theme/
│   │   └── app_theme.dart           ← Thème Deep Glass
│   ├── router/
│   │   └── app_router.dart          ← GoRouter configuration
│   └── services/
│       └── api_client.dart          ← Dio + intercepteur JWT
├── features/
│   ├── auth/
│   │   ├── providers/
│   │   ├── views/
│   │   └── widgets/
│   ├── dashboard/
│   │   ├── providers/
│   │   ├── views/
│   │   └── widgets/
│   ├── journal/
│   │   ├── providers/
│   │   ├── views/
│   │   └── widgets/
│   ├── schedule/
│   │   ├── providers/
│   │   ├── views/
│   │   └── widgets/
│   ├── budget/
│   │   ├── providers/
│   │   ├── views/
│   │   └── widgets/
│   └── analysis/
│       ├── providers/
│       ├── views/
│       └── widgets/
├── shared/
│   └── widgets/
│       ├── glass_container.dart      ← Composant glassmorphism
│       ├── app_shell.dart            ← Layout principal responsive
│       ├── desktop_sidebar.dart      ← Navigation desktop
│       ├── mobile_bottom_bar.dart    ← Navigation mobile
│       └── kpi_card.dart             ← Carte de métrique
└── l10n/
    └── app_fr.arb                    ← Chaînes françaises
```

### Checklist 2.2

- [x] Tous les dossiers créés
- [x] Fichiers `.dart` vides créés pour les modules core

---

## Étape 2.3 — Configuration de l'Application (`app_config.dart`)

### Rôle

Centralise l'accès aux variables d'environnement. Toutes les autres parties du code utilisent `AppConfig` — jamais `dotenv.env` directement.

### Variables à exposer

| Getter | Source |
|---|---|
| `supabaseUrl` | `dotenv.env['SUPABASE_URL']` |
| `supabaseAnonKey` | `dotenv.env['SUPABASE_ANON_KEY']` |
| `apiBaseUrl` | `dotenv.env['API_BASE_URL']` (fallback: `http://localhost:5000`) |

### Ajouter `API_BASE_URL` dans `.env.local`

```
SUPABASE_URL=https://[ref].supabase.co
SUPABASE_ANON_KEY=[clé anon]
API_BASE_URL=http://localhost:5000
```

### Checklist 2.3

- [x] `AppConfig` créé comme classe avec getters statiques
- [x] `.env.local` mis à jour avec `API_BASE_URL`
- [x] Noms de variables sans préfixe (pas de `EXPO_PUBLIC_` ni `NEXT_PUBLIC_`)

---

## Étape 2.4 — Thème "Deep Glass"

### Palette de couleurs

Toutes les couleurs définies dans `AppColors` (ou similaire) :

| Token | Valeur |
|---|---|
| `deepBlack` | `#050505` |
| `surfaceCard` | Blanc 5% opacité sur deepBlack |
| `electricBlue` | `#3B82F6` |
| `neonEmerald` | `#10B981` |
| `softRed` | `#EF4444` |
| `coolPurple` | `#A855F7` |
| `warmAmber` | `#F59E0B` |
| `textPrimary` | Blanc 90% |
| `textSecondary` | Blanc 60% |
| `textDisabled` | Blanc 30% |
| `borderSubtle` | Blanc 10% |

### ThemeData

Le thème Flutter doit configurer :
- `brightness` : dark
- `scaffoldBackgroundColor` : `deepBlack`
- `colorScheme` : dark avec `primary = electricBlue`
- `textTheme` : Plus Jakarta Sans (via `google_fonts`)
- Suppression du fond grisé par défaut sur les dialogs
- Style des `InputDecoration` pour les formulaires (bordures glass)

### Composant `GlassContainer`

Composant réutilisable pour tous les cards/panels :
- `BackdropFilter` avec blur configurable (défaut : 10)
- Fond blanc à 5% d'opacité
- Bordure blanc à 10% d'opacité
- `BorderRadius` de 24px
- Props : `child`, `blur`, `borderColor`, `padding`

### Checklist 2.4

- [x] Toutes les couleurs définies comme constantes
- [x] `ThemeData` dark configuré et appliqué dans `main.dart`
- [x] Police Plus Jakarta Sans chargée (corps de texte)
- [ ] Police Roboto Mono chargée (montants financiers) — à ajouter en Phase 3 si nécessaire
- [x] `GlassContainer` widget créé et fonctionnel

---

## Étape 2.5 — Navigation (GoRouter)

### Routes à définir

```
/login                    ← Écran de connexion
/                         ← Redirect vers /dashboard si connecté
ShellRoute (AppShell)
  /dashboard              ← Vue principale
  /journal                ← Liste chronologique
  /schedule               ← Échéancier
  /budget                 ← Planification
  /analysis               ← Charts
```

### Comportement requis

- Redirection automatique vers `/login` si non authentifié
- Redirection vers `/dashboard` si déjà connecté et accès à `/login`
- `url_strategy` configuré pour URLs sans `#` sur web
- ShellRoute enveloppe les routes principales dans `AppShell`

### `AppShell` — Layout Responsive

Le composant `AppShell` adapte la navigation selon la largeur d'écran :

| Largeur | Navigation |
|---|---|
| < 768px (Mobile) | `BottomNavigationBar` en bas |
| 768–1024px (Tablet) | Sidebar icons uniquement (repliée) |
| > 1024px (Desktop) | Sidebar complète avec labels |

**Items de navigation (dans l'ordre) :**

| Icône | Label | Route |
|---|---|---|
| `dashboard` | Tableau de bord | `/dashboard` |
| `list_alt` | Journal | `/journal` |
| `calendar_today` | Échéancier | `/schedule` |
| `pie_chart` | Budget | `/budget` |
| `analytics` | Analyse | `/analysis` |

### Checklist 2.5

- [x] Routes définies avec GoRouter
- [x] `ProviderScope` + `MaterialApp.router` dans `main.dart`
- [x] Redirection login/dashboard fonctionnelle
- [x] `AppShell` créé et responsive
- [x] URLs sans `#` sur web
- [ ] Navigation testée sur tous les breakpoints (validation runtime)

---

## Étape 2.6 — Authentification Supabase

### Flux attendu

1. L'utilisateur arrive sur `/login`
2. Saisit email + mot de passe
3. Flutter SDK Supabase appelle `signInWithPassword`
4. En cas de succès : redirection vers `/dashboard`
5. En cas d'erreur : message d'erreur affiché

### Provider Riverpod pour l'auth

- Un provider observe l'état de session Supabase
- Il expose : `isAuthenticated`, `userId`, `accessToken`
- Le router écoute ce provider pour les redirections
- En cas de déconnexion : redirection automatique vers `/login`

### Écran de login

Design conforme au thème Deep Glass :
- Fond `deepBlack`
- Logo/titre "Solver" centré
- `GlassContainer` autour du formulaire
- Champ email + champ password
- Bouton "Se connecter"
- Messages d'erreur lisibles

### Checklist 2.6

- [x] Provider auth créé avec Riverpod
- [x] `Supabase.initialize` appelé dans `main.dart` avec les bonnes variables
- [x] Écran login fonctionnel
- [ ] Login réussi redirige vers dashboard (validation runtime)
- [ ] Erreur login affichée proprement (validation runtime)
- [ ] Déconnexion fonctionnelle (validation runtime)
- [ ] Session persistée entre les rechargements (validation runtime)

---

## Étape 2.7 — Client HTTP (Dio)

### Configuration

Le client Dio est fourni via un provider Riverpod avec :
- `baseUrl` depuis `AppConfig.apiBaseUrl`
- Intercepteur JWT : ajoute automatiquement le token Supabase à chaque requête
- Intercepteur d'erreur : gère les 401 (token expiré → refresh ou logout)
- Timeout : 30 secondes

### Gestion des erreurs réseau

Toutes les erreurs Dio sont transformées en types d'erreur métier :
- `401` → Redirection login
- `404` → Ressource non trouvée (affiché à l'UI)
- `500` → Erreur serveur (message générique)
- Timeout / Connexion perdue → Message réseau

### Checklist 2.7

- [x] Provider Dio créé
- [x] Intercepteur JWT fonctionnel (token attaché automatiquement)
- [ ] Gestion 401 (refresh ou redirect) — à implémenter en Phase 3
- [x] Timeouts configurés
- [ ] Test : appel API avec token valide → succès (validation runtime)
- [ ] Test : appel API sans login → redirect login (validation runtime)

---

## Validation Finale de la Phase 2

### Test d'intégration à effectuer

1. Lancer `flutter run -d chrome`
2. L'application s'ouvre sur `/login`
3. Login avec un compte de test Supabase
4. Redirection vers `/dashboard` (vide pour l'instant)
5. Navigation entre les 5 routes via sidebar/bottom bar
6. Rechargement de la page → session maintenue
7. Déconnexion → retour sur `/login`

### Checklist finale

- [x] Application compile sans erreur ni warning (`flutter analyze` : 0 issues)
- [ ] Thème Deep Glass appliqué correctement (validation runtime)
- [ ] Navigation fonctionnelle (5 routes) (validation runtime)
- [ ] Responsive vérifié sur 3 tailles (validation runtime)
- [ ] Authentification Supabase fonctionnelle (validation runtime)
- [x] Client HTTP configuré
- [x] Aucun secret hardcodé dans le code source

---

## Passage à la Phase Suivante

La Phase 2 terminée débloque :
- **→ Phase 3** : Dashboard (peut démarrer dès que Phase 1 ET Phase 2 sont terminées)
