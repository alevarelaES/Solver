# CLAUDE.md - Guide Operationnel Generique (Tous Projets Web/App)

Ce fichier definit un cadre universel pour qu'un agent soit operationnel des le debut, sur tout projet (site web, app frontend/backend, SaaS).

---

## 1) Priorites non negociables

1. Securite d'abord.
2. Comportement correct avant optimisation.
3. Architecture lisible et responsabilites separees.
4. Pas de hardcode de theme dans les vues/composants metiers.
5. Pas de hardcode de donnees metier dans les vues.
6. Pas de hardcode de donnees dans le backend.
7. Livrer par petits batches reviewables.
8. **Impact minimal** : chaque changement ne touche que ce qui est strictement necessaire. Ne pas introduire de modifications parasites.
9. **Pas de fix temporaire** : trouver la cause racine. Standards senior developer.

---

## 2) Demarrage de session (obligatoire)

Sur toute tache non triviale :

1. Lire les docs du repo (`README`, `ARCHITECTURE`, `CONVENTIONS`, `SECURITY`, `CONTRIBUTING`) si elles existent.
2. **Relire `tasks/lessons.md`** pour appliquer les lecons des sessions precedentes.
3. Identifier la stack active (frontend, backend, base de donnees, CI).
4. Verifier l'etat git (`git status`) et ne jamais ecraser les changements utilisateur.
5. Definir un plan court avec criteres d'acceptation.

Si le repo n'a pas encore de suivi de tache, creer :
- `tasks/todo.md`
- `tasks/lessons.md`

---

## 3) Workflow d'execution

### Plan d'abord (par defaut)

Utiliser un plan explicite pour toute tache avec :
- 3 etapes ou plus,
- impact architecture,
- impact multi-couches (front + back + data).

Regles :
- specifier objectif, limites, rollback, verification,
- si ca derive : stop, re-plan, puis reprendre.

### Execution par batch

- 1 batch = 1 objectif coherent.
- Ne pas melanger gros refactor structurel + nouvelle feature.
- Avancer en lots petits et testables.
- **Impact minimal** : ne modifier que ce qui est necessaire au batch en cours, rien de plus.

### Verification avant "done"

Ne jamais cloturer sans preuve :
- tests/analyses/lint adaptes a la stack,
- smoke test du flux modifie,
- comparaison avant/apres sur le comportement attendu,
- **question systematique : "Est-ce qu'un senior engineer validerait ce diff ?"**

### Boucle d'amelioration

Apres correction utilisateur :
- noter l'erreur dans `tasks/lessons.md`,
- ajouter une regle preventive,
- appliquer cette regle au batch suivant.

### Correction de bug autonome

Quand un bug est signale :
- ne pas demander de guidage supplementaire,
- pointer les logs, erreurs, tests en echec,
- identifier la **cause racine** avant de coder,
- resoudre sans fix temporaire.

### Subagents (si disponibles)

Pour garder le contexte principal propre :
- offloader la recherche, l'exploration et l'analyse parallele a des sous-agents,
- 1 sous-agent = 1 tache focalisee,
- pour les problemes complexes : augmenter le compute via sous-agents plutot que d'allonger le contexte principal.

---

## 4) Contrat de gestion des taches

Pour chaque tache significative :

1. Ecrire le plan dans `tasks/todo.md`.
2. Cocher l'avancement au fil de l'execution.
3. Documenter ce qui change et pourquoi.
4. Ajouter les preuves de verification.
5. Capitaliser les retours dans `tasks/lessons.md`.

---

## 5) Contrat d'architecture generique

### Frontend

Structure cible (adapter selon framework) :
- `views/pages` : orchestration d'ecran/page uniquement.
- `components/widgets` : blocs UI reutilisables.
- `state/store/providers` : orchestration des donnees et cas d'usage.
- `models/types` : modeles de donnees.
- `data/adapters` : mapping, catalogues, serialisation.

Layout de base recommande pour chaque page :
1. `head` (meta/seo/scripts critiques)
2. `body` / shell applicatif
3. `header` de page
4. contenu principal par sections
5. `footer` optionnel (actions, liens, infos)

Regles :
- pas de logique metier lourde dans le rendu UI,
- pas de duplication de composants/styles si abstraction partagee existe,
- separer clairement affichage, orchestration, data.

### Backend

Structure cible (adapter selon stack) :
- `entrypoint` (composition, middlewares, routing),
- `routes/endpoints/controllers` (transport + validation),
- `services/use-cases` (logique metier),
- `repositories/data-access` (acces donnees),
- `migrations/schema` (evolution DB).

Regles :
- pas de logique metier dans le routing,
- pas de SQL fragile disperse dans la couche transport,
- pas de duplication des regles metier entre endpoints,
- transactions et ecriture batchees quand pertinent.

---

## 6) Politique de taille de fichiers

Ne pas attendre qu'un fichier devienne ingouvernable.

Limites recommandees :
- page/view : <= 600 lignes,
- composant/service : <= 300 lignes,
- endpoint/controller : <= 300 lignes.

Declencheur preventif :
- commencer le split vers 70% de la limite.
- extraire par responsabilite (header, filtres, table, modal, detail, mapper, service).

---

## 7) Politique anti-hardcode (obligatoire)

### Theme/design

Interdit dans les vues metier :
- couleurs litterales,
- radius/spacing/borders litteraux repetes,
- styles copy/paste.

Obligatoire :
- 1 a 3 fichiers centraux de tokens/theme/styles partages,
- consommation via variables/tokens/classes utilitaires.

### Donnees affichees

Interdit :
- datasets metier hardcodes dans les vues,
- textes UI hardcodes (hors prototype local tres court),
- valeurs metier dupliquees dans plusieurs fichiers.

Obligatoire :
- textes UI dans un systeme i18n/l10n,
- donnees metier centralisees (JSON/config/catalogue + mapping type),
- source unique de verite pour chaque donnee.

---

## 8) Securite minimale (tous projets)

- Auth server-side robuste (session/JWT/OAuth selon stack).
- Autorisation controlee cote serveur (jamais faire confiance au client).
- Validation stricte de toutes les entrees.
- Gestion stricte des secrets (jamais commits).
- CORS/CSRF/config runtime limites aux besoins reels.
- Journalisation sans fuite de secrets ni donnees sensibles.
- Principe du moindre privilege (DB, API, infra).

---

## 9) Gate de verification (adapter au projet)

Chaque repo doit declarer ses commandes dans la section "Project Profile" (section 12).

Minimum attendu apres chaque batch :
1. analyse statique / type-check
2. lint / format check
3. build
4. tests unitaires
5. tests d'integration ou smoke tests sur flux critiques
6. audit securite de base (deps/config/secret scan si dispo)

---

## 10) Criteres de fin de batch

- comportement attendu conserve (ou changement explicitement valide),
- checks passes,
- architecture plus claire qu'avant,
- duplication reduite,
- **impact limite au strict necessaire** (pas de changements parasites),
- documentation et traces de verification a jour.

---

## 11) Checklist PR/review

- [ ] Structure respectee et separations claires.
- [ ] Aucun hardcode theme ou data metier en vue.
- [ ] Validation et securite conformes.
- [ ] **Diff limite au besoin reel** (pas de changements parasites).
- [ ] **Cause racine identifiee**, pas de fix temporaire.
- [ ] **Impact minimal verifie** : rien de superflu modifie.
- [ ] Preuves de verification jointes.

---

## 12) Project Profile (a renseigner par repo)

Completer cette section au debut de chaque projet :

- Stack frontend :
- Stack backend :
- Dossiers de reference :
- **Commandes de demarrage** (install, seed, lancer le serveur) :
- Commandes qualite obligatoires :
- Regles de securite specifiques :
- Limites de taille specifiques :
- Conventions de nommage :
- Definition of Done locale :

---

Ce guide reste volontairement generique ; les details projet doivent vivre dans la section "Project Profile", sans casser les principes ci-dessus.
