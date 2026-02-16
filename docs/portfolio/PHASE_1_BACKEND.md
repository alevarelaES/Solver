# Phase 1 — Backend : Services Twelve Data + Finnhub + Endpoints API

## Objectif
Intégrer les APIs Twelve Data (prix, historique) et Finnhub (news, fondamentaux), mettre en place le cache, et exposer les endpoints REST pour le portfolio et la watchlist.

## Prérequis
- Phase 0 terminée (tables + modèles EF Core en place)
- Compte Twelve Data créé → API key obtenue (gratuit) : https://twelvedata.com/
- Compte Finnhub créé → API key obtenue (gratuit) : https://finnhub.io/
- API keys ajoutées dans `.env`

## 1. Configuration

### .env — ajouter
```
TWELVE_DATA_API_KEY=your_api_key
TWELVE_DATA_BASE_URL=https://api.twelvedata.com
TWELVE_DATA_CACHE_MINUTES=5

FINNHUB_API_KEY=your_api_key
FINNHUB_BASE_URL=https://finnhub.io/api/v1
FINNHUB_CACHE_MINUTES=60
```

### Program.cs — charger la config
```csharp
// --- Twelve Data (prix, historique, recherche) ---
var twelveDataApiKey = Environment.GetEnvironmentVariable("TWELVE_DATA_API_KEY")
    ?? throw new InvalidOperationException("TWELVE_DATA_API_KEY not set");
var twelveDataBaseUrl = Environment.GetEnvironmentVariable("TWELVE_DATA_BASE_URL")
    ?? "https://api.twelvedata.com";
var tdCacheMinutes = int.TryParse(
    Environment.GetEnvironmentVariable("TWELVE_DATA_CACHE_MINUTES"), out var cm) ? cm : 5;

builder.Services.AddHttpClient("TwelveData", client =>
{
    client.BaseAddress = new Uri(twelveDataBaseUrl);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

builder.Services.AddSingleton(new TwelveDataConfig(twelveDataApiKey, tdCacheMinutes));
builder.Services.AddScoped<TwelveDataService>();

// --- Finnhub (news, profil entreprise, sentiment) ---
var finnhubApiKey = Environment.GetEnvironmentVariable("FINNHUB_API_KEY")
    ?? throw new InvalidOperationException("FINNHUB_API_KEY not set");
var finnhubBaseUrl = Environment.GetEnvironmentVariable("FINNHUB_BASE_URL")
    ?? "https://finnhub.io/api/v1";
var fhCacheMinutes = int.TryParse(
    Environment.GetEnvironmentVariable("FINNHUB_CACHE_MINUTES"), out var fcm) ? fcm : 60;

builder.Services.AddHttpClient("Finnhub", client =>
{
    client.BaseAddress = new Uri(finnhubBaseUrl);
    client.DefaultRequestHeaders.Add("X-Finnhub-Token", finnhubApiKey);
    client.DefaultRequestHeaders.Add("Accept", "application/json");
});

builder.Services.AddSingleton(new FinnhubConfig(finnhubApiKey, fhCacheMinutes));
builder.Services.AddScoped<FinnhubService>();
```

## 2. Service Twelve Data

### Fichier : `Services/TwelveDataConfig.cs`
```csharp
namespace Solver.Api.Services;

public record TwelveDataConfig(string ApiKey, int CacheMinutes);
```

### Fichier : `Services/TwelveDataService.cs`

Responsabilités :
- Fetch prix d'un ou plusieurs symboles
- Fetch historique (daily/weekly)
- Recherche de symboles (autocomplete)
- Gestion du cache en DB

