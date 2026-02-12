using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.AspNetCore.Http;
using Microsoft.IdentityModel.Tokens;
using Solver.Api.Middleware;

namespace Solver.Tests;

public class AuthMiddlewareTests
{
    private static readonly RSA _rsa = RSA.Create(2048);
    private static readonly RsaSecurityKey _key = new(_rsa);
    private static readonly Guid TestUserId = Guid.NewGuid();

    private static string CreateToken(Guid userId, DateTime? expires = null, bool malformed = false)
    {
        if (malformed) return "not.a.valid.jwt.token";

        var handler = new JwtSecurityTokenHandler();
        var descriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity([new Claim("sub", userId.ToString())]),
            Expires = expires ?? DateTime.UtcNow.AddHours(1),
            SigningCredentials = new SigningCredentials(_key, SecurityAlgorithms.RsaSha256)
        };
        return handler.WriteToken(handler.CreateToken(descriptor));
    }

    private static (SupabaseAuthMiddleware middleware, DefaultHttpContext context) Setup(string? token)
    {
        var middleware = new SupabaseAuthMiddleware(_ => Task.CompletedTask);

        var context = new DefaultHttpContext();
        if (token is not null)
            context.Request.Headers.Authorization = $"Bearer {token}";

        return (middleware, context);
    }

    [Fact]
    public async Task NoToken_Returns401()
    {
        var (middleware, context) = Setup(null);

        await middleware.InvokeAsync(context);

        Assert.Equal(401, context.Response.StatusCode);
        Assert.False(context.Items.ContainsKey("UserId"));
    }

    [Fact]
    public async Task EmptyToken_Returns401()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers.Authorization = "Bearer ";

        var middleware = new SupabaseAuthMiddleware(_ => Task.CompletedTask);
        await middleware.InvokeAsync(context);

        Assert.Equal(401, context.Response.StatusCode);
    }

    [Fact]
    public async Task MalformedToken_Returns401()
    {
        var (middleware, context) = Setup(CreateToken(TestUserId, malformed: true));

        await middleware.InvokeAsync(context);

        Assert.Equal(401, context.Response.StatusCode);
    }

    [Fact]
    public async Task HealthEndpoint_SkipsAuth()
    {
        var nextCalled = false;
        var middleware = new SupabaseAuthMiddleware(_ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        var context = new DefaultHttpContext();
        context.Request.Path = "/health";
        // No token provided

        await middleware.InvokeAsync(context);

        Assert.True(nextCalled);
        Assert.NotEqual(401, context.Response.StatusCode);
    }
}
