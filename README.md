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
| `SUPABASE_URL` | URL du projet Supabase (pour JWKS) |
| `ALLOWED_ORIGINS` | (Production) Origines CORS autorisees, separees par des virgules |

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
    phases/         # Phases d'implementation (PHASE_0 a PHASE_6)
    PROJECT_OVERVIEW.md
    CONVENTIONS.md
    SECURITY.md
```

## Architecture

Voir [docs/PROJECT_OVERVIEW.md](docs/PROJECT_OVERVIEW.md) pour l'architecture detaillee.

## Conventions

Voir [docs/CONVENTIONS.md](docs/CONVENTIONS.md) pour les conventions de code et Git.
