using Solver.Api.DTOs;
using Solver.Api.Models;
using Solver.Api.Services;

namespace Solver.Tests;

public class RecurrenceServiceTests
{
    private static readonly Guid UserId = Guid.NewGuid();
    private static readonly Guid AccountId = Guid.NewGuid();

    private static BatchTransactionDto MakeDto(
        int year, int month, int dayOfMonth, decimal amount = 100m,
        string? note = "Test", TransactionStatus status = TransactionStatus.Completed,
        bool isAuto = true)
    {
        var tx = new CreateTransactionDto(
            AccountId,
            new DateOnly(year, month, 1),
            amount,
            note,
            status,
            isAuto);
        var recurrence = new RecurrenceOptionsDto(dayOfMonth);
        return new BatchTransactionDto(tx, recurrence);
    }

    private static RepaymentPlanDto MakeRepaymentDto(
        int year,
        int month,
        int day,
        decimal totalAmount,
        decimal monthlyAmount,
        TransactionStatus status = TransactionStatus.Pending,
        bool isAuto = false,
        string? note = "Remboursement"
    )
    {
        var tx = new CreateTransactionDto(
            AccountId,
            new DateOnly(year, month, day),
            monthlyAmount,
            note,
            status,
            isAuto
        );
        var repayment = new RepaymentOptionsDto(totalAmount, monthlyAmount);
        return new RepaymentPlanDto(tx, repayment);
    }

    [Fact]
    public void Generate_CorrectCount_FromStartMonthToDecember()
    {
        var dto = MakeDto(2026, 3, 15); // March → December = 10 months
        var today = new DateOnly(2026, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        Assert.Equal(10, result.Count);
        Assert.Equal(3, result.First().Date.Month);
        Assert.Equal(12, result.Last().Date.Month);
    }

    [Fact]
    public void Generate_February28_NonLeapYear_ClampsDayOfMonth()
    {
        var dto = MakeDto(2025, 1, 31); // 2025 is not a leap year
        var today = new DateOnly(2025, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        var feb = result.First(t => t.Date.Month == 2);
        Assert.Equal(28, feb.Date.Day);
    }

    [Fact]
    public void Generate_February29_LeapYear()
    {
        var dto = MakeDto(2028, 1, 29); // 2028 is a leap year
        var today = new DateOnly(2028, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        var feb = result.First(t => t.Date.Month == 2);
        Assert.Equal(29, feb.Date.Day);
    }

    [Fact]
    public void Generate_30DayMonth_ClampsDayOfMonth31()
    {
        var dto = MakeDto(2026, 4, 31); // April has 30 days
        var today = new DateOnly(2026, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        var april = result.First(t => t.Date.Month == 4);
        Assert.Equal(30, april.Date.Day);

        var june = result.First(t => t.Date.Month == 6);
        Assert.Equal(30, june.Date.Day);
    }

    [Fact]
    public void Generate_StatusDependsOnDate_PastCompleted_FuturePending()
    {
        var dto = MakeDto(2026, 1, 15, status: TransactionStatus.Completed);
        var today = new DateOnly(2026, 6, 20);

        var result = RecurrenceService.Generate(dto, UserId, today);

        // Jan–Jun should be completed (date <= today)
        Assert.All(result.Where(t => t.Date <= today), t =>
            Assert.Equal(TransactionStatus.Completed, t.Status));

        // Jul–Dec should be pending
        Assert.All(result.Where(t => t.Date > today), t =>
            Assert.Equal(TransactionStatus.Pending, t.Status));
    }

    [Fact]
    public void Generate_AutoPendingCreatedAfterDueDay_StartsNextOccurrence()
    {
        var dto = new BatchTransactionDto(
            new CreateTransactionDto(
                AccountId,
                new DateOnly(2026, 2, 1),
                120m,
                "Auto debit",
                TransactionStatus.Pending,
                true
            ),
            new RecurrenceOptionsDto(12)
        );
        var today = new DateOnly(2026, 2, 14);

        var result = RecurrenceService.Generate(dto, UserId, today);

        Assert.NotEmpty(result);
        Assert.Equal(new DateOnly(2026, 3, 12), result[0].Date);
        Assert.DoesNotContain(result, t => t.Date == new DateOnly(2026, 2, 12));
    }

    [Fact]
    public void Generate_StartMonth12_OnlyOneTransaction()
    {
        var dto = MakeDto(2026, 12, 15);
        var today = new DateOnly(2026, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        Assert.Single(result);
        Assert.Equal(12, result[0].Date.Month);
    }

    [Fact]
    public void Generate_DayOfMonth1_WorksForAll12Months()
    {
        var dto = MakeDto(2026, 1, 1);
        var today = new DateOnly(2026, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        Assert.Equal(12, result.Count);
        Assert.All(result, t => Assert.Equal(1, t.Date.Day));
    }

    [Fact]
    public void Generate_FieldsPropagatedCorrectly()
    {
        var dto = MakeDto(2026, 6, 10, amount: 1500.50m, note: "Salary", isAuto: true);
        var today = new DateOnly(2026, 12, 31);

        var result = RecurrenceService.Generate(dto, UserId, today);

        Assert.All(result, t =>
        {
            Assert.Equal(AccountId, t.AccountId);
            Assert.Equal(UserId, t.UserId);
            Assert.Equal(1500.50m, t.Amount);
            Assert.Equal("Salary", t.Note);
            Assert.True(t.IsAuto);
            Assert.NotEqual(Guid.Empty, t.Id);
        });
    }

    [Fact]
    public void GenerateRepaymentPlan_1000_By300_Creates4Installments()
    {
        var dto = MakeRepaymentDto(2026, 2, 10, totalAmount: 1000m, monthlyAmount: 300m);
        var today = new DateOnly(2026, 1, 1);

        var result = RecurrenceService.GenerateRepaymentPlan(dto, UserId, today);

        Assert.Equal(4, result.Count);
        Assert.Equal(300m, result[0].Amount);
        Assert.Equal(300m, result[1].Amount);
        Assert.Equal(300m, result[2].Amount);
        Assert.Equal(100m, result[3].Amount);
        Assert.Equal(new DateOnly(2026, 5, 10), result[3].Date);
    }

    [Fact]
    public void GenerateRepaymentPlan_FutureDates_ArePending()
    {
        var dto = MakeRepaymentDto(
            2026,
            6,
            14,
            totalAmount: 600m,
            monthlyAmount: 200m,
            status: TransactionStatus.Completed
        );
        var today = new DateOnly(2026, 6, 20);

        var result = RecurrenceService.GenerateRepaymentPlan(dto, UserId, today);

        Assert.Equal(TransactionStatus.Completed, result[0].Status);
        Assert.Equal(TransactionStatus.Pending, result[1].Status);
        Assert.Equal(TransactionStatus.Pending, result[2].Status);
    }
}
