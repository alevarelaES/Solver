# Phase 1 — Backend .NET (API REST)

> Références : [PROJECT_OVERVIEW.md](../../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../../CONVENTIONS.md) | [SECURITY.md](../../SECURITY.md)
>
> **Statut :** ✅ Terminé
>
> **Prérequis :** Phase 0 complète — DB_CONNECTION_STRING disponible
>
> **Bloque :** Phase 3 (Dashboard), Phase 4 (Récurrence), Phase 5 (Vues)

---

## Objectif

Créer une API REST .NET 10 sécurisée qui :
- Valide les tokens JWT Supabase
- Expose les endpoints CRUD pour `accounts` et `transactions`
- Filtre toutes les données par `user_id`
- Est prête à recevoir les requêtes du frontend Flutter

---

## Contexte

Le backend est le **seul point d'accès** aux données. Il fait le lien entre le frontend Flutter (qui fournit un JWT Supabase) et la base de données PostgreSQL. Il ne stocke aucun état — chaque requête est indépendante.

**Important :** La connexion à Supabase se fait via la **connection string PostgreSQL directe**, pas via le SDK Supabase. EF Core parle directement à la base de données.

---

## Étape 1.1 — Initialisation de la Solution

### Structure cible

```
solver/
├── src/
│   └── Solver.Api/
│       ├── Models/
│       ├── DTOs/
│       ├── Services/
│       ├── Data/
│       ├── Middleware/
│       └── Endpoints/
├── Solver.sln
└── .env              ← Non commité
```

### Packages NuGet requis

| Package | Version | Usage |
|---|---|---|
| `Npgsql.EntityFrameworkCore.PostgreSQL` | Dernière stable | Driver PostgreSQL pour EF Core |
| `Microsoft.EntityFrameworkCore.Design` | Dernière stable | Outils de migration |
| `Microsoft.AspNetCore.Authentication.JwtBearer` | Dernière stable | Validation JWT |
| `dotenv.net` | Dernière stable | Chargement du fichier `.env` |

### Fichiers de configuration à créer

**`appsettings.json`** — Configuration non-sensible uniquement :
- Niveau de log
- Allowed hosts
- Configuration CORS (origines autorisées)

**`.env`** — Secrets uniquement (non commité) :
- `DB_CONNECTION_STRING`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `JWT_SECRET` (à récupérer dans Supabase → Settings → API → JWT Secret)

**`.env.example`** — Template avec clés mais sans valeurs (commité) :
- Mêmes clés que `.env`, avec valeurs vides ou descriptives

### Checklist 1.1

- [x] Solution créée (`dotnet new sln`)
- [x] Projet API créé (`dotnet new webapi`)
- [x] Structure de dossiers créée manuellement
- [x] Tous les packages NuGet installés
- [x] `appsettings.json` configuré (sans secrets)
- [x] `.env` créé avec les vraies valeurs (non commité)
- [x] `.env.example` créé (commité)
- [x] `dotnet build` passe sans erreur

---

## Étape 1.2 — Modèles de Données (EF Core)

### Entités à créer dans `Models/`

**`Account.cs`** — Miroir exact de la table `accounts` Supabase :

| Propriété C# | Colonne DB | Type C# |
|---|---|---|
| `Id` | `id` | `Guid` |
| `UserId` | `user_id` | `Guid` |
| `Name` | `name` | `string` |
| `Type` | `type` | `AccountType` (enum) |
| `Group` | `group` | `string` |
| `IsFixed` | `is_fixed` | `bool` |
| `Budget` | `budget` | `decimal` |
| `CreatedAt` | `created_at` | `DateTime` |

**`Transaction.cs`** — Miroir exact de la table `transactions` :

| Propriété C# | Colonne DB | Type C# |
|---|---|---|
| `Id` | `id` | `Guid` |
| `AccountId` | `account_id` | `Guid` |
| `UserId` | `user_id` | `Guid` |
| `Date` | `date` | `DateOnly` |
| `Amount` | `amount` | `decimal` |
| `Note` | `note` | `string?` |
| `Status` | `status` | `TransactionStatus` (enum) |
| `IsAuto` | `is_auto` | `bool` |
| `CreatedAt` | `created_at` | `DateTime` |

