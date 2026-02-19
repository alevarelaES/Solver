using Solver.Api.Services;

namespace Solver.Tests;

public class AppRuntimeSecurityTests
{
    [Fact]
    public void ParseAllowedOrigins_NormalizesAndFiltersInvalidOrigins()
    {
        var parsed = AppRuntimeSecurity.ParseAllowedOrigins(
            " https://app.example.com/ ,http://localhost:3000,not-a-url,ftp://invalid.example ");

        Assert.Equal(2, parsed.Length);
        Assert.Contains("https://app.example.com", parsed);
        Assert.Contains("http://localhost:3000", parsed);
    }

    [Fact]
    public void ParseAllowedOriginsDetailed_TracksInvalidEntries()
    {
        var result = AppRuntimeSecurity.ParseAllowedOriginsDetailed(
            "https://app.example.com,not-a-url,ftp://invalid.example");

        Assert.Single(result.Origins);
        Assert.Contains("https://app.example.com", result.Origins);
        Assert.Equal(2, result.InvalidEntries.Length);
        Assert.Contains("not-a-url", result.InvalidEntries);
        Assert.Contains("ftp://invalid.example", result.InvalidEntries);
    }

    [Theory]
    [InlineData("http://localhost:5173", true)]
    [InlineData("https://127.0.0.1:3000", true)]
    [InlineData("https://example.com", false)]
    [InlineData("chrome-extension://abc", false)]
    public void IsLocalDevelopmentOrigin_ValidatesLoopbackOrigins(string origin, bool expected)
    {
        var actual = AppRuntimeSecurity.IsLocalDevelopmentOrigin(origin);
        Assert.Equal(expected, actual);
    }

    [Fact]
    public void BuildExpectedIssuer_UsesExplicitIssuerFirst()
    {
        var issuer = AppRuntimeSecurity.BuildExpectedIssuer(
            "https://project.supabase.co",
            "https://issuer.example.com/");

        Assert.Equal("https://issuer.example.com", issuer);
    }

    [Fact]
    public void BuildExpectedIssuer_DerivesFromSupabaseUrl()
    {
        var issuer = AppRuntimeSecurity.BuildExpectedIssuer("https://project.supabase.co/");

        Assert.Equal("https://project.supabase.co/auth/v1", issuer);
    }
}
