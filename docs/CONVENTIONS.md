# Solver — Conventions et Standards

> Référence : [PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md)

Ces conventions sont **obligatoires** pour toute contribution humaine ou IA. Elles garantissent la cohérence du codebase sur la durée.

---

## Langue

| Contexte | Langue |
|---|---|
| Code (variables, fonctions, classes, fichiers) | **Anglais** |
| Commentaires dans le code | **Anglais** |
| Textes affichés à l'utilisateur (UI) | **Français** |
| Fichiers de documentation (`docs/`) | **Français** |
| Messages de commit Git | **Anglais** |
| Noms de branches Git | **Anglais** |

---

## Conventions Flutter / Dart

### Nomenclature des fichiers

| Type | Convention | Exemple |
|---|---|---|
| Fichiers Dart | `snake_case` | `dashboard_view.dart` |
| Dossiers | `snake_case` | `features/dashboard/` |
| Classes | `PascalCase` | `DashboardView` |
| Variables / méthodes | `camelCase` | `currentBalance` |
| Constantes | `camelCase` | `maxMonths` |
| Providers Riverpod | `camelCase` + suffixe `Provider` | `dashboardDataProvider` |

### Structure des dossiers Flutter

```
lib/
├── core/
│   ├── config/           ← Constantes globales et configuration
│   ├── theme/            ← Thème, couleurs, styles
│   ├── router/           ← GoRouter configuration
│   └── services/         ← Client HTTP (Dio), services partagés
├── features/
│   ├── auth/
│   │   ├── providers/    ← Riverpod providers
│   │   ├── views/        ← Écrans complets
│   │   └── widgets/      ← Composants spécifiques à la feature
│   ├── dashboard/
│   ├── journal/
│   ├── schedule/
│   ├── budget/
│   └── analysis/
├── shared/
│   └── widgets/          ← Composants réutilisables entre features
└── l10n/                 ← Fichiers ARB de localisation
```

### Règles Riverpod

- Un provider = un fichier dédié dans `providers/`
- Toujours utiliser `AsyncValue` pour les données asynchrones
- Invalider le provider concerné après chaque mutation (POST/PUT/DELETE)
- Utiliser `ref.watch` dans `build()`, `ref.read` dans les callbacks

### Règles GoRouter

- Routes définies comme constantes nommées
- Navigation toujours via `context.go()` ou `context.push()`, jamais via `Navigator.push()`
- ShellRoute pour la navigation principale avec sidebar/bottom bar
- URL sans fragment `#` (configuration `url_strategy` requise)

### Gestion des erreurs

- Toutes les erreurs réseau sont capturées au niveau du provider
- Les erreurs sont affichées à l'utilisateur via des widgets dédiés (jamais silent fail)
- Log des erreurs en console (dev) — jamais en production

---

## Conventions .NET / C#

### Nomenclature

| Type | Convention | Exemple |
|---|---|---|
| Fichiers | `PascalCase` | `DashboardService.cs` |
| Classes | `PascalCase` | `DashboardService` |
| Méthodes | `PascalCase` | `GetDashboardDataAsync` |
| Variables locales | `camelCase` | `userId` |
| Propriétés | `PascalCase` | `CreatedAt` |
| Paramètres | `camelCase` | `accountId` |
| Interfaces | Préfixe `I` + PascalCase | `IDashboardService` |

### Structure des dossiers .NET

```
src/Solver.Api/
├── Models/           ← Entités EF Core (tables DB)
├── DTOs/             ← Data Transfer Objects (entrées/sorties API)
├── Services/         ← Logique métier isolée
├── Data/             ← DbContext et configurations EF
├── Middleware/       ← Middleware HTTP (auth, logging)
└── Endpoints/        ← Groupes d'endpoints Minimal API
```

### Règles des endpoints

- Endpoints groupés par ressource dans des fichiers dédiés
- Toujours récupérer le `userId` depuis `HttpContext.Items`, jamais depuis le body
- Validation des DTOs via DataAnnotations ou FluentValidation
- Toujours retourner des types `Results.*` explicites

