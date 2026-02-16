using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;
using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class WatchlistEndpoints
{
    public static void MapWatchlistEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/watchlist");

        group.MapGet("/", GetWatchlistAsync);
        group.MapPost("/", AddToWatchlistAsync);
        group.MapDelete("/{id:guid}", RemoveFromWatchlistAsync);
        group.MapPut("/reorder", ReorderWatchlistAsync);
    }

    private static async Task<IResult> GetWatchlistAsync(
        SolverDbContext db,
        TwelveDataService twelveData,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        var items = await db.WatchlistItems
            .Where(w => w.UserId == userId)
            .OrderBy(w => w.SortOrder)
            .ToListAsync();

        if (items.Count == 0)
            return Results.Ok(new { items = Array.Empty<object>() });

        var symbols = items.Select(w => w.Symbol).Distinct();
        var quotes = await twelveData.GetQuotesAsync(symbols);

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

    private static async Task<IResult> AddToWatchlistAsync(
        AddWatchlistDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        if (string.IsNullOrWhiteSpace(dto.Symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var symbol = dto.Symbol.Trim().ToUpperInvariant();

        var existing = await db.WatchlistItems
            .AnyAsync(w => w.UserId == userId && w.Symbol == symbol);
        if (existing)
            return Results.Conflict(new { error = $"{symbol} is already in your watchlist." });

        var maxOrder = await db.WatchlistItems
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

        db.WatchlistItems.Add(item);
        await db.SaveChangesAsync();

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

    private static async Task<IResult> RemoveFromWatchlistAsync(
        Guid id,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var item = await db.WatchlistItems
            .FirstOrDefaultAsync(w => w.Id == id && w.UserId == userId);
        if (item is null) return Results.NotFound();

        db.WatchlistItems.Remove(item);
        await db.SaveChangesAsync();
        return Results.NoContent();
    }

    private static async Task<IResult> ReorderWatchlistAsync(
        ReorderDto dto,
        SolverDbContext db,
        HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        if (dto.Order == null || dto.Order.Count == 0)
            return Results.BadRequest(new { error = "Order list is required." });

        var items = await db.WatchlistItems
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

        await db.SaveChangesAsync();
        return Results.Ok(new { reordered = true });
    }

    private static string ValidateAssetType(string? assetType)
    {
        var normalized = (assetType ?? "stock").Trim().ToLowerInvariant();
        return normalized switch
        {
            "stock" or "etf" or "crypto" or "forex" => normalized,
            _ => "stock"
        };
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;

    public sealed record AddWatchlistDto(
        string Symbol,
        string? Exchange,
        string? Name,
        string? AssetType);

    public sealed record ReorderDto(List<Guid>? Order);
}
