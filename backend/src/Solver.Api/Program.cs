using dotenv.net;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Middleware;
using Solver.Api.Services;

DotEnv.Load(options: new DotEnvOptions(envFilePaths: [".env"]));

static string NormalizePgConnectionString(string raw, string envVarName)
{
    if (string.IsNullOrWhiteSpace(raw))
    {
        throw new InvalidOperationException($"{envVarName} is empty.");
    }

    if (!raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
        && !raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
    {
        return raw;
    }

    if (!Uri.TryCreate(raw, UriKind.Absolute, out var uri))
    {
        throw new InvalidOperationException($"{envVarName} URI is invalid.");
    }

    if (!string.Equals(uri.Scheme, "postgres", StringComparison.OrdinalIgnoreCase)
        && !string.Equals(uri.Scheme, "postgresql", StringComparison.OrdinalIgnoreCase))
    {
        throw new InvalidOperationException($"{envVarName} must use postgres/postgresql scheme.");
    }

    var userInfo = uri.UserInfo ?? string.Empty;
    var userInfoParts = userInfo.Split(':', 2, StringSplitOptions.None);
    var username = userInfoParts.Length > 0 ? Uri.UnescapeDataString(userInfoParts[0]) : string.Empty;
    var password = userInfoParts.Length > 1 ? Uri.UnescapeDataString(userInfoParts[1]) : string.Empty;
    var database = uri.AbsolutePath.Trim('/');
    if (string.IsNullOrWhiteSpace(database))
    {
        database = "postgres";
    }

    var builder = new NpgsqlConnectionStringBuilder
    {
        Host = uri.Host,
        Port = uri.IsDefaultPort ? 5432 : uri.Port,
        Database = database,
        Username = username
    };
    if (!string.IsNullOrWhiteSpace(password))
    {
        builder.Password = password;
    }

    var query = uri.Query;
    if (!string.IsNullOrWhiteSpace(query))
    {
        var querySpan = query.AsSpan().TrimStart('?').ToString();
        var items = querySpan.Split('&', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        foreach (var item in items)
        {
            var idx = item.IndexOf('=');
            if (idx <= 0 || idx >= item.Length - 1)
            {
                continue;
            }

            var key = Uri.UnescapeDataString(item[..idx]).Replace("_", " ", StringComparison.Ordinal);
            var value = Uri.UnescapeDataString(item[(idx + 1)..]);
            try
            {
                builder[key] = value;
            }
            catch
            {
                // Ignore unknown query params from URI-style DSN.
            }
        }
    }

    return builder.ConnectionString;
}

var builder = WebApplication.CreateBuilder(args);
var isDevelopment = builder.Environment.IsDevelopment();

// Database
var baseConnectionStringRaw = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
    ?? throw new InvalidOperationException("DB_CONNECTION_STRING is not set.");
var baseConnectionString = NormalizePgConnectionString(baseConnectionStringRaw, "DB_CONNECTION_STRING");
var runtimeConnectionStringOverride = Environment.GetEnvironmentVariable("DB_RUNTIME_CONNECTION_STRING");
var runtimeRawConnectionString = string.IsNullOrWhiteSpace(runtimeConnectionStringOverride)
    ? baseConnectionString
    : NormalizePgConnectionString(runtimeConnectionStringOverride, "DB_RUNTIME_CONNECTION_STRING");

var connectionStringBuilder = new NpgsqlConnectionStringBuilder(runtimeRawConnectionString);
var dbHost = connectionStringBuilder.Host ?? string.Empty;
var forceDisablePooling = string.Equals(
    Environment.GetEnvironmentVariable("DB_DISABLE_POOLING"),
    "true",
    StringComparison.OrdinalIgnoreCase);
if (forceDisablePooling || dbHost.Contains("pooler.supabase.com", StringComparison.OrdinalIgnoreCase))
{
    // Supabase pooler already manages pooling; or force-disable for stability.
    // Local Npgsql pooling can create connector lifecycle races on some combos.
    connectionStringBuilder.Pooling = false;
    connectionStringBuilder.Multiplexing = false;
    connectionStringBuilder.NoResetOnClose = true;
}
var connectionString = connectionStringBuilder.ConnectionString;

builder.Services.AddDbContext<SolverDbContext>(options =>
    options.UseNpgsql(connectionString, npgsql =>
        npgsql
            // Keep EF provider retry disabled here: app-level retry is centralized
            // and this avoids connector disposal races during startup migrations.
            // Stability over throughput: avoid multi-command EF batches that can
            // trigger connector disposal races with some Npgsql/runtime combos.
            .MaxBatchSize(1)));

// Memory cache (for Finnhub service)
builder.Services.AddMemoryCache();

// Twelve Data (market prices, history, search)
var twelveDataApiKey = Environment.GetEnvironmentVariable("TWELVE_DATA_API_KEY") ?? "";
var twelveDataBaseUrl = Environment.GetEnvironmentVariable("TWELVE_DATA_BASE_URL") ?? "https://api.twelvedata.com";
var tdCacheMinutes = int.TryParse(Environment.GetEnvironmentVariable("TWELVE_DATA_CACHE_MINUTES"), out var tdCm) ? tdCm : 5;

if (!string.IsNullOrEmpty(twelveDataApiKey) && twelveDataApiKey != "your_twelve_data_api_key")
{
    builder.Services.AddHttpClient("TwelveData", client =>
    {
        client.BaseAddress = new Uri(twelveDataBaseUrl);
        client.DefaultRequestHeaders.Add("Accept", "application/json");
    });
}
builder.Services.AddSingleton(new TwelveDataConfig(twelveDataApiKey, tdCacheMinutes));
builder.Services.AddSingleton<TwelveDataRateLimiter>();
builder.Services.AddScoped<TwelveDataService>();
builder.Services.AddSingleton<TwelveDataWebSocketService>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<TwelveDataWebSocketService>());
builder.Services.AddSingleton<DbRetryService>();
builder.Services.AddScoped<AccountsService>();
builder.Services.AddScoped<DashboardService>();
builder.Services.AddScoped<AnalysisService>();
builder.Services.AddScoped<CategoriesService>();
builder.Services.AddScoped<BudgetService>();
builder.Services.AddScoped<GoalsService>();
builder.Services.AddScoped<TransactionsService>();
builder.Services.AddScoped<PortfolioService>();
builder.Services.AddScoped<WatchlistService>();
builder.Services.AddScoped<MarketService>();

// Auth hardening (fail-fast in non-dev when auth material is missing)
var supabaseUrl = Environment.GetEnvironmentVariable("SUPABASE_URL");
var jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET");
var allowLegacyHs256 = AppRuntimeSecurity.GetBoolEnv("AUTH_ALLOW_HS256_FALLBACK", isDevelopment);
if (!isDevelopment &&
    string.IsNullOrWhiteSpace(supabaseUrl) &&
    !(allowLegacyHs256 && !string.IsNullOrWhiteSpace(jwtSecret)))
{
    throw new InvalidOperationException(
        "Authentication is not configured for non-development. Configure SUPABASE_URL or enable AUTH_ALLOW_HS256_FALLBACK with JWT_SECRET.");
}

// Finnhub (company profile, news, recommendations)
var finnhubApiKey = Environment.GetEnvironmentVariable("FINNHUB_API_KEY") ?? "";
var finnhubBaseUrl = Environment.GetEnvironmentVariable("FINNHUB_BASE_URL") ?? "https://finnhub.io/api/v1";
var fhCacheMinutes = int.TryParse(Environment.GetEnvironmentVariable("FINNHUB_CACHE_MINUTES"), out var fhCm) ? fhCm : 60;

if (!string.IsNullOrEmpty(finnhubApiKey) && finnhubApiKey != "your_finnhub_api_key")
{
    builder.Services.AddHttpClient("Finnhub", client =>
    {
        client.BaseAddress = new Uri(finnhubBaseUrl.TrimEnd('/') + "/");
        client.DefaultRequestHeaders.Add("X-Finnhub-Token", finnhubApiKey);
        client.DefaultRequestHeaders.Add("Accept", "application/json");
    });
}
builder.Services.AddSingleton(new FinnhubConfig(finnhubApiKey, fhCacheMinutes));
builder.Services.AddScoped<FinnhubService>();

// Response compression (gzip)
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<GzipCompressionProvider>();
});

