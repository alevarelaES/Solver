using System.Text.Json;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Services;

public class TwelveDataService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly TwelveDataConfig _config;
    private readonly SolverDbContext _db;
    private readonly TwelveDataRateLimiter _rateLimiter;
    private readonly IMemoryCache _memoryCache;
    private readonly ILogger<TwelveDataService> _logger;

    public TwelveDataService(
        IHttpClientFactory httpClientFactory,
        TwelveDataConfig config,
        SolverDbContext db,
        TwelveDataRateLimiter rateLimiter,
        IMemoryCache memoryCache,
        ILogger<TwelveDataService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
        _db = db;
        _rateLimiter = rateLimiter;
        _memoryCache = memoryCache;
        _logger = logger;
    }

    public async Task<Dictionary<string, QuoteData>> GetQuotesAsync(IEnumerable<string> symbols)
    {
        var symbolList = symbols
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim().ToUpperInvariant())
            .Distinct()
            .ToList();
        if (symbolList.Count == 0) return [];

        var results = new Dictionary<string, QuoteData>(StringComparer.OrdinalIgnoreCase);

        foreach (var symbol in symbolList)
        {
            if (TryGetQuoteFromMemory(symbol, out var memoryQuote))
            {
                results[symbol] = memoryQuote with { IsStale = true };
            }
        }

        var cutoff = DateTime.UtcNow.AddMinutes(-_config.CacheMinutes);
        var missingBeforeDb = symbolList.Where(s => !results.ContainsKey(s)).ToList();
        var cached = await _db.AssetPriceCache
            .Where(p => missingBeforeDb.Contains(p.Symbol) && p.FetchedAt > cutoff)
            .ToListAsync();

        foreach (var c in cached)
        {
            var fresh = new QuoteData(c.Price, c.PreviousClose, c.ChangePercent, c.Currency, false);
            results[c.Symbol] = fresh;
            SetQuoteInMemory(c.Symbol, fresh);
        }

        var stale = symbolList.Where(s => !results.ContainsKey(s)).ToList();
        if (stale.Count == 0) return results;

        // Fetch in batches of 8 (Twelve Data limit)
        foreach (var batch in stale.Chunk(8))
        {
            if (!await _rateLimiter.TryAcquireAsync())
            {
                _logger.LogWarning("TwelveData rate limit reached, serving stale cache");
                // Try to serve stale cache for remaining symbols
                var staleCache = await _db.AssetPriceCache
                    .Where(p => batch.Contains(p.Symbol))
                    .ToListAsync();
                foreach (var sc in staleCache)
                {
                    var staleQuote = new QuoteData(sc.Price, sc.PreviousClose, sc.ChangePercent, sc.Currency, true);
                    results.TryAdd(sc.Symbol, staleQuote);
                    SetQuoteInMemory(sc.Symbol, staleQuote);
                }

                foreach (var symbol in batch)
                {
                    if (results.ContainsKey(symbol)) continue;
                    if (TryGetQuoteFromMemory(symbol, out var memQuote))
                    {
                        results[symbol] = memQuote with { IsStale = true };
                    }
                }
                continue;
            }

            try
            {
                var fetched = await FetchQuoteBatchAsync(batch);
                foreach (var (symbol, quote) in fetched)
                {
                    results[symbol] = quote;
                    SetQuoteInMemory(symbol, quote);
                    await UpsertPriceCacheAsync(symbol, quote);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "TwelveData quote fetch failed for {Symbols}", string.Join(",", batch));
                // Fallback: serve stale cache
                var staleCache = await _db.AssetPriceCache
                    .Where(p => batch.Contains(p.Symbol))
                    .ToListAsync();
                foreach (var sc in staleCache)
                {
                    var staleQuote = new QuoteData(sc.Price, sc.PreviousClose, sc.ChangePercent, sc.Currency, true);
                    results.TryAdd(sc.Symbol, staleQuote);
                    SetQuoteInMemory(sc.Symbol, staleQuote);
                }

                foreach (var symbol in batch)
                {
                    if (results.ContainsKey(symbol)) continue;
                    if (TryGetQuoteFromMemory(symbol, out var memQuote))
                    {
                        results[symbol] = memQuote with { IsStale = true };
                    }
                }
            }
        }

        return results;
    }

    public async Task<List<TwelveDataSymbolSearch>> SearchSymbolsAsync(string query, int limit = 100)
    {
        if (!await _rateLimiter.TryAcquireAsync())
            return [];

        try
        {
            var clampedLimit = Math.Clamp(limit, 10, 120);
            var client = _httpClientFactory.CreateClient("TwelveData");
            var response = await client.GetFromJsonAsync<TwelveDataSymbolSearchResponse>(
                $"/symbol_search?symbol={Uri.EscapeDataString(query)}&outputsize={clampedLimit}&apikey={_config.ApiKey}");
            return response?.Data ?? [];
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "TwelveData symbol search failed for {Query}", query);
            return [];
        }
    }

    public async Task<List<TwelveDataTimeSeriesPoint>> GetTimeSeriesAsync(
        string symbol, string interval = "1day", int outputSize = 30)
    {
        var normalizedSymbol = symbol.Trim().ToUpperInvariant();
        var normalizedInterval = interval.Trim().ToLowerInvariant();
        var normalizedOutput = Math.Clamp(outputSize, 2, 500);
        var cacheKey = $"td:series:{normalizedSymbol}:{normalizedInterval}:{normalizedOutput}";

        if (_memoryCache.TryGetValue(cacheKey, out List<TwelveDataTimeSeriesPoint>? cached) &&
            cached != null && cached.Count > 1)
        {
            return cached;
        }

        if (!await _rateLimiter.TryAcquireAsync())
        {
            _logger.LogWarning(
                "TwelveData time series throttled for {Symbol} ({Interval}, {OutputSize})",
                normalizedSymbol,
                normalizedInterval,
                normalizedOutput);
            return cached ?? [];
        }

        try
        {
            var client = _httpClientFactory.CreateClient("TwelveData");
            var response = await client.GetFromJsonAsync<TwelveDataTimeSeriesResponse>(
                $"/time_series?symbol={Uri.EscapeDataString(normalizedSymbol)}" +
                $"&interval={normalizedInterval}&outputsize={normalizedOutput}&apikey={_config.ApiKey}");

            var values = response?.Values ?? [];
            if (values.Count == 0)
                return cached ?? [];

            var ordered = NormalizeSeries(values);
            _memoryCache.Set(cacheKey, ordered, TimeSpan.FromMinutes(10));
            return ordered;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "TwelveData time series failed for {Symbol}", normalizedSymbol);
            return cached ?? [];
        }
    }

    public async Task<Dictionary<string, List<PriceHistoryPoint>>> GetHistoryBatchAsync(
        IEnumerable<string> symbols,
        string interval = "1day",
        int outputSize = 7)
    {
        var normalizedSymbols = symbols
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .Select(s => s.Trim().ToUpperInvariant())
            .Distinct()
            .ToList();

        if (normalizedSymbols.Count == 0)
            return [];

        var result = new Dictionary<string, List<PriceHistoryPoint>>(StringComparer.OrdinalIgnoreCase);
        var cacheKeys = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var symbol in normalizedSymbols)
        {
            var cacheKey = $"td:history:{symbol}:{interval}:{outputSize}";
            cacheKeys[symbol] = cacheKey;
            if (_memoryCache.TryGetValue(cacheKey, out List<PriceHistoryPoint>? cachedPoints) && cachedPoints != null)
            {
                result[symbol] = cachedPoints;
                continue;
            }

            var series = await GetTimeSeriesAsync(symbol, interval, outputSize);
            var points = series
                .Select(p =>
                {
                    if (!decimal.TryParse(
                            p.Close,
                            System.Globalization.NumberStyles.Any,
                            System.Globalization.CultureInfo.InvariantCulture,
                            out var close))
                    {
                        return null;
                    }

                    return new PriceHistoryPoint(p.Datetime, close);
                })
                .Where(p => p != null)
                .Select(p => p!)
                .ToList();

            result[symbol] = points;
            _memoryCache.Set(cacheKey, points, TimeSpan.FromMinutes(10));
        }

        var missingOrSparse = normalizedSymbols
            .Where(symbol => !result.TryGetValue(symbol, out var points) || points.Count < 2)
            .ToList();

        if (missingOrSparse.Count > 0)
        {
            var quoteFallback = await GetQuotesAsync(missingOrSparse);
            foreach (var symbol in missingOrSparse)
            {
                if (!quoteFallback.TryGetValue(symbol, out var quote))
                    continue;

                var synthetic = BuildSyntheticHistory(quote, outputSize);
                result[symbol] = synthetic;
                if (cacheKeys.TryGetValue(symbol, out var cacheKey))
                {
                    _memoryCache.Set(cacheKey, synthetic, TimeSpan.FromMinutes(10));
                }
            }
        }

        return result;
    }

    private static readonly string[] TrendingSymbols =
    [
        "AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "NFLX",
        "JPM", "V", "JNJ", "WMT", "PG", "DIS", "PYPL", "AMD", "INTC",
        "BA", "CRM", "UBER"
    ];

    private static readonly string[] TrendingCryptoSymbols =
    [
        "BTC/USD", "ETH/USD", "SOL/USD", "BNB/USD", "XRP/USD",
        "ADA/USD", "DOGE/USD", "AVAX/USD", "DOT/USD", "LINK/USD"
    ];

    private static readonly Dictionary<string, string> TrendingNames = new()
    {
        ["AAPL"] = "Apple Inc", ["MSFT"] = "Microsoft Corp", ["GOOGL"] = "Alphabet Inc",
        ["AMZN"] = "Amazon.com Inc", ["TSLA"] = "Tesla Inc", ["META"] = "Meta Platforms",
        ["NVDA"] = "NVIDIA Corp", ["NFLX"] = "Netflix Inc", ["JPM"] = "JPMorgan Chase",
        ["V"] = "Visa Inc", ["JNJ"] = "Johnson & Johnson", ["WMT"] = "Walmart Inc",
        ["PG"] = "Procter & Gamble", ["DIS"] = "Walt Disney Co", ["PYPL"] = "PayPal Holdings",
        ["AMD"] = "Advanced Micro Devices", ["INTC"] = "Intel Corp", ["BA"] = "Boeing Co",
        ["CRM"] = "Salesforce Inc", ["UBER"] = "Uber Technologies"
    };

    private static readonly Dictionary<string, string> TrendingCryptoNames = new()
    {
        ["BTC/USD"] = "Bitcoin",
        ["ETH/USD"] = "Ethereum",
        ["SOL/USD"] = "Solana",
        ["BNB/USD"] = "BNB",
        ["XRP/USD"] = "XRP",
        ["ADA/USD"] = "Cardano",
        ["DOGE/USD"] = "Dogecoin",
        ["AVAX/USD"] = "Avalanche",
        ["DOT/USD"] = "Polkadot",
        ["LINK/USD"] = "Chainlink",
    };

    public async Task<List<TrendingQuote>> GetTrendingQuotesAsync()
    {
        var quotes = await GetQuotesAsync(TrendingSymbols);
        return quotes.Select(kv => new TrendingQuote(
            kv.Key,
            TrendingNames.GetValueOrDefault(kv.Key, kv.Key),
            kv.Value.Price,
            kv.Value.ChangePercent,
            kv.Value.Currency,
            kv.Value.IsStale,
            "stock"
        )).OrderByDescending(t => Math.Abs(t.ChangePercent ?? 0)).ToList();
    }

    public async Task<TrendingSnapshot> GetTrendingSnapshotAsync()
    {
        const string cacheKey = "td:trending:snapshot:v2";
        if (_memoryCache.TryGetValue(cacheKey, out TrendingSnapshot? cachedSnapshot) &&
            cachedSnapshot != null)
        {
            return cachedSnapshot;
        }

        // Sequential calls: this service holds a scoped DbContext, so avoid parallel operations.
        var stockQuotes = await GetQuotesAsync(TrendingSymbols);
        var cryptoQuotes = await GetQuotesAsync(TrendingCryptoSymbols);

        var stocks = stockQuotes
            .Select(kv => new TrendingQuote(
                kv.Key,
                TrendingNames.GetValueOrDefault(kv.Key, kv.Key),
                kv.Value.Price,
                kv.Value.ChangePercent,
                kv.Value.Currency,
                kv.Value.IsStale,
                "stock"))
            .OrderByDescending(t => Math.Abs(t.ChangePercent ?? 0))
            .Take(12)
            .ToList();

        var crypto = cryptoQuotes
            .Select(kv => new TrendingQuote(
                kv.Key,
                TrendingCryptoNames.GetValueOrDefault(kv.Key, kv.Key),
                kv.Value.Price,
                kv.Value.ChangePercent,
                kv.Value.Currency,
                kv.Value.IsStale,
                "crypto"))
            .OrderByDescending(t => Math.Abs(t.ChangePercent ?? 0))
            .Take(8)
            .ToList();

        var snapshot = new TrendingSnapshot(stocks, crypto);
        _memoryCache.Set(cacheKey, snapshot, TimeSpan.FromMinutes(2));
        return snapshot;
    }

    public async Task UpdateCachedPriceAsync(string symbol, decimal price, CancellationToken ct = default)
    {
        var normalized = symbol.Trim().ToUpperInvariant();
        var existing = await _db.AssetPriceCache.FindAsync([normalized], ct);
        if (existing != null)
        {
            var previousPrice = existing.Price;
            existing.Price = price;
            if (previousPrice > 0)
            {
                existing.ChangePercent = Math.Round((price - previousPrice) / previousPrice * 100m, 4);
            }

            existing.FetchedAt = DateTime.UtcNow;
        }
        else
        {
            _db.AssetPriceCache.Add(new AssetPriceCache
            {
                Symbol = normalized,
                Price = price,
                PreviousClose = null,
                ChangePercent = null,
                Currency = "USD",
                FetchedAt = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync(ct);
    }

    private async Task<Dictionary<string, QuoteData>> FetchQuoteBatchAsync(string[] symbols)
    {
        var client = _httpClientFactory.CreateClient("TwelveData");
        var joined = string.Join(",", symbols);
        var url = $"/quote?symbol={Uri.EscapeDataString(joined)}&apikey={_config.ApiKey}";

        var response = await client.GetStringAsync(url);
        var results = new Dictionary<string, QuoteData>();

        using var doc = JsonDocument.Parse(response);

        if (symbols.Length == 1)
        {
            // Single symbol: response is the quote object directly
            var quote = ParseQuoteElement(doc.RootElement);
            if (quote != null)
                results[symbols[0]] = quote;
        }
        else
        {
            // Multiple symbols: response is an object with symbol keys
            foreach (var symbol in symbols)
            {
                if (doc.RootElement.TryGetProperty(symbol, out var elem))
                {
                    var quote = ParseQuoteElement(elem);
                    if (quote != null)
                        results[symbol] = quote;
                }
            }
        }

        return results;
    }

    private static QuoteData? ParseQuoteElement(JsonElement elem)
    {
        if (elem.TryGetProperty("close", out var closeElem) &&
            decimal.TryParse(closeElem.GetString(), System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out var price))
        {
            decimal? prevClose = null;
            if (elem.TryGetProperty("previous_close", out var pcElem) &&
                decimal.TryParse(pcElem.GetString(), System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out var pc))
                prevClose = pc;

            decimal? changePct = null;
            if (elem.TryGetProperty("percent_change", out var pctElem) &&
                decimal.TryParse(pctElem.GetString(), System.Globalization.NumberStyles.Any,
                    System.Globalization.CultureInfo.InvariantCulture, out var pct))
                changePct = pct;

            var currency = "USD";
            if (elem.TryGetProperty("currency", out var curElem))
                currency = curElem.GetString() ?? "USD";

            return new QuoteData(price, prevClose, changePct, currency, false);
        }

        return null;
    }

    private static List<TwelveDataTimeSeriesPoint> NormalizeSeries(
        List<TwelveDataTimeSeriesPoint> points)
    {
        if (points.Count < 2) return points;

        static DateTime ParseDate(string raw)
        {
            if (DateTime.TryParse(raw, out var parsed))
                return parsed;
            return DateTime.MinValue;
        }

        return points
            .OrderBy(p => ParseDate(p.Datetime))
            .ToList();
    }

    private static List<PriceHistoryPoint> BuildSyntheticHistory(
        QuoteData quote,
        int outputSize)
    {
        var points = new List<PriceHistoryPoint>();
        var size = Math.Clamp(outputSize, 2, 90);
        var start = quote.PreviousClose ?? quote.Price;
        var end = quote.Price;
        var delta = end - start;
        var seed = (int)((end * 1000m) % int.MaxValue);
        var rng = new Random(seed);
        var prev = start;

        for (var i = 0; i < size; i++)
        {
            var ratio = size == 1 ? 1m : (decimal)i / (size - 1);
            var baseline = start + (delta * ratio);
            var volatility = Math.Max(Math.Abs(start * 0.006m), 0.01m);
            var noise = ((decimal)rng.NextDouble() - 0.5m) * volatility;
            var meanReversion = (baseline - prev) * 0.45m;
            var value = prev + meanReversion + noise;
            prev = value;

            if (i == 0) value = start;
            if (i == size - 1) value = end;

            var timestamp = DateTime.UtcNow.AddDays(-(size - 1 - i)).ToString("yyyy-MM-dd HH:mm:ss");
            points.Add(new PriceHistoryPoint(timestamp, Math.Round(value, 6)));
        }

        return points;
    }

    private bool TryGetQuoteFromMemory(string symbol, out QuoteData quote)
    {
        var cacheKey = $"td:quote:last:{symbol}";
        if (_memoryCache.TryGetValue(cacheKey, out QuoteData? cached) && cached != null)
        {
            quote = cached;
            return true;
        }

        quote = default!;
        return false;
    }

    private void SetQuoteInMemory(string symbol, QuoteData quote)
    {
        var cacheKey = $"td:quote:last:{symbol}";
        _memoryCache.Set(cacheKey, quote with { IsStale = false }, TimeSpan.FromMinutes(_config.CacheMinutes));
    }

    private async Task UpsertPriceCacheAsync(string symbol, QuoteData quote)
    {
        var existing = await _db.AssetPriceCache.FindAsync(symbol);
        if (existing != null)
        {
            existing.Price = quote.Price;
            existing.PreviousClose = quote.PreviousClose;
            existing.ChangePercent = quote.ChangePercent;
            existing.Currency = quote.Currency;
            existing.FetchedAt = DateTime.UtcNow;
        }
        else
        {
            _db.AssetPriceCache.Add(new AssetPriceCache
            {
                Symbol = symbol,
                Price = quote.Price,
                PreviousClose = quote.PreviousClose,
                ChangePercent = quote.ChangePercent,
                Currency = quote.Currency,
                FetchedAt = DateTime.UtcNow
            });
        }

        await _db.SaveChangesAsync();
    }
}

public record QuoteData(decimal Price, decimal? PreviousClose, decimal? ChangePercent, string Currency, bool IsStale);
public record PriceHistoryPoint(string Datetime, decimal Close);
public record TrendingQuote(string Symbol, string Name, decimal Price, decimal? ChangePercent, string Currency, bool IsStale, string AssetType);
public record TrendingSnapshot(List<TrendingQuote> Stocks, List<TrendingQuote> Crypto);
