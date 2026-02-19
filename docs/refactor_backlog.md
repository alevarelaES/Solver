# Refactor Backlog

## Completed
- Journal view split into modular parts:
  - `lib/features/journal/views/journal_view.dart`
  - `lib/features/journal/views/journal_view.header.part.dart`
  - `lib/features/journal/views/journal_view.filters.part.dart`
  - `lib/features/journal/views/journal_view.table.part.dart`
  - `lib/features/journal/views/journal_view.detail.part.dart`
- Shared page composition primitives added:
  - `lib/shared/widgets/page_header.dart`
  - `lib/shared/widgets/page_scaffold.dart`
- EF Core initial schema migration generated:
  - `backend/src/Solver.Api/Data/Migrations/20260218161011_InitialSchema.cs`
  - `backend/src/Solver.Api/Data/Migrations/SolverDbContextModelSnapshot.cs`
- Step 4 (in progress) - dynamic data centralization started:
  - `lib/features/portfolio/data/portfolio_trending_catalog.dart`
  - `lib/features/portfolio/data/portfolio_symbol_catalog.dart`
  - `lib/features/analysis/data/analysis_peer_catalog.dart`
  - fallback lists removed from portfolio/analysis views and providers
  - portfolio add flows now accept manual ticker entry (no strict dependency on search results):
    - `lib/features/portfolio/widgets/add_holding_dialog.dart`
    - `lib/features/portfolio/widgets/add_watchlist_dialog.dart`
    - `lib/features/portfolio/widgets/symbol_search_field.dart`
  - market symbol search expanded with `limit` support:
    - `backend/src/Solver.Api/Endpoints/MarketEndpoints.cs`
    - `backend/src/Solver.Api/Services/TwelveDataService.cs`
    - `lib/features/portfolio/providers/market_search_provider.dart`
  - explicit cache+TTL fallback policy added in:
    - `lib/features/portfolio/providers/trending_provider.dart`
    - `lib/features/portfolio/providers/price_history_provider.dart`
- Step 6/7 (in progress) - backend endpoint decomposition + persistence hardening started:
  - `backend/src/Solver.Api/Endpoints/TransactionsEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/GoalsEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/BudgetEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/CategoriesEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/PortfolioEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/WatchlistEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/MarketEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/AccountsEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/DashboardEndpoints.cs`
  - `backend/src/Solver.Api/Endpoints/AnalysisEndpoints.cs`
  - `backend/src/Solver.Api/Services/TransactionsService.cs`
  - `backend/src/Solver.Api/Services/GoalsService.cs`
  - `backend/src/Solver.Api/Services/BudgetService.cs`
  - `backend/src/Solver.Api/Services/CategoriesService.cs`
  - `backend/src/Solver.Api/Services/PortfolioService.cs`
  - `backend/src/Solver.Api/Services/WatchlistService.cs`
  - `backend/src/Solver.Api/Services/MarketService.cs`
  - `backend/src/Solver.Api/Services/AccountsService.cs`
  - `backend/src/Solver.Api/Services/DashboardService.cs`
  - `backend/src/Solver.Api/Services/AnalysisService.cs`
  - shared retry service added:
    - `backend/src/Solver.Api/Services/DbRetryService.cs`
  - recurring transaction persistence now uses centralized retry + `AddRange` + single `SaveChangesAsync` per attempt
  - duplicated create/batch/repayment insert blocks removed
  - goals entry persistence now uses the same centralized retry path
  - budget upsert now uses shared retry path (`DbRetryService`)
  - categories/goals/transactions/budget/portfolio/watchlist/market/accounts/dashboard/analysis logic moved out of endpoint lambdas into dedicated services (endpoint layer now routing-only)
  - previous `BudgetEndpoints.Helpers.cs` merged into `BudgetService`
  - endpoint footprint greatly reduced (examples):
    - `MarketEndpoints.cs`: 14475 -> 1821 bytes
    - `PortfolioEndpoints.cs`: 9003 -> 1651 bytes
    - `WatchlistEndpoints.cs`: 5600 -> 1091 bytes
    - `DashboardEndpoints.cs`: 5742 -> 357 bytes
    - `AccountsEndpoints.cs`: 4640 -> 1142 bytes
    - `AnalysisEndpoints.cs`: 2881 -> 352 bytes
  - backend practice findings reduced from 4 to 0 (`audit_backend_practices.ps1`)
