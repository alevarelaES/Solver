using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class TransactionsService
{
    private const string VoidedTag = "[ANNULEE]";
    private const string ReimbursementTag = "[REMBOURSEMENT]";

    private readonly SolverDbContext _db;
    private readonly DbRetryService _dbRetry;
    private readonly IServiceScopeFactory _scopeFactory;

    public TransactionsService(
        SolverDbContext db,
        DbRetryService dbRetry,
        IServiceScopeFactory scopeFactory)
    {
        _db = db;
        _dbRetry = dbRetry;
        _scopeFactory = scopeFactory;
    }

    public async Task<IResult> GetTransactionsAsync(
        HttpContext ctx,
        Guid? accountId,
        string? status,
        int? month,
        int? year,
        string? search,
        bool showFuture = false,
        int page = 1,
        int pageSize = 50)
    {
        var userId = GetUserId(ctx);
        var query = _db.Transactions.Where(t => t.UserId == userId);

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
            .Select(t => new
            {
                id = t.Id,
                accountId = t.AccountId,
                accountName = t.Account!.Name,
                accountGroup = t.Account!.Group,
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
    }

    public async Task<IResult> GetUpcomingAsync(HttpContext ctx, int days = 30)
    {
        var userId = GetUserId(ctx);
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var clampedDays = Math.Clamp(days, 1, 3650);
        var limit = today.AddDays(clampedDays);

        var upcoming = await _db.Transactions
            .Where(t => t.UserId == userId
                && t.Status == TransactionStatus.Pending
                && t.Account!.Type == AccountType.Expense
                && (!t.IsAuto || t.Date >= today)
                && t.Date <= limit)
            .OrderBy(t => t.Date)
            .Select(t => new
            {
                id = t.Id,
                accountId = t.AccountId,
                accountName = t.Account!.Name,
                accountGroup = t.Account!.Group,
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
    }

    public async Task<IResult> GetProjectionYearlyAsync(HttpContext ctx, int? year)
    {
        var userId = GetUserId(ctx);
        var targetYear = year ?? DateTime.UtcNow.Year;

        var yearly = await _db.Transactions
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
    }

    public async Task<IResult> CreateTransactionAsync(CreateTransactionDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var accountExists = await _db.Accounts.AnyAsync(a => a.Id == dto.AccountId && a.UserId == userId);
        if (!accountExists) return Results.NotFound(new { error = "Account not found" });

        var seed = new TransactionSeed(
            Id: Guid.NewGuid(),
            AccountId: dto.AccountId,
            UserId: userId,
            Date: dto.Date,
            Amount: dto.Amount,
            Note: dto.Note,
            Status: dto.Status,
            IsAuto: dto.IsAuto,
            CreatedAt: DateTime.UtcNow);

        var saveError = await PersistSeedsWithRetryAsync(
            [seed],
            maxAttempts: 2,
            failureDetail: "Echec de creation de transaction. Reessayez dans quelques secondes.");
        if (saveError is not null) return saveError;

        var created = ToEntity(seed);
        return Results.Created($"/api/transactions/{created.Id}", created);
    }

    public async Task<IResult> CreateBatchAsync(BatchTransactionDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var accountExists = await _db.Accounts.AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);
        if (!accountExists) return Results.NotFound(new { error = "Account not found" });

        if (dto.Recurrence.EndDate.HasValue && dto.Recurrence.EndDate.Value < dto.Transaction.Date)
        {
            return Results.BadRequest(new { error = "End date must be on or after transaction date" });
        }

        var planned = RecurrenceService.Generate(dto, userId)
            .Select(ToSeed)
            .ToList();

        var saveError = await PersistSeedsWithRetryAsync(
            planned,
            maxAttempts: 3,
            failureDetail: "Echec de creation des transactions recurentes. Reessayez dans quelques secondes.");
        if (saveError is not null) return saveError;

        return Results.Ok(new { count = planned.Count });
    }

    public async Task<IResult> CreateRepaymentPlanAsync(RepaymentPlanDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var accountExists = await _db.Accounts.AnyAsync(a => a.Id == dto.Transaction.AccountId && a.UserId == userId);
        if (!accountExists) return Results.NotFound(new { error = "Account not found" });

        if (dto.Repayment.TotalAmount <= 0 || dto.Repayment.MonthlyAmount <= 0)
        {
            return Results.BadRequest(new { error = "TotalAmount and MonthlyAmount must be > 0" });
        }

        var planned = RecurrenceService.GenerateRepaymentPlan(dto, userId)
            .Select(ToSeed)
            .ToList();

        if (planned.Count == 0)
        {
            return Results.BadRequest(new { error = "No repayment transactions generated" });
        }

        var saveError = await PersistSeedsWithRetryAsync(
            planned,
            maxAttempts: 3,
            failureDetail: "Echec de creation du plan de remboursement. Reessayez dans quelques secondes.");
        if (saveError is not null) return saveError;

        var endDate = planned[^1].Date;
        var lastAmount = planned[^1].Amount;
        var totalAmount = planned.Sum(t => t.Amount);
        return Results.Ok(new { count = planned.Count, endDate, lastAmount, totalAmount });
    }

    public async Task<IResult> UpdateTransactionAsync(Guid id, UpdateTransactionDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var transaction = await _db.Transactions.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
        if (transaction is null) return Results.NotFound();

        transaction.Date = dto.Date;
        transaction.Amount = dto.Amount;
        transaction.Note = dto.Note;
        transaction.Status = dto.Status;
        transaction.IsAuto = dto.IsAuto;

        await _db.SaveChangesAsync();
        return Results.Ok(transaction);
    }

    public async Task<IResult> DeleteTransactionAsync(Guid id, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var transaction = await _db.Transactions.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
        if (transaction is null) return Results.NotFound();

        _db.Transactions.Remove(transaction);
        await _db.SaveChangesAsync();
        return Results.NoContent();
    }

    public async Task<IResult> ReverseTransactionAsync(Guid id, ReverseTransactionDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var reason = string.IsNullOrWhiteSpace(dto.Reason) ? null : dto.Reason.Trim();
        var reversalDate = dto.Date ?? DateOnly.FromDateTime(DateTime.UtcNow);

        Guid newReimbursementId = default;
        var retry = await _dbRetry.ExecuteAsync(
            _scopeFactory,
            async db =>
            {
                var transaction = await db.Transactions
                    .Include(t => t.Account)
                    .FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
                if (transaction is null) return (byte)1; // NotFound

                if (HasTag(transaction.Note, VoidedTag))
                    return (byte)2; // Already voided
                if (HasTag(transaction.Note, ReimbursementTag))
                    return (byte)3; // Cannot void reimbursement

                var absOriginal = Math.Abs(transaction.Amount);
                var sign = transaction.Amount >= 0 ? 1 : -1;
                var sourceLabel = BuildSourceLabel(transaction);

                var refundAmount = dto.Amount.HasValue
                    ? Math.Min(dto.Amount.Value, absOriginal)
                    : absOriginal;

                bool isPartial = refundAmount < absOriginal;

                if (isPartial)
                {
                    // Partial refund: reduce original amount, keep it active (not voided)
                    transaction.Amount -= refundAmount * sign;
                }
                else
                {
                    // Full reversal: void the original transaction
                    transaction.Note = BuildVoidedNote(transaction.Note, reason, reversalDate);
                    transaction.Status = TransactionStatus.Completed;
                    transaction.IsAuto = false;
                }

                var reimbursementAmount = -sign * refundAmount;

                var reimbursement = new Transaction
                {
                    Id = Guid.NewGuid(),
                    AccountId = transaction.AccountId,
                    UserId = userId,
                    Date = reversalDate,
                    Amount = reimbursementAmount,
                    Note = BuildReimbursementNote(sourceLabel, reason),
                    Status = TransactionStatus.Completed,
                    IsAuto = false,
                    CreatedAt = DateTime.UtcNow,
                };
                db.Transactions.Add(reimbursement);

                await db.SaveChangesAsync();
                newReimbursementId = reimbursement.Id;
                return (byte)0; // Success
            },
            maxAttempts: 3);

        if (!retry.Succeeded)
        {
            return Results.Problem(
                title: "Erreur temporaire base de donnees",
                detail: "Impossible d'annuler la transaction. Veuillez reessayer.",
                statusCode: StatusCodes.Status503ServiceUnavailable);
        }

        return retry.Value switch
        {
            1 => Results.NotFound(),
            2 => Results.BadRequest(new { error = "Transaction already voided." }),
            3 => Results.BadRequest(new { error = "Cannot void a reimbursement transaction." }),
            _ => Results.Ok(new { voidedId = id, reimbursementId = newReimbursementId }),
        };
    }

    private async Task<IResult?> PersistSeedsWithRetryAsync(
        IReadOnlyCollection<TransactionSeed> seeds,
        int maxAttempts,
        string failureDetail)
    {
        if (seeds.Count == 0) return null;

        var retry = await _dbRetry.ExecuteAsync(
            _scopeFactory,
            async db =>
            {
                db.Transactions.AddRange(seeds.Select(ToEntity));
                await db.SaveChangesAsync();
                return true;
            },
            maxAttempts: maxAttempts);

        if (retry.Succeeded) return null;
        return Results.Problem(
            title: "Erreur temporaire base de donnees",
            detail: failureDetail,
            statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    private static TransactionSeed ToSeed(Transaction transaction) =>
        new(
            transaction.Id,
            transaction.AccountId,
            transaction.UserId,
            transaction.Date,
            transaction.Amount,
            transaction.Note,
            transaction.Status,
            transaction.IsAuto,
            transaction.CreatedAt);

    private static Transaction ToEntity(TransactionSeed seed) =>
        new()
        {
            Id = seed.Id,
            AccountId = seed.AccountId,
            UserId = seed.UserId,
            Date = seed.Date,
            Amount = seed.Amount,
            Note = seed.Note,
            Status = seed.Status,
            IsAuto = seed.IsAuto,
            CreatedAt = seed.CreatedAt,
        };

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;

    private static bool HasTag(string? note, string tag)
    {
        if (string.IsNullOrWhiteSpace(note)) return false;
        return note.TrimStart().StartsWith(tag, StringComparison.OrdinalIgnoreCase);
    }

    private static string BuildSourceLabel(Transaction tx)
    {
        var cleaned = StripSystemTag(tx.Note);
        if (!string.IsNullOrWhiteSpace(cleaned)) return cleaned;
        if (tx.Account is not null && !string.IsNullOrWhiteSpace(tx.Account.Name))
        {
            return tx.Account.Name.Trim();
        }
        return tx.Id.ToString()[..8].ToUpperInvariant();
    }

    private static string BuildVoidedNote(
        string? note,
        string? reason,
        DateOnly date)
    {
        var cleaned = StripSystemTag(note);
        var baseText = string.IsNullOrWhiteSpace(cleaned)
            ? $"{VoidedTag} annulation {date:yyyy-MM-dd}"
            : $"{VoidedTag} {cleaned}";

        if (string.IsNullOrWhiteSpace(reason))
        {
            return TrimToMaxNote(baseText);
        }

        return TrimToMaxNote($"{baseText} - {reason}");
    }

    private static string BuildReimbursementNote(
        string sourceLabel,
        string? reason)
    {
        var note = $"{ReimbursementTag} correction {sourceLabel}";
        if (!string.IsNullOrWhiteSpace(reason))
        {
            note = $"{note} - {reason}";
        }
        return TrimToMaxNote(note);
    }

    private static string StripSystemTag(string? note)
    {
        if (string.IsNullOrWhiteSpace(note)) return string.Empty;
        var cleaned = note.Trim();
        if (HasTag(cleaned, VoidedTag))
        {
            cleaned = cleaned[VoidedTag.Length..].TrimStart();
        }
        if (HasTag(cleaned, ReimbursementTag))
        {
            cleaned = cleaned[ReimbursementTag.Length..].TrimStart();
        }
        return cleaned;
    }

    private static string TrimToMaxNote(string value) =>
        value.Length <= 500 ? value : value[..500];

    private sealed record TransactionSeed(
        Guid Id,
        Guid AccountId,
        Guid UserId,
        DateOnly Date,
        decimal Amount,
        string? Note,
        TransactionStatus Status,
        bool IsAuto,
        DateTime CreatedAt);
}
