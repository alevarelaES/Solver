using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading.Channels;

namespace Solver.Api.Services;

public sealed partial class MarketService
{
    private static readonly HashSet<string> ValidIntervals = new(StringComparer.OrdinalIgnoreCase)
    {
        "1min", "5min", "15min", "30min", "45min", "1h", "2h", "4h", "1day", "1week", "1month"
    };

    // Allows standard ticker formats: AAPL, BRK.A, BF-B, EUR/USD, AAPL:NASDAQ (max 20 chars)
    [GeneratedRegex(@"^[A-Z0-9][A-Z0-9.\-:/]{0,19}$", RegexOptions.Compiled)]
    private static partial Regex SymbolPattern();

    private static bool IsValidSymbol(string normalizedSymbol) =>
        SymbolPattern().IsMatch(normalizedSymbol);

    private readonly TwelveDataService _twelveData;
    private readonly TwelveDataWebSocketService _wsService;
    private readonly FinnhubService _finnhub;

    public MarketService(
        TwelveDataService twelveData,
        TwelveDataWebSocketService wsService,
        FinnhubService finnhub)
    {
        _twelveData = twelveData;
        _wsService = wsService;
        _finnhub = finnhub;
    }

    public async Task<IResult> SearchSymbolsAsync(string q, int? limit)
    {
        if (string.IsNullOrWhiteSpace(q) || q.Length < 2)
            return Results.BadRequest(new { error = "Query must be at least 2 characters." });

        var maxResults = Math.Clamp(limit ?? 100, 10, 120);
        var results = await _twelveData.SearchSymbolsAsync(q.Trim(), maxResults);

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

    public async Task<IResult> GetQuotesAsync(string symbols)
    {
        if (string.IsNullOrWhiteSpace(symbols))
            return Results.BadRequest(new { error = "Symbols parameter is required." });

        var symbolList = symbols.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(s => s.ToUpperInvariant())
            .Distinct()
            .ToList();

        if (symbolList.Count == 0)
            return Results.BadRequest(new { error = "At least one symbol is required." });

        var quotes = await _twelveData.GetQuotesAsync(symbolList);

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

    public async Task<IResult> GetHistoryAsync(string symbol, string? interval, int? outputsize)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var normalizedSymbol = symbol.Trim().ToUpperInvariant();
        if (!IsValidSymbol(normalizedSymbol))
            return Results.BadRequest(new { error = "Invalid symbol format." });

        var ivl = interval ?? "1day";
        if (!ValidIntervals.Contains(ivl))
            return Results.BadRequest(new { error = $"Invalid interval. Valid: {string.Join(", ", ValidIntervals)}" });

        var size = Math.Clamp(outputsize ?? 30, 1, 500);

        var points = await _twelveData.GetTimeSeriesAsync(normalizedSymbol, ivl, size);

        if (points.Count < 2)
        {
            var fallbackMap = await _twelveData.GetHistoryBatchAsync([normalizedSymbol], ivl, size);
            if (fallbackMap.TryGetValue(normalizedSymbol, out var fallbackPoints) &&
                fallbackPoints.Count >= 2)
            {
                return Results.Ok(new
                {
                    symbol = normalizedSymbol,
                    interval = ivl,
                    isSynthetic = true,
                    values = fallbackPoints.Select(p => new
                    {
                        datetime = p.Datetime,
                        open = p.Close,
                        high = p.Close,
                        low = p.Close,
                        close = p.Close,
                        volume = 0
                    })
                });
            }
        }

        return Results.Ok(new
        {
            symbol = normalizedSymbol,
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

    public async Task<IResult> GetHistoryBatchAsync(string symbols, string? interval, int? outputsize)
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
        var histories = await _twelveData.GetHistoryBatchAsync(symbolList, ivl, size);

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

    public async Task StreamSymbolAsync(string symbol, HttpContext context)
    {
        if (string.IsNullOrWhiteSpace(symbol))
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsJsonAsync(new { error = "Symbol is required." }, context.RequestAborted);
            return;
        }

        var normalized = symbol.Trim().ToUpperInvariant();
        if (!IsValidSymbol(normalized))
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsJsonAsync(new { error = "Invalid symbol format." }, context.RequestAborted);
            return;
        }

        if (!_wsService.IsConfigured)
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            await context.Response.WriteAsJsonAsync(new { error = "Live streaming is not configured." }, context.RequestAborted);
            return;
        }
        var subscribed = await _wsService.SubscribeToSymbolAsync(normalized, context.RequestAborted);
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

        _wsService.PriceUpdated += HandlePrice;
        try
        {
            await WriteSseDataAsync(context, new
            {
                symbol = normalized,
                status = "subscribed",
                timestampUtc = DateTime.UtcNow
            });

            var initial = await _twelveData.GetQuotesAsync([normalized]);
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
            _wsService.PriceUpdated -= HandlePrice;
            channel.Writer.TryComplete();
        }
    }

    public async Task<IResult> GetTrendingAsync()
    {
        var snapshot = await _twelveData.GetTrendingSnapshotAsync();
        return Results.Ok(new
        {
            stocks = snapshot.Stocks.Select(t => new
            {
                symbol = t.Symbol,
                name = t.Name,
                price = t.Price,
                changePercent = t.ChangePercent,
                currency = t.Currency,
                isStale = t.IsStale,
                assetType = t.AssetType,
            }),
            crypto = snapshot.Crypto.Select(t => new
            {
                symbol = t.Symbol,
                name = t.Name,
                price = t.Price,
                changePercent = t.ChangePercent,
                currency = t.Currency,
                isStale = t.IsStale,
                assetType = t.AssetType,
            }),
        });
    }

    public async Task<IResult> GetMarketNewsGeneralAsync()
    {
        var news = await _finnhub.GetMarketNewsAsync();
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

    public async Task<IResult> GetProfileAsync(string symbol)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var normalizedSymbol = symbol.Trim().ToUpperInvariant();
        if (!IsValidSymbol(normalizedSymbol))
            return Results.BadRequest(new { error = "Invalid symbol format." });

        var profile = await _finnhub.GetCompanyProfileAsync(normalizedSymbol);
        if (profile?.Name == null)
            return Results.NotFound(new { error = $"No profile found for {normalizedSymbol}" });

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

    public async Task<IResult> GetNewsAsync(string symbol, int? days)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var normalizedSymbol = symbol.Trim().ToUpperInvariant();
        if (!IsValidSymbol(normalizedSymbol))
            return Results.BadRequest(new { error = "Invalid symbol format." });

        var d = Math.Clamp(days ?? 7, 1, 30);
        var news = await _finnhub.GetCompanyNewsAsync(normalizedSymbol, d);

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

    public async Task<IResult> GetRecommendationsAsync(string symbol)
    {
        if (string.IsNullOrWhiteSpace(symbol))
            return Results.BadRequest(new { error = "Symbol is required." });

        var normalizedSymbol = symbol.Trim().ToUpperInvariant();
        if (!IsValidSymbol(normalizedSymbol))
            return Results.BadRequest(new { error = "Invalid symbol format." });

        var recos = await _finnhub.GetRecommendationsAsync(normalizedSymbol);

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

    private static async Task WriteSseDataAsync(HttpContext context, object payload)
    {
        var json = JsonSerializer.Serialize(payload);
        await context.Response.WriteAsync($"data: {json}\n\n", context.RequestAborted);
        await context.Response.Body.FlushAsync(context.RequestAborted);
    }
}
