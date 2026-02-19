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
- `docs/archive/2026-02-refactor-baseline/audit_baseline_frontend.md`
- `docs/archive/2026-02-refactor-baseline/audit_baseline_backend.md`

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

## Current status
- Step 0 completed:
  - `docs/archive/2026-02-refactor-baseline/audit_baseline_frontend.md`
  - `docs/archive/2026-02-refactor-baseline/audit_baseline_backend.md`
- Step 1 completed:
  - `docs/architecture_contract.md`
- Step 2 completed:
  - Shared page skeleton (`AppPageScaffold` + `AppPageHeader`) applied to main screens:
    - `dashboard`, `budget`, `goals`, `schedule`, `journal`, `analysis`, `spreadsheet`, `portfolio`
- Step 3 completed:
  - Oversized views split into focused parts:
    - `analysis_view.dart` -> `analysis_view.kpi.part.dart`, `analysis_view.charts.part.dart`, `analysis_view.peer.part.dart`
    - `spreadsheet_view.dart` -> `spreadsheet_view.widgets.part.dart`
    - `portfolio_view.dart` -> `portfolio_view.ticker.part.dart`
    - `budget_view.dart` -> `budget_view.logic.part.dart` + existing section parts
    - `schedule_view.dart` -> `schedule_view.header.part.dart`, `schedule_view.list.part.dart`, `schedule_view.card.part.dart`, `schedule_view.calendar.part.dart`, `schedule_view.calendar_widgets.part.dart`
    - `goals_view.dart` -> `goals_view.logic.part.dart`, `goals_view.widgets.part.dart`
  - Result: all `lib/features/**/views/*_view.dart` are now <= 600 lines.
- Step 4 in progress:
  - Dynamic fallback catalogs centralized (single source of truth):
    - `lib/features/portfolio/data/portfolio_trending_catalog.dart`
    - `lib/features/portfolio/data/portfolio_symbol_catalog.dart`
    - `lib/features/analysis/data/analysis_peer_catalog.dart`
  - Hardcoded business fallback data removed from views/providers:
    - `portfolio_view.ticker.part.dart` now reads catalog data
    - `trending_provider.dart` now reads catalog data
    - `analysis_view.peer.part.dart` now reads catalog data
    - `market_tab.dart` quick symbols now read catalog data
    - `positions_tab.dart` known symbols now read catalog data
    - `asset_logo.dart` known logo domains + crypto aliases now read catalog data
    - `symbol_search_field.dart` hint examples now read catalog data
    - `positions_tab.dart` no longer filters holdings by a static known-symbol list
  - API fallback policy made explicit (cache + TTL + secondary source):
    - `lib/features/portfolio/data/portfolio_cache_policy.dart`
    - `lib/features/portfolio/providers/trending_provider.dart`:
      - fresh cache -> API live -> stale cache -> catalog fallback
    - `lib/features/portfolio/providers/price_history_provider.dart`:
      - fresh cache -> API live (exact + secondary response key) -> stale cache -> empty fallback
- Step 6/7 started (backend):
  - shared persistence retry service:
    - `backend/src/Solver.Api/Services/DbRetryService.cs`
  - `CategoriesEndpoints` / `GoalsEndpoints` / `TransactionsEndpoints` / `BudgetEndpoints` / `PortfolioEndpoints` / `WatchlistEndpoints` / `MarketEndpoints` / `AccountsEndpoints` / `DashboardEndpoints` / `AnalysisEndpoints` decomposed with service separation:
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/CategoriesEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/GoalsEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/TransactionsEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/BudgetEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/PortfolioEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/WatchlistEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/MarketEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/AccountsEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/DashboardEndpoints.cs`
    - routing-only endpoint: `backend/src/Solver.Api/Endpoints/AnalysisEndpoints.cs`
    - business logic service: `backend/src/Solver.Api/Services/CategoriesService.cs`
    - business logic service: `backend/src/Solver.Api/Services/GoalsService.cs`
    - business logic service: `backend/src/Solver.Api/Services/TransactionsService.cs`
    - business logic service: `backend/src/Solver.Api/Services/BudgetService.cs`
    - business logic service: `backend/src/Solver.Api/Services/PortfolioService.cs`
    - business logic service: `backend/src/Solver.Api/Services/WatchlistService.cs`
    - business logic service: `backend/src/Solver.Api/Services/MarketService.cs`
    - business logic service: `backend/src/Solver.Api/Services/AccountsService.cs`
    - business logic service: `backend/src/Solver.Api/Services/DashboardService.cs`
    - business logic service: `backend/src/Solver.Api/Services/AnalysisService.cs`
  - endpoint-level duplicated retry blocks removed for transaction creation/batch/repayment, goal entry creation, and budget upsert.
  - backend practices audit findings reduced from `4` to `0`.
- Step 8 completed (backend hardening):
  - auth middleware hardened in `backend/src/Solver.Api/Middleware/SupabaseAuthMiddleware.cs`:
    - strict bearer header parsing
    - synchronized JWKS cache refresh
    - configurable issuer/audience validation
    - controlled HS256 fallback policy
  - runtime security helpers centralized in `backend/src/Solver.Api/Services/AppRuntimeSecurity.cs`
  - non-development fail-fast checks added in `backend/src/Solver.Api/Program.cs`:
    - auth material presence
    - mandatory `ALLOWED_ORIGINS`
    - invalid `ALLOWED_ORIGINS` entries now fail fast
  - targeted tests added:
    - `backend/tests/Solver.Tests/AppRuntimeSecurityTests.cs`
    - `backend/tests/Solver.Tests/AuthMiddlewareTests.cs`
- Step 9 completed (finalization + governance):
  - PR checklist template added:
    - `.github/pull_request_template.md`
  - PR governance workflow added:
    - `.github/workflows/pr-governance.yml`
  - maintenance/governance guide added:
    - `docs/maintenance_governance.md`
  - backend runtime env template added:
    - `backend/src/Solver.Api/.env.example`
  - verification gate tightened by default:
    - `tools/refactor/verify_step.ps1` now enforces `MaxUiFindings=0` and `MaxBackendFindings=0`