// CORS
var allowedOriginsParseResult = AppRuntimeSecurity.ParseAllowedOriginsDetailed(
    Environment.GetEnvironmentVariable("ALLOWED_ORIGINS"));
var allowedOrigins = allowedOriginsParseResult.Origins;
if (!isDevelopment && allowedOriginsParseResult.InvalidEntries.Length > 0)
{
    throw new InvalidOperationException(
        $"ALLOWED_ORIGINS contains invalid entries: {string.Join(", ", allowedOriginsParseResult.InvalidEntries)}");
}
if (!isDevelopment && allowedOrigins.Length == 0)
{
    throw new InvalidOperationException(
        "ALLOWED_ORIGINS must be configured in non-development environments.");
}

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (allowedOrigins.Length > 0)
        {
            // Production: restrict to specific origins
            policy
                .WithOrigins(allowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
        else
        {
            // Development: allow localhost
            policy
                .SetIsOriginAllowed(AppRuntimeSecurity.IsLocalDevelopmentOrigin)
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
    });
});

var app = builder.Build();

// HTTPS redirect in production
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Schema updates via EF migrations, then data migrations.
var applyMigrationsOnStartup = AppRuntimeSecurity.GetBoolEnv(
    "DB_APPLY_MIGRATIONS_ON_STARTUP",
    true);
