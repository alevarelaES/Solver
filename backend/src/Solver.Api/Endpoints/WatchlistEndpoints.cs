using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class WatchlistEndpoints
{
    public static void MapWatchlistEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/watchlist");

        group.MapGet("/", (
            WatchlistService service,
            HttpContext ctx) => service.GetWatchlistAsync(ctx));
        group.MapPost("/", (
            AddWatchlistDto dto,
            WatchlistService service,
            HttpContext ctx) => service.AddToWatchlistAsync(dto, ctx));
        group.MapDelete("/{id:guid}", (
            Guid id,
            WatchlistService service,
            HttpContext ctx) => service.RemoveFromWatchlistAsync(id, ctx));
        group.MapPut("/reorder", (
            ReorderDto dto,
            WatchlistService service,
            HttpContext ctx) => service.ReorderWatchlistAsync(dto, ctx));
    }

    public sealed record AddWatchlistDto(
        string Symbol,
        string? Exchange,
        string? Name,
        string? AssetType);

    public sealed record ReorderDto(List<Guid>? Order);
}
