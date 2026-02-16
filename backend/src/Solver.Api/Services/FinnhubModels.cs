using System.Text.Json.Serialization;

namespace Solver.Api.Services;

public record FinnhubCompanyProfile(
    [property: JsonPropertyName("name")] string? Name,
    [property: JsonPropertyName("ticker")] string? Ticker,
    [property: JsonPropertyName("exchange")] string? Exchange,
    [property: JsonPropertyName("finnhubIndustry")] string? FinnhubIndustry,
    [property: JsonPropertyName("country")] string? Country,
    [property: JsonPropertyName("currency")] string? Currency,
    [property: JsonPropertyName("marketCapitalization")] decimal? MarketCapitalization,
    [property: JsonPropertyName("logo")] string? Logo,
    [property: JsonPropertyName("ipo")] string? Ipo,
    [property: JsonPropertyName("weburl")] string? WebUrl);

public record FinnhubCompanyNews(
    [property: JsonPropertyName("category")] string? Category,
    [property: JsonPropertyName("datetime")] long Datetime,
    [property: JsonPropertyName("headline")] string? Headline,
    [property: JsonPropertyName("image")] string? Image,
    [property: JsonPropertyName("related")] string? Related,
    [property: JsonPropertyName("source")] string? Source,
    [property: JsonPropertyName("summary")] string? Summary,
    [property: JsonPropertyName("url")] string? Url);

public record FinnhubRecommendation(
    [property: JsonPropertyName("buy")] int Buy,
    [property: JsonPropertyName("hold")] int Hold,
    [property: JsonPropertyName("sell")] int Sell,
    [property: JsonPropertyName("strongBuy")] int StrongBuy,
    [property: JsonPropertyName("strongSell")] int StrongSell,
    [property: JsonPropertyName("period")] string? Period);