```csharp
namespace Solver.Api.Services;

public class TwelveDataService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly TwelveDataConfig _config;
    private readonly SolverDbContext _db;

    public TwelveDataService(
        IHttpClientFactory httpClientFactory,
        TwelveDataConfig config,
        SolverDbContext db)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
        _db = db;
    }

    // --- PRIX EN BATCH ---
    // GET /quote?symbol=AAPL,MSFT,TSLA&apikey=xxx
    // Twelve Data supporte jusqu'à 8 symboles par appel batch
    public async Task<Dictionary<string, QuoteResult>> GetQuotes(IEnumerable<string> symbols)
    {
        // 1. Vérifier le cache DB
        var symbolList = symbols.Distinct().ToList();
        var cutoff = DateTime.UtcNow.AddMinutes(-_config.CacheMinutes);
        var cached = await _db.AssetPriceCache
            .Where(p => symbolList.Contains(p.Symbol) && p.FetchedAt > cutoff)
            .ToDictionaryAsync(p => p.Symbol);

        var stale = symbolList.Where(s => !cached.ContainsKey(s)).ToList();
        if (stale.Count == 0) return MapFromCache(cached);

        // 2. Fetch les prix manquants/périmés (batch de 8 max)
        var results = new Dictionary<string, QuoteResult>();
        foreach (var batch in stale.Chunk(8))
        {
            var fetched = await FetchQuoteBatch(batch);
            foreach (var (symbol, quote) in fetched)
            {
                results[symbol] = quote;
                await UpsertPriceCache(symbol, quote);
            }
        }

        // 3. Merger cache frais + nouveaux résultats
        foreach (var (symbol, cache) in cached)
            results[symbol] = MapFromCacheEntry(cache);

        return results;
    }

    // --- RECHERCHE DE SYMBOLES ---
    // GET /symbol_search?symbol=appl&apikey=xxx
    public async Task<List<SymbolSearchResult>> SearchSymbols(string query)
    {
        var client = _httpClientFactory.CreateClient("TwelveData");
        var response = await client.GetFromJsonAsync<SymbolSearchResponse>(
            $"/symbol_search?symbol={Uri.EscapeDataString(query)}&apikey={_config.ApiKey}");
        return response?.Data ?? [];
    }

    // --- HISTORIQUE ---
    // GET /time_series?symbol=AAPL&interval=1day&outputsize=30&apikey=xxx
    public async Task<List<TimeSeriesPoint>> GetTimeSeries(
        string symbol, string interval = "1day", int outputSize = 30)
    {
        var client = _httpClientFactory.CreateClient("TwelveData");
        var response = await client.GetFromJsonAsync<TimeSeriesResponse>(
            $"/time_series?symbol={Uri.EscapeDataString(symbol)}" +
            $"&interval={interval}&outputsize={outputSize}&apikey={_config.ApiKey}");
        return response?.Values ?? [];
    }

    // --- HELPERS PRIVÉS ---
    private async Task<Dictionary<string, QuoteResult>> FetchQuoteBatch(string[] symbols)
    {
        var client = _httpClientFactory.CreateClient("TwelveData");
        var joined = string.Join(",", symbols);
        // ... appel HTTP + parsing JSON
        // Retourne un dict symbol → QuoteResult
    }

    private async Task UpsertPriceCache(string symbol, QuoteResult quote)
    {
        var existing = await _db.AssetPriceCache.FindAsync(symbol);
        if (existing != null)
        {
            existing.Price = quote.Price;
            existing.PreviousClose = quote.PreviousClose;
            existing.ChangePercent = quote.ChangePercent;
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
```

### DTOs Twelve Data — `Services/TwelveDataModels.cs`

```csharp
namespace Solver.Api.Services;

public record QuoteResult(
    decimal Price,
    decimal? PreviousClose,
    decimal? ChangePercent,
    string Currency);

public record SymbolSearchResult(
    string Symbol,
    string InstrumentName,
    string Exchange,
    string InstrumentType,
    string Country);

public record SymbolSearchResponse(List<SymbolSearchResult> Data);

public record TimeSeriesPoint(
    string Datetime,
    decimal Open,
    decimal High,
    decimal Low,
    decimal Close,
    long Volume);

public record TimeSeriesResponse(List<TimeSeriesPoint> Values);
```

## 3. Service Finnhub

### Fichier : `Services/FinnhubConfig.cs`
```csharp
namespace Solver.Api.Services;

public record FinnhubConfig(string ApiKey, int CacheMinutes);
```

### Fichier : `Services/FinnhubService.cs`

