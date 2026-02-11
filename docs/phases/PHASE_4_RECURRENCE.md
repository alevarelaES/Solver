# Phase 4 — Moteur de Récurrence et Formulaire Transaction

> Références : [PROJECT_OVERVIEW.md](../PROJECT_OVERVIEW.md) | [CONVENTIONS.md](../CONVENTIONS.md)
>
> **Statut :** ⏳ En attente de Phase 3
>
> **Prérequis :** Phase 3 complète (Dashboard et modal de base)
>
> **Bloque :** Aucune phase — fonctionnalité autonome

---

## Objectif

Permettre à l'utilisateur de créer une transaction **unique** ou **récurrente** (répétée jusqu'en décembre) via un formulaire modal. La récurrence est la fonctionnalité signature de Solver qui élimine la saisie manuelle répétitive.

---

## Contexte

### Problème résolu

Sans récurrence, l'utilisateur devrait créer 12 transactions identiques (une par mois) pour un loyer ou un abonnement. Avec le moteur de récurrence, il crée une seule transaction et coche "Répéter jusqu'en Décembre" — le backend génère automatiquement toutes les occurrences futures.

### Logique métier

Quand "Répéter jusqu'en Décembre" est activé :
- Le backend génère une transaction pour **chaque mois restant** de l'année (du mois de la date choisie jusqu'à décembre)
- Toutes les transactions futures sont automatiquement en status `pending`
- La transaction du mois courant garde le status choisi par l'utilisateur
- Le **jour du mois** est respecté pour chaque occurrence (ex: si le 30, génère le 28 ou 29 en février)
- Si une transaction pour ce compte/ce mois existe déjà → comportement : création en doublon (l'utilisateur doit gérer lui-même)

---

## Étape 4.1 — Backend : Endpoint Batch

### Route

`POST /api/transactions/batch`

### DTO d'entrée

```
BatchTransactionRequest {
  transaction: {
    accountId: uuid,
    date: date,
    amount: decimal,
    note: string?,
    status: "completed" | "pending",
    isAuto: boolean
  },
  recurrence: {
    dayOfMonth: int    ← Jour du mois à utiliser pour chaque occurrence
  }
}
```

### Logique de génération

1. Extraire le mois de `date` comme mois de départ
2. Pour chaque mois de (mois de départ) à 12 :
   a. Calculer la date : année de `date`, mois courant, jour = `dayOfMonth`
   b. Si le jour dépasse le nombre de jours du mois → prendre le dernier jour du mois
   c. Status : si mois < mois actuel ou mois = mois de `date` → status du DTO, sinon → `pending`
3. Insérer toutes les transactions en une seule opération (`AddRangeAsync`)
4. Retourner le nombre de transactions créées et leurs IDs

### Cas limites à gérer

| Cas | Comportement attendu |
|---|---|
| `dayOfMonth = 31` en février | Utiliser le 28 (ou 29 si bissextile) |
| `dayOfMonth = 30` en février | Idem |
| Mois de départ = décembre | Créer 1 seule transaction |
| `dayOfMonth` invalide (< 1 ou > 31) | Retourner 400 |
| `amount` ≤ 0 | Retourner 400 |

### Service à créer

`RecurrenceService.cs` dans `Services/` :
- Responsable uniquement de la logique de génération des dates
- Testable unitairement sans base de données
- Indépendant du DbContext

### Checklist 4.1

- [ ] `RecurrenceService.cs` créé avec logique de génération
- [ ] Gestion des mois courts (fév, avr, jun, sep, nov)
- [ ] Gestion année bissextile pour février
- [ ] Endpoint `POST /api/transactions/batch` créé
- [ ] Validation du DTO (dayOfMonth 1-31, amount > 0)
- [ ] Insertion en batch (pas de boucle de sauvegardes individuelles)
- [ ] Retourne nombre de transactions créées
- [ ] Tests unitaires pour `RecurrenceService` (cas normaux + limites)

---

## Étape 4.2 — Frontend : Modal de Création de Transaction

### Déclenchement

Le modal s'ouvre depuis :
- Le bouton flottant "+" sur le Dashboard
- Un futur bouton "Nouvelle transaction" dans le Journal

### Comportement adaptatif selon la plateforme

| Plateforme | Composant |
|---|---|
| Desktop / Tablet | `Dialog` centré, largeur max 480px |
| Mobile | `BottomSheet` qui monte depuis le bas |

### Champs du formulaire

| Champ | Type | Obligatoire | Validation |
|---|---|---|---|
| Compte | Dropdown | Oui | Doit exister dans la liste des comptes de l'utilisateur |
| Date | Date picker | Oui | Date valide |
| Montant (CHF) | Champ numérique | Oui | > 0, max 1 000 000 |
| Note | Champ texte | Non | Max 500 caractères |
| Prélèvement automatique | Switch | — | Défaut : off |
| Déjà payé ? | Switch | — | Défaut : off (= pending) |
| Répéter jusqu'en Décembre | Switch | — | Défaut : off |
| Jour du mois | Champ numérique | Si récurrence | Visible uniquement si récurrence activée, 1-31 |

### Logique du switch "Répéter jusqu'en Décembre"

Quand activé :
- Le champ "Jour du mois" apparaît (pré-rempli avec le jour de la date choisie)
- Le bouton de soumission indique le nombre d'occurrences qui seront créées (ex: "Créer 8 transactions")
- La date choisie dans le date picker n'est utilisée que pour le mois de départ

### Sélection du compte

Le dropdown doit :
- Afficher les comptes groupés (par groupe d'abord, puis par nom)
- Afficher le type (revenus/dépenses) via une icône ou couleur
- Être searchable si > 10 comptes
- Charger les comptes depuis le provider Riverpod existant

### Soumission

- **Sans récurrence** → `POST /api/transactions`
- **Avec récurrence** → `POST /api/transactions/batch`
- Après succès : fermer le modal + invalider `dashboardDataProvider` + invalider les providers pertinents
- En cas d'erreur : afficher le message d'erreur dans le modal (ne pas le fermer)

### Feedback utilisateur

- Bouton de soumission en état loading pendant l'appel API
- Message de succès bref (snackbar) après création
- Message d'erreur explicite en cas d'échec

### Checklist 4.2

- [ ] Modal créé (Dialog desktop / BottomSheet mobile)
- [ ] Tous les champs fonctionnels
- [ ] Dropdown comptes avec groupes
- [ ] Switch récurrence affiche/cache le champ "Jour du mois"
- [ ] Compteur d'occurrences à créer affiché quand récurrence active
- [ ] Validation de tous les champs avant soumission
- [ ] Appel au bon endpoint (simple vs batch)
- [ ] Dashboard rafraîchi après création
- [ ] État loading sur le bouton de soumission
- [ ] Snackbar de confirmation
- [ ] Testé sur mobile (BottomSheet) et desktop (Dialog)

---

## Étape 4.3 — Fonctionnalité de Validation d'une Transaction Pending

### Contexte

Dans le Dashboard et le Journal, l'utilisateur doit pouvoir marquer une transaction `pending` comme `completed` (ex: confirmer qu'un prélèvement a bien eu lieu).

### Comportement attendu

- Tap sur une transaction pending → options : "Valider" ou "Supprimer"
- "Valider" = `PUT /api/transactions/{id}` avec `status = "completed"`
- Après validation : mise à jour du solde réel + rafraîchissement de la vue
- Possibilité de modifier le montant lors de la validation (cas: montant réel différent de l'estimation)

### Checklist 4.3

- [ ] Action "Valider" disponible sur les transactions pending
- [ ] Appel `PUT` avec nouveau status
- [ ] Rafraîchissement des données après validation
- [ ] Option de modifier le montant lors de la validation

---

## Validation Finale de la Phase 4

### Scénarios de test

**Transaction simple :**
1. Ouvrir le modal via le "+"
2. Choisir un compte, une date, un montant
3. Soumettre → vérifier que la transaction apparaît dans le Dashboard

**Transaction récurrente :**
1. Ouvrir le modal
2. Activer "Répéter jusqu'en Décembre"
3. Le compteur indique X occurrences
4. Soumettre → vérifier que X transactions apparaissent dans la grille (une par mois)
5. Vérifier que les transactions passées ont le bon status, les futures sont `pending`

**Gestion de février :**
1. Créer une transaction récurrente avec jour 31
2. Vérifier que la transaction de février est créée au 28 (ou 29 si bissextile)

**Validation d'un pending :**
1. Avoir une transaction `pending`
2. La valider → vérifier que le solde réel est mis à jour

### Checklist finale

- [ ] Transaction simple créée correctement
- [ ] Transaction récurrente génère le bon nombre d'occurrences
- [ ] Gestion des mois courts validée
- [ ] Validation de pending fonctionne
- [ ] Dashboard se rafraîchit à chaque action
- [ ] Aucune erreur en console

---

## Passage à la Phase Suivante

- **→ Phase 5** : Vues secondaires (Journal, Échéancier, Budget, Analyse)
