namespace Solver.Api.Models;

public class SavingGoal
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public SavingGoalType GoalType { get; set; } = SavingGoalType.Savings;
    public decimal TargetAmount { get; set; }
    public DateOnly TargetDate { get; set; }
    public decimal InitialAmount { get; set; }
    public decimal MonthlyContribution { get; set; }
    public int Priority { get; set; }
    public bool IsArchived { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<SavingGoalEntry> Entries { get; set; } = [];
}

public enum SavingGoalType
{
    Savings,
    Debt
}
