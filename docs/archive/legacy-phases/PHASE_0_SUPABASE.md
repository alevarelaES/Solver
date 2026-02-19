# Phase 0 — Configuration Supabase

> Références : [PROJECT_OVERVIEW.md](../../PROJECT_OVERVIEW.md) | [SECURITY.md](../../SECURITY.md)
>
> **Statut :** ✅ Terminé
>
> **Prérequis :** Aucun — c'est la première phase
>
> **Bloque :** Phase 1 (Backend) et Phase 2 (Flutter)

---

## Objectif

Avoir un projet Supabase entièrement configuré avec les tables, les politiques de sécurité, et l'authentification prêts à être utilisés par le backend .NET et l'application Flutter.

---

## Contexte

Supabase joue deux rôles dans l'architecture Solver :

1. **Base de données** : PostgreSQL managé avec les tables `accounts` et `transactions`
2. **Authentification** : Gestion des utilisateurs, tokens JWT, sessions

L'application Flutter communique avec Supabase **uniquement pour l'authentification**. Toutes les données passent par le backend .NET qui valide le JWT Supabase.

---

## Étape 0.1 — Créer le Projet Supabase

### Actions

1. Se connecter sur [supabase.com](https://supabase.com)
2. Créer une nouvelle organisation si nécessaire
3. Cliquer sur **"New Project"**
4. Remplir les champs :
   - **Name** : `solver`
   - **Database Password** : Générer un mot de passe fort (min 20 caractères) et le sauvegarder immédiatement dans un gestionnaire de mots de passe
   - **Region** : Europe Central (Frankfurt) — ou la région la plus proche des utilisateurs
5. Attendre la création du projet (environ 2 minutes)

### Résultat attendu

- Tableau de bord Supabase accessible
- URL du projet disponible (format `https://[ref].supabase.co`)

---

## Étape 0.2 — Récupérer les Credentials

### Actions

1. Aller dans **Project Settings → API**
2. Copier et sauvegarder :
   - **Project URL** → sera `SUPABASE_URL`
   - **anon / public key** → sera `SUPABASE_ANON_KEY`
   - **service_role / secret key** → sera `SUPABASE_SERVICE_ROLE_KEY`

3. Aller dans **Project Settings → Database**
4. Section **Connection string → URI**
5. Copier la connection string et remplacer `[YOUR-PASSWORD]` par le mot de passe créé en 0.1
   - Cette chaîne sera `DB_CONNECTION_STRING`

### ⚠️ Sécurité

- La `service_role` key donne un accès **total** à la base de données en contournant le RLS
- Elle ne doit **jamais** être dans le code Flutter ou dans Git
- La stocker uniquement dans le fichier `.env` du backend .NET

---

## Étape 0.3 — Créer les Tables

Les tables sont créées via l'éditeur SQL de Supabase (**Table Editor** ou **SQL Editor**).

### Ordre de création

1. Table `accounts` en premier (référencée par `transactions`)
2. Table `transactions` ensuite

### Table `accounts`

Colonnes à créer :

| Colonne | Type Postgres | Contraintes |
|---|---|---|
| `id` | `uuid` | PRIMARY KEY, DEFAULT `gen_random_uuid()` |
| `user_id` | `uuid` | NOT NULL, REFERENCES `auth.users(id)` ON DELETE CASCADE |
| `name` | `text` | NOT NULL, CHECK length ≤ 100 |
| `type` | `text` | NOT NULL, CHECK IN ('income', 'expense') |
| `group` | `text` | NOT NULL |
| `is_fixed` | `boolean` | NOT NULL, DEFAULT `false` |
| `budget` | `numeric(12,2)` | NOT NULL, DEFAULT `0`, CHECK ≥ 0 |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` |

### Table `transactions`

Colonnes à créer :

| Colonne | Type Postgres | Contraintes |
|---|---|---|
| `id` | `uuid` | PRIMARY KEY, DEFAULT `gen_random_uuid()` |
| `account_id` | `uuid` | NOT NULL, REFERENCES `accounts(id)` ON DELETE CASCADE |
| `user_id` | `uuid` | NOT NULL, REFERENCES `auth.users(id)` ON DELETE CASCADE |
| `date` | `date` | NOT NULL |
| `amount` | `numeric(12,2)` | NOT NULL, CHECK > 0 |
| `note` | `text` | NULLABLE |
| `status` | `text` | NOT NULL, CHECK IN ('completed', 'pending'), DEFAULT 'pending' |
| `is_auto` | `boolean` | NOT NULL, DEFAULT `false` |
| `created_at` | `timestamptz` | NOT NULL, DEFAULT `now()` |

### Index à créer manuellement

Sur `accounts` :
- Index sur `user_id`

Sur `transactions` :
- Index sur `user_id`
- Index composite sur `(user_id, date)`
- Index sur `account_id`

---

## Étape 0.4 — Configurer Row Level Security (RLS)

### Activer RLS

Activer RLS sur les deux tables dans **Table Editor → [table] → RLS Policies**.

### Policies à créer

Pour chaque table, créer 4 policies (une par opération) :

**Table `accounts` :**

| Policy | Opération | Expression |
|---|---|---|
| `accounts_select_own` | SELECT | `auth.uid() = user_id` |
| `accounts_insert_own` | INSERT | `auth.uid() = user_id` |
| `accounts_update_own` | UPDATE | `auth.uid() = user_id` |
| `accounts_delete_own` | DELETE | `auth.uid() = user_id` |

**Table `transactions` :**

| Policy | Opération | Expression |
|---|---|---|
| `transactions_select_own` | SELECT | `auth.uid() = user_id` |
| `transactions_insert_own` | INSERT | `auth.uid() = user_id` |
| `transactions_update_own` | UPDATE | `auth.uid() = user_id` |
| `transactions_delete_own` | DELETE | `auth.uid() = user_id` |

---

## Étape 0.5 — Configurer l'Authentification

### Actions dans Supabase Auth Settings

1. Aller dans **Authentication → Providers**
2. S'assurer que **Email** est activé
3. Configurer les options :
   - **Confirm email** : Désactiver pour le développement (réactiver en production)
   - **Secure email change** : Activer
   - **Minimum password length** : 8 caractères

4. Aller dans **Authentication → URL Configuration**
5. Ajouter les Redirect URLs autorisées :
   - `http://localhost:*` (pour le développement Flutter Web)
   - L'URL de production une fois connue

---

## Étape 0.6 — Créer les Fichiers d'Environnement Locaux

### Fichier `config.example.json` (à commiter — sans valeurs réelles)

Ce fichier sert de template pour les autres développeurs et les IAs.

Champs à documenter :
- `SUPABASE_URL` : URL du projet Supabase
- `SUPABASE_ANON_KEY` : Clé publique (anon)

### Fichier `.env.local` (Flutter — ne pas commiter)

Variables à renseigner avec les vraies valeurs :
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

**⚠️ Ne pas utiliser les préfixes `NEXT_PUBLIC_` ou `EXPO_PUBLIC_`** — ces préfixes sont spécifiques à Next.js et Expo. Dans ce projet Flutter, les variables n'ont pas de préfixe.

### Fichier `.env` (Backend .NET — ne pas commiter)

Variables à renseigner :
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `DB_CONNECTION_STRING`

### Vérifier `.gitignore`

S'assurer que ces entrées sont présentes dans `.gitignore` :
- `.env`
- `.env.local`
- `.env.*`
- `config.json`

---

## Validation de la Phase 0

### Checklist complète

**Supabase :**
- [x] Projet créé et accessible
- [x] Credentials (URL, anon key, service_role, connection string) sauvegardés en sécurité
- [x] Table `accounts` créée avec toutes les colonnes et contraintes
- [x] Table `transactions` créée avec toutes les colonnes et contraintes
- [x] Tous les index créés
- [x] RLS activé sur les deux tables
- [x] 8 policies RLS créées (4 par table)
- [x] Auth configuré (email provider, no confirm en dev)
- [x] URL de redirect configurée pour localhost

**Fichiers locaux :**
- [x] `.env.local` créé avec les vraies valeurs (non commité)
- [ ] `.env` (backend) créé avec les vraies valeurs → à faire en Phase 1
- [x] `config.example.json` créé avec des valeurs placeholder (commité)
- [x] `.gitignore` vérifié

**Test de validation :**
- [ ] Créer manuellement un utilisateur de test dans Supabase Auth
- [x] Tables visibles dans Table Editor
- [ ] Tester RLS (à valider en Phase 1 avec le backend)

---

## Passage à la Phase Suivante

Une fois toutes les cases cochées, les phases suivantes peuvent démarrer en parallèle :

- **→ Phase 1** : Backend .NET (nécessite `DB_CONNECTION_STRING` et `SUPABASE_SERVICE_ROLE_KEY`)
- **→ Phase 2** : Flutter Foundation (nécessite `SUPABASE_URL` et `SUPABASE_ANON_KEY`)