### Règles EF Core

- Tables en `snake_case` (convention PostgreSQL)
- Toujours inclure un index sur `user_id`
- Toujours inclure un index sur les colonnes de filtrage fréquent (`date`, `status`)
- Utiliser `Include()` pour éviter les requêtes N+1
- Utiliser `AddRangeAsync()` pour les insertions multiples

---

## Conventions Git

### Branches

```
main                    ← Production stable uniquement
feat/nom-fonctionnalite ← Nouvelles fonctionnalités
fix/nom-du-bug          ← Corrections de bugs
chore/tache             ← Tâches non-fonctionnelles (deps, config)
```

### Messages de commit

Format : `type(scope): description courte`

| Type | Usage |
|---|---|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `chore` | Maintenance, dépendances |
| `refactor` | Refactorisation sans changement fonctionnel |
| `docs` | Documentation uniquement |
| `test` | Ajout ou modification de tests |

Exemples :
- `feat(dashboard): add 12-month grid component`
- `fix(auth): handle token expiration correctly`
- `chore(deps): update supabase_flutter to 2.8.0`

### Règles Git

- Un commit = une fonctionnalité ou correction complète
- Ne jamais commit de secrets ou fichiers `.env`
- Ne jamais push directement sur `main` sans validation
- Pull Request requis pour tout merge sur `main`

---

## Conventions de Variables d'Environnement

### Préfixes par contexte

| Contexte | Préfixe | Exemple |
|---|---|---|
| Flutter (public) | Aucun | `SUPABASE_URL` |
| .NET (serveur) | Aucun | `DB_CONNECTION_STRING` |
| ~~NEXT_PUBLIC_~~ | ❌ Jamais | Préfixe Next.js, non applicable |
| ~~EXPO_PUBLIC_~~ | ❌ Jamais | Préfixe Expo/RN, non applicable |

### Variables requises

**Flutter** (fichier `.env.local`) :

| Variable | Description |
|---|---|
| `SUPABASE_URL` | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | Clé publique Supabase |

**Backend .NET** (fichier `.env`) :

| Variable | Description |
|---|---|
| `SUPABASE_URL` | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | Clé publique Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Clé secrète (serveur uniquement) |
| `DB_CONNECTION_STRING` | Connection string PostgreSQL |
| `JWT_SECRET` | Secret pour validation JWT |

---

## Conventions d'API REST

| Action | Méthode | URL |
|---|---|---|
| Lister | GET | `/api/accounts` |
| Créer | POST | `/api/accounts` |
| Lire un | GET | `/api/accounts/{id}` |
| Modifier | PUT | `/api/accounts/{id}` |
| Supprimer | DELETE | `/api/accounts/{id}` |
| Action métier | POST | `/api/transactions/batch` |

### Réponses HTTP

| Cas | Code |
|---|---|
| Succès (lecture) | 200 |
| Succès (création) | 201 |
| Pas de contenu | 204 |
| Mauvaise requête | 400 |
| Non authentifié | 401 |
| Accès refusé | 403 |
| Non trouvé | 404 |
| Erreur serveur | 500 |

---

## Design System

### Couleurs (Deep Glass Theme)

| Token | Valeur Hex | Usage |
|---|---|---|
| `deepBlack` | `#050505` | Fond principal |
| `electricBlue` | `#3B82F6` | Primaire, actions, solde actuel |
| `neonEmerald` | `#10B981` | Revenus, positif |
| `softRed` | `#EF4444` | Dépenses, négatif, alertes |
| `coolPurple` | `#A855F7` | Secondaire, accents |
| `warmAmber` | `#F59E0B` | Warnings, pending |

### Typographie

- Police principale : **Plus Jakarta Sans** (Google Fonts)
- Police chiffres : **Roboto Mono** (monospace pour alignement)

### Breakpoints Responsive

| Nom | Largeur | Comportement |
|---|---|---|
| Mobile | < 768px | Bottom navigation bar |
| Tablet | 768–1024px | Sidebar repliée |
| Desktop | > 1024px | Sidebar complète |