- Step 8 completed - auth/cors runtime hardening:
  - strict bearer parsing + synchronized JWKS refresh
  - configurable issuer/audience policy
  - fail-fast auth/cors checks in non-development
  - invalid `ALLOWED_ORIGINS` entries now fail fast
- Step 9 completed - governance and closure:
  - PR checklist template: `.github/pull_request_template.md`
  - PR governance workflow: `.github/workflows/pr-governance.yml`
  - maintenance guide: `docs/maintenance_governance.md`
  - active-vs-archive doc strategy clarified:
    - `docs/README.md`
    - `docs/archive/README.md`
    - legacy docs moved to:
      - `docs/archive/legacy-phases/`
      - `docs/archive/legacy-ui-refonte/`
  - backend runtime env template: `backend/src/Solver.Api/.env.example`
  - strict verification defaults: `tools/refactor/verify_step.ps1` (`MaxUiFindings=0`, `MaxBackendFindings=0`)

## Next Batches

### Batch UI-0 - Global design consistency baseline
- Run `tools/refactor/audit_ui_consistency.ps1` and snapshot findings
- Replace direct `*.styleFrom` in feature files with `AppButtonStyles`
- Replace ad-hoc radius values with `AppRadius` tokens where possible
- Reduce raw `Color(0x...)` usage in features in favor of `AppColors`
- Gate policy: `verify_step.ps1` now enforces strict defaults (`MaxUiFindings=0`, `MaxBackendFindings=0`)
- Transitional thresholds are allowed only with explicit args during temporary cleanup batches.

### Batch 1 - Budget
- Split `budget_view.dart` by sections (header, filters, table/cards, dialogs)
- Extract repeated chips/buttons into shared widgets
- Remove duplicated formatting logic

### Batch 2 - Goals
- Split page into summary/list/details widgets
- Consolidate duplicated progress/amount formatting

### Batch 3 - Schedule
- Separate timeline/table/detail logic
- Extract status badge + row actions in shared components

### Batch 4 - Spreadsheet + Analysis
- Isolate heavy rendering/transform logic
- Move reusable helpers out of views

### Batch 5 - Backend bootstrap and migrations
- Remove runtime DDL bootstrap from startup
- Keep startup composition-only in `Program.cs` (`Database.Migrate` + data migrations only)
- Add explicit migration ordering and idempotency checks
- Backend findings gate is strict by default (`MaxBackendFindings=0`)

### Batch 6 - Backend endpoint decomposition
- Split oversized endpoint files (`BudgetEndpoints`, `GoalsEndpoints`, `TransactionsEndpoints`, `CategoriesEndpoints`)
- Extract validation, mapping, and persistence logic into services
- Reduce duplicated retry logic (single reusable strategy)

### Batch 7 - Backend persistence and query hardening
- Remove `SaveChangesAsync` inside loops where possible (batch + transaction)
- Replace fragile case-insensitive comparisons (`ToLower`) with indexed-safe patterns
- Review raw SQL usage and keep only parameterized/idempotent migration SQL

### Batch 8 - Auth/CORS hardening
- Tighten token validation parameters (issuer/audience policy)
- Review key cache refresh/failure behavior
- Review CORS defaults and production restrictions
  - implemented:
    - `backend/src/Solver.Api/Middleware/SupabaseAuthMiddleware.cs`
      - strict bearer parsing
      - synchronized JWKS cache refresh
      - configurable issuer/audience validation
      - controlled HS256 fallback (`AUTH_ALLOW_HS256_FALLBACK`)
    - `backend/src/Solver.Api/Services/AppRuntimeSecurity.cs`
      - origin parsing/normalization helpers
      - issuer/audience parsing helpers
    - `backend/src/Solver.Api/Program.cs`
      - fail-fast auth/cors checks in non-development
      - sanitized CORS origin handling
    - tests:
      - `backend/tests/Solver.Tests/AppRuntimeSecurityTests.cs`
      - `backend/tests/Solver.Tests/AuthMiddlewareTests.cs` (extra invalid scheme case)

## Optimization Tasks (Cross-cutting)
- Detect repeated code blocks and centralize utilities
- Detect obsolete/unused files after refactor batches
- Normalize design tokens usage (colors/radius/spacing)
- Remove dead imports and stale widgets
