# Solver

Application de gestion financiere personnelle. Dashboard annuel, journal, echeancier, budget zero-based et analyse graphique. Stack: Flutter Web + .NET 10 Minimal API + Supabase (PostgreSQL + Auth).

## Prerequis

| Outil | Version |
|---|---|
| Flutter | >= 3.10 |
| .NET SDK | 10.0 |
| Node.js | >= 18 (pour Supabase CLI) |
| Supabase CLI | via `npx supabase` |

## Installation locale

### 1. Backend (.NET)

```bash
cd backend/src/Solver.Api
cp .env.example .env
# Remplir les valeurs dans .env (DB_CONNECTION_STRING, SUPABASE_URL)
dotnet run
```

Le serveur demarre sur `http://localhost:5108`.

### 2. Frontend (Flutter Web)

```bash
# Depuis la racine du projet
cp config.example.json .env.local
# Remplir SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL
flutter run -d chrome
```

## Variables d'environnement

### Backend (`backend/src/Solver.Api/.env`)

| Variable | Description |
|---|---|
| `DB_CONNECTION_STRING` | Chaine de connexion PostgreSQL (pooler Supabase) |
| `DB_RUNTIME_CONNECTION_STRING` | (Optionnel) Chaine runtime directe (non-pooler), prioritaire sur `DB_CONNECTION_STRING` |
| `DB_MIGRATIONS_CONNECTION_STRING` | Chaine directe (non-pooler) pour appliquer les migrations EF au demarrage |
| `DB_APPLY_MIGRATIONS_ON_STARTUP` | Active/desactive les migrations EF automatiques au demarrage |
| `SUPABASE_URL` | URL du projet Supabase (pour JWKS) |
| `ALLOWED_ORIGINS` | (Production) Origines CORS autorisees, separees par des virgules |
| `AUTH_ALLOW_HS256_FALLBACK` | Fallback legacy HS256 (desactive recommande hors dev) |
| `JWT_SECRET` | Secret fallback HS256 (uniquement si fallback active) |
| `JWT_VALIDATE_ISSUER` | Active la validation issuer JWT |
| `JWT_VALIDATE_AUDIENCE` | Active la validation audience JWT |
| `JWT_ALLOWED_AUDIENCES` | Audiences JWT autorisees (CSV) |

Note migration Supabase:
- Si `DB_CONNECTION_STRING` pointe vers `*.pooler.supabase.com`, les migrations EF auto doivent utiliser `DB_MIGRATIONS_CONNECTION_STRING` (connexion directe) ou etre desactivees via `DB_APPLY_MIGRATIONS_ON_STARTUP=false`.
- Si tu observes des erreurs runtime pooler (`XX000 DbHandler exited`), configure `DB_RUNTIME_CONNECTION_STRING` vers l'hote direct (`db.<project-ref>.supabase.co`).

### Frontend (`.env.local` ou `config.json`)

| Variable | Description |
|---|---|
| `SUPABASE_URL` | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | Cle anonyme Supabase |
| `API_BASE_URL` | URL du backend (defaut: `http://localhost:5108`) |

## Build production (Flutter)

```bash
flutter build web --dart-define-from-file=config.prod.json --web-renderer canvaskit
```

Le fichier `config.prod.json` contient les memes variables que `config.example.json` avec les valeurs de production. Ce fichier ne doit jamais etre commite — il est injecte par le CI/CD.

## Tests

```bash
# Backend (.NET)
cd backend
dotnet test tests/Solver.Tests/ --configuration Release

# Frontend (Flutter)
flutter test
```

## Structure du projet

```
solver/
  lib/
    core/           # Config, router, theme, services, constantes
    features/       # Modules metier (dashboard, journal, schedule, budget, analysis, auth, accounts, transactions)
    shared/         # Widgets reutilisables (KpiCard, GlassContainer, AppShell)
  test/             # Tests Flutter
  backend/
    src/Solver.Api/ # API .NET 10 (Endpoints, Middleware, Models, DTOs, Services)
    tests/          # Tests xUnit
  docs/
    refactor_master_plan.md   # Plan actif de refactor
    refactor_backlog.md       # Etat d'avancement actif
    maintenance_governance.md # Regles PR/CI et gouvernance
    archive/                  # Documentation historique archivee
    PROJECT_OVERVIEW.md
    CONVENTIONS.md
    SECURITY.md
```

## Architecture

Voir [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) pour l'architecture detaillee.

## Conventions

Voir [docs/CONVENTIONS.md](docs/CONVENTIONS.md) pour les conventions de code et Git.
