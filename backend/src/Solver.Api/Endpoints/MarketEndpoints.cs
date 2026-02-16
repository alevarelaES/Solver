using System.Text.Json;
using System.Threading.Channels;
using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class MarketEndpoints
{
    private static readonly HashSet<string> ValidIntervals = new(StringComparer.OrdinalIgnoreCase)
    {
        "1min", "5min", "15min", "30min", "45min", "1h", "2h", "4h", "1day", "1week", "1month"
    };

    public static void MapMarketEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/market");

        // Twelve Data
        group.MapGet("/search", SearchSymbolsAsync);
        group.MapGet("/quote", GetQuotesAsync);
        group.MapGet("/history/{symbol}", GetHistoryAsync);
        group.MapGet("/history-batch", GetHistoryBatchAsync);
        group.MapGet("/stream/{symbol}", StreamSymbolAsync);

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

        var ivl = interval ?? "1day";
        if (!ValidIntervals.Contains(ivl))
            return Results.BadRequest(new { error = $"Invalid interval. Valid: {string.Join(", ", ValidIntervals)}" });

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

    private static async Task<IResult> GetHistoryBatchAsync(
        string symbols,
        string? interval,
        int? outputsize,
        TwelveDataService twelveData)
    {
        if (string.IsNullOrWhiteSpace(symbols))
            return Results.BadRequest(new { error = "Symbols parameter is required." });

        var symbolList = symbols
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => s.ToUpperInvariant())
            .Distinct()
            .Take(30)
            .ToList();

        if (symbolList.Count == 0)
            return Results.BadRequest(new { error = "At least one symbol is required." });

        var ivl = interval ?? "1day";
        if (!ValidIntervals.Contains(ivl))
            return Results.BadRequest(new { error = $"Invalid interval. Valid: {string.Join(", ", ValidIntervals)}" });

        var size = Math.Clamp(outputsize ?? 7, 2, 500);
        var histories = await twelveData.GetHistoryBatchAsync(symbolList, ivl, size);

        return Results.Ok(new
        {
            interval = ivl,
            outputSize = size,
            histories = histories.ToDictionary(
                kv => kv.Key,
                kv => kv.Value.Select(p => new
                {
                    datetime = p.Datetime,
                    close = p.Close
                }))
        });
    }

    private static async Task StreamSymbolAsync(
        string symbol,
        HttpContext context,
        TwelveDataService twelveData,
        TwelveDataWebSocketService wsService)
    {
        if (string.IsNullOrWhiteSpace(symbol))
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsJsonAsync(new { error = "Symbol is required." }, context.RequestAborted);
            return;
        }

        if (!wsService.IsConfigured)
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            await context.Response.WriteAsJsonAsync(new { error = "Live streaming is not configured." }, context.RequestAborted);
            return;
        }

        var normalized = symbol.Trim().ToUpperInvariant();
        var subscribed = await wsService.SubscribeToSymbolAsync(normalized, context.RequestAborted);
        if (!subscribed)
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            await context.Response.WriteAsJsonAsync(new { error = "Unable to subscribe to live stream." }, context.RequestAborted);
            return;
        }

        context.Response.Headers.CacheControl = "no-cache";
        context.Response.Headers.Append("X-Accel-Buffering", "no");
        context.Response.ContentType = "text/event-stream";

        var channel = Channel.CreateUnbounded<LivePriceUpdate>();

        void HandlePrice(LivePriceUpdate update)
        {
            if (string.Equals(update.Symbol, normalized, StringComparison.OrdinalIgnoreCase))
            {
                channel.Writer.TryWrite(update);
            }
        }

        wsService.PriceUpdated += HandlePrice;
        try
        {
            await WriteSseDataAsync(context, new
            {
                symbol = normalized,
                status = "subscribed",
                timestampUtc = DateTime.UtcNow
            });

            var initial = await twelveData.GetQuotesAsync([normalized]);
            if (initial.TryGetValue(normalized, out var quote))
            {
                await WriteSseDataAsync(context, new
                {
                    symbol = normalized,
                    price = quote.Price,
                    isStale = quote.IsStale,
                    timestampUtc = DateTime.UtcNow
                });
            }

            while (!context.RequestAborted.IsCancellationRequested)
            {
                var readTask = channel.Reader.ReadAsync(context.RequestAborted).AsTask();
                var pingTask = Task.Delay(TimeSpan.FromSeconds(15), context.RequestAborted);
                var completed = await Task.WhenAny(readTask, pingTask);

                if (completed == pingTask)
                {
                    await context.Response.WriteAsync(": ping\n\n", context.RequestAborted);
                    await context.Response.Body.FlushAsync(context.RequestAborted);
                    continue;
                }

                var update = await readTask;
                await WriteSseDataAsync(context, new
                {
                    symbol = update.Symbol,
                    price = update.Price,
                    timestampUtc = update.TimestampUtc
                });
            }
        }
        catch (OperationCanceledException)
        {
            // Client disconnected.
        }
        finally
        {
            wsService.PriceUpdated -= HandlePrice;
            channel.Writer.TryComplete();
        }
    }

    private static async Task WriteSseDataAsync(HttpContext context, object payload)
    {
        var json = JsonSerializer.Serialize(payload);
        await context.Response.WriteAsync($"data: {json}\n\n", context.RequestAborted);
        await context.Response.Body.FlushAsync(context.RequestAborted);
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
