using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class BudgetEndpoints
{
    public static void MapBudgetEndpoints(this WebApplication app)
    {
        app.MapGet("/api/budget/stats", (
            int? year,
            int? month,
            bool reusePlan,
            BudgetService service,
            HttpContext ctx) => service.GetBudgetStatsAsync(year, month, reusePlan, ctx));

        app.MapPut("/api/budget/plan/{year:int}/{month:int}", (
            int year,
            int month,
            UpsertBudgetPlanDto dto,
            BudgetService service,
            HttpContext ctx) => service.UpsertBudgetPlanAsync(year, month, dto, ctx));

        app.MapGet("/api/budget/template", (
            BudgetService service,
            HttpContext ctx) => service.GetBudgetTemplateAsync(ctx));

        app.MapPut("/api/budget/template", (
            UpsertBudgetPlanDto dto,
            BudgetService service,
            HttpContext ctx) => service.UpsertBudgetTemplateAsync(dto, ctx));

        app.MapDelete("/api/budget/template", (
            BudgetService service,
            HttpContext ctx) => service.DeleteBudgetTemplateAsync(ctx));
    }

    public sealed record UpsertBudgetPlanDto(
        decimal? ForecastDisposableIncome,
        bool? UseGrossIncomeBase,
        List<UpsertBudgetPlanGroupDto>? Groups
    );

    public sealed record UpsertBudgetPlanGroupDto(
        Guid GroupId,
        string? InputMode,
        decimal? PlannedPercent,
        decimal? PlannedAmount,
        int? Priority
    );
}
