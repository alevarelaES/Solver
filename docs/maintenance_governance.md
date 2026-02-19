# Gouvernance Maintenance et PR

Ce document definit les regles operationnelles pour garder le projet propre, securise et maintenable apres le refactor.

## 1. Regles de lot (batch)
- Un batch = une responsabilite claire (pas de melange feature + refactor structurel).
- Un batch doit etre reviewable en une PR.
- Chaque batch doit avoir un plan de rollback simple.

## 2. Gate qualite obligatoire
Chaque PR doit passer ces commandes avant merge:

```powershell
flutter analyze
flutter test
dotnet build backend/src/Solver.Api/Solver.Api.csproj -nologo
dotnet test backend/tests/Solver.Tests/Solver.Tests.csproj -nologo
powershell -ExecutionPolicy Bypass -File tools/refactor/audit_ui_consistency.ps1
powershell -ExecutionPolicy Bypass -File tools/refactor/audit_backend_practices.ps1
powershell -ExecutionPolicy Bypass -File tools/refactor/verify_step.ps1
```

Regle: warnings backend traites comme bloquants.

CI PR:
- Workflow: `.github/workflows/pr-governance.yml`
- Verifie la structure minimale du corps de PR (sections du template).
- Lance la gate stricte `tools/refactor/verify_step.ps1` sur chaque PR non-draft.

## 3. Regles runtime backend
En non-development:
- `ALLOWED_ORIGINS` est obligatoire et ne doit contenir que des origines HTTP/HTTPS valides.
- L'auth doit etre configuree:
  - recommande: `SUPABASE_URL` (JWKS),
  - fallback legacy uniquement si `AUTH_ALLOW_HS256_FALLBACK=true` ET `JWT_SECRET` defini.
- Les secrets ne doivent jamais etre commits.

## 4. Regles architecture
- Endpoints minces: transport + validation d'entree + delegation service.
- Services: logique metier + persistence.
- Flutter views: orchestration, pas de logique metier lourde.
- Design system: utiliser tokens/theme shared (`AppColors`, `AppRadius`, `AppSpacing`, styles partages).

## 5. Checklist review
Le reviewer verifie explicitement:
- respect de `docs/architecture_contract.md`,
- absence de hardcode business dynamique en UI,
- absence de SQL runtime ad hoc dans startup,
- absence de duplication evidente (helper/widget/service deja existant),
- preuves de verification (sortie des commandes).

## 6. Checklist release
Avant release:
- executer la gate complete `verify_step.ps1`,
- valider la config runtime cible (origins, auth, env),
- verifier migrations EF appliquees,
- verifier smoke tests des routes critiques (auth, transactions, budget, goals, portfolio).
