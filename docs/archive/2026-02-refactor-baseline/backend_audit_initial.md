# Backend Audit (Initial)

Date: 2026-02-18

## Scope
- `backend/src/Solver.Api/Program.cs`
- `backend/src/Solver.Api/Endpoints/*`
- `backend/src/Solver.Api/Services/*`
- `backend/src/Solver.Api/Data/SolverDbContext.cs`
- `backend/src/Solver.Api/Middleware/SupabaseAuthMiddleware.cs`

## Key Findings

### High
- Runtime schema SQL block in startup composition root.
  - File: `backend/src/Solver.Api/Program.cs:121`
  - Impact: startup fragility, harder rollback, oversized bootstrap responsibilities.

- Multiple `SaveChangesAsync` inside loops in migration services.
  - Files:
    - `backend/src/Solver.Api/Services/CategoryResetMigration.cs:107`
    - `backend/src/Solver.Api/Services/CategoryGroupBackfillMigration.cs:71`
  - Impact: high DB roundtrips, partial-state risk on failure, difficult transactional guarantees.

### Medium
- Oversized endpoint files (mixed responsibilities: validation, query, mapping, retry).
  - Examples:
    - `backend/src/Solver.Api/Endpoints/BudgetEndpoints.cs`
    - `backend/src/Solver.Api/Endpoints/GoalsEndpoints.cs`
    - `backend/src/Solver.Api/Endpoints/TransactionsEndpoints.cs`
    - `backend/src/Solver.Api/Endpoints/CategoriesEndpoints.cs`
  - Impact: maintainability, testability, regression risk.

- Repeated retry/pool recovery logic duplicated in multiple endpoints.
  - Files:
    - `backend/src/Solver.Api/Endpoints/BudgetEndpoints.cs:221`
    - `backend/src/Solver.Api/Endpoints/GoalsEndpoints.cs:188`
    - `backend/src/Solver.Api/Endpoints/TransactionsEndpoints.cs:180`
  - Impact: drift and inconsistent behavior.

- Case-insensitive comparisons using `ToLower()` in queries.
  - File: `backend/src/Solver.Api/Endpoints/CategoriesEndpoints.cs:76`
  - Impact: potential index bypass and locale-sensitive behavior.

### Low
- `dotnet build` blocked by running process lock (`Solver.Api.exe` in use), so full warning baseline not yet captured.
  - Build command attempted: `dotnet build backend/src/Solver.Api/Solver.Api.csproj`

## Immediate Plan Additions
1. Extract startup SQL bootstrap from `Program.cs` into dedicated migration runner service.
2. Refactor migration services to batch state changes with explicit transaction boundaries.
3. Split endpoint files by feature use-case and move business logic into services.
4. Introduce shared persistence retry strategy (single reusable policy).
5. Replace `ToLower()` query patterns with safer/index-friendly alternatives.
6. Run build/warnings baseline after stopping local running API process.