Responsabilités :
- Fetch profil entreprise (secteur, capitalisation, logo, pays)
- Fetch news par symbole
- Fetch sentiment / recommandations analystes
- Cache en mémoire (1h par défaut — ces données changent peu)

```csharp
namespace Solver.Api.Services;

public class FinnhubService
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly FinnhubConfig _config;
    private readonly IMemoryCache _cache; // Microsoft.Extensions.Caching.Memory

    public FinnhubService(
        IHttpClientFactory httpClientFactory,
        FinnhubConfig config,
        IMemoryCache cache)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
        _cache = cache;
    }

    // --- PROFIL ENTREPRISE ---
    // GET /stock/profile2?symbol=AAPL
    // Retourne : name, logo, sector, marketCap, country, exchange, ipo, etc.
    public async Task<CompanyProfile?> GetCompanyProfile(string symbol)
    {
        var cacheKey = $"finnhub:profile:{symbol}";
        if (_cache.TryGetValue(cacheKey, out CompanyProfile? cached)) return cached;

        var client = _httpClientFactory.CreateClient("Finnhub");
        var profile = await client.GetFromJsonAsync<CompanyProfile>(
            $"/stock/profile2?symbol={Uri.EscapeDataString(symbol)}");

        if (profile != null)
            _cache.Set(cacheKey, profile, TimeSpan.FromMinutes(_config.CacheMinutes));

        return profile;
    }

    // --- NEWS PAR SYMBOLE ---
    // GET /company-news?symbol=AAPL&from=2026-02-09&to=2026-02-16
    // Retourne : liste d'articles (headline, summary, url, image, source, datetime)
    public async Task<List<CompanyNews>> GetCompanyNews(string symbol, int days = 7)
    {
        var cacheKey = $"finnhub:news:{symbol}";
        if (_cache.TryGetValue(cacheKey, out List<CompanyNews>? cached)) return cached!;

        var client = _httpClientFactory.CreateClient("Finnhub");
        var to = DateTime.UtcNow.ToString("yyyy-MM-dd");
        var from = DateTime.UtcNow.AddDays(-days).ToString("yyyy-MM-dd");
        var news = await client.GetFromJsonAsync<List<CompanyNews>>(
            $"/company-news?symbol={Uri.EscapeDataString(symbol)}&from={from}&to={to}");

        var result = news?.Take(10).ToList() ?? []; // limiter à 10 articles
        _cache.Set(cacheKey, result, TimeSpan.FromMinutes(30)); // cache 30 min pour les news
        return result;
    }

    // --- SENTIMENT / RECOMMANDATIONS ANALYSTES ---
    // GET /stock/recommendation?symbol=AAPL
    // Retourne : buy, hold, sell, strongBuy, strongSell, period
    public async Task<List<AnalystRecommendation>> GetRecommendations(string symbol)
    {
        var cacheKey = $"finnhub:reco:{symbol}";
        if (_cache.TryGetValue(cacheKey, out List<AnalystRecommendation>? cached)) return cached!;

        var client = _httpClientFactory.CreateClient("Finnhub");
        var recos = await client.GetFromJsonAsync<List<AnalystRecommendation>>(
            $"/stock/recommendation?symbol={Uri.EscapeDataString(symbol)}");

        var result = recos?.Take(4).ToList() ?? []; // 4 derniers mois
        _cache.Set(cacheKey, result, TimeSpan.FromMinutes(_config.CacheMinutes));
        return result;
    }
}
```

### DTOs Finnhub — `Services/FinnhubModels.cs`

```csharp
namespace Solver.Api.Services;

public record CompanyProfile(
    string Name,
    string Ticker,
    string Exchange,
    string FinnhubIndustry,  // secteur
    string Country,
    string Currency,
    decimal MarketCapitalization, // en millions
    string Logo,               // URL du logo
    string Ipo,                // date d'IPO
    string WebUrl);

public record CompanyNews(
    string Category,
    long Datetime,             // unix timestamp
    string Headline,
    string Image,              // URL image
    string Related,            // symbole
    string Source,
    string Summary,
    string Url);

public record AnalystRecommendation(
    int Buy,
    int Hold,
    int Sell,
    int StrongBuy,
    int StrongSell,
    string Period);            // "2026-02-01"
```

