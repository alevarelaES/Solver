using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class AnalysisService
{
    private readonly SolverDbContext _db;

    public AnalysisService(SolverDbContext db)
    {
        _db = db;
    }

    public async Task<IResult> GetAnalysisAsync(int? year, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var analysisYear = year ?? DateTime.UtcNow.Year;

        var transactions = await _db.Transactions
            .Include(t => t.Account)
            .Where(t => t.UserId == userId
                && t.Status == TransactionStatus.Completed
                && t.Date.Year == analysisYear)
            .ToListAsync();

        var byMonth = Enumerable.Range(1, 12).Select(m =>
        {
            var monthTxs = transactions.Where(t => t.Date.Month == m).ToList();
            var income = monthTxs.Where(t => t.Account!.Type == AccountType.Income).Sum(t => t.Amount);
            var expenses = monthTxs.Where(t => t.Account!.Type == AccountType.Expense).Sum(t => t.Amount);
            return new { month = m, income, expenses, savings = income - expenses };
        }).ToList();

        var expenseTxs = transactions.Where(t => t.Account!.Type == AccountType.Expense).ToList();
        var totalExpenses = expenseTxs.Sum(t => t.Amount);
        var byGroup = expenseTxs
            .GroupBy(t => t.Account!.Group)
            .Select(g => new
            {
                group = g.Key,
                total = g.Sum(t => t.Amount),
                percentage = totalExpenses > 0 ? Math.Round(g.Sum(t => t.Amount) / totalExpenses * 100, 1) : 0m
            })
            .OrderByDescending(g => g.total)
            .ToList();

        var topExpenseAccounts = expenseTxs
            .GroupBy(t => t.Account)
            .Select(g => new
            {
                accountName = g.Key!.Name,
                total = g.Sum(t => t.Amount),
                budget = g.Key!.Budget
            })
            .OrderByDescending(a => a.total)
            .Take(5)
            .ToList();

        var totalIncome = transactions.Where(t => t.Account!.Type == AccountType.Income).Sum(t => t.Amount);
        var savingsRate = totalIncome > 0 ? Math.Round((totalIncome - totalExpenses) / totalIncome * 100, 1) : 0m;

        return Results.Ok(new { byGroup, byMonth, topExpenseAccounts, savingsRate, totalIncome, totalExpenses });
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
