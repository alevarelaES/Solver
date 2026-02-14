using System.IdentityModel.Tokens.Jwt;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace Solver.Api.Middleware;

public class SupabaseAuthMiddleware(RequestDelegate next)
{
    private static readonly HttpClient _http = new();
    private static List<SecurityKey> _cachedKeys = [];
    private static DateTime _keysExpiry = DateTime.MinValue;

    public async Task InvokeAsync(HttpContext context)
    {
        if (context.Request.Path.StartsWithSegments("/health")
            || context.Request.Method == HttpMethods.Options)
        {
            await next(context);
            return;
        }

        var token = context.Request.Headers.Authorization
            .FirstOrDefault()?.Split(" ").Last();

        if (string.IsNullOrEmpty(token))
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "Missing authorization token" });
            return;
        }

        var userId = await ValidateTokenAsync(token);
        if (userId is null)
        {
            context.Response.StatusCode = 401;
            await context.Response.WriteAsJsonAsync(new { error = "Invalid or expired token" });
            return;
        }

        context.Items["UserId"] = userId;
        await next(context);
    }

    private static async Task<List<SecurityKey>> GetSigningKeysAsync()
    {
        if (_cachedKeys.Count > 0 && DateTime.UtcNow < _keysExpiry)
            return _cachedKeys;

        var keys = new List<SecurityKey>();

        // RS256 — fetch public keys from Supabase JWKS endpoint
        try
        {
            var supabaseUrl = Environment.GetEnvironmentVariable("SUPABASE_URL")
                ?? throw new InvalidOperationException("SUPABASE_URL not set");

            var jwksJson = await _http.GetStringAsync(
                $"{supabaseUrl}/auth/v1/.well-known/jwks.json");

            var jwks = new JsonWebKeySet(jwksJson);
            var jwksKeys = jwks.GetSigningKeys().ToList();
            keys.AddRange(jwksKeys);
            Console.WriteLine($"[Auth] Loaded {jwksKeys.Count} JWKS key(s) from Supabase");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Auth] JWKS fetch failed: {ex.Message}");
        }

        // HS256 — legacy symmetric secret (fallback)
        var secret = Environment.GetEnvironmentVariable("JWT_SECRET");
        if (!string.IsNullOrEmpty(secret))
            keys.Add(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret)));

        _cachedKeys = keys;
        _keysExpiry = DateTime.UtcNow.AddHours(1);

        Console.WriteLine($"[Auth] Total signing keys available: {keys.Count}");
        return keys;
    }

    private static async Task<Guid?> ValidateTokenAsync(string token)
    {
        try
        {
            var signingKeys = await GetSigningKeysAsync();

            var handler = new JwtSecurityTokenHandler();
            handler.ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = signingKeys,
                ValidateIssuer = false,
                ValidateAudience = false,
                ClockSkew = TimeSpan.Zero,
            }, out var validatedToken);

            var jwt = (JwtSecurityToken)validatedToken;
            var sub = jwt.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;
            return sub is not null ? Guid.Parse(sub) : null;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[Auth] JWT validation failed: {ex.GetType().Name}: {ex.Message}");
            return null;
        }
    }
}
