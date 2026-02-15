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
        var startDate = dto.Transaction.Date;

        // If an automatic pending recurrence is created after its day of month,
        // start from today so we do not create an immediately overdue instance.
        if (dto.Transaction.IsAuto
            && dto.Transaction.Status == TransactionStatus.Pending
            && startDate < today)
        {
            startDate = today;
        }

        var endDate = dto.Recurrence.EndDate ?? new DateOnly(startDate.Year, 12, 31);

        if (endDate < startDate) return transactions;

        var cursorYear = startDate.Year;
        var cursorMonth = startDate.Month;
        var safety = 0;

        while (safety++ < 120)
        {
            var maxDay = DateTime.DaysInMonth(cursorYear, cursorMonth);
            var day = Math.Min(dto.Recurrence.DayOfMonth, maxDay);
            var date = new DateOnly(cursorYear, cursorMonth, day);

            if (date > endDate) break;
            if (date < startDate)
            {
                IncrementMonth(ref cursorYear, ref cursorMonth);
                continue;
            }

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

            IncrementMonth(ref cursorYear, ref cursorMonth);
        }

        return transactions;
    }

    public static List<Transaction> GenerateRepaymentPlan(RepaymentPlanDto dto, Guid userId)
    {
        return GenerateRepaymentPlan(dto, userId, DateOnly.FromDateTime(DateTime.UtcNow));
    }

    public static List<Transaction> GenerateRepaymentPlan(RepaymentPlanDto dto, Guid userId, DateOnly today)
    {
        var transactions = new List<Transaction>();
        var startDate = dto.Transaction.Date;
        var remaining = decimal.Round(dto.Repayment.TotalAmount, 2, MidpointRounding.AwayFromZero);
        var monthlyAmount = decimal.Round(dto.Repayment.MonthlyAmount, 2, MidpointRounding.AwayFromZero);

        if (remaining <= 0m || monthlyAmount <= 0m)
        {
            return transactions;
        }

        var cursorYear = startDate.Year;
        var cursorMonth = startDate.Month;
        var safety = 0;

        while (remaining > 0m && safety++ < 240)
        {
            var maxDay = DateTime.DaysInMonth(cursorYear, cursorMonth);
            var day = Math.Min(startDate.Day, maxDay);
            var date = new DateOnly(cursorYear, cursorMonth, day);
            var installment = decimal.Min(remaining, monthlyAmount);
            var status = date <= today ? dto.Transaction.Status : TransactionStatus.Pending;

            transactions.Add(new Transaction
            {
                Id = Guid.NewGuid(),
                AccountId = dto.Transaction.AccountId,
                UserId = userId,
                Date = date,
                Amount = installment,
                Note = dto.Transaction.Note,
                Status = status,
                IsAuto = dto.Transaction.IsAuto,
                CreatedAt = DateTime.UtcNow
            });

            remaining = decimal.Round(remaining - installment, 2, MidpointRounding.AwayFromZero);
            IncrementMonth(ref cursorYear, ref cursorMonth);
        }

        return transactions;
    }

    private static void IncrementMonth(ref int year, ref int month)
    {
        month++;
        if (month <= 12) return;
        month = 1;
        year++;
    }
}
