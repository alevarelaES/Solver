# Transactions Backlog

## Etat actuel
- Popup transaction enrichi:
  - categorie rapide
  - groupes/categories
  - recurrent "jusqu'a date"
  - plan de remboursement

## Next
1. UX anti-erreur "Deja paye":
   - badge visuel plus fort si desactive
   - confirmation si montant eleve et non paye
2. Remboursement:
   - note auto de type "Remboursement - Nom"
   - resume detaille avant creation
   - option "arreter le plan a partir de telle date"
3. Qualite des donnees:
   - validation stricte montant total >= mensualite
   - alertes si mensualite trop faible (horizon trop long)

## Later
1. Templates de transactions frequentes.
2. Rules engine:
   - auto-categorisation basee sur note/montant.
3. Wizard "depense exceptionnelle" (voyage, impots, achat unique).

## Definition of Done (lot UX)
1. Utilisateur cree une transaction complexe en < 20 sec.
2. Reduction des erreurs de statut paye/non-paye.
3. Remboursement comprensible sans support externe.
