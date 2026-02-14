namespace Solver.Api.Models;

public class CategoryPreference
{
    public Guid AccountId { get; set; }
    public Guid UserId { get; set; }
    public int SortOrder { get; set; }
    public bool IsArchived { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Account Account { get; set; } = null!;
}
