namespace Solver.Api.Models;

public class WatchlistItem
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string? Exchange { get; set; }
    public string? Name { get; set; }
    public string AssetType { get; set; } = "stock";
    public int SortOrder { get; set; }
    public DateTime CreatedAt { get; set; }
}
