using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class PortfolioService
{
    private readonly SolverDbContext _db;
    private readonly TwelveDataService _twelveData;

    public PortfolioService(SolverDbContext db, TwelveDataService twelveData)
    {
        _db = db;
        _twelveData = twelveData;
    }

    public async Task<IResult> GetPortfolioAsync(HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        var holdings = await _db.PortfolioHoldings
            .Where(h => h.UserId == userId && !h.IsArchived)
            .OrderBy(h => h.CreatedAt)
            .ToListAsync();

        if (holdings.Count == 0)
            return Results.Ok(new { holdings = Array.Empty<object>(), summary = EmptySummary() });

        var symbols = holdings.Select(h => h.Symbol).Distinct();
        var quotes = await _twelveData.GetQuotesAsync(symbols);

        var holdingPayloads = holdings.Select(h =>
        {
            quotes.TryGetValue(h.Symbol, out var quote);
            return ToHoldingPayload(h, quote);
        }).ToList();

        var totalValue = holdingPayloads.Sum(h => (decimal)(h.totalValue ?? 0m));
        var totalInvested = holdings
            .Where(h => h.AverageBuyPrice.HasValue)
            .Sum(h => h.Quantity * h.AverageBuyPrice!.Value);
        var totalGainLoss = totalInvested > 0 ? totalValue - totalInvested : 0m;
        var totalGainLossPercent = totalInvested > 0
            ? Math.Round(totalGainLoss / totalInvested * 100m, 2)
            : 0m;

        return Results.Ok(new
        {
            holdings = holdingPayloads,
            summary = new
            {
                totalValue = Math.Round(totalValue, 2),
                totalInvested = Math.Round(totalInvested, 2),
                totalGainLoss = Math.Round(totalGainLoss, 2),
                totalGainLossPercent,
                holdingsCount = holdings.Count
            }
        });
    }

    public async Task<IResult> CreateHoldingAsync(PortfolioEndpoints.CreateHoldingDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        if (string.IsNullOrWhiteSpace(dto.Symbol))
            return Results.BadRequest(new { error = "Symbol is required." });
        if (dto.Quantity <= 0)
            return Results.BadRequest(new { error = "Quantity must be > 0." });

        var symbol = dto.Symbol.Trim().ToUpperInvariant();

        var existing = await _db.PortfolioHoldings
            .FirstOrDefaultAsync(h => h.UserId == userId && h.Symbol == symbol && !h.IsArchived);
        if (existing != null)
            return Results.Conflict(new { error = $"Active holding for {symbol} already exists. Update it instead." });

        var now = DateTime.UtcNow;
        var holding = new PortfolioHolding
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Symbol = symbol,
            Exchange = dto.Exchange?.Trim(),
            Name = dto.Name?.Trim(),
            AssetType = ValidateAssetType(dto.AssetType),
            Quantity = dto.Quantity,
            AverageBuyPrice = dto.AverageBuyPrice,
            BuyDate = dto.BuyDate,
            Currency = string.IsNullOrWhiteSpace(dto.Currency) ? "USD" : dto.Currency.Trim().ToUpperInvariant(),
            Notes = dto.Notes?.Trim(),
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
        };

        _db.PortfolioHoldings.Add(holding);
        await _db.SaveChangesAsync();

        return Results.Created($"/api/portfolio/{holding.Id}", ToHoldingPayload(holding, null));
    }

    public async Task<IResult> UpdateHoldingAsync(Guid id, PortfolioEndpoints.UpdateHoldingDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var holding = await _db.PortfolioHoldings
            .FirstOrDefaultAsync(h => h.Id == id && h.UserId == userId);
        if (holding is null) return Results.NotFound();

        if (dto.Quantity <= 0)
            return Results.BadRequest(new { error = "Quantity must be > 0." });

        holding.Quantity = dto.Quantity;
        holding.AverageBuyPrice = dto.AverageBuyPrice;
        holding.BuyDate = dto.BuyDate;
        holding.Notes = dto.Notes?.Trim();
        holding.Name = dto.Name?.Trim() ?? holding.Name;
        holding.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Results.Ok(ToHoldingPayload(holding, null));
    }

    public async Task<IResult> DeleteHoldingAsync(Guid id, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var holding = await _db.PortfolioHoldings
            .FirstOrDefaultAsync(h => h.Id == id && h.UserId == userId);
        if (holding is null) return Results.NotFound();

        _db.PortfolioHoldings.Remove(holding);
        await _db.SaveChangesAsync();
        return Results.NoContent();
    }

    public async Task<IResult> ArchiveHoldingAsync(Guid id, PortfolioEndpoints.ArchiveHoldingDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var holding = await _db.PortfolioHoldings
            .FirstOrDefaultAsync(h => h.Id == id && h.UserId == userId);
        if (holding is null) return Results.NotFound();

        holding.IsArchived = dto.IsArchived;
        holding.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Results.Ok(new { id, isArchived = dto.IsArchived });
    }

    private static dynamic ToHoldingPayload(PortfolioHolding h, QuoteData? quote)
    {
        var currentPrice = quote?.Price;
        var totalValue = currentPrice.HasValue ? h.Quantity * currentPrice.Value : (decimal?)null;
        var totalInvested = h.AverageBuyPrice.HasValue ? h.Quantity * h.AverageBuyPrice.Value : (decimal?)null;
        var totalGainLoss = totalValue.HasValue && totalInvested.HasValue
            ? totalValue.Value - totalInvested.Value : (decimal?)null;
        var totalGainLossPercent = totalGainLoss.HasValue && totalInvested > 0
            ? Math.Round(totalGainLoss.Value / totalInvested.Value * 100m, 2) : (decimal?)null;

        return new
        {
            id = h.Id,
            symbol = h.Symbol,
            name = h.Name,
            exchange = h.Exchange,
            assetType = h.AssetType,
            quantity = h.Quantity,
            averageBuyPrice = h.AverageBuyPrice,
            buyDate = h.BuyDate,
            currency = h.Currency,
            notes = h.Notes,
            currentPrice,
            changePercent = quote?.ChangePercent,
            totalValue = totalValue.HasValue ? Math.Round(totalValue.Value, 2) : (decimal?)null,
            totalGainLoss = totalGainLoss.HasValue ? Math.Round(totalGainLoss.Value, 2) : (decimal?)null,
            totalGainLossPercent,
            isStale = quote?.IsStale ?? false,
            isArchived = h.IsArchived,
            createdAt = h.CreatedAt,
            updatedAt = h.UpdatedAt,
        };
    }

    private static object EmptySummary() => new
    {
        totalValue = 0m,
        totalInvested = 0m,
        totalGainLoss = 0m,
        totalGainLossPercent = 0m,
        holdingsCount = 0
    };

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
