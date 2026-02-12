using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;
using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class TransactionsEndpoints
{
    public static void MapTransactionsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/transactions");

        // GET /api/transactions — paginated, includes accountName/accountType
        group.MapGet("/", async (
            SolverDbContext db,
            HttpContext ctx,
            Guid? accountId,
            string? status,
            int? month,
            int? year,
            bool showFuture = false,
            int page = 1,
            int pageSize = 50) =>
        {
            var userId = GetUserId(ctx);
            var query = db.Transactions.Where(t => t.UserId == userId);

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

            var totalCount = await query.CountAsync();
            pageSize = Math.Clamp(pageSize, 1, 100);
            page = Math.Max(page, 1);

            var items = await query
                .OrderByDescending(t => t.Date)
                .ThenBy(t => t.Id)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(t => new {
                    id = t.Id,
                    accountId = t.AccountId,
                    accountName = t.Account!.Name,
                    accountType = t.Account!.Type == AccountType.Income ? "income" : "expense",
                    userId = t.UserId,
                    date = t.Date,
                    amount = t.Amount,
                    note = t.Note,
                    status = t.Status == TransactionStatus.Completed ? "completed" : "pending",
                    isAuto = t.IsAuto
                })
                .ToListAsync();

            return Results.Ok(new { items, totalCount, page, pageSize });
        });

        // GET /api/transactions/upcoming — before /{id:guid} to avoid route conflict
        group.MapGet("/upcoming", async (
            SolverDbContext db,
            HttpContext ctx,
            int days = 30) =>
        {
            var userId = GetUserId(ctx);
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var limit = today.AddDays(Math.Min(days, 90));

            var upcoming = await db.Transactions
                .Where(t => t.UserId == userId
                    && t.Status == TransactionStatus.Pending
                    && t.Date >= today
                    && t.Date <= limit)
                .OrderBy(t => t.Date)
                .Select(t => new {
                    id = t.Id,
                    accountId = t.AccountId,
                    accountName = t.Account!.Name,
                    accountType = t.Account!.Type == AccountType.Income ? "income" : "expense",
                    userId = t.UserId,
                    date = t.Date,
                    amount = t.Amount,
                    note = t.Note,
                    status = "pending",
                    isAuto = t.IsAuto
                })
                .ToListAsync();

            var auto = upcoming.Where(t => t.isAuto).ToList();
            var manual = upcoming.Where(t => !t.isAuto).ToList();
            var totalAuto = auto.Sum(t => t.amount);
            var totalManual = manual.Sum(t => t.amount);

            return Results.Ok(new { auto, manual, totalAuto, totalManual, grandTotal = totalAuto + totalManual });
        });

        group.MapPost("/", async (CreateTransactionDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var accountExists = await db.Accounts.AnyAsync(a => a.Id == dto.AccountId && a.UserId == userId);
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
            var accountExists = await db.Accounts.AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);
            if (!accountExists) return Results.NotFound(new { error = "Account not found" });

            var transactions = RecurrenceService.Generate(dto, userId);
            await db.Transactions.AddRangeAsync(transactions);
            await db.SaveChangesAsync();
            return Results.Ok(new { count = transactions.Count });
        });

        group.MapPut("/{id:guid}", async (Guid id, UpdateTransactionDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var transaction = await db.Transactions.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
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
            var transaction = await db.Transactions.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
            if (transaction is null) return Results.NotFound();

            db.Transactions.Remove(transaction);
            await db.SaveChangesAsync();
            return Results.NoContent();
        });
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
