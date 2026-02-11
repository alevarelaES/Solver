using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class DashboardEndpoints
{
    public static void MapDashboardEndpoints(this WebApplication app)
    {
        app.MapGet("/api/dashboard", async (int? year, HttpContext ctx, SolverDbContext db) =>
        {
            var userId = GetUserId(ctx);
            var targetYear = year ?? DateTime.UtcNow.Year;
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var currentMonth = today.Month;
            var currentYear = today.Year;

            // 1. Load all accounts for this user
            var accounts = await db.Accounts
                .Where(a => a.UserId == userId)
                .OrderBy(a => a.Group)
                .ThenBy(a => a.Name)
                .ToListAsync();

            if (accounts.Count == 0)
                return Results.Ok(new DashboardDto(0, 0, 0, 0, 0, []));

            var accountTypeMap = accounts.ToDictionary(a => a.Id, a => a.Type);

            // 2. Load transactions for the target year (for grid)
            var yearTransactions = await db.Transactions
                .Where(t => t.UserId == userId && t.Date.Year == targetYear)
                .ToListAsync();

            // 3. Load all completed transactions for global balance
            var allCompleted = await db.Transactions
                .Where(t => t.UserId == userId && t.Status == TransactionStatus.Completed)
                .Select(t => new { t.Amount, t.AccountId })
                .ToListAsync();

            var currentBalance = allCompleted.Sum(t =>
                accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                    ? t.Amount
                    : -t.Amount);

            // 4. Current month KPIs
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
                .Where(t => t.Status == TransactionStatus.Completed
                         && accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Expense)
                .Sum(t => t.Amount);

            var pendingMonthNet = currentMonthTx
                .Where(t => t.Status == TransactionStatus.Pending)
                .Sum(t => accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                    ? t.Amount : -t.Amount);

            var projectedEndOfMonth = currentBalance + pendingMonthNet;

            // 5. Balance before target year (for footer cumulative calculation)
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

            // 6. Build grid by grouping transactions per account per month
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
                            a.Type.ToString().ToLower(),
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
        });
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
