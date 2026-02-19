using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class MarketEndpoints
{
    public static void MapMarketEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/market");

        group.MapGet("/search", (
            string q,
            int? limit,
            MarketService service) => service.SearchSymbolsAsync(q, limit));
        group.MapGet("/quote", (
            string symbols,
            MarketService service) => service.GetQuotesAsync(symbols));
        group.MapGet("/history/{symbol}", (
            string symbol,
            string? interval,
            int? outputsize,
            MarketService service) => service.GetHistoryAsync(symbol, interval, outputsize));
        group.MapGet("/history-batch", (
            string symbols,
            string? interval,
            int? outputsize,
            MarketService service) => service.GetHistoryBatchAsync(symbols, interval, outputsize));
        group.MapGet("/stream/{symbol}", (
            string symbol,
            HttpContext context,
            MarketService service) => service.StreamSymbolAsync(symbol, context));

        group.MapGet("/trending", (MarketService service) => service.GetTrendingAsync());
        group.MapGet("/news-general", (MarketService service) => service.GetMarketNewsGeneralAsync());

        group.MapGet("/profile/{symbol}", (
            string symbol,
            MarketService service) => service.GetProfileAsync(symbol));
        group.MapGet("/news/{symbol}", (
            string symbol,
            int? days,
            MarketService service) => service.GetNewsAsync(symbol, days));
        group.MapGet("/recommendations/{symbol}", (
            string symbol,
            MarketService service) => service.GetRecommendationsAsync(symbol));
    }
}
