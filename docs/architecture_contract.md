# Architecture Contract (Step 1)

Status: mandatory reference for all refactor batches.
Scope: frontend + backend.

## 1) Frontend feature structure (mandatory)

Each feature must follow this structure:

```text
lib/features/<feature>/
  data/
    <feature>_catalog.dart
    <feature>_mapper.dart
  models/
    *.dart
  providers/
    *_provider.dart
  views/
    <feature>_view.dart
    <feature>_view.<section>.part.dart
  widgets/
    *.dart
```

Global reusable components:

```text
lib/shared/widgets/
  app_shell.dart
  page_scaffold.dart
  page_header.dart
  app_panel.dart
  ...
```

## 2) Backend structure (mandatory)

```text
backend/src/Solver.Api/
  Data/
    SolverDbContext.cs
    Migrations/
  Endpoints/
    *Endpoints.cs
  Services/
    *.cs
  Middleware/
    *.cs
  Program.cs
```

Rules:
- `Program.cs` is composition-only.
- `Data/Migrations` contains EF schema migrations only.
- Endpoint layer is transport-focused, business logic belongs in services.

## 3) Dependency rules

Frontend:
- `views` can depend on `providers`, `models`, `widgets`, `shared/widgets`.
- `widgets` can depend on `models` and pure UI helpers.
- `providers` can depend on `data`, `models`, and API clients.
- `data` cannot depend on `views` or UI widgets.

Backend:
- `Endpoints` -> `Services` -> `Data`.
- `Services` can depend on `Data` and domain models.
- `Program.cs` wires dependencies only; no business logic.

Forbidden:
- `views` importing feature-private internal logic from other feature views.
- endpoint files containing heavy business workflow.
- runtime DDL in startup.

## 4) File naming contract

Frontend:
- screen: `<feature>_view.dart`
- screen sections: `<feature>_view.<section>.part.dart`
- provider: `<name>_provider.dart`
- catalog/mapping: `<feature>_catalog.dart`, `<feature>_mapper.dart`

Backend:
- endpoint: `<Domain>Endpoints.cs`
- service: `<Domain><Action>Service.cs`
- migration data task: `<Domain><MigrationName>Migration.cs`

## 5) Size limits

Hard limits:
- frontend view file: <= 600 lines
- frontend non-view file: <= 300 lines
- backend endpoint/service file: <= 300 lines

Exceptions:
- generated migration files under `Data/Migrations`.

## 6) Dynamic data contract

Rules:
- no large business data blocks inside views.
- fallback data must be centralized in `feature/data/` (or served by backend endpoint).
- one source of truth only (no duplicated fallback catalog in provider + view).

Applied example:
- Portfolio trending fallback must exist once (single catalog/provider strategy), not duplicated across multiple files.

## 7) Shared page composition contract

Default page composition:
- `AppShell` (global nav)
- `AppPageScaffold` (page spacing, max width)
- `AppPageHeader` (title/subtitle/actions/secondary controls)

Any page deviating from this must justify why (auth pages, modals, onboarding).

## 8) Backend endpoint contract

Each endpoint file should contain:
- route registration,
- request DTO validation,
- response mapping.

Should not contain:
- long loops with persistence calls inside loop when batch is possible,
- duplicated helper blocks already present elsewhere (`GetUserId`, retry checks, asset type mapping),
- inline SQL when equivalent EF operations exist.

## 9) Test and quality gates contract

Mandatory commands at end of each refactor step:
- `flutter analyze`
- `flutter test`
- `dotnet build backend/src/Solver.Api/Solver.Api.csproj -nologo`
- `dotnet test backend/tests/Solver.Tests/Solver.Tests.csproj -nologo`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_ui_consistency.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_backend_practices.ps1`
- `powershell -ExecutionPolicy Bypass -File tools/refactor/verify_step.ps1`

## 10) Refactor delivery contract

- One batch = one structural objective.
- No mix of feature delivery and structure refactor in same batch.
- Each batch must update docs and reduce measurable debt:
  - fewer oversized files,
  - fewer duplicates,
  - fewer hardcoded business blocks,
  - stable or reduced gate findings.

