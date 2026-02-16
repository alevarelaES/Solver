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
            string? search,
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

            if (!string.IsNullOrWhiteSpace(search))
            {
                var pattern = $"%{search.Trim()}%";
                query = query.Where(t =>
                    EF.Functions.ILike(t.Account!.Name, pattern) ||
                    (t.Note != null && EF.Functions.ILike(t.Note, pattern)));
            }

            if (!showFuture)
            {
                var today = DateOnly.FromDateTime(DateTime.UtcNow);
                query = query.Where(t => t.Date <= today || t.Status == TransactionStatus.Pending);
            }

            var totalCount = await query.CountAsync();
            pageSize = Math.Clamp(pageSize, 1, 5000);
            page = Math.Max(page, 1);

            var items = await query
                .OrderByDescending(t => t.Date)
                .ThenByDescending(t => t.CreatedAt)
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

        // GET /api/transactions/upcoming — includes pending items up to limit.
        // Overdue automatic debits are excluded from upcoming (assumed already collected).
        group.MapGet("/upcoming", async (
            SolverDbContext db,
            HttpContext ctx,
            int days = 30) =>
        {
            var userId = GetUserId(ctx);
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var clampedDays = Math.Clamp(days, 1, 3650);
            var limit = today.AddDays(clampedDays);

            var upcoming = await db.Transactions
                .Where(t => t.UserId == userId
                    && t.Status == TransactionStatus.Pending
                    && t.Account!.Type == AccountType.Expense
                    && (!t.IsAuto || t.Date >= today)
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

        // GET /api/transactions/projection/yearly?year=2026
        // Returns pending expense totals by month for a full year.
        group.MapGet("/projection/yearly", async (
            SolverDbContext db,
            HttpContext ctx,
            int? year) =>
        {
            var userId = GetUserId(ctx);
            var targetYear = year ?? DateTime.UtcNow.Year;

            var yearly = await db.Transactions
                .Where(t => t.UserId == userId
                    && t.Status == TransactionStatus.Pending
                    && t.Date.Year == targetYear
                    && t.Account!.Type == AccountType.Expense)
                .Select(t => new
                {
                    month = t.Date.Month,
                    amount = t.Amount,
                    isAuto = t.IsAuto
                })
                .ToListAsync();

            var manualByMonth = Enumerable.Repeat(0m, 12).ToArray();
            var autoByMonth = Enumerable.Repeat(0m, 12).ToArray();

            foreach (var t in yearly)
            {
                var index = t.month - 1;
                if (index < 0 || index > 11) continue;
                if (t.isAuto) autoByMonth[index] += t.amount;
                else manualByMonth[index] += t.amount;
            }

            var totalByMonth = new decimal[12];
            for (var i = 0; i < 12; i++)
            {
                totalByMonth[i] = manualByMonth[i] + autoByMonth[i];
            }

            return Results.Ok(new
            {
                year = targetYear,
                manualByMonth,
                autoByMonth,
                totalByMonth
            });
        });

        group.MapPost("/", async (CreateTransactionDto dto, IServiceScopeFactory scopeFactory, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            for (var attempt = 1; attempt <= 2; attempt++)
            {
                using var scope = scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();
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
                try
                {
                    await db.SaveChangesAsync();
                    return Results.Created($"/api/transactions/{transaction.Id}", transaction);
                }
                catch (DbUpdateException ex) when (IsNpgsqlDisposedConnector(ex))
                {
                    if (attempt < 2)
                    {
                        await Task.Delay(120);
                        continue;
                    }

                    return Results.Problem(
                        title: "Erreur temporaire base de donnees",
                        detail: "Echec de creation de transaction. Reessayez dans quelques secondes.",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
            }

            return Results.Problem(
                title: "Erreur temporaire base de donnees",
                detail: "Echec de creation de transaction. Reessayez dans quelques secondes.",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        });

        group.MapPost("/batch", async (BatchTransactionDto dto, IServiceScopeFactory scopeFactory, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            using (var validationScope = scopeFactory.CreateScope())
            {
                var db = validationScope.ServiceProvider.GetRequiredService<SolverDbContext>();
                var accountExists = await db.Accounts.AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);
                if (!accountExists) return Results.NotFound(new { error = "Account not found" });
            }

            if (dto.Recurrence.EndDate.HasValue && dto.Recurrence.EndDate.Value < dto.Transaction.Date)
            {
                return Results.BadRequest(new { error = "End date must be on or after transaction date" });
            }

            var planned = RecurrenceService.Generate(dto, userId)
                .Select(t => new
                {
                    t.Id,
                    t.AccountId,
                    t.UserId,
                    t.Date,
                    t.Amount,
                    t.Note,
                    t.Status,
                    t.IsAuto,
                    t.CreatedAt,
                })
                .ToList();

            foreach (var seed in planned)
            {
                var saved = false;

                for (var attempt = 1; attempt <= 3; attempt++)
                {
                    using var scope = scopeFactory.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();

                    db.Transactions.Add(new Transaction
                    {
                        Id = seed.Id,
                        AccountId = seed.AccountId,
                        UserId = seed.UserId,
                        Date = seed.Date,
                        Amount = seed.Amount,
                        Note = seed.Note,
                        Status = seed.Status,
                        IsAuto = seed.IsAuto,
                        CreatedAt = seed.CreatedAt
                    });

                    try
                    {
                        await db.SaveChangesAsync();
                        saved = true;
                        break;
                    }
                    catch (DbUpdateException ex) when (IsNpgsqlDisposedConnector(ex))
                    {
                        if (attempt < 3)
                        {
                            await Task.Delay(120);
                            continue;
                        }

                        return Results.Problem(
                            title: "Erreur temporaire base de donnees",
                            detail: "Echec de creation des transactions recurentes. Reessayez dans quelques secondes.",
                            statusCode: StatusCodes.Status503ServiceUnavailable);
                    }
                }

                if (!saved)
                {
                    return Results.Problem(
                        title: "Erreur temporaire base de donnees",
                        detail: "Echec de creation des transactions recurentes. Reessayez dans quelques secondes.",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
            }

            return Results.Ok(new { count = planned.Count });
        });

        group.MapPost("/repayment-plan", async (RepaymentPlanDto dto, IServiceScopeFactory scopeFactory, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            using (var validationScope = scopeFactory.CreateScope())
            {
                var db = validationScope.ServiceProvider.GetRequiredService<SolverDbContext>();
                var accountExists = await db.Accounts.AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);
                if (!accountExists) return Results.NotFound(new { error = "Account not found" });
            }

            if (dto.Repayment.TotalAmount <= 0 || dto.Repayment.MonthlyAmount <= 0)
            {
                return Results.BadRequest(new { error = "TotalAmount and MonthlyAmount must be > 0" });
            }

            var planned = RecurrenceService.GenerateRepaymentPlan(dto, userId)
                .Select(t => new
                {
                    t.Id,
                    t.AccountId,
                    t.UserId,
                    t.Date,
                    t.Amount,
                    t.Note,
                    t.Status,
                    t.IsAuto,
                    t.CreatedAt,
                })
                .ToList();

            if (planned.Count == 0)
            {
                return Results.BadRequest(new { error = "No repayment transactions generated" });
            }

            foreach (var seed in planned)
            {
                var saved = false;

                for (var attempt = 1; attempt <= 3; attempt++)
                {
                    using var scope = scopeFactory.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();

                    db.Transactions.Add(new Transaction
                    {
                        Id = seed.Id,
                        AccountId = seed.AccountId,
                        UserId = seed.UserId,
                        Date = seed.Date,
                        Amount = seed.Amount,
                        Note = seed.Note,
                        Status = seed.Status,
                        IsAuto = seed.IsAuto,
                        CreatedAt = seed.CreatedAt
                    });

                    try
                    {
                        await db.SaveChangesAsync();
                        saved = true;
                        break;
                    }
                    catch (DbUpdateException ex) when (IsNpgsqlDisposedConnector(ex))
                    {
                        if (attempt < 3)
                        {
                            await Task.Delay(120);
                            continue;
                        }

                        return Results.Problem(
                            title: "Erreur temporaire base de donnees",
                            detail: "Echec de creation du plan de remboursement. Reessayez dans quelques secondes.",
                            statusCode: StatusCodes.Status503ServiceUnavailable);
                    }
                }

                if (!saved)
                {
                    return Results.Problem(
                        title: "Erreur temporaire base de donnees",
                        detail: "Echec de creation du plan de remboursement. Reessayez dans quelques secondes.",
                        statusCode: StatusCodes.Status503ServiceUnavailable);
                }
            }

            var endDate = planned[^1].Date;
            var lastAmount = planned[^1].Amount;
            var totalAmount = planned.Sum(t => t.Amount);
            return Results.Ok(new { count = planned.Count, endDate, lastAmount, totalAmount });
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

    private static bool IsNpgsqlDisposedConnector(DbUpdateException ex)
    {
        if (ex.InnerException is not ObjectDisposedException disposed) return false;
        return string.Equals(disposed.ObjectName, "System.Threading.ManualResetEventSlim", StringComparison.Ordinal)
            || string.Equals(disposed.ObjectName, "Npgsql.NpgsqlConnection", StringComparison.Ordinal);
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
