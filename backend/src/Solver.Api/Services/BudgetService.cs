using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class BudgetService
{
    private readonly SolverDbContext _db;
    private readonly DbRetryService _dbRetry;
    private readonly IServiceScopeFactory _scopeFactory;

    public BudgetService(
        SolverDbContext db,
        DbRetryService dbRetry,
        IServiceScopeFactory scopeFactory)
    {
        _db = db;
        _dbRetry = dbRetry;
        _scopeFactory = scopeFactory;
    }

    public async Task<IResult> GetBudgetStatsAsync(
        int? year,
        int? month,
        bool reusePlan,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var selectedYear = year ?? today.Year;
        var selectedMonth = month ?? today.Month;
        if (selectedMonth is < 1 or > 12)
        {
            return Results.BadRequest(new { error = "Month must be between 1 and 12." });
        }

        var monthStart = new DateOnly(selectedYear, selectedMonth, 1);
        var (averageIncome, fixedExpensesTotal) = await GetIncomeAndFixedExpensesAsync(userId, monthStart);
        var (committedManualAmount, committedAutoAmount) = await GetCommittedExpensesAsync(
            userId,
            selectedYear,
            selectedMonth);
        var committedTotalAmount = committedManualAmount + committedAutoAmount;
        var defaultDisposableIncome = Math.Max(0m, averageIncome - committedTotalAmount);

        var expenseGroups = await _db.CategoryGroups
            .Where(g => g.UserId == userId && g.Type == AccountType.Expense && !g.IsArchived)
            .OrderBy(g => g.SortOrder)
            .ThenBy(g => g.Name)
            .ToListAsync();

        var expenseAccounts = await _db.Accounts
            .Where(a => a.UserId == userId && a.Type == AccountType.Expense)
            .OrderBy(a => a.Group)
            .ThenBy(a => a.Name)
            .ToListAsync();

        var spendingMap = await GetSpentByAccountAsync(
            userId,
            selectedYear,
            selectedMonth);
        var manualSpendingMap = await GetSpentByAccountAsync(
            userId,
            selectedYear,
            selectedMonth,
            isAuto: false);
        var manualPendingMap = await GetPendingByAccountAsync(
            userId,
            selectedYear,
            selectedMonth,
            isAuto: false);
        var autoByGroup = await GetAutoByGroupAsync(
            userId,
            selectedYear,
            selectedMonth);

        var currentMonthSpending = expenseAccounts.Select(a =>
        {
            var spent = spendingMap.GetValueOrDefault(a.Id, 0m);
            return new
            {
                accountId = a.Id,
                accountName = a.Name,
                group = a.Group,
                groupId = a.GroupId,
                isFixed = a.IsFixed,
                budget = a.Budget,
                spent,
                percentage = a.Budget > 0 ? Math.Round(spent / a.Budget * 100, 1) : 0m
            };
        }).ToList();

        var (planMonth, copiedFrom) = await GetOrCreatePlanMonthAsync(
            userId,
            selectedYear,
            selectedMonth,
            defaultDisposableIncome,
            defaultUseGrossIncomeBase: false,
            reusePlan);

        var categoriesByGroup = expenseAccounts
            .Where(a => a.GroupId.HasValue)
            .GroupBy(a => a.GroupId!.Value)
            .ToDictionary(
                g => g.Key,
                g => g.Select(a =>
                {
                    var spent = manualSpendingMap.GetValueOrDefault(a.Id, 0m);
                    return new
                    {
                        accountId = a.Id,
                        accountName = a.Name,
                        isFixed = a.IsFixed,
                        budget = a.Budget,
                        spent,
                        pending = manualPendingMap.GetValueOrDefault(a.Id, 0m),
                        percentage = a.Budget > 0 ? Math.Round(spent / a.Budget * 100, 1) : 0m
                    };
                }).OrderByDescending(x => x.spent).ToList());

        var allocationByGroupId = planMonth.GroupAllocations.ToDictionary(a => a.GroupId, a => a);

        var groups = expenseGroups.Select(g =>
        {
            var categories = categoriesByGroup.GetValueOrDefault(g.Id) ?? [];
            var spentActual = categories.Sum(c => c.spent);
            var alloc = allocationByGroupId.GetValueOrDefault(g.Id);
            var autoPlannedAmount = autoByGroup.GetValueOrDefault(g.Id, 0m);
            var autoPlannedPercent = planMonth.ForecastDisposableIncome > 0
                ? autoPlannedAmount / planMonth.ForecastDisposableIncome * 100m
                : 0m;
            var storedAmount = alloc?.PlannedAmount ?? 0m;
            // Migration-safe behavior: previous versions stored "manual + auto" together.
            // Keep only the manual part in editable allocation.
            var plannedAmount = Math.Max(0m, storedAmount - autoPlannedAmount);
            var plannedPercent = planMonth.ForecastDisposableIncome > 0
                ? plannedAmount / planMonth.ForecastDisposableIncome * 100m
                : 0m;
            var inputMode = alloc?.InputMode ?? "percent";
            return new
            {
                groupId = g.Id,
                groupName = g.Name,
                sortOrder = g.SortOrder,
                isFixedGroup = categories.Count > 0 && categories.All(c => c.isFixed),
                categories,
                spentActual,
                pendingAmount = Math.Round(categories.Sum(c => c.pending), 2),
                autoPlannedAmount = Math.Round(autoPlannedAmount, 2),
                autoPlannedPercent = Math.Round(autoPlannedPercent, 4),
                plannedPercent = Math.Round(plannedPercent, 4),
                plannedAmount = Math.Round(plannedAmount, 2),
                inputMode,
                priority = alloc?.Priority ?? g.SortOrder
            };
        }).ToList();

        var manualAllocatedPercent = groups.Sum(g => g.plannedPercent);
        var manualAllocatedAmount = groups.Sum(g => g.plannedAmount);
        var autoReserveAmount = groups.Sum(g => g.autoPlannedAmount);
        var autoReservePercent = planMonth.ForecastDisposableIncome > 0
            ? autoReserveAmount / planMonth.ForecastDisposableIncome * 100m
            : 0m;
        var totalAllocatedPercent = manualAllocatedPercent;
        var totalAllocatedAmount = manualAllocatedAmount;
        var manualAllocatablePercent = 100m;
        var manualAllocatableAmount = Math.Max(0m, planMonth.ForecastDisposableIncome);
        var remainingPercent = Math.Max(0, 100 - totalAllocatedPercent);
        var remainingAmount = Math.Max(0, planMonth.ForecastDisposableIncome - totalAllocatedAmount);

        return Results.Ok(new
        {
            averageIncome,
            fixedExpensesTotal,
            disposableIncome = defaultDisposableIncome,
            selectedYear,
            selectedMonth,
            currentMonthSpending,
            budgetPlan = new
            {
                id = planMonth.Id,
                forecastDisposableIncome = planMonth.ForecastDisposableIncome,
                useGrossIncomeBase = planMonth.UseGrossIncomeBase,
                grossIncomeReference = Math.Round(averageIncome, 2),
                committedManualAmount = Math.Round(committedManualAmount, 2),
                committedAutoAmount = Math.Round(committedAutoAmount, 2),
                committedTotalAmount = Math.Round(committedTotalAmount, 2),
                recommendedNetIncome = Math.Round(defaultDisposableIncome, 2),
                manualAllocatedPercent = Math.Round(manualAllocatedPercent, 2),
                manualAllocatedAmount = Math.Round(manualAllocatedAmount, 2),
                manualAllocatablePercent = Math.Round(manualAllocatablePercent, 2),
                manualAllocatableAmount = Math.Round(manualAllocatableAmount, 2),
                manualRemainingPercent = Math.Round(manualAllocatablePercent - manualAllocatedPercent, 2),
                manualRemainingAmount = Math.Round(manualAllocatableAmount - manualAllocatedAmount, 2),
                autoReservePercent = Math.Round(autoReservePercent, 2),
                autoReserveAmount = Math.Round(autoReserveAmount, 2),
                totalAllocatedPercent = Math.Round(totalAllocatedPercent, 2),
                totalAllocatedAmount = Math.Round(totalAllocatedAmount, 2),
                remainingPercent = Math.Round(remainingPercent, 2),
                remainingAmount = Math.Round(remainingAmount, 2),
                copiedFrom = copiedFrom is null ? null : new
                {
                    year = copiedFrom.Value.year,
                    month = copiedFrom.Value.month
                },
                groups
            }
        });
    }

    public async Task<IResult> UpsertBudgetPlanAsync(
        int year,
        int month,
        BudgetEndpoints.UpsertBudgetPlanDto dto,
        HttpContext ctx)
    {
        var retry = await _dbRetry.ExecuteAsync(
            _scopeFactory,
            db => UpsertBudgetPlanCoreAsync(
                year,
                month,
                dto,
                db,
                ctx),
            maxAttempts: 3,
            clearPoolsOnRetry: true);

        if (retry.Succeeded && retry.Value is not null) return retry.Value;
        return Results.Problem(
            title: "Erreur temporaire base de donnees",
            detail: "Echec de sauvegarde du plan budget. Reessayez dans quelques secondes.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private async Task<IResult> UpsertBudgetPlanCoreAsync(
        int year,
        int month,
        BudgetEndpoints.UpsertBudgetPlanDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        if (month is < 1 or > 12)
        {
            return Results.BadRequest(new { error = "Month must be between 1 and 12." });
        }

        var userId = GetUserId(ctx);
        var monthStart = new DateOnly(year, month, 1);
        var (averageIncome, fixedExpensesTotal) = await GetIncomeAndFixedExpensesAsync(userId, monthStart);
        var (committedManualAmount, committedAutoAmount) = await GetCommittedExpensesAsync(
            userId,
            year,
            month);
        var committedTotalAmount = committedManualAmount + committedAutoAmount;
        var defaultDisposableIncome = Math.Max(0m, averageIncome - committedTotalAmount);

        var (planMonth, _) = await GetOrCreatePlanMonthAsync(
            userId,
            year,
            month,
            defaultDisposableIncome,
            defaultUseGrossIncomeBase: false,
            reusePreviousMonth: false,
            dbOverride: db);

        var requestedDisposableIncome = dto.ForecastDisposableIncome ?? planMonth.ForecastDisposableIncome;
        if (requestedDisposableIncome < 0)
        {
            return Results.BadRequest(new { error = "ForecastDisposableIncome must be >= 0." });
        }
        var requestedUseGrossIncomeBase = dto.UseGrossIncomeBase ?? planMonth.UseGrossIncomeBase;
        planMonth.ForecastDisposableIncome = requestedDisposableIncome;
        planMonth.UseGrossIncomeBase = requestedUseGrossIncomeBase;
        planMonth.UpdatedAt = DateTime.UtcNow;

        var autoByGroup = await GetAutoByGroupAsync(
            userId,
            year,
            month,
            dbOverride: db);
        var autoReserveAmount = autoByGroup.Values.Sum();
        var autoReservePercent = requestedDisposableIncome > 0
            ? autoReserveAmount / requestedDisposableIncome * 100m
            : 0m;
        var manualAllocatablePercent = 100m;
        var manualAllocatableAmount = Math.Max(0m, requestedDisposableIncome);

        var requested = dto.Groups ?? [];
        var requestedGroupIds = requested.Select(x => x.GroupId).Distinct().ToList();
        var allowedGroups = await db.CategoryGroups
            .Where(g => g.UserId == userId && g.Type == AccountType.Expense && requestedGroupIds.Contains(g.Id))
            .ToDictionaryAsync(g => g.Id, g => g);

        if (requestedGroupIds.Count != allowedGroups.Count)
        {
            return Results.BadRequest(new { error = "One or more groupIds are invalid for this user." });
        }

        var normalized = new List<BudgetPlanGroupAllocation>();
        var manualTotalPercent = 0m;
        var manualTotalAmount = 0m;
        var now = DateTime.UtcNow;

        foreach (var row in requested)
        {
            var mode = string.Equals(
                row.InputMode?.Trim(),
                "amount",
                StringComparison.OrdinalIgnoreCase)
                ? "amount"
                : "percent";
            decimal plannedAmount;
            decimal plannedPercent;

            if (mode == "amount")
            {
                plannedAmount = Math.Max(0m, row.PlannedAmount ?? 0m);
                if (requestedDisposableIncome == 0m && plannedAmount > 0m)
                {
                    return Results.BadRequest(new
                    {
                        error = "Cannot allocate by amount when forecast disposable income is 0."
                    });
                }
                plannedPercent = requestedDisposableIncome > 0
                    ? plannedAmount / requestedDisposableIncome * 100m
                    : 0m;
            }
            else
            {
                plannedPercent = Math.Max(0m, row.PlannedPercent ?? 0m);
                plannedAmount = requestedDisposableIncome * plannedPercent / 100m;
            }

            manualTotalPercent += plannedPercent;
            manualTotalAmount += plannedAmount;

            normalized.Add(new BudgetPlanGroupAllocation
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                PlanMonthId = planMonth.Id,
                GroupId = row.GroupId,
                InputMode = mode,
                PlannedPercent = Math.Round(plannedPercent, 4),
                PlannedAmount = Math.Round(plannedAmount, 2),
                Priority = row.Priority ?? 0,
                CreatedAt = now,
                UpdatedAt = now,
            });
        }

        if (manualTotalPercent > manualAllocatablePercent + 0.0001m)
        {
            return Results.BadRequest(new
            {
                error = "Manual allocation exceeds the available share.",
                manualTotalPercent = Math.Round(manualTotalPercent, 2),
                manualAllocatablePercent = Math.Round(manualAllocatablePercent, 2)
            });
        }

        if (manualTotalAmount > manualAllocatableAmount + 0.01m)
        {
            return Results.BadRequest(new
            {
                error = "Manual allocation amount exceeds available disposable income.",
                manualTotalAmount = Math.Round(manualTotalAmount, 2),
                manualAllocatableAmount = Math.Round(manualAllocatableAmount, 2)
            });
        }

        var existingRows = await db.BudgetPlanGroupAllocations
            .Where(a => a.UserId == userId && a.PlanMonthId == planMonth.Id)
            .ToListAsync();
        db.BudgetPlanGroupAllocations.RemoveRange(existingRows);
        db.BudgetPlanGroupAllocations.AddRange(normalized);

        await db.SaveChangesAsync();

        var totalAllocatedAmount = manualTotalAmount;
        var totalAllocatedPercent = manualTotalPercent;
        return Results.Ok(new
        {
            year,
            month,
            forecastDisposableIncome = planMonth.ForecastDisposableIncome,
            useGrossIncomeBase = planMonth.UseGrossIncomeBase,
            manualAllocatedPercent = Math.Round(manualTotalPercent, 2),
            manualAllocatedAmount = Math.Round(manualTotalAmount, 2),
            manualAllocatablePercent = Math.Round(manualAllocatablePercent, 2),
            manualAllocatableAmount = Math.Round(manualAllocatableAmount, 2),
            manualRemainingPercent = Math.Round(manualAllocatablePercent - manualTotalPercent, 2),
            manualRemainingAmount = Math.Round(manualAllocatableAmount - manualTotalAmount, 2),
            autoReservePercent = Math.Round(autoReservePercent, 2),
            autoReserveAmount = Math.Round(autoReserveAmount, 2),
            totalAllocatedPercent = Math.Round(totalAllocatedPercent, 2),
            totalAllocatedAmount = Math.Round(totalAllocatedAmount, 2),
            remainingPercent = Math.Round(Math.Max(0, 100m - totalAllocatedPercent), 2),
            remainingAmount = Math.Round(Math.Max(0, planMonth.ForecastDisposableIncome - totalAllocatedAmount), 2),
            groups = normalized.Select(x => new
            {
                groupId = x.GroupId,
                inputMode = x.InputMode,
                plannedPercent = x.PlannedPercent,
                plannedAmount = x.PlannedAmount,
                priority = x.Priority,
            })
        });
    }

    private async Task<(BudgetPlanMonth plan, (int year, int month)? copiedFrom)> GetOrCreatePlanMonthAsync(
        Guid userId,
        int year,
        int month,
        decimal defaultDisposableIncome,
        bool defaultUseGrossIncomeBase,
        bool reusePreviousMonth,
        SolverDbContext? dbOverride = null)
    {
        var db = dbOverride ?? _db;
        var existing = await db.BudgetPlanMonths
            .Include(p => p.GroupAllocations)
            .FirstOrDefaultAsync(p => p.UserId == userId && p.Year == year && p.Month == month);
        if (existing is not null) return (existing, null);

        var now = DateTime.UtcNow;
        var created = new BudgetPlanMonth
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Year = year,
            Month = month,
            ForecastDisposableIncome = defaultDisposableIncome,
            UseGrossIncomeBase = defaultUseGrossIncomeBase,
            CreatedAt = now,
            UpdatedAt = now,
        };

        (int year, int month)? copiedFrom = null;

        if (reusePreviousMonth)
        {
            var previous = await db.BudgetPlanMonths
                .Include(p => p.GroupAllocations)
                .Where(p => p.UserId == userId && (p.Year < year || (p.Year == year && p.Month < month)))
                .OrderByDescending(p => p.Year)
                .ThenByDescending(p => p.Month)
                .FirstOrDefaultAsync();

            if (previous is not null)
            {
                created.ForecastDisposableIncome = previous.ForecastDisposableIncome;
                created.UseGrossIncomeBase = previous.UseGrossIncomeBase;
                created.GroupAllocations = previous.GroupAllocations.Select(a => new BudgetPlanGroupAllocation
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    PlanMonthId = created.Id,
                    GroupId = a.GroupId,
                    InputMode = a.InputMode,
                    PlannedPercent = a.PlannedPercent,
                    PlannedAmount = a.PlannedAmount,
                    Priority = a.Priority,
                    CreatedAt = now,
                    UpdatedAt = now,
                }).ToList();
                copiedFrom = (previous.Year, previous.Month);
            }
        }

        db.BudgetPlanMonths.Add(created);
        await db.SaveChangesAsync();
        return (created, copiedFrom);
    }

    private async Task<(decimal averageIncome, decimal fixedExpensesTotal)> GetIncomeAndFixedExpensesAsync(
        Guid userId,
        DateOnly monthStart)
    {
        var dateFrom = monthStart.AddMonths(-3);
        var dateTo = monthStart;

        var recentMonthlyIncome = await (
            from t in _db.Transactions
            join a in _db.Accounts on t.AccountId equals a.Id
            where t.UserId == userId
                && t.Status == TransactionStatus.Completed
                && a.Type == AccountType.Income
                && t.Date >= dateFrom && t.Date < dateTo
            group t by new { t.Date.Year, t.Date.Month }
            into g
            select g.Sum(t => t.Amount)
        ).ToListAsync();

        var averageIncome = recentMonthlyIncome.Count > 0
            ? recentMonthlyIncome.Average()
            : 0m;

        var fixedExpensesTotal = await _db.Accounts
            .Where(a => a.UserId == userId && a.IsFixed && a.Type == AccountType.Expense)
            .SumAsync(a => a.Budget);

        return (averageIncome, fixedExpensesTotal);
    }

    private async Task<(decimal manualAmount, decimal autoAmount)> GetCommittedExpensesAsync(
        Guid userId,
        int year,
        int month)
    {
        var rows = await _db.Transactions
            .Where(t => t.UserId == userId
                && t.Date.Year == year
                && t.Date.Month == month
                && (t.Status == TransactionStatus.Completed || t.Status == TransactionStatus.Pending))
            .Join(
                _db.Accounts.Where(a => a.Type == AccountType.Expense),
                t => t.AccountId,
                a => a.Id,
                (t, _) => new
                {
                    t.IsAuto,
                    t.Amount
                })
            .ToListAsync();

        var manualAmount = rows.Where(x => !x.IsAuto).Sum(x => x.Amount);
        var autoAmount = rows.Where(x => x.IsAuto).Sum(x => x.Amount);
        return (manualAmount, autoAmount);
    }

    private async Task<Dictionary<Guid, decimal>> GetSpentByAccountAsync(
        Guid userId,
        int year,
        int month,
        bool? isAuto = null)
    {
        var query = _db.Transactions
            .Where(t => t.UserId == userId
                && t.Status == TransactionStatus.Completed
                && t.Date.Month == month
                && t.Date.Year == year);

        if (isAuto.HasValue)
        {
            query = query.Where(t => t.IsAuto == isAuto.Value);
        }

        var spentByAccount = await query
            .Join(_db.Accounts.Where(a => a.Type == AccountType.Expense),
                t => t.AccountId, a => a.Id, (t, _) => t)
            .GroupBy(t => t.AccountId)
            .Select(g => new { AccountId = g.Key, Spent = g.Sum(t => t.Amount) })
            .ToListAsync();

        return spentByAccount.ToDictionary(x => x.AccountId, x => x.Spent);
    }

    private async Task<Dictionary<Guid, decimal>> GetPendingByAccountAsync(
        Guid userId,
        int year,
        int month,
        bool? isAuto = null)
    {
        var query = _db.Transactions
            .Where(t => t.UserId == userId
                && t.Status == TransactionStatus.Pending
                && t.Date.Month == month
                && t.Date.Year == year);

        if (isAuto.HasValue)
        {
            query = query.Where(t => t.IsAuto == isAuto.Value);
        }

        var pendingByAccount = await query
            .Join(_db.Accounts.Where(a => a.Type == AccountType.Expense),
                t => t.AccountId, a => a.Id, (t, _) => t)
            .GroupBy(t => t.AccountId)
            .Select(g => new { AccountId = g.Key, Spent = g.Sum(t => t.Amount) })
            .ToListAsync();

        return pendingByAccount.ToDictionary(x => x.AccountId, x => x.Spent);
    }

    private async Task<Dictionary<Guid, decimal>> GetAutoByGroupAsync(
        Guid userId,
        int year,
        int month,
        SolverDbContext? dbOverride = null)
    {
        var db = dbOverride ?? _db;
        var rows = await db.Transactions
            .Where(t => t.UserId == userId
                && t.IsAuto
                && t.Date.Year == year
                && t.Date.Month == month)
            .Join(
                db.Accounts.Where(a => a.Type == AccountType.Expense && a.GroupId.HasValue),
                t => t.AccountId,
                a => a.Id,
                (t, a) => new
                {
                    GroupId = a.GroupId!.Value,
                    t.Amount
                })
            .GroupBy(x => x.GroupId)
            .Select(g => new
            {
                GroupId = g.Key,
                Amount = g.Sum(x => x.Amount)
            })
            .ToListAsync();

        return rows.ToDictionary(x => x.GroupId, x => x.Amount);
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