### Note sur le cache Finnhub
Finnhub utilise un **cache en mémoire** (`IMemoryCache`) plutôt qu'en DB car :
- Les données (profil, news) sont volumineuses et semi-structurées
- Pas besoin de persister entre les redémarrages du backend
- Le cache DB (`asset_price_cache`) reste dédié aux prix Twelve Data

Ajouter dans `Program.cs` :
```csharp
builder.Services.AddMemoryCache();
```

## 4. Endpoints API

### Fichier : `Endpoints/PortfolioEndpoints.cs`

```
GET    /api/portfolio              → Liste des positions + prix actuels
POST   /api/portfolio              → Ajouter une position
PUT    /api/portfolio/{id}         → Modifier une position (quantité, prix achat, notes)
DELETE /api/portfolio/{id}         → Supprimer une position
PATCH  /api/portfolio/{id}/archive → Archiver une position

GET    /api/watchlist              → Liste de la watchlist + prix actuels
POST   /api/watchlist              → Ajouter un symbole à la watchlist
DELETE /api/watchlist/{id}         → Retirer de la watchlist
PUT    /api/watchlist/reorder      → Réordonner la watchlist

GET    /api/market/search?q=apple  → Recherche de symboles (autocomplete)
GET    /api/market/quote?symbols=AAPL,MSFT → Prix batch
GET    /api/market/history/{symbol}?interval=1day&days=30 → Historique

GET    /api/market/profile/{symbol}        → Profil entreprise (Finnhub)
GET    /api/market/news/{symbol}           → News récentes (Finnhub)
GET    /api/market/recommendations/{symbol} → Recommandations analystes (Finnhub)
```

### Détail des endpoints principaux

#### GET /api/portfolio
```
Response 200:
{
  "holdings": [
    {
      "id": "uuid",
      "symbol": "AAPL",
      "name": "Apple Inc.",
      "exchange": "NASDAQ",
      "assetType": "stock",
      "quantity": 10,
      "averageBuyPrice": 150.00,
      "currentPrice": 178.50,         // ← enrichi par Twelve Data
      "changePercent": 1.23,           // ← variation du jour
      "totalValue": 1785.00,           // ← quantity * currentPrice
      "totalGainLoss": 285.00,         // ← totalValue - (quantity * avgBuyPrice)
      "totalGainLossPercent": 19.0,    // ← gain/loss en %
      "currency": "USD"
    }
  ],
  "summary": {
    "totalValue": 15420.50,
    "totalInvested": 12000.00,
    "totalGainLoss": 3420.50,
    "totalGainLossPercent": 28.5,
    "holdingsCount": 5
  }
}
```

**Logique clé :**
1. Fetch toutes les positions non-archivées du user
2. Collecter tous les symboles uniques
3. Appeler `TwelveDataService.GetQuotes(symbols)` → cache ou API
4. Enrichir chaque holding avec le prix actuel
5. Calculer les totaux (valeur, gain/perte)

#### POST /api/portfolio
```
Request:
{
  "symbol": "AAPL",
  "exchange": "NASDAQ",         // optionnel
  "name": "Apple Inc.",         // optionnel, peut être auto-fill via search
  "assetType": "stock",
  "quantity": 10,
  "averageBuyPrice": 150.00,   // optionnel
  "buyDate": "2024-06-15",     // optionnel
  "notes": "Achat long terme"  // optionnel
}
```

#### GET /api/market/search?q=apple
```
Response 200:
{
  "results": [
    { "symbol": "AAPL", "name": "Apple Inc.", "exchange": "NASDAQ", "type": "stock", "country": "US" },
    { "symbol": "AAPL.LON", "name": "Apple Inc.", "exchange": "LSE", "type": "stock", "country": "GB" }
  ]
}
```

