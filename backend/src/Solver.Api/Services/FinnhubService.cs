using Microsoft.Extensions.Caching.Memory;

namespace Solver.Api.Services;

public class FinnhubService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly FinnhubConfig _config;
    private readonly IMemoryCache _cache;
    private readonly ILogger<FinnhubService> _logger;

    public FinnhubService(
        IHttpClientFactory httpClientFactory,
        FinnhubConfig config,
        IMemoryCache cache,
        ILogger<FinnhubService> logger)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
        _cache = cache;
        _logger = logger;
    }

    public async Task<FinnhubCompanyProfile?> GetCompanyProfileAsync(string symbol)
    {
        var cacheKey = $"finnhub:profile:{symbol}";
        if (_cache.TryGetValue(cacheKey, out FinnhubCompanyProfile? cached))
            return cached;

        try
        {
            var client = _httpClientFactory.CreateClient("Finnhub");
            var profile = await client.GetFromJsonAsync<FinnhubCompanyProfile>(
                $"stock/profile2?symbol={Uri.EscapeDataString(symbol)}");

            if (profile?.Name != null)
                _cache.Set(cacheKey, profile, TimeSpan.FromMinutes(_config.CacheMinutes));

            return profile;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Finnhub profile fetch failed for {Symbol}", symbol);
            return null;
        }
    }

    public async Task<List<FinnhubCompanyNews>> GetCompanyNewsAsync(string symbol, int days = 7)
    {
        var cacheKey = $"finnhub:news:{symbol}";
        if (_cache.TryGetValue(cacheKey, out List<FinnhubCompanyNews>? cached))
            return cached!;

        try
        {
            var client = _httpClientFactory.CreateClient("Finnhub");
            var to = DateTime.UtcNow.ToString("yyyy-MM-dd");
            var from = DateTime.UtcNow.AddDays(-days).ToString("yyyy-MM-dd");
            var news = await client.GetFromJsonAsync<List<FinnhubCompanyNews>>(
                $"company-news?symbol={Uri.EscapeDataString(symbol)}&from={from}&to={to}");

            var result = news?.Take(10).ToList() ?? [];
            _cache.Set(cacheKey, result, TimeSpan.FromMinutes(30));
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Finnhub news fetch failed for {Symbol}", symbol);
            return [];
        }
    }

    public async Task<List<FinnhubCompanyNews>> GetMarketNewsAsync()
    {
        var cacheKey = "finnhub:market_news";
        if (_cache.TryGetValue(cacheKey, out List<FinnhubCompanyNews>? cached))
            return cached!;

        try
        {
            var client = _httpClientFactory.CreateClient("Finnhub");
            var news = await client.GetFromJsonAsync<List<FinnhubCompanyNews>>(
                "news?category=general&minId=0");

            var result = news?.Take(15).ToList() ?? [];
            _cache.Set(cacheKey, result, TimeSpan.FromMinutes(30));
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Finnhub market news fetch failed");
            return [];
        }
    }

    public async Task<List<FinnhubRecommendation>> GetRecommendationsAsync(string symbol)
    {
        var cacheKey = $"finnhub:reco:{symbol}";
        if (_cache.TryGetValue(cacheKey, out List<FinnhubRecommendation>? cached))
            return cached!;

        try
        {
            var client = _httpClientFactory.CreateClient("Finnhub");
            var recos = await client.GetFromJsonAsync<List<FinnhubRecommendation>>(
                $"stock/recommendation?symbol={Uri.EscapeDataString(symbol)}");

            var result = recos?.Take(4).ToList() ?? [];
            _cache.Set(cacheKey, result, TimeSpan.FromMinutes(_config.CacheMinutes));
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Finnhub recommendations fetch failed for {Symbol}", symbol);
            return [];
        }
    }
}
