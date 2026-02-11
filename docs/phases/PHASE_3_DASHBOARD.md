# Phase 3 — Dashboard (Vue Core)

> Références : [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../CONVENTIONS.md)
>
> **Statut :** ✅ Terminé
>
> **Prérequis :** Phase 1 (Backend) ET Phase 2 (Flutter) complètes
>
> **Bloque :** Phase 4 (Récurrence — dépend du modal transaction)

---

## Objectif

Implémenter la vue principale de Solver : une **grille 12 mois × comptes** qui donne une vision financière complète de l'année, avec KPIs en en-tête et solde projeté en pied de page.

C'est la feature la plus importante de l'application. Elle doit être parfaite avant de passer à la suite.

---

## Contexte

Le dashboard est le cœur de Solver. L'utilisateur y passe la majorité de son temps. Il affiche :

- **4 KPI cards** en haut : Solde Réel, Revenus du mois, Dépenses du mois, Solde Projeté fin de mois
- **La grille centrale** : Lignes = comptes, Colonnes = 12 mois. Chaque cellule affiche le total des transactions pour ce compte ce mois-là.
- **Le footer sticky** : Ligne "Solde Fin de Mois" avec le solde projeté pour chaque mois futur

### Logique temporelle des cellules

| Mois | Fond | Texte | Signification |
|---|---|---|---|
| Passé (< mois actuel) | Opacité très réduite | Opacité 50% | Données historiques |
| Actuel (= mois actuel) | Légèrement mis en valeur | Normal | En cours |
| Futur (> mois actuel) | Transparent | Italique, opacité 70% | Projections |

### Logique couleurs des montants

| Condition | Couleur |
|---|---|
| Compte de type `income` | `neonEmerald` |
| Compte de type `expense` | `softRed` |
| Cellule vide (0) | `textDisabled` |

### Indicateur de transactions pending

Si une cellule contient des transactions `pending`, afficher une petite icône horloge à côté du montant.

---

## Étape 3.1 — Backend : Endpoint Dashboard

### Route

`GET /api/dashboard?year={year}`

### Données retournées

L'endpoint doit agréger les transactions et retourner une structure optimisée pour le frontend. Le frontend ne doit pas avoir à faire plusieurs appels ni à recalculer.

**Structure de réponse :**

```
{
  currentBalance: decimal,        ← Somme de toutes les transactions completed
  currentMonthIncome: decimal,    ← Revenus completed du mois actuel
  currentMonthExpenses: decimal,  ← Dépenses completed du mois actuel
  projectedEndOfMonth: decimal,   ← Solde après toutes les pending du mois actuel

  groups: [
    {
      groupName: string,
      accounts: [
        {
          accountId: uuid,
          accountName: string,
          accountType: "income" | "expense",
          months: {
            1: { total: decimal, pendingCount: int, completedCount: int },
            2: { ... },
            ... 12 mois
          }
        }
      ]
    }
  ]
}
```

### Logique de calcul côté backend

**`currentBalance`** = somme de toutes les transactions `completed` de l'utilisateur (tous les mois confondus)

**`projectedEndOfMonth`** = `currentBalance` + somme des transactions `pending` du mois courant

**Agrégation par groupe :**
- Récupérer tous les comptes de l'utilisateur avec leurs groupes
- Pour chaque compte, récupérer les transactions de l'année demandée
- Grouper par mois et calculer totaux + compteurs

### Performances

- Une seule requête DB avec `Include()` pour les comptes
- Calcul de l'agrégation en mémoire (le volume est limité : max 12 mois × N comptes)
- Pas de N+1 queries

### Checklist 3.1

- [x] Service intégré dans `DashboardEndpoints.cs` (logique en endpoint)
- [x] Calcul `currentBalance` correct (uniquement `completed`)
- [x] Calcul `projectedEndOfMonth` correct
- [x] Agrégation par groupe fonctionnelle
- [x] Compteurs `pending` vs `completed` corrects
- [x] Endpoint déclaré dans `DashboardEndpoints.cs`
- [x] Testé avec données réelles (4 comptes, 12 transactions via MCP)
- [ ] Temps de réponse < 500ms avec 1000 transactions (non mesuré)

---

## Étape 3.2 — Frontend : Modèles de Données

### Classes Dart à créer dans `features/dashboard/`

**`DashboardData`** — Miroir du DTO backend :
- `currentBalance` : `double`
- `currentMonthIncome` : `double`
- `currentMonthExpenses` : `double`
- `projectedEndOfMonth` : `double`
- `groups` : `List<GroupData>`

**`GroupData`** :
- `groupName` : `String`
- `accounts` : `List<AccountMonthlyData>`

**`AccountMonthlyData`** :
- `accountId` : `String`
- `accountName` : `String`
- `accountType` : `String` (`income` ou `expense`)
- `months` : `Map<int, MonthCell>` (clé = numéro de mois 1-12)

**`MonthCell`** :
- `total` : `double`
- `pendingCount` : `int`
- `completedCount` : `int`

Chaque classe doit implémenter `fromJson` pour la désérialisation.

### Checklist 3.2

- [x] Toutes les classes créées avec `fromJson`
- [x] Désérialisation testée avec une réponse réelle du backend

---

## Étape 3.3 — Frontend : Provider Riverpod

### Provider à créer dans `features/dashboard/providers/`

**`dashboardDataProvider`** :
- Paramètre : `year` (int)
- Appelle `GET /api/dashboard?year={year}`
- Retourne `AsyncValue<DashboardData>`
- Invalidé après chaque création/modification de transaction

