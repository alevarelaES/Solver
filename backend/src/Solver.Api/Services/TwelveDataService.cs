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
        var symbolList = symbols.Distinct().ToList();
        if (symbolList.Count == 0) return [];

        var cutoff = DateTime.UtcNow.AddMinutes(-_config.CacheMinutes);
        var cached = await _db.AssetPriceCache
            .Where(p => symbolList.Contains(p.Symbol) && p.FetchedAt > cutoff)
            .ToListAsync();

        var results = cached.ToDictionary(
            c => c.Symbol,
            c => new QuoteData(c.Price, c.PreviousClose, c.ChangePercent, c.Currency, false));

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
                    results.TryAdd(sc.Symbol, new QuoteData(sc.Price, sc.PreviousClose, sc.ChangePercent, sc.Currency, true));
                continue;
            }

            try
            {
                var fetched = await FetchQuoteBatchAsync(batch);
                foreach (var (symbol, quote) in fetched)
                {
                    results[symbol] = quote;
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
                    results.TryAdd(sc.Symbol, new QuoteData(sc.Price, sc.PreviousClose, sc.ChangePercent, sc.Currency, true));
            }
        }

        return results;
    }

    public async Task<List<TwelveDataSymbolSearch>> SearchSymbolsAsync(string query)
    {
        if (!await _rateLimiter.TryAcquireAsync())
            return [];

        try
        {
            var client = _httpClientFactory.CreateClient("TwelveData");
            var response = await client.GetFromJsonAsync<TwelveDataSymbolSearchResponse>(
                $"/symbol_search?symbol={Uri.EscapeDataString(query)}&apikey={_config.ApiKey}");
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
        if (!await _rateLimiter.TryAcquireAsync())
            return [];

        try
        {
            var client = _httpClientFactory.CreateClient("TwelveData");
            var response = await client.GetFromJsonAsync<TwelveDataTimeSeriesResponse>(
                $"/time_series?symbol={Uri.EscapeDataString(symbol)}" +
                $"&interval={interval}&outputsize={outputSize}&apikey={_config.ApiKey}");
            return response?.Values ?? [];
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "TwelveData time series failed for {Symbol}", symbol);
            return [];
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

        foreach (var symbol in normalizedSymbols)
        {
            var cacheKey = $"td:history:{symbol}:{interval}:{outputSize}";
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
            _memoryCache.Set(cacheKey, points, TimeSpan.FromHours(1));
        }

        return result;
    }

    private static readonly string[] TrendingSymbols =
    [
        "AAPL", "MSFT", "GOOGL", "AMZN", "TSLA", "META", "NVDA", "NFLX",
        "JPM", "V", "JNJ", "WMT", "PG", "DIS", "PYPL", "AMD", "INTC",
        "BA", "CRM", "UBER"
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

    public async Task<List<TrendingQuote>> GetTrendingQuotesAsync()
    {
        var quotes = await GetQuotesAsync(TrendingSymbols);
        return quotes.Select(kv => new TrendingQuote(
            kv.Key,
            TrendingNames.GetValueOrDefault(kv.Key, kv.Key),
            kv.Value.Price,
            kv.Value.ChangePercent,
            kv.Value.Currency,
            kv.Value.IsStale
        )).OrderByDescending(t => Math.Abs(t.ChangePercent ?? 0)).ToList();
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
public record TrendingQuote(string Symbol, string Name, decimal Price, decimal? ChangePercent, string Currency, bool IsStale);
