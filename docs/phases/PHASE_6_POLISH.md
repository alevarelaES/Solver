# Phase 6 — Polish, Tests et Finalisation

> Références : [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../CONVENTIONS.md) | [SECURITY.md](../SECURITY.md)
>
> **Statut :** ⏳ En attente de Phase 5
>
> **Prérequis :** Toutes les phases 0–5 complètes et validées
>
> **Bloque :** Rien — c'est la phase finale

---

## Objectif

Transformer un produit fonctionnel en un produit **soigné et robuste** :
- Responsive parfait sur tous les écrans
- Micro-animations et transitions fluides
- Tests unitaires sur les logiques critiques
- Performances optimisées
- Documentation finale à jour
- Préparation à la production

---

## Étape 6.1 — Audit Responsive Complet

### Appareils cibles à tester

| Appareil | Résolution | Notes |
|---|---|---|
| iPhone SE | 375×667 | Petit mobile |
| iPhone 14 Pro | 390×844 | Mobile standard |
| iPad Air | 820×1180 | Tablette |
| Desktop HD | 1440×900 | Standard |
| Desktop 4K | 2560×1440 | Grand écran |

### Points de vérification par vue

**Dashboard :**
- Scroll horizontal fonctionne sur mobile
- KPI cards en colonne sur mobile, en ligne sur desktop
- Footer sticky ne masque pas le contenu
- Le + flottant est accessible sans être gêné

**Journal :**
- Barre de filtres ne déborde pas sur mobile
- Items de liste lisibles sur petit écran
- BottomSheet modal bien dimensionné

**Échéancier :**
- Deux colonnes sur desktop, deux onglets sur mobile
- Cards lisibles sur petit écran

**Budget :**
- Allocateur utilisable au doigt sur mobile
- Sliders avec zone de tap suffisante

**Analyse :**
- Charts redimensionnés correctement
- Légendes lisibles

### Points communs à toutes les vues

- Aucun `overflow` (textes tronqués ou `...` plutôt que coupés)
- Zones de tap min 48×48px sur mobile
- Police lisible (min 14px sur mobile)
- Contraste suffisant (WCAG AA minimum)

### Checklist 6.1

- [ ] Testé sur 5 résolutions minimum
- [ ] Aucun overflow constaté
- [ ] Navigation mobile (bottom bar) accessible au pouce
- [ ] Formulaires utilisables au clavier (web) et au tactile (mobile)

---

## Étape 6.2 — Micro-animations et Transitions

### Philosophie

Les animations doivent être **subtiles** et **utiles** — elles guident l'attention, pas ne la distraient. Durées courtes (150–300ms), courbes d'accélération naturelles.

### Animations à implémenter

**Navigation :**
- Transition entre vues : fade ou slide selon la direction
- Durée : 200ms

**Dashboard :**
- KPI cards : fade-in séquentiel au chargement (décalage de 50ms entre chaque)
- Cellules grille : fade-in depuis le centre vers les bords
- Footer : slide-in depuis le bas

**GlassContainer :**
- Hover (web) : légère élévation + intensification du blur
- Press (mobile) : scale down 0.98

**Modal / BottomSheet :**
- Entrée : scale + fade (Dialog) ou slide up (BottomSheet)
- Sortie : inverse de l'entrée

**Boutons :**
- Ripple effect cohérent avec la palette
- Loading state : spinner intégré dans le bouton

**Erreurs / Succès :**
- Snackbar : slide-in depuis le bas, auto-dismiss après 3s
- Erreur formulaire : shake animation sur le champ

### Checklist 6.2

- [ ] Transitions entre vues fluides
- [ ] Animations KPI cards
- [ ] Hover effects sur web
- [ ] Loading states sur tous les boutons d'action
- [ ] Snackbar animé
- [ ] Aucune animation ne bloque l'interaction (tous `ignorePointer` pendant les transitions)

---

## Étape 6.3 — Tests Unitaires (Logiques Critiques)

### Philosophie

Tester uniquement les logiques métier **critiques** — celles où un bug aurait un impact financier ou de sécurité. Pas de tests pour les widgets simples.

### Backend — Tests requis

**`RecurrenceService` (priorité haute) :**
- Génère le bon nombre de transactions selon le mois de départ
- Gère correctement le mois de février (28 jours)
- Gère correctement les années bissextiles (29 jours en fév)
- Gère correctement les mois de 30 jours (avr, jun, sep, nov) quand `dayOfMonth = 31`
- Status correct : pending pour les mois futurs, respecte le choix pour le mois courant
- `dayOfMonth` invalide (0, 32) : retourne une erreur

**`DashboardService` (priorité haute) :**
- `currentBalance` = uniquement transactions `completed`
- `projectedEndOfMonth` = currentBalance + pending du mois courant
- Isolation : les données d'un user n'apparaissent pas pour un autre user

**`AuthMiddleware` (priorité haute) :**
- Token valide → `UserId` correctement extrait
- Token expiré → 401
- Token mallformé → 401
- Pas de token → 401
- `UserId` ne peut pas être forgé par le client

### Flutter — Tests requis

**Calculs financiers (`priorité haute`) :**
- `formatCurrency` formate correctement (2 décimales, symbole CHF)
- Calcul du taux d'épargne

**Logique temporelle des cellules (priorité moyenne) :**
- Cellule passée → correct identifié
- Cellule courante → correct identifié
- Cellule future → correct identifié

### Structure des tests

