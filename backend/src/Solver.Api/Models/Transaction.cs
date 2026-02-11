namespace Solver.Api.Models;

public class Transaction
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public Guid UserId { get; set; }
    public DateOnly Date { get; set; }
    public decimal Amount { get; set; }
    public string? Note { get; set; }
    public TransactionStatus Status { get; set; }
    public bool IsAuto { get; set; }
    public DateTime CreatedAt { get; set; }

    public Account Account { get; set; } = null!;
}

public enum TransactionStatus
{
    Completed,
    Pending
}
