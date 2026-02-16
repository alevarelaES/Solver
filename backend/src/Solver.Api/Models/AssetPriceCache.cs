namespace Solver.Api.Models;

public class AssetPriceCache
{
    public string Symbol { get; set; } = string.Empty;
    public string? Exchange { get; set; }
    public decimal Price { get; set; }
    public decimal? PreviousClose { get; set; }
    public decimal? ChangePercent { get; set; }
    public string Currency { get; set; } = "USD";
    public DateTime FetchedAt { get; set; }
}
