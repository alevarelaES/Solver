using System.Text.Json.Serialization;

namespace Solver.Api.Services;

public record TwelveDataQuote(
    [property: JsonPropertyName("symbol")] string Symbol,
    [property: JsonPropertyName("name")] string? Name,
    [property: JsonPropertyName("exchange")] string? Exchange,
    [property: JsonPropertyName("currency")] string? Currency,
    [property: JsonPropertyName("close")] string? Close,
    [property: JsonPropertyName("previous_close")] string? PreviousClose,
    [property: JsonPropertyName("change")] string? Change,
    [property: JsonPropertyName("percent_change")] string? PercentChange);

public record TwelveDataSymbolSearch(
    [property: JsonPropertyName("symbol")] string Symbol,
    [property: JsonPropertyName("instrument_name")] string InstrumentName,
    [property: JsonPropertyName("exchange")] string Exchange,
    [property: JsonPropertyName("instrument_type")] string InstrumentType,
    [property: JsonPropertyName("country")] string Country);

public record TwelveDataSymbolSearchResponse(
    [property: JsonPropertyName("data")] List<TwelveDataSymbolSearch>? Data);

public record TwelveDataTimeSeriesPoint(
    [property: JsonPropertyName("datetime")] string Datetime,
    [property: JsonPropertyName("open")] string Open,
    [property: JsonPropertyName("high")] string High,
    [property: JsonPropertyName("low")] string Low,
    [property: JsonPropertyName("close")] string Close,
    [property: JsonPropertyName("volume")] string? Volume);

public record TwelveDataTimeSeriesResponse(
    [property: JsonPropertyName("values")] List<TwelveDataTimeSeriesPoint>? Values);
