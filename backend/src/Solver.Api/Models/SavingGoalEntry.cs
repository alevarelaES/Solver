namespace Solver.Api.Models;

public class SavingGoalEntry
{
    public Guid Id { get; set; }
    public Guid GoalId { get; set; }
    public Guid UserId { get; set; }
    public DateOnly EntryDate { get; set; }
    public decimal Amount { get; set; } // positive deposit, negative withdrawal
    public string? Note { get; set; }
    public bool IsAuto { get; set; }
    public DateTime CreatedAt { get; set; }

    public SavingGoal Goal { get; set; } = null!;
}