**Backend** : xUnit dans un projet `Solver.Tests` séparé

**Flutter** : `flutter_test` dans `test/` à la racine du projet

### Checklist 6.3

- [ ] Projet de tests .NET créé
- [ ] Tests `RecurrenceService` : 8 cas couverts
- [ ] Tests `DashboardService` : 3 cas couverts
- [ ] Tests `AuthMiddleware` : 4 cas couverts
- [ ] `dotnet test` passe en vert
- [ ] Tests Flutter : 3 cas couverts
- [ ] `flutter test` passe en vert

---

## Étape 6.4 — Optimisations de Performance

### Backend

**Requêtes DB :**
- Vérifier qu'aucune requête N+1 n'existe avec les outils de log EF Core
- Ajouter un index manquant si détecté
- Activer la mise en cache pour les données peu changeantes (comptes)

**API :**
- Ajouter la compression gzip sur les réponses
- Ajouter des headers de cache sur les endpoints stables (ex: `/api/accounts`)

### Flutter

**Chargement initial :**
- Utiliser `keepAlive` sur les providers pour éviter de recharger les vues déjà visitées
- Lazy loading : ne charger les données d'une vue qu'au premier accès

**Grille Dashboard :**
- Utiliser `const` widgets sur les cellules qui ne changent pas
- Éviter les rebuilds inutiles de Riverpod (utiliser `select` pour s'abonner à une partie du state)

**Images / Fonts :**
- Précharger les fonts Google dans `initState`
- Utiliser `flutter build web --web-renderer canvaskit` pour la qualité du rendu

### Checklist 6.4

- [ ] Aucune requête N+1 côté backend
- [ ] Compression gzip activée
- [ ] Providers Flutter avec `keepAlive`
- [ ] Temps de chargement initial < 3s sur connexion 4G

---

## Étape 6.5 — Préparation à la Production (Sécurité)

### Flutter Web

La stratégie `flutter_dotenv` + asset bundle n'est **pas adaptée à la production** pour la même raison qu'en développement : le fichier `.env.local` est lisible dans le bundle.

**Solution pour la production :**
Utiliser `--dart-define-from-file=config.prod.json` lors du build :
- `config.prod.json` n'est **jamais commité** ni dans le repo
- Il est injecté par le pipeline CI/CD au moment du build
- Les valeurs sont compilées dans le binaire (non extractibles facilement)

Documenter dans le README comment builder pour la production.

### Backend .NET

- Variables d'environnement injectées par le serveur (jamais de fichier `.env` en prod)
- HTTPS obligatoire (configurer redirection HTTP → HTTPS)
- CORS : restreindre à l'URL de production uniquement

### Checklist 6.5

- [ ] Stratégie de secrets pour la production documentée
- [ ] HTTPS configuré ou documenté
- [ ] CORS production configuré
- [ ] Variables d'environnement de production listées dans le README

---

## Étape 6.6 — Documentation Finale

### README.md à la racine du projet

Le README doit permettre à un développeur de démarrer en moins de 15 minutes. Il doit contenir :

**Sections obligatoires :**

1. **Description** — Ce qu'est Solver en 2-3 phrases
2. **Prérequis** — Node/Flutter/dotnet/Supabase CLI versions
3. **Installation locale (Backend)** — Commandes exactes pour lancer le .NET
4. **Installation locale (Flutter)** — Commandes exactes pour lancer Flutter Web
5. **Variables d'environnement** — Référence vers les fichiers `.env.example` et `config.example.json`
6. **Structure du projet** — Arborescence commentée
7. **Architecture** — Lien vers `docs/PROJECT_OVERVIEW.md`
8. **Contribution** — Référence aux conventions Git dans `docs/CONVENTIONS.md`

### Mise à jour des checklists dans les phases

Vérifier et cocher tous les items dans les fichiers `docs/phases/*.md`.

### Checklist 6.6

- [ ] `README.md` créé et complet
- [ ] Toutes les checklists des phases mises à jour
- [ ] `config.example.json` à jour avec toutes les variables nécessaires
- [ ] `.env.example` (backend) à jour

---

## Validation Finale du Projet

### Test de bout en bout complet

1. Nouvel utilisateur → inscription → connexion
2. Créer 3 comptes (1 revenu, 2 dépenses avec groupes différents)
3. Créer un salaire récurrent (12 mois)
4. Créer un loyer récurrent (remaining months)
5. Valider le salaire et le loyer du mois actuel
6. Vérifier le Dashboard : KPIs corrects, grille correcte
7. Aller sur le Journal : filtres fonctionnels
8. Aller sur l'Échéancier : prochains paiements visibles
9. Aller sur le Budget : reste à vivre calculé
10. Aller sur l'Analyse : charts avec données
11. Tester sur mobile + desktop

### Checklist finale du projet

**Fonctionnel :**
- [ ] Les 5 vues fonctionnent correctement
- [ ] Création / modification / suppression de transactions
- [ ] Récurrence fonctionnelle
- [ ] Calculs financiers corrects

**Technique :**
- [ ] `dotnet build` sans warnings
- [ ] `flutter build web` sans warnings
- [ ] Tous les tests passent
- [ ] Aucun secret dans Git

**UX :**
- [ ] Responsive sur mobile et desktop
- [ ] Animations fluides
- [ ] Messages d'erreur clairs
- [ ] Loading states présents

**Documentation :**
- [ ] README complet
- [ ] Toutes les phases cochées
