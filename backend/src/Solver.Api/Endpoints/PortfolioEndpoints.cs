using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class PortfolioEndpoints
{
    public static void MapPortfolioEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/portfolio");

        group.MapGet("/", (
            PortfolioService service,
            HttpContext ctx) => service.GetPortfolioAsync(ctx));
        group.MapPost("/", (
            CreateHoldingDto dto,
            PortfolioService service,
            HttpContext ctx) => service.CreateHoldingAsync(dto, ctx));
        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateHoldingDto dto,
            PortfolioService service,
            HttpContext ctx) => service.UpdateHoldingAsync(id, dto, ctx));
        group.MapDelete("/{id:guid}", (
            Guid id,
            PortfolioService service,
            HttpContext ctx) => service.DeleteHoldingAsync(id, ctx));
        group.MapPatch("/{id:guid}/archive", (
            Guid id,
            ArchiveHoldingDto dto,
            PortfolioService service,
            HttpContext ctx) => service.ArchiveHoldingAsync(id, dto, ctx));
    }

    public sealed record CreateHoldingDto(
        string Symbol,
        string? Exchange,
        string? Name,
        string? AssetType,
        decimal Quantity,
        decimal? AverageBuyPrice,
        DateOnly? BuyDate,
        string? Currency,
        string? Notes);

    public sealed record UpdateHoldingDto(
        string? Name,
        decimal Quantity,
        decimal? AverageBuyPrice,
        DateOnly? BuyDate,
        string? Notes);

    public sealed record ArchiveHoldingDto(bool IsArchived);
}
