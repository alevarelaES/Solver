# Solver — Vue d'Ensemble du Projet

## Contexte

Solver est une application SaaS financière personnelle pensée pour remplacer les tableurs complexes. Elle offre deux lectures simultanées de la situation financière de l'utilisateur : le **Solde Réel** (ce qui est en banque aujourd'hui) et le **Solde Projeté** (ce qui restera en fin de mois une fois tous les paiements passés).

L'application cible **web, iOS et Android** via un seul codebase Flutter.

---

## Stack Technique

### Frontend

| Technologie | Rôle | Justification |
|---|---|---|
| Flutter | UI multiplateforme (web, iOS, Android) | Un seul codebase pour toutes les cibles |
| Riverpod | State management | Typage fort, testable, compile-safe |
| GoRouter | Navigation | Support ShellRoute, URL propres sans # |
| Dio | Appels HTTP | Intercepteurs JWT, gestion d'erreurs centralisée |
| Supabase Flutter | Authentification uniquement | SDK officiel pour login/logout/session |
| flutter_dotenv | Variables d'environnement (dev) | Chargement fichier .env local |

### Backend

| Technologie | Rôle | Justification |
|---|---|---|
| .NET 10 Minimal APIs | API REST | Performance, typage fort, modern C# |
| Entity Framework Core | ORM | Migrations, type-safe queries |
| Npgsql | Driver PostgreSQL | Optimisé pour Supabase/Postgres |
| JWT Bearer Auth | Validation des tokens Supabase | Stateless, scalable |

### Infrastructure

| Technologie | Rôle |
|---|---|
| Supabase | PostgreSQL managé + Auth + Row Level Security |
| GitHub | Contrôle de version |

---

## Architecture de Données

```
Utilisateur
    │
    │ Login (email/password)
    ▼
Supabase Auth ──── JWT Token ────►  Flutter App
                                        │
                                        │ Requêtes HTTP + Bearer Token
                                        ▼
                                   .NET Backend
                                        │
                                        │ Validation JWT + Queries filtrées par userId
                                        ▼
                                   Supabase PostgreSQL
                                   (Row Level Security activé)
```

**Principe de sécurité fondamental :**
Le .NET backend valide chaque token JWT Supabase et filtre TOUTES les données par `user_id`. Le RLS Supabase est une seconde couche de protection.

---

## Modèle de Données

### Table `accounts`

Représente les catégories financières de l'utilisateur (ex: Salaire, Loyer, Courses).

| Colonne | Type | Description |
|---|---|---|
| id | UUID | Identifiant unique |
| user_id | UUID | Propriétaire (FK vers auth.users) |
| name | TEXT | Nom du compte (ex: "Loyer") |
| type | TEXT | `income` ou `expense` |
| group | TEXT | Groupe parent (ex: "Charges Fixes") |
| is_fixed | BOOLEAN | Montant fixe ou variable |
| budget | DECIMAL | Montant budgété mensuel |
| created_at | TIMESTAMPTZ | Date de création (UTC) |

### Table `transactions`

Représente chaque mouvement financier, passé ou futur.

| Colonne | Type | Description |
|---|---|---|
| id | UUID | Identifiant unique |
| account_id | UUID | FK vers accounts |
| user_id | UUID | Propriétaire (dénormalisé pour RLS) |
| date | DATE | Date de la transaction |
| amount | DECIMAL | Montant (toujours positif) |
| note | TEXT | Note optionnelle |
| status | TEXT | `completed` ou `pending` |
| is_auto | BOOLEAN | Prélèvement automatique ou manuel |
| created_at | TIMESTAMPTZ | Date de création (UTC) |

---

## Les 5 Vues Principales

| Vue | Rôle | Priorité |
|---|---|---|
| **Dashboard** | Matrice 12 mois × comptes avec KPIs | P0 — Core |
| **Journal** | Liste chronologique avec filtres | P1 |
| **Échéancier** | Prochaines échéances (auto vs manuel) | P1 |
| **Budget** | Allocateur zero-based + monitoring | P2 |
| **Analysis** | Charts et tendances annuelles | P2 |

---

## Logique Métier Clé

### Dualité Solde Réel / Solde Projeté

- **Solde Réel** = solde bancaire actuel = somme des transactions `completed`
- **Solde Projeté** = solde estimé fin de mois = Solde Réel + toutes les transactions `pending` du mois courant

### Comportement Temporel des Cellules (Dashboard)

| Période | Comportement visuel | Données |
|---|---|---|
| Mois passés | Opacité réduite | Historique réel |
| Mois courant | Mise en valeur | Réel + pending |
| Mois futurs | Italique, transparent | Projections uniquement |

### Moteur de Récurrence

Une transaction peut être créée en "batch" pour tous les mois restants de l'année. Le jour du mois est respecté (avec gestion de février 28/29 jours).

---

## Structure des Fichiers de Documentation

```
docs/
├── PROJECT_OVERVIEW.md       ← Ce fichier
├── CONVENTIONS.md            ← Règles de code et nomenclature
├── SECURITY.md               ← Règles de sécurité obligatoires
└── phases/
    ├── PHASE_0_SUPABASE.md   ← Configuration Supabase
    ├── PHASE_1_BACKEND.md    ← API .NET
    ├── PHASE_2_FLUTTER.md    ← Fondations Flutter
    ├── PHASE_3_DASHBOARD.md  ← Vue Dashboard (core)
    ├── PHASE_4_RECURRENCE.md ← Moteur de récurrence
    ├── PHASE_5_VIEWS.md      ← Vues secondaires
    └── PHASE_6_POLISH.md     ← Finalisation
```

---

## Ordre d'Exécution des Phases

```
PHASE 0 (Supabase)
    └──► PHASE 1 (Backend .NET)
             └──► PHASE 2 (Flutter Fondations)
                      └──► PHASE 3 (Dashboard)
                               └──► PHASE 4 (Récurrence)
                                        └──► PHASE 5 (Vues secondaires)
                                                 └──► PHASE 6 (Polish)
```

Chaque phase doit être **entièrement validée** avant de passer à la suivante.

---

## Règles de Collaboration Multi-IA

Chaque fichier de phase est **autonome** : il contient tout le contexte nécessaire pour travailler dessus sans devoir lire les autres. Quand une IA travaille sur une phase, elle doit :

1. Lire ce fichier (`PROJECT_OVERVIEW.md`) en premier
2. Lire le fichier de la phase concernée
3. Lire `CONVENTIONS.md` et `SECURITY.md`
4. Ne modifier que ce qui concerne sa phase
5. Cocher les éléments de la checklist une fois complétés
