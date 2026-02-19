using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class WatchlistService
{
    private readonly SolverDbContext _db;
    private readonly TwelveDataService _twelveData;

    public WatchlistService(SolverDbContext db, TwelveDataService twelveData)
    {
        _db = db;
        _twelveData = twelveData;
    }

    public async Task<IResult> GetWatchlistAsync(HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        var items = await _db.WatchlistItems
            .Where(w => w.UserId == userId)
            .OrderBy(w => w.SortOrder)
            .ToListAsync();

        if (items.Count == 0)
            return Results.Ok(new { items = Array.Empty<object>() });

        var symbols = items.Select(w => w.Symbol).Distinct();
        var quotes = await _twelveData.GetQuotesAsync(symbols);

        var payload = items.Select(w =>
        {
            quotes.TryGetValue(w.Symbol, out var quote);
            return new
            {
                id = w.Id,
                symbol = w.Symbol,
                name = w.Name,
                exchange = w.Exchange,
                assetType = w.AssetType,
                sortOrder = w.SortOrder,
                currentPrice = quote?.Price,
                changePercent = quote?.ChangePercent,
                currency = quote?.Currency ?? "USD",
                isStale = quote?.IsStale ?? false,
                createdAt = w.CreatedAt,
            };
        });

        return Results.Ok(new { items = payload });
    }

    public async Task<IResult> AddToWatchlistAsync(WatchlistEndpoints.AddWatchlistDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        if (string.IsNullOrWhiteSpace(dto.Symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var symbol = dto.Symbol.Trim().ToUpperInvariant();

        var existing = await _db.WatchlistItems
            .AnyAsync(w => w.UserId == userId && w.Symbol == symbol);
        if (existing)
            return Results.Conflict(new { error = $"{symbol} is already in your watchlist." });

        var maxOrder = await _db.WatchlistItems
            .Where(w => w.UserId == userId)
            .Select(w => (int?)w.SortOrder)
            .MaxAsync() ?? -1;

        var item = new WatchlistItem
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Symbol = symbol,
            Exchange = dto.Exchange?.Trim(),
            Name = dto.Name?.Trim(),
            AssetType = ValidateAssetType(dto.AssetType),
            SortOrder = maxOrder + 1,
            CreatedAt = DateTime.UtcNow,
        };

        _db.WatchlistItems.Add(item);
        await _db.SaveChangesAsync();

        return Results.Created($"/api/watchlist/{item.Id}", new
        {
            id = item.Id,
            symbol = item.Symbol,
            name = item.Name,
            exchange = item.Exchange,
            assetType = item.AssetType,
            sortOrder = item.SortOrder,
            createdAt = item.CreatedAt,
        });
    }

    public async Task<IResult> RemoveFromWatchlistAsync(Guid id, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var item = await _db.WatchlistItems
            .FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId);
        if (item is null) return Results.NotFound();

        _db.WatchlistItems.Remove(item);
        await _db.SaveChangesAsync();
        return Results.NoContent();
    }

    public async Task<IResult> ReorderWatchlistAsync(WatchlistEndpoints.ReorderDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        if (dto.Order == null || dto.Order.Count == 0)
            return Results.BadRequest(new { error = "Order list is required." });

        var items = await _db.WatchlistItems
            .Where(w => w.UserId == userId)
            .ToListAsync();

        var orderMap = dto.Order
            .Select((id, idx) => (id, idx))
            .ToDictionary(x => x.id, x => x.idx);

        foreach (var item in items)
        {
            if (orderMap.TryGetValue(item.Id, out var newOrder))
                item.SortOrder = newOrder;
        }

        await _db.SaveChangesAsync();
        return Results.Ok(new { reordered = true });
    }

    private static string ValidateAssetType(string? assetType)
    {
        var normalized = (assetType ?? "stock").Trim();
        if (string.Equals(normalized, "etf", StringComparison.OrdinalIgnoreCase))
            return "etf";
        if (string.Equals(normalized, "crypto", StringComparison.OrdinalIgnoreCase))
            return "crypto";
        if (string.Equals(normalized, "forex", StringComparison.OrdinalIgnoreCase))
            return "forex";
        return "stock";
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
