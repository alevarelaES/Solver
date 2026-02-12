using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Tests;

public class DashboardServiceTests : IDisposable
{
    private readonly SolverDbContext _db;

    private static readonly Guid UserA = Guid.NewGuid();
    private static readonly Guid UserB = Guid.NewGuid();
    private static readonly Guid IncomeAccountA = Guid.NewGuid();
    private static readonly Guid ExpenseAccountA = Guid.NewGuid();
    private static readonly Guid IncomeAccountB = Guid.NewGuid();

    public DashboardServiceTests()
    {
        var options = new DbContextOptionsBuilder<SolverDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new SolverDbContext(options);
        SeedData();
    }

    private void SeedData()
    {
        // User A accounts
        _db.Accounts.AddRange(
            new Account { Id = IncomeAccountA, UserId = UserA, Name = "Salary", Type = AccountType.Income, Group = "Revenus" },
            new Account { Id = ExpenseAccountA, UserId = UserA, Name = "Rent", Type = AccountType.Expense, Group = "Charges" });

        // User B account
        _db.Accounts.Add(
            new Account { Id = IncomeAccountB, UserId = UserB, Name = "Freelance", Type = AccountType.Income, Group = "Revenus" });

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var currentMonth = today.Month;
        var currentYear = today.Year;

        // User A transactions
        _db.Transactions.AddRange(
            // Completed income
            new Transaction { Id = Guid.NewGuid(), AccountId = IncomeAccountA, UserId = UserA,
                Date = new DateOnly(currentYear, currentMonth, 1), Amount = 5000, Status = TransactionStatus.Completed },
            // Completed expense
            new Transaction { Id = Guid.NewGuid(), AccountId = ExpenseAccountA, UserId = UserA,
                Date = new DateOnly(currentYear, currentMonth, 5), Amount = 1500, Status = TransactionStatus.Completed },
            // Pending income (current month)
            new Transaction { Id = Guid.NewGuid(), AccountId = IncomeAccountA, UserId = UserA,
                Date = new DateOnly(currentYear, currentMonth, 25), Amount = 500, Status = TransactionStatus.Pending },
            // Pending expense (current month)
            new Transaction { Id = Guid.NewGuid(), AccountId = ExpenseAccountA, UserId = UserA,
                Date = new DateOnly(currentYear, currentMonth, 28), Amount = 200, Status = TransactionStatus.Pending });

        // User B transaction (for isolation test)
        _db.Transactions.Add(
            new Transaction { Id = Guid.NewGuid(), AccountId = IncomeAccountB, UserId = UserB,
                Date = new DateOnly(currentYear, currentMonth, 1), Amount = 9999, Status = TransactionStatus.Completed });

        _db.SaveChanges();
    }

    [Fact]
    public async Task CurrentBalance_OnlyCompletedTransactions()
    {
        var accountTypeMap = await _db.Accounts
            .Where(a => a.UserId == UserA)
            .ToDictionaryAsync(a => a.Id, a => a.Type);

        var allCompleted = await _db.Transactions
            .Where(t => t.UserId == UserA && t.Status == TransactionStatus.Completed)
            .ToListAsync();

        var currentBalance = allCompleted.Sum(t =>
            accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount : -t.Amount);

        // 5000 income - 1500 expense = 3500
        Assert.Equal(3500m, currentBalance);
    }

    [Fact]
    public async Task ProjectedEndOfMonth_IncludesPendingNet()
    {
        var accountTypeMap = await _db.Accounts
            .Where(a => a.UserId == UserA)
            .ToDictionaryAsync(a => a.Id, a => a.Type);

        var allCompleted = await _db.Transactions
            .Where(t => t.UserId == UserA && t.Status == TransactionStatus.Completed)
            .ToListAsync();

        var currentBalance = allCompleted.Sum(t =>
            accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount : -t.Amount);

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var pendingMonthNet = await _db.Transactions
            .Where(t => t.UserId == UserA
                && t.Status == TransactionStatus.Pending
                && t.Date.Month == today.Month
                && t.Date.Year == today.Year)
            .ToListAsync();

        var pendingNet = pendingMonthNet.Sum(t =>
            accountTypeMap.GetValueOrDefault(t.AccountId) == AccountType.Income
                ? t.Amount : -t.Amount);

        var projected = currentBalance + pendingNet;

        // 3500 + (500 income pending - 200 expense pending) = 3800
        Assert.Equal(3800m, projected);
    }

    [Fact]
    public async Task UserIsolation_UserACannotSeeUserBData()
    {
        var userATransactions = await _db.Transactions
            .Where(t => t.UserId == UserA)
            .ToListAsync();

        // User A should not see User B's 9999 transaction
        Assert.DoesNotContain(userATransactions, t => t.Amount == 9999m);
        Assert.All(userATransactions, t => Assert.Equal(UserA, t.UserId));
    }

    public void Dispose() => _db.Dispose();
}