var migrationConnectionString = Environment.GetEnvironmentVariable("DB_MIGRATIONS_CONNECTION_STRING");
var hasMigrationConnection = !string.IsNullOrWhiteSpace(migrationConnectionString)
    && !string.Equals(migrationConnectionString, "false", StringComparison.OrdinalIgnoreCase);
var usePrimaryConnectionForMigrations = !hasMigrationConnection;
var primaryConnectionHost = new NpgsqlConnectionStringBuilder(baseConnectionString).Host ?? string.Empty;
var primaryConnectionUsesSupabasePooler = primaryConnectionHost.Contains(
    "pooler.supabase.com",
    StringComparison.OrdinalIgnoreCase);

if (applyMigrationsOnStartup)
{
    if (usePrimaryConnectionForMigrations && primaryConnectionUsesSupabasePooler)
    {
        const string poolerMigrationMessage =
            "Automatic EF migrations are disabled when DB_CONNECTION_STRING points to Supabase pooler. " +
            "Set DB_MIGRATIONS_CONNECTION_STRING to a direct database host connection string " +
            "(recommended) or set DB_APPLY_MIGRATIONS_ON_STARTUP=false.";

        if (!app.Environment.IsDevelopment())
        {
            throw new InvalidOperationException(poolerMigrationMessage);
        }

        app.Logger.LogWarning(poolerMigrationMessage);
    }
    else
    {
        var migrationBuilder = new NpgsqlConnectionStringBuilder(
            usePrimaryConnectionForMigrations
                ? baseConnectionString
                : NormalizePgConnectionString(migrationConnectionString!, "DB_MIGRATIONS_CONNECTION_STRING"));
        migrationBuilder.Pooling = false;
        migrationBuilder.Multiplexing = false;
        migrationBuilder.NoResetOnClose = true;

        var migrationOptions = new DbContextOptionsBuilder<SolverDbContext>()
            .UseNpgsql(
                migrationBuilder.ConnectionString,
                npgsql => npgsql.MaxBatchSize(1))
            .Options;

        await using var migrationDb = new SolverDbContext(migrationOptions);
        await migrationDb.Database.MigrateAsync();
        await CategoryResetMigration.ApplyAsync(migrationDb);
        await CategoryGroupBackfillMigration.ApplyAsync(migrationDb);
    }
}

// Pipeline order matters
app.UseResponseCompression();
app.UseRouting();
app.UseCors();
app.UseMiddleware<SupabaseAuthMiddleware>();

// Endpoints
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapAccountsEndpoints();
app.MapCategoriesEndpoints();
app.MapTransactionsEndpoints();
app.MapDashboardEndpoints();
app.MapBudgetEndpoints();
app.MapGoalsEndpoints();
app.MapAnalysisEndpoints();
app.MapPortfolioEndpoints();
app.MapWatchlistEndpoints();
app.MapMarketEndpoints();

app.Run();

