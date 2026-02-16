namespace Solver.Api.Models;

public class BudgetPlanMonth
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public int Year { get; set; }
    public int Month { get; set; }
    public decimal ForecastDisposableIncome { get; set; }
    public bool UseGrossIncomeBase { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<BudgetPlanGroupAllocation> GroupAllocations { get; set; } = [];
}
