# Currency Backlog (A Faire Plus Tard)

## Contexte actuel
- La devise est globale dans l'application (`CHF`, `EUR`, `USD`).
- Les montants existants ne sont pas convertis automatiquement: seul l'affichage change.

## V2: Devise par transaction
1. Ajouter `currency_code` sur `transactions` (ex: `CHF`, `EUR`, `USD`).
2. Ajouter `amount_in_transaction_currency` et garder `amount_base` (monnaie de reference du compte/utilisateur).
3. Sauver aussi `fx_rate_to_base` au moment de la creation.
4. Afficher dans le journal:
   - montant original (ex: `EUR 120`)
   - montant converti (ex: `CHF 115.40`) si devise differente.

## V2: Devise par compte (categorie)
1. Ajouter `currency_code` sur `accounts`.
2. Regle: une transaction herite par defaut de la devise du compte.
3. Option avancee: autoriser override transaction.

## V2: Service FX
1. Endpoint interne: `GET /api/fx/rate?from=EUR&to=CHF&date=2026-02-14`.
2. Cache local (24h) pour limiter les appels.
3. Fallback si API externe indisponible.

## V2: UX
1. Dans le popup transaction:
   - select devise pres du montant
   - preview conversion instantanee
2. Dans dashboard/analysis:
   - toggle "originale / convertie"
3. Badge discret quand une ligne est convertie.

## V2: Reporting
1. Calculs budget/analysis bases sur `amount_base`.
2. Export CSV:
   - colonnes `currency_code`, `amount_original`, `fx_rate`, `amount_base`.

## Migration & compatibilite
1. Script migration:
   - `currency_code = devise globale courante` pour historique
   - `amount_base = amount`
2. Pas de rupture API:
   - champs nouveaux optionnels au debut.

## Points de decision produit
1. Base currency:
   - par utilisateur
   - ou par workspace
2. Source FX officielle (ECB, exchangerate.host, provider payant).
3. Politique d'arrondi (banque vs standard).

## Definition of Done V2
1. Creation/edition transaction multi-devise stable.
2. Dashboard, budget, analyse coherents en devise base.
3. Tests unitaires + integration FX + migration validee.