**Enums à créer :**
- `AccountType` : valeurs `Income`, `Expense` → stockées en DB comme `income`, `expense`
- `TransactionStatus` : valeurs `Completed`, `Pending` → stockées en DB comme `completed`, `pending`

### Configuration EF Core (`Data/SolverDbContext.cs`)

**Règles de mapping obligatoires :**
- Noms de tables en `snake_case` (via `ToTable("accounts")`)
- Enums stockés comme strings (pas entiers)
- Index créés en code (pas seulement en DB) pour cohérence
- Navigation property : `Transaction.Account` vers `Account`

### Migration

- Une seule migration initiale suffit pour cette phase
- La migration doit correspondre exactement à la structure déjà créée dans Supabase (Phase 0)
- Vérifier que `dotnet ef migrations add InitialCreate` ne génère pas de diffs inattendus

### Checklist 1.2

- [x] `Account.cs` créé avec toutes les propriétés
- [x] `Transaction.cs` créé avec toutes les propriétés
- [x] Enums créés et configurés pour conversion string
- [x] `SolverDbContext.cs` créé avec mapping complet
- [x] Index définis dans `OnModelCreating`
- [ ] Migration créée → non nécessaire (tables déjà créées via SQL en Phase 0)
- [ ] `dotnet ef database update` → non nécessaire (tables déjà créées via SQL en Phase 0)
- [x] Tables visibles et identiques dans Supabase Dashboard

---

## Étape 1.3 — Middleware d'Authentification

### Rôle

Ce middleware intercepte **chaque requête** HTTP et :
1. Extrait le token JWT du header `Authorization: Bearer <token>`
2. Valide la signature du token (JWT Secret Supabase)
3. Extrait le `user_id` (claim `sub`)
4. Injecte le `user_id` dans `HttpContext.Items["UserId"]`
5. Retourne 401 si le token est absent, invalide ou expiré

### Comportement attendu

| Situation | Réponse |
|---|---|
| Pas de header Authorization | 401 Unauthorized |
| Token malformé | 401 Unauthorized |
| Token expiré | 401 Unauthorized |
| Token valide | Passe au handler suivant avec UserId injecté |

### Routes exemptées de l'authentification

- `GET /health` — Endpoint de health check
- Toute route de documentation si OpenAPI est activé

### Checklist 1.3

- [x] Middleware créé dans `Middleware/SupabaseAuthMiddleware.cs`
- [x] JWT Secret chargé depuis les variables d'environnement
- [x] Validation de signature implémentée
- [x] Extraction du claim `sub` → `UserId`
- [x] Retour 401 pour tous les cas d'erreur
- [x] Middleware enregistré dans `Program.cs`
- [x] Test : requête sans token → 401 ✓ (vérifié)
- [ ] Test : requête avec token valide → 200 (à tester avec un vrai token)
- [ ] Test : requête avec token expiré → 401 (à tester)

---

## Étape 1.4 — DTOs

Les DTOs (Data Transfer Objects) définissent le contrat de l'API. Ils sont différents des entités EF Core.

### DTOs à créer dans `DTOs/`

**`AccountDto.cs`** — Pour création et modification :

| Champ | Type | Validation |
|---|---|---|
| `Name` | `string` | Requis, max 100 chars |
| `Type` | `AccountType` | Requis, valeur d'enum valide |
| `Group` | `string` | Requis, max 50 chars |
| `IsFixed` | `bool` | Requis |
| `Budget` | `decimal` | Requis, min 0 |

**`TransactionDto.cs`** — Pour création :

| Champ | Type | Validation |
|---|---|---|
| `AccountId` | `Guid` | Requis, GUID valide |
| `Date` | `DateOnly` | Requis, not in the far future (max +10 ans) |
| `Amount` | `decimal` | Requis, > 0 |
| `Note` | `string?` | Optionnel, max 500 chars |
| `Status` | `TransactionStatus` | Requis, valeur d'enum valide |
| `IsAuto` | `bool` | Requis |

### Checklist 1.4

- [x] `AccountDto.cs` créé avec validations
- [x] `TransactionDto.cs` créé avec validations
- [x] Les DTOs ne contiennent **pas** le `UserId` (il vient du JWT)

---

## Étape 1.5 — Endpoints CRUD

### Organisation

