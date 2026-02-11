namespace Solver.Api.Models;

public class Account
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public AccountType Type { get; set; }
    public string Group { get; set; } = string.Empty;
    public bool IsFixed { get; set; }
    public decimal Budget { get; set; }
    public DateTime CreatedAt { get; set; }

    public ICollection<Transaction> Transactions { get; set; } = [];
}

public enum AccountType
{
    Income,
    Expense
}
