## Summary
- What changed:
- Why:
- Scope:

## Refactor/Architecture Checklist
- [ ] The change respects `docs/architecture_contract.md`
- [ ] No heavy business logic added inside Flutter `build()`
- [ ] No dynamic business data hardcoded directly in views/endpoints
- [ ] No runtime schema DDL added in startup path
- [ ] No duplicated helper/component introduced when a shared one exists

## Runtime/Security Checklist (if backend touched)
- [ ] `ALLOWED_ORIGINS` config is valid for target environment
- [ ] Auth config remains strict in non-development (`SUPABASE_URL` or explicit controlled fallback)
- [ ] No secret added in source files or docs
- [ ] Input validation and authorization checks preserved

## Validation Checklist (mandatory)
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `dotnet build backend/src/Solver.Api/Solver.Api.csproj -nologo`
- [ ] `dotnet test backend/tests/Solver.Tests/Solver.Tests.csproj -nologo`
- [ ] `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_ui_consistency.ps1`
- [ ] `powershell -ExecutionPolicy Bypass -File tools/refactor/audit_backend_practices.ps1`
- [ ] `powershell -ExecutionPolicy Bypass -File tools/refactor/verify_step.ps1`

## Risk and Rollback
- Risk level (low/medium/high):
- Rollback plan:

## Notes for reviewers
- Focus points:
- Known limitations:
