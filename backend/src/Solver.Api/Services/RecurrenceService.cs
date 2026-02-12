using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Services;

public static class RecurrenceService
{
    public static List<Transaction> Generate(BatchTransactionDto dto, Guid userId)
    {
        return Generate(dto, userId, DateOnly.FromDateTime(DateTime.UtcNow));
    }

    public static List<Transaction> Generate(BatchTransactionDto dto, Guid userId, DateOnly today)
    {
        var transactions = new List<Transaction>();
        var startMonth = dto.Transaction.Date.Month;
        var year = dto.Transaction.Date.Year;

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
}
