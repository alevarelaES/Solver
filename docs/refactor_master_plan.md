# Refactor Master Plan (Frontend + Backend)

## Goal
Build a codebase that is clean, readable, maintainable, secure, and easy to evolve:
- homogeneous architecture,
- clear separation of responsibilities,
- reduced duplication,
- dynamic data strategy (no business hardcode in views),
- strict verification at the end of each step.

This document is the reference plan for the full project cleanup.

## Problems to fix
- Oversized files (views > 1000/2000 lines).
- UI logic, business logic, and API mapping mixed together.
- Hardcoded fallback business data in views (example: ticker list).
- Fragile backend patterns from legacy code (runtime DDL, raw SQL in endpoints, brittle string comparisons).
- Repeated UI components/rules re-implemented in multiple places.
- Repeated methods with same logic that can be implement in a specific class where it can be call 
- Security of project (Best security practice)

## Target architecture

### Frontend (Flutter)
- `views/`: screen orchestration only.
- `widgets/`: reusable visual blocks.
- `state/providers/`: state and use-case orchestration.
- `models/`: UI/domain types.
- `data/`: static controlled catalogs, mapping, adapters.
- `shared/widgets/`: global primitives (`AppShell`, `AppPageHeader`, `AppPageScaffold`).

### Backend (.NET)
- `Program.cs`: composition only (DI, middleware, routing, `Database.Migrate`).
- `Endpoints`: transport/input validation + delegation.
- `Services`: business rules.
- `Data/Migrations`: EF schema history only.
- No ad hoc DDL in startup.

## Mandatory rules
- No heavy business logic in `build()`.
- No dynamic business data hardcoded directly in views.
- No raw SQL in endpoints (except documented justified exception).
- No `ToLower()` DB comparisons; use robust patterns (`EF.Functions.ILike`, collation-safe patterns, dedicated mapping).
- No duplicate component/helper when one shared abstraction exists.
- File size targets:
  - Screen view: <= 600 lines
  - Widget: <= 300 lines
  - Endpoint/service: <= 300 lines

## Execution plan by steps

## Step 0 - Baseline and inventory
### Objective
Measure and map current technical debt.
### Actions
- Generate oversized file inventory (frontend + backend).
- Detect duplicated helpers/patterns.
- Detect hardcoded business data blocks.
- Detect dead/obsolete code and files.
### Deliverables
- `docs/audit_baseline_frontend.md`
- `docs/audit_baseline_backend.md`

## Step 1 - Architecture contract
### Objective
Freeze project-wide structure and naming rules.
### Actions
- Define standard feature folder layout.
- Define file naming conventions (`*.view.dart`, `*.section.dart`, `*.provider.dart`, etc.).
- Define dependency rules (UI -> provider/service; never inverse).
### Deliverable
- `docs/architecture_contract.md`

## Step 2 - Global page layout refactor
### Objective
Unify page skeletons.
### Actions
- Use `AppPageScaffold` and `AppPageHeader` on all main pages.
- Replace repeated custom top bars with shared components.
- Normalize page spacing, max width, visual hierarchy.
### Done criteria
- Main screens share one consistent shell pattern.

## Step 3 - Split oversized views
### Objective
Break big files into focused units.
### Actions
- Split `Goals`, `Schedule`, `Spreadsheet`, `Analysis`, `Portfolio`, `Budget`.
- Extract sections (`header`, `filters`, `table/cards`, `dialogs`, `detail`).
- Move non-visual logic from view files to providers/services.
### Done criteria
- File size targets are respected.

## Step 4 - Dynamic data and hardcode removal
### Objective
Remove static business blocks from views.
### Actions
- Replace hardcoded lists (example: `_tickerFallbackAssets`) with:
  - dedicated backend source, or
  - centralized feature catalog (`feature/data/*.dart`) with clean builders.
- Define fallback policy (cache + TTL + secondary source).
- Centralize serialization/mapping adapters.
### Done criteria
- No large business data blocks hardcoded in view files.

## Step 5 - Backend startup and migration policy
### Objective
Enforce standard startup behavior.
### Actions
- Keep `Program.cs` as composition + `Database.MigrateAsync()` only.
- Maintain complete EF schema migrations in `Data/Migrations`.
- Separate schema migrations vs data migrations explicitly.
### Done criteria
- Zero ad hoc runtime DDL in startup path.

## Step 6 - Endpoint to service decomposition
### Objective
Make endpoint layer thin and testable.
### Actions
- Split oversized endpoint files (`Budget`, `Goals`, `Transactions`, `Categories`).
- Extract validation/mapping/persistence to dedicated services.
- Unify retry and transaction strategy (single reusable approach).
### Done criteria
- Endpoints are short, clear, and consistent.

## Step 7 - Optimization and deduplication
### Objective
Reduce repeated code and improve runtime behavior.
### Actions
- Consolidate duplicated helpers (formatting, parsing, comparison).
- Remove dead code and obsolete files.
- Review heavy queries and N+1 risks.
### Done criteria
- Lower duplication and stable or improved performance.

## Step 8 - Security and robustness hardening
### Objective
Make project reliable for long-term maintenance.
### Actions
- Review auth/cors/runtime config for production safety.
- Normalize error handling and input validation patterns.
- Add tests for critical flows.
### Done criteria
- No blocking warnings and reproducible quality gate.

## Step 9 - Finalization and governance
### Objective
Close refactor with enforceable standards.
### Actions
- Update developer docs and maintenance guide.
- Add PR checklist to prevent architecture regressions.
- Tighten final gates for UI/backend findings.

## Mandatory verification at end of each step
- `flutter analyze`
- `flutter test`
- `dotnet build backend/src/Solver.Api/Solver.Api.csproj -nologo`
- `dotnet test backend/tests/Solver.Tests/Solver.Tests.csproj -nologo`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_ui_consistency.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_backend_practices.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/verify_step.ps1`

## Delivery strategy
- One step = one coherent, reviewable, testable batch.
- Never mix product feature work and structural refactor in the same batch.
- Each batch must reduce complexity in measurable terms.

## Immediate priority order
1. Step 0 + Step 1 (baseline audit + architecture contract)
2. Step 2 + Step 3 (shared layout + oversized file split)
3. Step 4 (dynamic data strategy, hardcode removal)
4. Step 5 + Step 6 (backend cleanup and decomposition)
5. Step 7 + Step 8 + Step 9 (optimization, hardening, closure)

