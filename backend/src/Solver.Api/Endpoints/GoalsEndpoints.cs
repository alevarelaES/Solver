using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class GoalsEndpoints
{
    public static void MapGoalsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/goals");

        group.MapGet("/", (
            bool includeArchived,
            GoalsService service,
            HttpContext ctx) => service.GetGoalsAsync(includeArchived, ctx));
        group.MapPost("/", (
            CreateGoalDto dto,
            GoalsService service,
            HttpContext ctx) => service.CreateGoalAsync(dto, ctx));
        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateGoalDto dto,
            GoalsService service,
            HttpContext ctx) => service.UpdateGoalAsync(id, dto, ctx));
        group.MapPatch("/{id:guid}/archive", (
            Guid id,
            ArchiveGoalDto dto,
            GoalsService service,
            HttpContext ctx) => service.ArchiveGoalAsync(id, dto, ctx));
        group.MapGet("/{id:guid}/entries", (
            Guid id,
            GoalsService service,
            HttpContext ctx) => service.GetGoalEntriesAsync(id, ctx));
        group.MapPost("/{id:guid}/entries", (
            Guid id,
            CreateGoalEntryDto dto,
            GoalsService service,
            HttpContext ctx) => service.AddGoalEntryAsync(id, dto, ctx));
    }

    public sealed record CreateGoalDto(
        string Name,
        string? GoalType,
        decimal TargetAmount,
        DateOnly TargetDate,
        decimal? InitialAmount,
        decimal? MonthlyContribution,
        bool? AutoContributionEnabled,
        DateOnly? AutoContributionStartDate,
        int? Priority
    );

    public sealed record UpdateGoalDto(
        string Name,
        string? GoalType,
        decimal TargetAmount,
        DateOnly TargetDate,
        decimal InitialAmount,
        decimal MonthlyContribution,
        bool AutoContributionEnabled,
        DateOnly? AutoContributionStartDate,
        int Priority
    );

    public sealed record ArchiveGoalDto(bool IsArchived);

    public sealed record CreateGoalEntryDto(
        decimal Amount,
        DateOnly? EntryDate,
        string? Note,
        bool? IsAuto
    );
}
