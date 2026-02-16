namespace Solver.Api.Models;

public class PortfolioHolding
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Symbol { get; set; } = string.Empty;
    public string? Exchange { get; set; }
    public string? Name { get; set; }
    public string AssetType { get; set; } = "stock";
    public decimal Quantity { get; set; }
    public decimal? AverageBuyPrice { get; set; }
    public DateOnly? BuyDate { get; set; }
    public string Currency { get; set; } = "USD";
    public string? Notes { get; set; }
    public bool IsArchived { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
