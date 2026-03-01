namespace Solver.Api.Models;

public class BudgetPlanTemplate
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public decimal ForecastDisposableIncome { get; set; }
    public bool UseGrossIncomeBase { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<BudgetPlanTemplateGroupAllocation> GroupAllocations { get; set; } = [];
}
