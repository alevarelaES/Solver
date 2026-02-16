using Microsoft.EntityFrameworkCore;
using Npgsql;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class GoalsEndpoints
{
    public static void MapGoalsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/goals");

        group.MapGet("/", GetGoalsAsync);
        group.MapPost("/", CreateGoalAsync);
        group.MapPut("/{id:guid}", UpdateGoalAsync);
        group.MapPatch("/{id:guid}/archive", ArchiveGoalAsync);
        group.MapGet("/{id:guid}/entries", GetGoalEntriesAsync);
        group.MapPost("/{id:guid}/entries", AddGoalEntryAsync);
    }

    private static async Task<IResult> GetGoalsAsync(
        bool includeArchived,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        await ApplyAutoContributionsAsync(db, userId, today);

        var goals = await db.SavingGoals
            .Where(g => g.UserId == userId && (includeArchived || !g.IsArchived))
            .OrderBy(g => g.Priority)
            .ThenBy(g => g.TargetDate)
            .ToListAsync();

        var goalIds = goals.Select(g => g.Id).ToList();
        var sumsByGoal = await db.SavingGoalEntries
            .Where(e => e.UserId == userId && goalIds.Contains(e.GoalId))
            .GroupBy(e => e.GoalId)
            .Select(g => new { GoalId = g.Key, Amount = g.Sum(e => e.Amount) })
            .ToDictionaryAsync(x => x.GoalId, x => x.Amount);

        var payload = goals.Select(g => ToGoalPayload(g, today, sumsByGoal.GetValueOrDefault(g.Id, 0m)));
        return Results.Ok(payload);
    }

    private static async Task<IResult> CreateGoalAsync(
        CreateGoalDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return Results.BadRequest(new { error = "Name is required." });
        }
        if (dto.TargetAmount <= 0)
        {
            return Results.BadRequest(new { error = "TargetAmount must be > 0." });
        }

        var maxPriority = await db.SavingGoals
            .Where(g => g.UserId == userId)
            .Select(g => (int?)g.Priority)
            .MaxAsync() ?? -1;

        var now = DateTime.UtcNow;
        var goal = new SavingGoal
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name.Trim(),
            GoalType = ParseGoalType(dto.GoalType),
            TargetAmount = dto.TargetAmount,
            TargetDate = dto.TargetDate,
            InitialAmount = Math.Max(0m, dto.InitialAmount ?? 0m),
            MonthlyContribution = Math.Max(0m, dto.MonthlyContribution ?? 0m),
            AutoContributionEnabled = dto.AutoContributionEnabled ?? false,
            AutoContributionStartDate = dto.AutoContributionStartDate,
            Priority = dto.Priority ?? (maxPriority + 1),
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
        };

        db.SavingGoals.Add(goal);
        await db.SaveChangesAsync();

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        return Results.Created($"/api/goals/{goal.Id}", ToGoalPayload(goal, today, 0m));
    }

    private static async Task<IResult> UpdateGoalAsync(
        Guid id,
        UpdateGoalDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var goal = await db.SavingGoals.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
        if (goal is null) return Results.NotFound();

        if (string.IsNullOrWhiteSpace(dto.Name))
        {
            return Results.BadRequest(new { error = "Name is required." });
        }
        if (dto.TargetAmount <= 0)
        {
            return Results.BadRequest(new { error = "TargetAmount must be > 0." });
        }

        goal.Name = dto.Name.Trim();
        goal.GoalType = ParseGoalType(dto.GoalType);
        goal.TargetAmount = dto.TargetAmount;
        goal.TargetDate = dto.TargetDate;
        goal.InitialAmount = Math.Max(0m, dto.InitialAmount);
        goal.MonthlyContribution = Math.Max(0m, dto.MonthlyContribution);
        goal.AutoContributionEnabled = dto.AutoContributionEnabled;
        goal.AutoContributionStartDate = dto.AutoContributionStartDate;
        goal.Priority = dto.Priority;
        goal.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();

        var entriesSum = await db.SavingGoalEntries
            .Where(e => e.UserId == userId && e.GoalId == goal.Id)
            .SumAsync(e => e.Amount);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        return Results.Ok(ToGoalPayload(goal, today, entriesSum));
    }

    private static async Task<IResult> ArchiveGoalAsync(
        Guid id,
        ArchiveGoalDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var goal = await db.SavingGoals.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
        if (goal is null) return Results.NotFound();

        goal.IsArchived = dto.IsArchived;
        goal.UpdatedAt = DateTime.UtcNow;
        await db.SaveChangesAsync();
        return Results.Ok(new { id, isArchived = dto.IsArchived });
    }

    private static async Task<IResult> GetGoalEntriesAsync(
        Guid id,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var exists = await db.SavingGoals.AnyAsync(g => g.Id == id && g.UserId == userId);
        if (!exists) return Results.NotFound();

        var entries = await db.SavingGoalEntries
            .Where(e => e.UserId == userId && e.GoalId == id)
            .OrderByDescending(e => e.EntryDate)
            .ThenByDescending(e => e.CreatedAt)
            .Select(e => new
            {
                id = e.Id,
                goalId = e.GoalId,
                entryDate = e.EntryDate,
                amount = e.Amount,
                note = e.Note,
                isAuto = e.IsAuto,
                createdAt = e.CreatedAt,
            })
            .ToListAsync();

        return Results.Ok(entries);
    }

    private static async Task<IResult> AddGoalEntryAsync(
        Guid id,
        CreateGoalEntryDto dto,
        IServiceScopeFactory scopeFactory,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        if (dto.Amount == 0m)
        {
            return Results.BadRequest(new { error = "Amount cannot be 0." });
        }

        for (var attempt = 1; attempt <= 3; attempt++)
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();

            var goal = await db.SavingGoals
                .AsNoTracking()
                .FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
            if (goal is null) return Results.NotFound();

            if (dto.Amount < 0m)
            {
                var entriesSum = await db.SavingGoalEntries
                    .Where(e => e.UserId == userId && e.GoalId == id)
                    .SumAsync(e => e.Amount);
                var currentAmount = goal.InitialAmount + entriesSum;
                if (currentAmount + dto.Amount < 0m)
                {
                    return Results.BadRequest(new
                    {
                        error = "Withdrawal cannot exceed current amount."
                    });
                }
            }

            var entry = new SavingGoalEntry
            {
                Id = Guid.NewGuid(),
                GoalId = id,
                UserId = userId,
                EntryDate = dto.EntryDate ?? DateOnly.FromDateTime(DateTime.UtcNow),
                Amount = dto.Amount,
                Note = string.IsNullOrWhiteSpace(dto.Note) ? null : dto.Note.Trim(),
                IsAuto = dto.IsAuto ?? false,
                CreatedAt = DateTime.UtcNow,
            };

            db.SavingGoalEntries.Add(entry);

            try
            {
                await db.SaveChangesAsync();
                return Results.Created($"/api/goals/{id}/entries/{entry.Id}", new
                {
                    id = entry.Id,
                    goalId = entry.GoalId,
                    entryDate = entry.EntryDate,
                    amount = entry.Amount,
                    note = entry.Note,
                    isAuto = entry.IsAuto,
                    createdAt = entry.CreatedAt,
                });
            }
            catch (Exception ex) when (IsNpgsqlDisposedConnector(ex))
            {
                if (attempt < 3)
                {
                    NpgsqlConnection.ClearAllPools();
                    await Task.Delay(120 * attempt);
                    continue;
                }

                return Results.Problem(
                    title: "Erreur temporaire base de donnees",
                    detail: "Echec d'enregistrement du mouvement. Reessayez dans quelques secondes.",
                    statusCode: StatusCodes.Status503ServiceUnavailable);
            }
        }

        return Results.Problem(
            title: "Erreur temporaire base de donnees",
            detail: "Echec d'enregistrement du mouvement. Reessayez dans quelques secondes.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private static object ToGoalPayload(SavingGoal goal, DateOnly today, decimal entriesSum)
    {
        var currentAmount = goal.InitialAmount + entriesSum;
        var remaining = Math.Max(0m, goal.TargetAmount - currentAmount);
        var monthsRemaining = GetMonthsRemaining(today, goal.TargetDate);
        var recommendedMonthly = remaining <= 0
            ? 0m
            : monthsRemaining > 0
                ? remaining / monthsRemaining
                : remaining;

        string status;
        if (remaining <= 0) status = "achieved";
        else if (goal.TargetDate < today) status = "overdue";
        else status = goal.MonthlyContribution >= recommendedMonthly ? "on_track" : "behind";

        DateOnly? projectedDate = null;
        if (remaining <= 0)
        {
            projectedDate = today;
        }
        else if (goal.MonthlyContribution > 0)
        {
            var monthStart = new DateOnly(today.Year, today.Month, 1);
            var monthsToGoal = (int)Math.Ceiling(remaining / goal.MonthlyContribution);
            projectedDate = monthStart.AddMonths(Math.Max(0, monthsToGoal - 1));
        }

        var progressPct = goal.TargetAmount > 0
            ? Math.Min(100m, currentAmount / goal.TargetAmount * 100m)
            : 0m;

        return new
        {
            id = goal.Id,
            name = goal.Name,
            goalType = goal.GoalType.ToString().ToLowerInvariant(),
            targetAmount = goal.TargetAmount,
            targetDate = goal.TargetDate,
            initialAmount = goal.InitialAmount,
            monthlyContribution = goal.MonthlyContribution,
            autoContributionEnabled = goal.AutoContributionEnabled,
            autoContributionStartDate = goal.AutoContributionStartDate,
            priority = goal.Priority,
            isArchived = goal.IsArchived,
            currentAmount,
            remainingAmount = remaining,
            recommendedMonthly = Math.Round(recommendedMonthly, 2),
            progressPercent = Math.Round(progressPct, 2),
            monthsRemaining,
            projectedDate,
            status,
            createdAt = goal.CreatedAt,
            updatedAt = goal.UpdatedAt,
        };
    }

    private static int GetMonthsRemaining(DateOnly from, DateOnly target)
    {
        var monthDelta = (target.Year - from.Year) * 12 + (target.Month - from.Month) + 1;
        return Math.Max(0, monthDelta);
    }

    private static async Task ApplyAutoContributionsAsync(
        SolverDbContext db,
        Guid userId,
        DateOnly today)
    {
        var monthStart = new DateOnly(today.Year, today.Month, 1);

        var goals = await db.SavingGoals
            .Where(g => g.UserId == userId
                && !g.IsArchived
                && g.AutoContributionEnabled
                && g.MonthlyContribution > 0)
            .OrderBy(g => g.CreatedAt)
            .ToListAsync();
        if (goals.Count == 0) return;

        var goalIds = goals.Select(g => g.Id).ToList();
        var entries = await db.SavingGoalEntries
            .Where(e => e.UserId == userId && goalIds.Contains(e.GoalId))
            .Select(e => new
            {
                e.GoalId,
                e.EntryDate,
                e.Amount,
                e.IsAuto
            })
            .ToListAsync();

        var sumByGoal = entries
            .GroupBy(e => e.GoalId)
            .ToDictionary(g => g.Key, g => g.Sum(x => x.Amount));

        var existingAutoMonths = entries
            .Where(e => e.IsAuto && e.Amount > 0)
            .Select(e => BuildGoalMonthKey(e.GoalId, e.EntryDate.Year, e.EntryDate.Month))
            .ToHashSet(StringComparer.Ordinal);

        var now = DateTime.UtcNow;
        var newEntries = new List<SavingGoalEntry>();

        foreach (var goal in goals)
        {
            var currentAmount = goal.InitialAmount + sumByGoal.GetValueOrDefault(goal.Id, 0m);
            if (currentAmount >= goal.TargetAmount) continue;

            var startDate = goal.AutoContributionStartDate
                ?? DateOnly.FromDateTime(goal.CreatedAt.ToUniversalTime());
            if (startDate > today) continue;

            var depositDay = startDate.Day;
            var cursor = new DateOnly(startDate.Year, startDate.Month, 1);

            while (cursor <= monthStart)
            {
                var monthKey = BuildGoalMonthKey(goal.Id, cursor.Year, cursor.Month);
                if (existingAutoMonths.Contains(monthKey))
                {
                    cursor = cursor.AddMonths(1);
                    continue;
                }

                var plannedDay = Math.Min(depositDay, DateTime.DaysInMonth(cursor.Year, cursor.Month));
                var plannedDate = new DateOnly(cursor.Year, cursor.Month, plannedDay);
                if (plannedDate > today)
                {
                    break;
                }

                if (currentAmount >= goal.TargetAmount) break;
                var amount = Math.Min(goal.MonthlyContribution, goal.TargetAmount - currentAmount);
                if (amount <= 0) break;

                newEntries.Add(new SavingGoalEntry
                {
                    Id = Guid.NewGuid(),
                    GoalId = goal.Id,
                    UserId = userId,
                    EntryDate = plannedDate,
                    Amount = amount,
                    Note = goal.GoalType == SavingGoalType.Debt
                        ? "Paiement automatique mensuel"
                        : "Depot automatique mensuel",
                    IsAuto = true,
                    CreatedAt = now,
                });
                existingAutoMonths.Add(monthKey);
                currentAmount += amount;

                cursor = cursor.AddMonths(1);
            }
        }

        if (newEntries.Count == 0) return;
        db.SavingGoalEntries.AddRange(newEntries);
        await db.SaveChangesAsync();
    }

    private static string BuildGoalMonthKey(Guid goalId, int year, int month) =>
        $"{goalId:N}:{year:D4}-{month:D2}";

    private static bool IsNpgsqlDisposedConnector(DbUpdateException ex)
    {
        return IsNpgsqlDisposedConnector((Exception)ex);
    }

    private static bool IsNpgsqlDisposedConnector(Exception ex)
    {
        for (Exception? current = ex; current is not null; current = current.InnerException)
        {
            if (current is ObjectDisposedException disposed)
            {
                var objectName = disposed.ObjectName ?? string.Empty;
                if (objectName.Contains("ManualResetEventSlim", StringComparison.Ordinal)
                    || objectName.Contains("Npgsql", StringComparison.Ordinal))
                {
                    return true;
                }
            }

            var msg = current.Message ?? string.Empty;
            if (msg.Contains("Cannot access a disposed object", StringComparison.OrdinalIgnoreCase)
                && msg.Contains("Npgsql", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;

    private static SavingGoalType ParseGoalType(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return SavingGoalType.Savings;
        return raw.Trim().ToLowerInvariant() switch
        {
            "debt" => SavingGoalType.Debt,
            "repayment" => SavingGoalType.Debt,
            "remboursement" => SavingGoalType.Debt,
            _ => SavingGoalType.Savings
        };
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
