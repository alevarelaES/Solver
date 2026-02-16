using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace Solver.Api.Services;

public sealed class TwelveDataWebSocketService : BackgroundService, IDisposable
{
    private readonly TwelveDataConfig _config;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<TwelveDataWebSocketService> _logger;
    private readonly SemaphoreSlim _socketLock = new(1, 1);
    private readonly Uri _wsUri;

    private ClientWebSocket? _socket;
    private string? _currentSymbol;

    public event Action<LivePriceUpdate>? PriceUpdated;

    public TwelveDataWebSocketService(
        TwelveDataConfig config,
        IServiceScopeFactory scopeFactory,
        ILogger<TwelveDataWebSocketService> logger)
    {
        _config = config;
        _scopeFactory = scopeFactory;
        _logger = logger;

        var wsBaseUrl = Environment.GetEnvironmentVariable("TWELVE_DATA_WS_URL")
            ?? "wss://ws.twelvedata.com/v1/quotes/price";
        _wsUri = new Uri($"{wsBaseUrl}?apikey={Uri.EscapeDataString(_config.ApiKey)}");
    }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_config.ApiKey)
        && !string.Equals(_config.ApiKey, "your_twelve_data_api_key", StringComparison.OrdinalIgnoreCase);

    public async Task<bool> SubscribeToSymbolAsync(string symbol, CancellationToken ct = default)
    {
        if (!IsConfigured)
            return false;

        if (string.IsNullOrWhiteSpace(symbol))
            return false;

        var normalized = symbol.Trim().ToUpperInvariant();

        await _socketLock.WaitAsync(ct);
        try
        {
            await EnsureConnectedAsync(ct);
            if (_socket == null || _socket.State != WebSocketState.Open)
                return false;

            if (string.Equals(_currentSymbol, normalized, StringComparison.OrdinalIgnoreCase))
                return true;

            if (!string.IsNullOrWhiteSpace(_currentSymbol))
            {
                await SendJsonAsync(new
                {
                    action = "unsubscribe",
                    @params = new { symbols = _currentSymbol }
                }, ct);
            }

            await SendJsonAsync(new
            {
                action = "subscribe",
                @params = new { symbols = normalized }
            }, ct);

            _currentSymbol = normalized;
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to subscribe TwelveData WebSocket to {Symbol}", normalized);
            return false;
        }
        finally
        {
            _socketLock.Release();
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!IsConfigured)
        {
            _logger.LogInformation("TwelveData WebSocket disabled (missing API key).");
            return;
        }

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await EnsureConnectedAsync(stoppingToken);
                if (_socket == null)
                {
                    await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
                    continue;
                }

                await ReceiveLoopAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "TwelveData WebSocket loop failed, reconnecting...");
            }

            await DisposeSocketAsync();
            await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);
        }
    }

    private async Task EnsureConnectedAsync(CancellationToken ct)
    {
        if (_socket is { State: WebSocketState.Open })
            return;

        await DisposeSocketAsync();

        var socket = new ClientWebSocket();
        await socket.ConnectAsync(_wsUri, ct);
        _socket = socket;

        _logger.LogInformation("Connected to TwelveData WebSocket.");

        if (!string.IsNullOrWhiteSpace(_currentSymbol))
        {
            await SendJsonAsync(new
            {
                action = "subscribe",
                @params = new { symbols = _currentSymbol }
            }, ct);
        }
    }

    private async Task SendJsonAsync(object payload, CancellationToken ct)
    {
        if (_socket == null || _socket.State != WebSocketState.Open)
            return;

        var json = JsonSerializer.Serialize(payload);
        var bytes = Encoding.UTF8.GetBytes(json);
        await _socket.SendAsync(
            new ArraySegment<byte>(bytes),
            WebSocketMessageType.Text,
            true,
            ct);
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        if (_socket == null)
            return;

        var buffer = new byte[4096];
        using var ms = new MemoryStream();

        while (!ct.IsCancellationRequested && _socket.State == WebSocketState.Open)
        {
            var result = await _socket.ReceiveAsync(new ArraySegment<byte>(buffer), ct);

            if (result.MessageType == WebSocketMessageType.Close)
            {
                _logger.LogInformation("TwelveData WebSocket closed by server.");
                return;
            }

            ms.Write(buffer, 0, result.Count);

            if (!result.EndOfMessage)
                continue;

            var message = Encoding.UTF8.GetString(ms.ToArray());
            ms.SetLength(0);

            var update = TryParsePriceUpdate(message);
            if (update == null)
                continue;

            await PersistPriceAsync(update, ct);
            PriceUpdated?.Invoke(update);
        }
    }

    private LivePriceUpdate? TryParsePriceUpdate(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!root.TryGetProperty("event", out var eventElem)
                || !string.Equals(eventElem.GetString(), "price", StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            if (!root.TryGetProperty("symbol", out var symbolElem))
                return null;

            var symbol = symbolElem.GetString();
            if (string.IsNullOrWhiteSpace(symbol))
                return null;

            if (!root.TryGetProperty("price", out var priceElem))
                return null;

            decimal price;
            if (priceElem.ValueKind == JsonValueKind.Number)
            {
                if (!priceElem.TryGetDecimal(out price))
                    return null;
            }
            else
            {
                if (!decimal.TryParse(
                        priceElem.GetString(),
                        System.Globalization.NumberStyles.Any,
                        System.Globalization.CultureInfo.InvariantCulture,
                        out price))
                {
                    return null;
                }
            }

            return new LivePriceUpdate(symbol.Trim().ToUpperInvariant(), price, DateTime.UtcNow);
        }
        catch (Exception ex)
        {
            _logger.LogDebug(ex, "Ignoring invalid TwelveData WebSocket payload: {Payload}", json);
            return null;
        }
    }

    private async Task PersistPriceAsync(LivePriceUpdate update, CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var service = scope.ServiceProvider.GetRequiredService<TwelveDataService>();
        await service.UpdateCachedPriceAsync(update.Symbol, update.Price, ct);
    }

    private async Task DisposeSocketAsync()
    {
        if (_socket == null)
            return;

        try
        {
            if (_socket.State == WebSocketState.Open)
            {
                await _socket.CloseAsync(
                    WebSocketCloseStatus.NormalClosure,
                    "Closing",
                    CancellationToken.None);
            }
        }
        catch
        {
            // Ignore close errors.
        }

        _socket.Dispose();
        _socket = null;
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        await base.StopAsync(cancellationToken);
        await DisposeSocketAsync();
    }

    public override void Dispose()
    {
        _socketLock.Dispose();
        _socket?.Dispose();
        base.Dispose();
    }
}

public sealed record LivePriceUpdate(string Symbol, decimal Price, DateTime TimestampUtc);
