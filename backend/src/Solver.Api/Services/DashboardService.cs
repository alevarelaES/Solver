using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class DashboardService
{
    private readonly DbRetryService _dbRetry;
    private readonly IServiceScopeFactory _scopeFactory;

    public DashboardService(
        DbRetryService dbRetry,
        IServiceScopeFactory scopeFactory)
    {
        _dbRetry = dbRetry;
        _scopeFactory = scopeFactory;
    }

    public async Task<IResult> GetDashboardAsync(int? year, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var execution = await _dbRetry.ExecuteAsync(
            _scopeFactory,
            db => GetDashboardCoreAsync(db, year, userId),
            maxAttempts: 3,
            baseDelayMs: 200,
            clearPoolsOnRetry: true);

        if (execution.Succeeded && execution.Value is not null)
        {
            return execution.Value;
        }

        return Results.Problem(
            title: "Erreur temporaire base de donnees",
            detail: "Le tableau de bord est temporairement indisponible. Reessayez dans quelques secondes.",
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private static async Task<IResult> GetDashboardCoreAsync(
        SolverDbContext db,
        int? year,
        Guid userId)
    {
        var targetYear = year ?? DateTime.UtcNow.Year;
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var currentMonth = today.Month;
        var currentYear = today.Year;

        var accounts = await db.Accounts
            .Where(a => a.UserId == userId)
            .OrderBy(a => a.Group)
            .ThenBy(a => a.Name)
            .ToListAsync();

        if (accounts.Count == 0)
            return Results.Ok(new DashboardDto(0, 0, 0, 0, 0, []));

        var accountTypeMap = accounts.ToDictionary(a => a.Id, a => a.Type);

        var yearTransactions = await db.Transactions
            .Where(t => t.UserId == userId && t.Date.Year == targetYear)
            .ToListAsync();

        var allCompleted = await db.Transactions
            .Where(t => t.UserId == userId && t.Status == TransactionStatus.Completed)
            .Select(t => new { t.Amount, t.AccountId })
            .ToListAsync();

        var currentBalance = allCompleted.Sum(t =>
            accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount
                : -t.Amount);

        IEnumerable<Transaction> currentMonthTx = currentYear == targetYear
            ? yearTransactions.Where(t => t.Date.Month == currentMonth)
            : await db.Transactions
                .Where(t => t.UserId == userId && t.Date.Year == currentYear && t.Date.Month == currentMonth)
                .ToListAsync();

        var currentMonthIncome = currentMonthTx
            .Where(t => t.Status == TransactionStatus.Completed
                     && accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income)
            .Sum(t => t.Amount);

        var currentMonthExpenses = currentMonthTx
            .Where(t => accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Expense)
            .Sum(t => t.Amount);

        var pendingMonthNet = currentMonthTx
            .Where(t => t.Status == TransactionStatus.Pending)
            .Sum(t => accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount : -t.Amount);

        var projectedEndOfMonth = currentBalance + pendingMonthNet;

        var balanceBeforeYear = await db.Transactions
            .Where(t => t.UserId == userId
                     && t.Status == TransactionStatus.Completed
                     && t.Date.Year < targetYear)
            .Select(t => new { t.Amount, t.AccountId })
            .ToListAsync();

        var balanceBeforeYearTotal = balanceBeforeYear.Sum(t =>
            accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount
                : -t.Amount);

        var txByAccount = yearTransactions
            .GroupBy(t => t.AccountId)
            .ToDictionary(g => g.Key, g => g.ToList());

        var groups = accounts
            .GroupBy(a => a.Group)
            .OrderBy(g => g.Key)
            .Select(g => new GroupDto(
                g.Key,
                g.Select(a =>
                {
                    var months = Enumerable.Range(1, 12).ToDictionary(
                        m => m,
                        m =>
                        {
                            var monthTx = txByAccount.TryGetValue(a.Id, out var txList)
                                ? txList.Where(t => t.Date.Month == m).ToList()
                                : [];
                            return new MonthCellDto(
                                monthTx.Sum(t => t.Amount),
                                monthTx.Count(t => t.Status == TransactionStatus.Pending),
                                monthTx.Count(t => t.Status == TransactionStatus.Completed)
                            );
                        });

                    return new AccountMonthlyDto(
                        a.Id,
                        a.Name,
                        ToWireAccountType(a.Type),
                        months
                    );
                }).ToList()
            ))
            .ToList();

        return Results.Ok(new DashboardDto(
            currentBalance,
            currentMonthIncome,
            currentMonthExpenses,
            projectedEndOfMonth,
            balanceBeforeYearTotal,
            groups
        ));
    }

    private static string ToWireAccountType(AccountType type) =>
        type == AccountType.Income ? "income" : "expense";

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
