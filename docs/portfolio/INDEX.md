# Feature : Suivi de Portefeuille Boursier

## Vision

Ajouter une page **Portfolio** à Solver permettant aux utilisateurs de :
- Suivre la valeur de leurs investissements (actions, ETFs, crypto)
- Voir les prix en quasi temps réel (délai 15 min, gratuit)
- Visualiser la performance de leur portefeuille dans le temps
- Avoir une watchlist d'actifs surveillés

## APIs choisies : Twelve Data + Finnhub

On combine deux APIs complémentaires pour une expérience riche :

### Twelve Data — Prix & Historique
| Critère | Détail |
|---------|--------|
| **Free tier** | 800 appels/jour, 8 appels/min |
| **Temps réel** | Délai 15 min (gratuit), temps réel avec plan payant (29$/mois) |
| **Couverture** | Actions US/EU/Asie, ETFs, Forex, Crypto — 50+ bourses dont Euronext |
| **Protocoles** | REST + WebSocket |
| **Doc** | https://twelvedata.com/docs |
| **Rôle** | Prix en temps réel, historique, graphiques, recherche de symboles |

### Finnhub — News & Fondamentaux
| Critère | Détail |
|---------|--------|
| **Free tier** | 60 appels/min (très généreux) |
| **Temps réel** | WebSocket gratuit (trades US) |
| **Couverture** | US, EU, Crypto + news, fondamentaux, earnings, sentiment |
| **Protocoles** | REST + WebSocket |
| **Doc** | https://finnhub.io/docs/api |
| **Rôle** | News par action, profil entreprise (secteur, capitalisation, P/E), sentiment marché |

### Pourquoi ces deux APIs ?
| Besoin | Twelve Data | Finnhub |
|--------|-------------|---------|
| Prix temps réel | **oui** (principal) | oui (backup) |
| Historique/graphiques | **oui** | limité |
| Recherche symboles | **oui** | oui |
| News financières | non | **oui** |
| Profil entreprise (secteur, P/E, capitalisation) | non | **oui** |
| Sentiment marché | non | **oui** |
| Earnings / dividendes | non | **oui** |

Twelve Data = le moteur de prix. Finnhub = l'intelligence contextuelle.

### Stratégie de quota combinée
- **Cache serveur** : chaque prix est mis en cache 5 min, chaque profil/news 1h côté backend
- **1 appel = tous les users** : le backend fetch, cache, et sert à tout le monde
- **WebSocket** : 1 connexion Twelve Data pour le streaming prix
- **Twelve Data** : 800 appels/jour ≈ 160 symboles rafraîchis toutes les 5 min
- **Finnhub** : 60 appels/min ≈ news et profils rafraîchis à la demande, cache 1h

## Architecture

```
┌─────────────┐     WebSocket/REST      ┌──────────────┐
│ Twelve Data  │ ◄────────────────────── │              │
│  prix, hist. │ ────────────────────► │  .NET Backend │
└─────────────┘                         │  + Cache DB   │
                                        │              │
┌─────────────┐     REST                │              │
│   Finnhub    │ ◄────────────────────── │              │
│ news, profil │ ────────────────────► │              │
└─────────────┘                         └──────┬───────┘
                                               │ API REST
                                               ▼
                                        ┌──────────────┐
                                        │ Flutter Web   │
                                        │ Page Portfolio│
                                        └──────────────┘
```

## Phases d'implémentation

| Phase | Fichier | Contenu | Effort estimé |
|-------|---------|---------|---------------|
| **0** | [PHASE_0_DATABASE.md](PHASE_0_DATABASE.md) | Schéma DB : holdings, watchlist, price cache | Petit |
| **1** | [PHASE_1_BACKEND.md](PHASE_1_BACKEND.md) | Service Twelve Data, cache, endpoints API | Moyen |
| **2** | [PHASE_2_FRONTEND.md](PHASE_2_FRONTEND.md) | Page Portfolio, routing, providers, widgets | Moyen |
| **3** | [PHASE_3_REALTIME.md](PHASE_3_REALTIME.md) | Streaming temps réel, graphiques, polish | Moyen |

### Dépendances entre phases
```
Phase 0 (DB) → Phase 1 (Backend) → Phase 2 (Frontend) → Phase 3 (Realtime)
```
Chaque phase est fonctionnelle indépendamment :
- Après Phase 1 : tu peux tester les endpoints via Postman/curl
- Après Phase 2 : app fonctionnelle avec refresh manuel
- Après Phase 3 : expérience complète avec streaming

## Modèle de données (résumé)

### Nouvelles tables
- **portfolio_holdings** — Les positions de l'utilisateur (symbole, quantité, prix d'achat)
- **watchlist_items** — Symboles surveillés sans position
- **asset_price_cache** — Cache serveur des prix (partagé entre tous les users)

### Pas de nouvelles tables
- Pas besoin de stocker l'historique des prix (Twelve Data le fournit à la demande)
- Pas de table de transactions boursières (on track juste les positions agrégées pour rester simple)

## Scope volontairement exclu (v1)
- Trading / passage d'ordres
- Analyse technique avancée (RSI, MACD...)
- Multi-devise sur les positions (on convertit tout en devise principale de l'user)
- Alertes de prix / notifications push

Ces features pourront être ajoutées dans des phases ultérieures si besoin.