**`selectedYearProvider`** :
- State provider (int)
- Valeur initiale : année courante
- Contrôlé par les boutons de navigation année

### Checklist 3.3

- [x] `dashboardDataProvider` créé et fonctionnel
- [x] `selectedYearProvider` créé
- [x] Loading state géré
- [x] Error state géré avec message utilisateur

---

## Étape 3.4 — Frontend : KPI Cards

### 4 cards à afficher en header

| Label | Valeur | Couleur |
|---|---|---|
| Solde Actuel | `currentBalance` | `electricBlue` |
| Revenus du Mois | `currentMonthIncome` | `neonEmerald` |
| Dépenses du Mois | `currentMonthExpenses` | `softRed` |
| Fin de Mois Estimée | `projectedEndOfMonth` | `coolPurple` si positif, `softRed` si négatif |

### Comportement du composant `KpiCard`

- Fond `GlassContainer`
- Icône en haut à gauche
- Label en texte secondaire
- Montant en grande police **Roboto Mono**
- Le montant est toujours formaté avec le symbole monétaire (CHF) et 2 décimales
- Responsive : en colonne sur mobile, en ligne sur desktop

### Checklist 3.4

- [x] 4 KPI cards affichées
- [x] Montants formatés correctement (CHF, Roboto Mono)
- [x] Couleur dynamique sur "Fin de Mois"
- [x] Responsive (grille 2 cols mobile, rangée desktop)

---

## Étape 3.5 — Frontend : La Grille

C'est le composant central et le plus complexe.

### Structure HTML/Widget

```
ScrollView horizontal
  └── Column
       ├── Header row (mois en colonnes : Jan, Fév, Mar...)
       ├── Pour chaque groupe :
       │    ├── Row "header groupe" (sticky-like, toute la largeur, fond opaque)
       │    └── Pour chaque compte du groupe :
       │         └── Row account (nom + 12 cellules)
       └── Footer sticky : "Solde Fin de Mois"
```

### Dimensions et layout

- Première colonne (nom du compte) : largeur fixe 200px sur desktop, 140px sur mobile
- Colonnes mois : largeur minimale 80px, expansibles
- En-têtes de mois fixes pendant le scroll vertical
- Scroll horizontal possible

### Comportement des cellules

Chaque cellule affiche :
1. Le montant total (formaté, avec signe)
2. Une icône horloge (petite, `warmAmber`) si `pendingCount > 0`
3. Fond selon logique temporelle
4. Couleur texte selon type de compte

**Interaction :**
- Tap sur une cellule → ouvre le modal de la liste des transactions de ce compte ce mois-là
- Tap sur le "+" flottant → ouvre le modal de création de transaction

### Header des mois

- Afficher Jan, Fév, Mar, Avr, Mai, Jun, Jul, Aoû, Sep, Oct, Nov, Déc
- Le mois actuel est mis en évidence (police bold, bordure bleue)

### Footer "Solde Fin de Mois"

- Ligne sticky collée en bas de la grille
- Fond opaque `deepBlack` pour couvrir le contenu scrollé
- 12 cellules avec le solde projeté cumulé pour chaque mois futur
- Mois passés : afficher le solde réel en fin de mois
- Police **Roboto Mono**, taille légèrement plus grande

### Checklist 3.5

- [x] Scroll horizontal fonctionnel
- [x] En-tête mois toujours visible (scroll vertical)
- [x] En-têtes de groupes visuellement distincts
- [x] Logique temporelle : passé/actuel/futur
- [x] Icône horloge sur cellules avec pending
- [x] Couleurs revenus/dépenses correctes
- [x] Footer sticky fonctionnel
- [ ] Tap sur cellule → liste transactions (implémenté en Phase 4)
- [x] Responsive : scroll horizontal sur mobile

---

## Étape 3.6 — Frontend : Navigation Année

### Composant

En haut du dashboard :
- Bouton `<` (année précédente)
- Label "2026" (année courante, centré)
- Bouton `>` (année suivante)

### Comportement

- Changer l'année recharge les données du dashboard
- L'année actuelle est l'état initial
- Les boutons `>` et `<` ne naviguent pas au-delà d'un range raisonnable (ex: ±5 ans)

### Checklist 3.6

- [x] Navigation année fonctionnelle
- [x] Changement d'année recharge le dashboard
- [x] Année courante mise en évidence (bleu)

---

## Validation Finale de la Phase 3

### Scénarios de test

1. Créer 2-3 comptes (ex: "Salaire" income, "Loyer" expense, "Épicerie" expense)
2. Créer des transactions sur plusieurs mois, certaines `completed`, certaines `pending`
3. Vérifier :
   - Les KPI sont corrects
   - La grille affiche les bons montants dans les bonnes cellules
   - Les icônes horloge apparaissent sur les cellules avec pending
   - Le footer affiche les projections de fin de mois correctes
   - La logique temporelle (passé/actuel/futur) est visuellement correcte

### Checklist finale

- [x] KPI cards affichent les bonnes valeurs
- [x] Grille complète et fonctionnelle
- [x] Logique temporelle visuellement correcte
- [x] Footer sticky correct
- [x] Responsive validé
- [x] Navigation année fonctionnelle
- [ ] Performance : chargement < 2s sur connexion normale (non mesuré)

---

## Passage à la Phase Suivante

- **→ Phase 4** : Récurrence (le modal de transaction créé dans cette phase sera enrichi)
