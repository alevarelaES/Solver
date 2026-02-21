using System.IdentityModel.Tokens.Jwt;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using Solver.Api.Services;

namespace Solver.Api.Middleware;

public class SupabaseAuthMiddleware(RequestDelegate next)
{
    private static readonly HttpClient _http = new();
    private static readonly SemaphoreSlim _keysRefreshLock = new(1, 1);
    private static List<SecurityKey> _cachedKeys = [];
    private static DateTime _keysExpiry = DateTime.MinValue;
    private static readonly string? _supabaseUrl = Environment.GetEnvironmentVariable("SUPABASE_URL");
    private static readonly bool _isDevelopment = string.Equals(
        Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
        "Development",
        StringComparison.OrdinalIgnoreCase);

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/health")
            || context.Request.Method == HttpMethods.Options)
        {
            await next(context);
            return;
        }

        var token = TryGetBearerToken(context.Request.Headers.Authorization);
        if (string.IsNullOrWhiteSpace(token))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(
                new { error = "Missing or invalid authorization header" });
            return;
        }

        var userId = await ValidateTokenAsync(token);
        if (userId is null)
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new { error = "Invalid or expired token" });
            return;
        }

        context.Items["UserId"] = userId;
        await next(context);
    }

    private static async Task<List<SecurityKey>> GetSigningKeysAsync()
    {
        if (_cachedKeys.Count > 0 && DateTime.UtcNow < _keysExpiry)
        {
            return _cachedKeys;
        }

        await _keysRefreshLock.WaitAsync();
        try
        {
            if (_cachedKeys.Count > 0 && DateTime.UtcNow < _keysExpiry)
            {
                return _cachedKeys;
            }

            var keys = new List<SecurityKey>();

            if (!string.IsNullOrWhiteSpace(_supabaseUrl))
            {
                try
                {
                    var jwksJson = await _http.GetStringAsync(
                        $"{_supabaseUrl.TrimEnd('/')}/auth/v1/.well-known/jwks.json");
                    var jwks = new JsonWebKeySet(jwksJson);
                    keys.AddRange(jwks.GetSigningKeys());
                }
                catch
                {
                    // Keep legacy fallback behavior below.
                }
            }

            var allowHs256Fallback = AppRuntimeSecurity.GetBoolEnv(
                "AUTH_ALLOW_HS256_FALLBACK",
                false);
            var secret = Environment.GetEnvironmentVariable("JWT_SECRET");
            if (allowHs256Fallback && !string.IsNullOrWhiteSpace(secret))
            {
                keys.Add(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)));
            }

            _cachedKeys = keys;
            _keysExpiry = DateTime.UtcNow.AddHours(1);
            return keys;
        }
        finally
        {
            _keysRefreshLock.Release();
        }
    }

    private static async Task<Guid?> ValidateTokenAsync(string token)
    {
        try
        {
            var signingKeys = await GetSigningKeysAsync();
            if (signingKeys.Count == 0)
            {
                return null;
            }

            var explicitIssuer = Environment.GetEnvironmentVariable("SUPABASE_JWT_ISSUER");
            var validIssuer = AppRuntimeSecurity.BuildExpectedIssuer(_supabaseUrl, explicitIssuer);
            var validAudiences = AppRuntimeSecurity.ParseAudiences(
                Environment.GetEnvironmentVariable("JWT_ALLOWED_AUDIENCES"),
                includeDefaultAuthenticated: true);

            var validateIssuer = AppRuntimeSecurity.GetBoolEnv(
                "JWT_VALIDATE_ISSUER",
                !_isDevelopment && !string.IsNullOrWhiteSpace(validIssuer));
            var validateAudience = AppRuntimeSecurity.GetBoolEnv(
                "JWT_VALIDATE_AUDIENCE",
                !_isDevelopment && validAudiences.Length > 0);

            var handler = new JwtSecurityTokenHandler();
            handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = signingKeys,
                ValidateIssuer = validateIssuer,
                ValidIssuer = validIssuer,
                ValidateAudience = validateAudience,
                ValidAudiences = validAudiences,
                ClockSkew = TimeSpan.Zero,
            }, out var validatedToken);

            var jwt = (JwtSecurityToken)validatedToken;
            var sub = jwt.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
            return sub is not null && Guid.TryParse(sub, out var userId) ? userId : null;
        }
        catch
        {
            return null;
        }
    }

    private static string? TryGetBearerToken(string? authorizationHeader)
    {
        if (string.IsNullOrWhiteSpace(authorizationHeader))
        {
            return null;
        }

        var parts = authorizationHeader.Split(
            ' ',
            StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (parts.Length != 2)
        {
            return null;
        }

        return string.Equals(parts[0], "Bearer", StringComparison.OrdinalIgnoreCase)
            ? parts[1]
            : null;
    }
}
