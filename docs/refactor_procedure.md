# Refactor Procedure (Global)

## Objective
Refactor the codebase safely with 3 goals:
- modularity (small files, clear ownership)
- performance/maintainability optimization
- removal of redundant/obsolete code
- security and reliability hardening (backend + frontend)

## Mandatory Workflow
1. Audit
- map oversized files
- detect duplicate patterns
- identify dead/obsolete candidates
- create batch plan with risk scoring
- audit backend query patterns (raw SQL, save loops, transaction boundaries)
- audit auth/cors/runtime config hardening

2. Plan (per batch)
- define target files and extraction boundaries
- define acceptance criteria (behavior unchanged, no regressions)
- define rollback strategy

3. Execute (small batch)
- refactor only one feature batch at a time
- keep behavior unchanged first (structural refactor)
- run analysis/tests after each batch

4. Verify
- `flutter analyze`
- target feature smoke test
- compare key flows before/after
- backend compile + warnings review (`dotnet build`)
- API smoke checks for modified endpoints
- global UI consistency audit (`tools/refactor/audit_ui_consistency.ps1`)
- backend practices audit (`tools/refactor/audit_backend_practices.ps1`)
- mandatory end-of-step verification command:
  - `powershell -ExecutionPolicy Bypass -File tools/refactor/verify_step.ps1`
  - strict mode (recommended/default): warnings treated as blockers for backend checks
  - default gate is now strict (`MaxUiFindings=0`, `MaxBackendFindings=0`)
  - temporary thresholds can be used only for transition batches via explicit args

5. Optimize
- deduplicate helpers/widgets/styles
- remove dead files/obsolete code paths
- re-run full checks

## Guardrails
- Never mix refactor + feature changes in same batch.
- Max file size target: 800 lines for `views`, 500 for widgets/services.
- Prefer extraction by responsibility (header/filter/table/detail), not by random chunks.
- One batch = one commitable unit.
- For backend, avoid runtime schema DDL in `Program.cs`; use migration services or EF migrations.
- For backend, avoid `SaveChangesAsync` inside loops unless strictly required.
- For backend, centralize retry/pooler handling instead of duplicating in endpoints.
- For frontend, prefer `AppPanel`, `AppButtonStyles`, `AppInputStyles`, `AppRadius`, `AppSpacing` over hardcoded UI values.
- New UI code should not introduce raw `styleFrom`, hardcoded `Color(0x...)`, or non-token border radius unless justified.

## Done Criteria (Batch)
- No behavior regressions observed
- verification gate passed (`tools/refactor/verify_step.ps1`)
- File responsibilities clearly separated
- Duplication reduced or isolated for next batch

## Priority Order (Current)
1. `lib/features/budget/views/budget_view.dart`
2. `lib/features/goals/views/goals_view.dart`
3. `lib/features/schedule/views/schedule_view.dart`
4. `lib/features/spreadsheet/views/spreadsheet_view.dart`
5. `lib/features/analysis/views/analysis_view.dart`
6. Project-wide UI harmonization pass (buttons/cards/radius/colors)
7. `backend/src/Solver.Api/Program.cs` schema bootstrap extraction
8. `backend/src/Solver.Api/Endpoints/*` endpoint/service split + transaction strategy
9. `backend/src/Solver.Api/Services/*Migration.cs` batch persistence optimization
