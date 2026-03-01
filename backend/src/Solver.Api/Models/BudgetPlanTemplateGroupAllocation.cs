namespace Solver.Api.Models;

public class BudgetPlanTemplateGroupAllocation
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid TemplateId { get; set; }
    public Guid GroupId { get; set; }
    public string InputMode { get; set; } = "percent"; // percent | amount
    public decimal PlannedPercent { get; set; }
    public decimal PlannedAmount { get; set; }
    public int Priority { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public BudgetPlanTemplate Template { get; set; } = null!;
    public CategoryGroup Group { get; set; } = null!;
}
