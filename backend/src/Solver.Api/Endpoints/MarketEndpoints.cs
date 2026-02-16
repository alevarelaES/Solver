using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class MarketEndpoints
{
    public static void MapMarketEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/market");

        // Twelve Data
        group.MapGet("/search", SearchSymbolsAsync);
        group.MapGet("/quote", GetQuotesAsync);
        group.MapGet("/history/{symbol}", GetHistoryAsync);

        // Finnhub
        group.MapGet("/profile/{symbol}", GetProfileAsync);
        group.MapGet("/news/{symbol}", GetNewsAsync);
        group.MapGet("/recommendations/{symbol}", GetRecommendationsAsync);
    }

    private static async Task<IResult> SearchSymbolsAsync(
        string q,
        TwelveDataService twelveData)
    {
        if (string.IsNullOrWhiteSpace(q) || q.Length < 2)
            return Results.BadRequest(new { error = "Query must be at least 2 characters." });

        var results = await twelveData.SearchSymbolsAsync(q.Trim());

        return Results.Ok(new
        {
            results = results.Select(r => new
            {
                symbol = r.Symbol,
                name = r.InstrumentName,
                exchange = r.Exchange,
                type = r.InstrumentType,
                country = r.Country,
            })
        });
    }

    private static async Task<IResult> GetQuotesAsync(
        string symbols,
        TwelveDataService twelveData)
    {
        if (string.IsNullOrWhiteSpace(symbols))
            return Results.BadRequest(new { error = "Symbols parameter is required." });

        var symbolList = symbols.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => s.ToUpperInvariant())
            .Distinct()
            .ToList();

        if (symbolList.Count == 0)
            return Results.BadRequest(new { error = "At least one symbol is required." });

        var quotes = await twelveData.GetQuotesAsync(symbolList);

        return Results.Ok(new
        {
            quotes = quotes.ToDictionary(
                kv => kv.Key,
                kv => new
                {
                    price = kv.Value.Price,
                    previousClose = kv.Value.PreviousClose,
                    changePercent = kv.Value.ChangePercent,
                    currency = kv.Value.Currency,
                    isStale = kv.Value.IsStale,
                })
        });
    }

    private static async Task<IResult> GetHistoryAsync(
        string symbol,
        string? interval,
        int? outputsize,
        TwelveDataService twelveData)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var validIntervals = new[] { "1min", "5min", "15min", "30min", "45min", "1h", "2h", "4h", "1day", "1week", "1month" };
        var ivl = interval ?? "1day";
        if (!validIntervals.Contains(ivl))
            return Results.BadRequest(new { error = $"Invalid interval. Valid: {string.Join(", ", validIntervals)}" });

        var size = Math.Clamp(outputsize ?? 30, 1, 500);

        var points = await twelveData.GetTimeSeriesAsync(symbol.Trim().ToUpperInvariant(), ivl, size);

        return Results.Ok(new
        {
            symbol = symbol.ToUpperInvariant(),
            interval = ivl,
            values = points.Select(p => new
            {
                datetime = p.Datetime,
                open = p.Open,
                high = p.High,
                low = p.Low,
                close = p.Close,
                volume = p.Volume,
            })
        });
    }

    private static async Task<IResult> GetProfileAsync(
        string symbol,
        FinnhubService finnhub)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var profile = await finnhub.GetCompanyProfileAsync(symbol.Trim().ToUpperInvariant());
        if (profile?.Name == null)
            return Results.NotFound(new { error = $"No profile found for {symbol}" });

        return Results.Ok(new
        {
            name = profile.Name,
            ticker = profile.Ticker,
            exchange = profile.Exchange,
            sector = profile.FinnhubIndustry,
            country = profile.Country,
            currency = profile.Currency,
            marketCap = profile.MarketCapitalization,
            logo = profile.Logo,
            ipo = profile.Ipo,
            webUrl = profile.WebUrl,
        });
    }

    private static async Task<IResult> GetNewsAsync(
        string symbol,
        int? days,
        FinnhubService finnhub)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var d = Math.Clamp(days ?? 7, 1, 30);
        var news = await finnhub.GetCompanyNewsAsync(symbol.Trim().ToUpperInvariant(), d);

        return Results.Ok(new
        {
            news = news.Select(n => new
            {
                headline = n.Headline,
                summary = n.Summary,
                source = n.Source,
                url = n.Url,
                image = n.Image,
                datetime = DateTimeOffset.FromUnixTimeSeconds(n.Datetime).UtcDateTime,
            })
        });
    }

    private static async Task<IResult> GetRecommendationsAsync(
        string symbol,
        FinnhubService finnhub)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var recos = await finnhub.GetRecommendationsAsync(symbol.Trim().ToUpperInvariant());

        return Results.Ok(new
        {
            recommendations = recos.Select(r => new
            {
                period = r.Period,
                buy = r.Buy,
                hold = r.Hold,
                sell = r.Sell,
                strongBuy = r.StrongBuy,
                strongSell = r.StrongSell,
            })
        });
    }
}
