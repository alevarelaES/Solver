using System.ComponentModel.DataAnnotations;
using Solver.Api.Models;

namespace Solver.Api.DTOs;

public record CreateTransactionDto(
    [Required] Guid AccountId,
    [Required] DateOnly Date,
    [Range(0.01, 10_000_000)] decimal Amount,
    [MaxLength(500)][NoHtmlTags] string? Note,
    [Required] TransactionStatus Status,
    bool IsAuto
);

public record UpdateTransactionDto(
    [Required] DateOnly Date,
    [Range(0.01, 10_000_000)] decimal Amount,
    [MaxLength(500)][NoHtmlTags] string? Note,
    [Required] TransactionStatus Status,
    bool IsAuto
);

public record BatchTransactionDto(
    [Required] CreateTransactionDto Transaction,
    [Required] RecurrenceOptionsDto Recurrence
);

public record RepaymentPlanDto(
    [Required] CreateTransactionDto Transaction,
    [Required] RepaymentOptionsDto Repayment
);

public record RecurrenceOptionsDto(
    [Range(1, 31)] int DayOfMonth,
    DateOnly? EndDate = null
);

public record RepaymentOptionsDto(
    [Range(0.01, 10_000_000)] decimal TotalAmount,
    [Range(0.01, 10_000_000)] decimal MonthlyAmount
);

public record TransactionItemDto(
    Guid Id,
    Guid AccountId,
    string AccountName,
    string AccountType,
    Guid UserId,
    DateOnly Date,
    decimal Amount,
    string? Note,
    string Status,
    bool IsAuto
);
