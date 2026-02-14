# Goals Backlog (Objectifs d'Epargne)

## Vision
Permettre a l'utilisateur de definir un objectif comme:
- "Thailande 2027"
- Budget total cible
- Date cible
- Montant deja disponible

Puis afficher automatiquement:
- Epargne mensuelle requise
- Progression
- Date previsionnelle d'atteinte

## MVP (Now/Next)
1. Creation d'objectif:
   - Nom
   - Montant cible
   - Date cible
   - Montant initial (optionnel)
2. Calculs:
   - reste a epargner
   - mensualite requise = reste / nb mois restants
3. Affichage:
   - carte "Objectif principal" sur dashboard
   - liste sur page budget
4. Statut:
   - Sur la trajectoire
   - En retard
   - Atteint

## V2
1. Contribution automatique mensuelle (transaction planifiee).
2. Plusieurs objectifs en parallele avec priorites.
3. Recommandations:
   - "Augmenter de X par mois"
   - "Decaler la date cible"
4. Scenarios:
   - prudent
   - normal
   - agressif

## Data model propose (V1)
- Table `saving_goals`
  - `id`
  - `user_id`
  - `name`
  - `target_amount`
  - `target_date`
  - `initial_amount`
  - `is_archived`
  - `created_at`
  - `updated_at`

## API proposee (V1)
- `GET /api/goals`
- `POST /api/goals`
- `PUT /api/goals/{id}`
- `PATCH /api/goals/{id}/archive`

## UI proposee (V1)
- Dashboard:
  - mini carte objectif principal
  - CTA "Voir tous les objectifs"
- Budget:
  - section "Objectifs d'epargne"
  - creation/edition rapide

## Definition of Done (MVP)
1. CRUD objectif fonctionnel.
2. Calcul mensualite et progression corrects.
3. Affichage dashboard + budget coherent.
4. Tests backend unitaires sur formules.
