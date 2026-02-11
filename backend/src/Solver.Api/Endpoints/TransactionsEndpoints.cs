using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class TransactionsEndpoints
{
    public static void MapTransactionsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/transactions");

        group.MapGet("/", async (
            Guid? accountId,
            string? status,
            int? month,
            int? year,
            bool showFuture,
            SolverDbContext db,
            HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var query = db.Transactions
                .Include(t => t.Account)
                .Where(t => t.UserId == userId);

            if (accountId.HasValue)
                query = query.Where(t => t.AccountId == accountId.Value);

            if (!string.IsNullOrEmpty(status) && Enum.TryParse<TransactionStatus>(status, true, out var parsedStatus))
                query = query.Where(t => t.Status == parsedStatus);

            if (month.HasValue)
                query = query.Where(t => t.Date.Month == month.Value);

            if (year.HasValue)
                query = query.Where(t => t.Date.Year == year.Value);

            if (!showFuture)
            {
                var today = DateOnly.FromDateTime(DateTime.UtcNow);
                query = query.Where(t => t.Date <= today || t.Status == TransactionStatus.Pending);
            }

            var transactions = await query
                .OrderByDescending(t => t.Date)
                .ToListAsync();

            return Results.Ok(transactions);
        });

        group.MapPost("/", async (CreateTransactionDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            var accountExists = await db.Accounts
                .AnyAsync(a => a.Id == dto.AccountId && a.UserId == userId);

            if (!accountExists) return Results.NotFound(new { error = "Account not found" });

            var transaction = new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = dto.AccountId,
                UserId = userId,
                Date = dto.Date,
                Amount = dto.Amount,
                Note = dto.Note,
                Status = dto.Status,
                IsAuto = dto.IsAuto,
                CreatedAt = DateTime.UtcNow
            };

            db.Transactions.Add(transaction);
            await db.SaveChangesAsync();

            return Results.Created($"/api/transactions/{transaction.Id}", transaction);
        });

        group.MapPost("/batch", async (BatchTransactionDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            var accountExists = await db.Accounts
                .AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);

            if (!accountExists) return Results.NotFound(new { error = "Account not found" });

            var transactions = GenerateRecurringTransactions(dto, userId);

            await db.Transactions.AddRangeAsync(transactions);
            await db.SaveChangesAsync();

            return Results.Ok(new { count = transactions.Count });
        });

        group.MapPut("/{id:guid}", async (Guid id, UpdateTransactionDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var transaction = await db.Transactions
                .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

            if (transaction is null) return Results.NotFound();

            transaction.Date = dto.Date;
            transaction.Amount = dto.Amount;
            transaction.Note = dto.Note;
            transaction.Status = dto.Status;
            transaction.IsAuto = dto.IsAuto;

            await db.SaveChangesAsync();
            return Results.Ok(transaction);
        });

        group.MapDelete("/{id:guid}", async (Guid id, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var transaction = await db.Transactions
                .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);

            if (transaction is null) return Results.NotFound();

            db.Transactions.Remove(transaction);
            await db.SaveChangesAsync();

            return Results.NoContent();
        });
    }

    private static List<Transaction> GenerateRecurringTransactions(BatchTransactionDto dto, Guid userId)
    {
        var transactions = new List<Transaction>();
        var startMonth = dto.Transaction.Date.Month;
        var year = dto.Transaction.Date.Year;
        var today = DateOnly.FromDateTime(DateTime.UtcNow);

        for (int month = startMonth; month <= 12; month++)
        {
            var maxDay = DateTime.DaysInMonth(year, month);
            var day = Math.Min(dto.Recurrence.DayOfMonth, maxDay);
            var date = new DateOnly(year, month, day);

            var status = date <= today ? dto.Transaction.Status : TransactionStatus.Pending;

            transactions.Add(new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = dto.Transaction.AccountId,
                UserId = userId,
                Date = date,
                Amount = dto.Transaction.Amount,
                Note = dto.Transaction.Note,
                Status = status,
                IsAuto = dto.Transaction.IsAuto,
                CreatedAt = DateTime.UtcNow
            });
        }

        return transactions;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
