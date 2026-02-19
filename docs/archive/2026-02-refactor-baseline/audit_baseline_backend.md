# Audit Baseline Backend (Step 0)

Date baseline: 2026-02-18
Scope: `backend/src/Solver.Api/**`

## 1) Volume global
- C# files: 49
- Total lines: 7,668

## 2) Files above target size
Target from master plan:
- endpoint/service file: <= 300 lines

### Endpoints > 300
- 682 `backend/src/Solver.Api/Endpoints/BudgetEndpoints.cs`
- 506 `backend/src/Solver.Api/Endpoints/GoalsEndpoints.cs`
- 445 `backend/src/Solver.Api/Endpoints/CategoriesEndpoints.cs`
- 441 `backend/src/Solver.Api/Endpoints/TransactionsEndpoints.cs`
- 410 `backend/src/Solver.Api/Endpoints/MarketEndpoints.cs`

Count: 5

### Services > 300
- 564 `backend/src/Solver.Api/Services/TwelveDataService.cs`

Count: 1

### EF migrations > 300 (expected generated code)
- 706 `backend/src/Solver.Api/Data/Migrations/20260218161011_InitialSchema.Designer.cs`
- 703 `backend/src/Solver.Api/Data/Migrations/SolverDbContextModelSnapshot.cs`
- 432 `backend/src/Solver.Api/Data/Migrations/20260218161011_InitialSchema.cs`

Count: 3

Note: migration files are generated and excluded from manual size constraints.

## 3) Backend practices baseline
From `tools/refactor/audit_backend_practices.ps1`:
- inline SQL bootstrap in `Program.cs`: 0
- `SaveChangesAsync` potentially inside loops: 4
  - `GoalsEndpoints.cs:229`
  - `TransactionsEndpoints.cs:201`
  - `TransactionsEndpoints.cs:280`
  - `TransactionsEndpoints.cs:371`
- `ToLower/ToLowerInvariant` in endpoints: 0
- raw SQL outside allowed migration services: 0
- total findings: 4

## 4) Structural duplication signals
Repeated helper patterns across endpoints:
- `private static Guid GetUserId(HttpContext ctx)` declared in 9 endpoint files.
- `private static string ValidateAssetType(...)` duplicated in:
  - `PortfolioEndpoints.cs`
  - `WatchlistEndpoints.cs`
- `IsNpgsqlDisposedConnector(...)` variants duplicated across endpoint files.

## 5) Legacy/transition markers
- Legacy fallback auth comment in middleware:
  - `backend/src/Solver.Api/Middleware/SupabaseAuthMiddleware.cs`
- Data migration services remain large and procedural:
  - `CategoryResetMigration.cs`
  - `CategoryGroupBackfillMigration.cs`

## 6) Startup and migration policy status
- Good: startup uses `Database.MigrateAsync()` and no runtime DDL in `Program.cs`.
- Good: EF migration folder now exists and baseline schema migration is generated.
- Remaining: split large endpoints/services and centralize duplicated helpers.

## 7) Candidate review list (not automatic deletion)
- Service files with file-name match count = 0 in simple text scan:
  - `FinnhubModels.cs`
  - `TwelveDataModels.cs`

This may be false positive (types inside can still be referenced). Manual verification required before any removal.

## 8) Step 0 conclusion (backend)
Main backend debt is now concentrated in:
- oversized endpoint files,
- duplicated utility patterns,
- loop persistence patterns in a few flows.

Priority for Step 5/6/7:
1. split `Budget/Goals/Transactions/Categories/Market` endpoints,
2. move common endpoint helpers to shared components,
3. remove loop-save patterns in transaction-heavy paths.

