using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class BudgetEndpoints
{
    public static void MapBudgetEndpoints(this WebApplication app)
    {
        app.MapGet("/api/budget/stats", async (SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var currentMonth = today.Month;
            var currentYear = today.Year;

            // Average income of last 3 complete months
            var dateFrom = new DateOnly(currentYear, currentMonth, 1).AddMonths(-3);
            var dateTo = new DateOnly(currentYear, currentMonth, 1);

            var recentMonthlyIncome = await (
                from t in db.Transactions
                join a in db.Accounts on t.AccountId equals a.Id
                where t.UserId == userId
                    && t.Status == TransactionStatus.Completed
                    && a.Type == AccountType.Income
                    && t.Date >= dateFrom && t.Date < dateTo
                group t by new { t.Date.Year, t.Date.Month } into g
                select g.Sum(t => t.Amount)
            ).ToListAsync();

            var averageIncome = recentMonthlyIncome.Count > 0 ? recentMonthlyIncome.Average() : 0m;

            // Fixed expenses total
            var fixedExpensesTotal = await db.Accounts
                .Where(a => a.UserId == userId && a.IsFixed && a.Type == AccountType.Expense)
                .SumAsync(a => a.Budget);

            // Current month spending per expense account
            var accounts = await db.Accounts
                .Where(a => a.UserId == userId && a.Type == AccountType.Expense)
                .OrderBy(a => a.Group).ThenBy(a => a.Name)
                .ToListAsync();

            var spentByAccount = await db.Transactions
                .Where(t => t.UserId == userId
                    && t.Status == TransactionStatus.Completed
                    && t.Date.Month == currentMonth
                    && t.Date.Year == currentYear)
                .Join(db.Accounts.Where(a => a.Type == AccountType.Expense),
                    t => t.AccountId, a => a.Id, (t, _) => t)
                .GroupBy(t => t.AccountId)
                .Select(g => new { AccountId = g.Key, Spent = g.Sum(t => t.Amount) })
                .ToListAsync();

            var spendingMap = spentByAccount.ToDictionary(x => x.AccountId, x => x.Spent);

            var currentMonthSpending = accounts.Select(a =>
            {
                var spent = spendingMap.GetValueOrDefault(a.Id, 0m);
                return new
                {
                    accountId = a.Id,
                    accountName = a.Name,
                    group = a.Group,
                    isFixed = a.IsFixed,
                    budget = a.Budget,
                    spent,
                    percentage = a.Budget > 0 ? Math.Round(spent / a.Budget * 100, 1) : 0m
                };
            }).ToList();

            return Results.Ok(new
            {
                averageIncome,
                fixedExpensesTotal,
                disposableIncome = averageIncome - fixedExpensesTotal,
                currentMonthSpending
            });
        });
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