#### GET /api/market/profile/AAPL
```
Response 200:
{
  "name": "Apple Inc.",
  "ticker": "AAPL",
  "exchange": "NASDAQ",
  "sector": "Technology",
  "country": "US",
  "currency": "USD",
  "marketCap": 2890000,
  "logo": "https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/AAPL.png",
  "ipo": "1980-12-12",
  "webUrl": "https://www.apple.com"
}
```

#### GET /api/market/news/AAPL
```
Response 200:
{
  "news": [
    {
      "headline": "Apple Reports Record Q1 Revenue",
      "summary": "Apple Inc. reported quarterly revenue of...",
      "source": "Reuters",
      "url": "https://...",
      "image": "https://...",
      "datetime": "2026-02-15T14:30:00Z"
    }
  ]
}
```

#### GET /api/market/recommendations/AAPL
```
Response 200:
{
  "recommendations": [
    { "period": "2026-02-01", "buy": 24, "hold": 7, "sell": 1, "strongBuy": 12, "strongSell": 0 },
    { "period": "2026-01-01", "buy": 22, "hold": 8, "sell": 2, "strongBuy": 11, "strongSell": 0 }
  ]
}
```

## 4. Rate Limiting côté backend

Pour ne pas dépasser les 800 appels/jour et 8/min :

```csharp
// Services/TwelveDataRateLimiter.cs
public class TwelveDataRateLimiter
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    private int _callsThisMinute = 0;
    private int _callsToday = 0;
    private DateTime _minuteStart = DateTime.UtcNow;
    private DateTime _dayStart = DateTime.UtcNow.Date;

    public async Task<bool> TryAcquireAsync()
    {
        await _semaphore.WaitAsync();
        try
        {
            var now = DateTime.UtcNow;

            // Reset compteur minute
            if ((now - _minuteStart).TotalMinutes >= 1)
            {
                _callsThisMinute = 0;
                _minuteStart = now;
            }

            // Reset compteur jour
            if (now.Date > _dayStart)
            {
                _callsToday = 0;
                _dayStart = now.Date;
            }

            if (_callsThisMinute >= 7 || _callsToday >= 780) // marge de sécurité
                return false;

            _callsThisMinute++;
            _callsToday++;
            return true;
        }
        finally
        {
            _semaphore.Release();
        }
    }
}
```

## 6. Gestion des erreurs Twelve Data

| Code HTTP | Signification | Action |
|-----------|--------------|--------|
| 200 | OK | Parser normalement |
| 401 | API key invalide | Log erreur, retourner 503 au client |
| 429 | Rate limit atteint | Attendre, retourner cache périmé si dispo |
| 500+ | Erreur Twelve Data | Retourner cache périmé si dispo, sinon 503 |

**Principe : ne jamais crasher si une API externe est down.** Retourner les dernières données en cache, même périmées, avec un flag `isStale: true`. Cela s'applique à Twelve Data ET Finnhub.

## Checklist Phase 1

### Twelve Data (prix, historique)
- [ ] Créer `TwelveDataConfig.cs`
- [ ] Créer `TwelveDataModels.cs` (DTOs)
- [ ] Créer `TwelveDataService.cs` (fetch + cache DB)
- [ ] Créer `TwelveDataRateLimiter.cs`

### Finnhub (news, profil, sentiment)
- [ ] Créer `FinnhubConfig.cs`
- [ ] Créer `FinnhubModels.cs` (DTOs)
- [ ] Créer `FinnhubService.cs` (fetch + cache mémoire)
- [ ] Ajouter `builder.Services.AddMemoryCache()` dans Program.cs

### Endpoints & intégration
- [ ] Enregistrer tous les services dans `Program.cs`
- [ ] Créer `PortfolioEndpoints.cs` (CRUD holdings)
- [ ] Créer `WatchlistEndpoints.cs` (CRUD watchlist)
- [ ] Créer `MarketEndpoints.cs` (search, quote, history, profile, news, recommendations)
- [ ] Ajouter `TWELVE_DATA_API_KEY` et `FINNHUB_API_KEY` dans `.env`
- [ ] Tester via curl/Postman : search → add holding → get portfolio avec prix
- [ ] Tester via curl/Postman : profile → news → recommendations
