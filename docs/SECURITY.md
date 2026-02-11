# Solver — Règles de Sécurité

> Référence : [PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md)

Ce fichier définit les règles de sécurité **non négociables** du projet. Toute contribution doit les respecter.

---

## Principes Fondamentaux

### 1. Isolation des données par utilisateur

Chaque donnée appartient à un utilisateur précis. La sécurité est appliquée en **double couche** :

- **Couche 1 — Backend .NET** : Chaque requête filtre les données par `user_id` extrait du JWT. Il est impossible d'accéder aux données d'un autre utilisateur via l'API.
- **Couche 2 — Supabase RLS** : Row Level Security activé sur toutes les tables. Même si le backend était compromis, la base de données refuserait l'accès aux données d'autres utilisateurs.

Ces deux couches doivent être **toujours actives et testées**.

### 2. Séparation stricte des secrets

| Secret | Flutter | .NET Backend | Git |
|---|---|---|---|
| `SUPABASE_URL` | ✅ | ✅ | ❌ Jamais |
| `SUPABASE_ANON_KEY` | ✅ (publique) | ✅ | ❌ Jamais dans le code |
| `SUPABASE_SERVICE_ROLE_KEY` | ❌ Jamais | ✅ | ❌ Jamais |
| `DB_CONNECTION_STRING` | ❌ Jamais | ✅ | ❌ Jamais |
| `JWT_SECRET` | ❌ Jamais | ✅ | ❌ Jamais |

### 3. Le frontend ne fait jamais confiance au client

Le `user_id` est **toujours extrait du JWT côté serveur**, jamais accepté comme paramètre dans la requête. Un utilisateur ne peut pas usurper l'identité d'un autre en modifiant le body de sa requête.

---

## Gestion des Variables d'Environnement

### Flutter

**Méthode autorisée :** `flutter_dotenv` avec fichier `.env.local`

**⚠️ Avertissement critique** : Le fichier `.env.local` est déclaré comme asset dans `pubspec.yaml`. Cela signifie qu'il est **inclus dans le bundle de l'application** et peut être extrait par n'importe qui. Pour cette raison :

- `.env.local` ne doit contenir **que la clé anon** (conçue pour être publique)
- La `service_role` key ne doit **jamais** apparaître dans ce fichier
- En production, utiliser `--dart-define-from-file` à la place (non bundlé)

**Ce qui est acceptable dans `.env.local` :**
- `SUPABASE_URL` (URL publique du projet)
- `SUPABASE_ANON_KEY` (clé publique, conçue pour être exposée côté client)

**Ce qui est interdit dans `.env.local` :**
- `SUPABASE_SERVICE_ROLE_KEY`
- `DB_CONNECTION_STRING`
- Toute clé JWT ou secret

### Backend .NET

- Variables chargées via `dotenv.net` ou les variables d'environnement système
- Fichier `.env` à la racine du projet backend, **jamais commité**
- En production : injecter via les variables d'environnement du serveur (pas de fichier .env)

---

## Configuration Git

### Fichiers à ne jamais commiter

Ces fichiers doivent être dans `.gitignore` :

```
# Flutter
.env.local
.env
.env.*

# .NET
src/Solver.Api/.env
appsettings.Development.json

# Certificats et clés
*.pem
*.key
*.p12
*.pfx
```

### Vérification avant commit

Avant tout commit, vérifier qu'aucun de ces patterns n'est présent dans les fichiers modifiés :

- URLs Supabase hardcodées (pattern : `supabase.co`)
- Clés qui ressemblent à des JWT (chaînes base64 longues)
- Chaînes de connexion PostgreSQL (`postgresql://` ou `Host=`)
- Tout ce qui contient `password`, `secret`, `key` comme valeur littérale

---

## Supabase Row Level Security

### Règles obligatoires

Toutes les tables doivent avoir RLS **activé** avec les politiques suivantes :

**Table `accounts` :**
- SELECT : `user_id = auth.uid()`
- INSERT : `user_id = auth.uid()`
- UPDATE : `user_id = auth.uid()`
- DELETE : `user_id = auth.uid()`

**Table `transactions` :**
- SELECT : `user_id = auth.uid()`
- INSERT : `user_id = auth.uid()`
- UPDATE : `user_id = auth.uid()`
- DELETE : `user_id = auth.uid()`

### Test de validation RLS

Pour valider que le RLS fonctionne, il faut tester avec deux utilisateurs distincts et vérifier qu'aucun n'accède aux données de l'autre, même avec des requêtes SQL directes.

---

## Authentification

### Flux d'authentification

```
Utilisateur saisit email/password
    └──► Flutter SDK Supabase → Supabase Auth
              └──► JWT Token retourné
                       └──► Stocké en mémoire (session Supabase)
                                └──► Attaché à chaque requête HTTP (header Authorization)
                                         └──► .NET valide le JWT à chaque requête
```

### Règles de token

- Les tokens ne sont **jamais** stockés dans localStorage (web) sans précaution
- Les tokens expirent selon la configuration Supabase (défaut : 1 heure)
- Le refresh token est géré automatiquement par le SDK Supabase Flutter
- Sur 401, l'application doit rediriger vers la page de login

### CORS

Le backend .NET doit configurer CORS **explicitement** :

- En développement : autoriser `localhost` uniquement
- En production : autoriser uniquement le domaine de l'application
- Ne jamais utiliser `AllowAnyOrigin()` en production

---

## Validation des Entrées

### Côté backend (.NET)

- Tous les DTOs doivent avoir des contraintes de validation
- Les montants financiers : toujours positifs, limites max définies
- Les dates : pas de dates trop lointaines dans le futur (max +10 ans)
- Les chaînes de texte : longueur maximale définie (ex: `name` ≤ 100 chars)
- Les UUIDs : toujours validés comme GUID valide

### Côté frontend (Flutter)

- Validation des formulaires avant soumission
- Les erreurs de validation sont affichées à l'utilisateur
- Ne jamais désactiver la validation côté client (même si le backend la refait)

---

## Checklist Sécurité par Phase

### Avant de démarrer chaque phase

- [ ] `.gitignore` est à jour avec les nouveaux fichiers sensibles
- [ ] Aucun secret hardcodé dans le code à commiter

### Avant chaque merge sur `main`

- [ ] Audit manuel des fichiers modifiés pour détecter des secrets
- [ ] RLS testé sur toutes les tables modifiées
- [ ] CORS vérifié si des endpoints ont été ajoutés
- [ ] Validation des inputs vérifiée sur les nouveaux endpoints