Chaque ressource a son propre fichier dans `Endpoints/` avec une méthode d'extension `Map[Resource]Endpoints`.

### Endpoints `accounts`

| Méthode | Route | Description |
|---|---|---|
| GET | `/api/accounts` | Lister tous les comptes de l'utilisateur |
| POST | `/api/accounts` | Créer un nouveau compte |
| PUT | `/api/accounts/{id}` | Modifier un compte existant |
| DELETE | `/api/accounts/{id}` | Supprimer un compte (cascade sur transactions) |

**Règles de sécurité pour chaque endpoint :**
- Toujours extraire `userId` depuis `HttpContext.Items["UserId"]`
- Sur PUT/DELETE : vérifier que l'entité appartient au `userId` avant d'agir
- Retourner 404 (pas 403) si l'entité n'appartient pas à l'utilisateur (évite l'énumération)

### Endpoints `transactions`

| Méthode | Route | Description |
|---|---|---|
| GET | `/api/transactions` | Lister les transactions (avec filtres) |
| POST | `/api/transactions` | Créer une transaction |
| PUT | `/api/transactions/{id}` | Modifier une transaction |
| DELETE | `/api/transactions/{id}` | Supprimer une transaction |

**Paramètres de filtre pour GET :**
- `accountId` (Guid, optionnel)
- `status` (string, optionnel)
- `month` (int, optionnel)
- `year` (int, optionnel)
- `showFuture` (bool, optionnel, défaut false)

### Endpoint de santé

- `GET /health` → retourne `{ "status": "ok" }`

### Checklist 1.5

- [x] Tous les endpoints `accounts` fonctionnels
- [x] Tous les endpoints `transactions` fonctionnels (+ batch)
- [x] Endpoint `/health` créé et testé ✓
- [x] Vérification propriété avant PUT/DELETE
- [x] Retour 404 pour entités appartenant à un autre user
- [x] Retour 201 avec location header pour les POST
- [x] Filtres transactions fonctionnels

---

## Étape 1.6 — Configuration CORS et Program.cs

### CORS

Pour que Flutter Web puisse appeler le backend en développement local, CORS doit autoriser les origines `localhost`.

**Configuration requise :**
- En développement : autoriser `http://localhost:*`
- Méthodes autorisées : GET, POST, PUT, DELETE, OPTIONS
- Headers autorisés : `Content-Type`, `Authorization`
- **Ne pas utiliser** `AllowAnyOrigin()` même en dev

### Order du pipeline

L'ordre dans `Program.cs` est important :

1. CORS
2. Auth Middleware (Supabase JWT)
3. Routing / Endpoints

### Checklist 1.6

- [x] CORS configuré et fonctionnel
- [x] `Program.cs` propre avec la configuration complète
- [x] Ordre du pipeline correct (CORS → Auth → Endpoints)
- [x] Logs configurés (Information level minimum)

---

## Validation Finale de la Phase 1

### Tests à effectuer avec un client HTTP (Postman, Thunder Client, etc.)

1. **Sans token** : `GET /api/accounts` → doit retourner 401
2. **Avec token valide** :
   - `POST /api/accounts` → crée un compte, retourne 201
   - `GET /api/accounts` → retourne la liste avec le compte créé
   - `PUT /api/accounts/{id}` → modifie le compte
   - `DELETE /api/accounts/{id}` → supprime le compte
3. **Isolation** : Avec deux tokens utilisateurs différents, vérifier qu'on ne voit pas les données de l'autre
4. **Health check** : `GET /health` sans token → 200

### Checklist finale

- [x] Solution compile (`dotnet build`) sans warning ✓ (0 erreur, 0 warning)
- [x] `/health` → 200 ✓
- [x] `/api/accounts` sans token → 401 ✓
- [ ] Test avec token valide → à valider en Phase 2 (Flutter auth)
- [x] Aucun secret dans le code source
- [x] `.env.example` à jour
- [x] Port fixé : 5108

---

## Passage à la Phase Suivante

La Phase 1 terminée débloque les phases en parallèle :
- **→ Phase 3** : Dashboard (nécessite les endpoints transactions et accounts)
- **→ Phase 4** : Récurrence (nécessite les endpoints transactions)
- **→ Phase 5** : Vues secondaires

