namespace Solver.Api.Services;

public static class AppRuntimeSecurity
{
    public sealed record AllowedOriginsParseResult(
        string[] Origins,
        string[] InvalidEntries);

    public static bool GetBoolEnv(string key, bool defaultValue)
    {
        var raw = Environment.GetEnvironmentVariable(key);
        return bool.TryParse(raw, out var parsed) ? parsed : defaultValue;
    }

    public static string[] ParseAllowedOrigins(string? raw)
    {
        return ParseAllowedOriginsDetailed(raw).Origins;
    }

    public static AllowedOriginsParseResult ParseAllowedOriginsDetailed(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return new AllowedOriginsParseResult([], []);
        }

        var origins = new List<string>();
        var invalidEntries = new List<string>();

        foreach (var entry in raw.Split(
                     ',',
                     StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var normalized = NormalizeOrigin(entry);
            if (normalized is null)
            {
                invalidEntries.Add(entry);
                continue;
            }

            origins.Add(normalized);
        }

        return new AllowedOriginsParseResult(
            origins.Distinct(StringComparer.OrdinalIgnoreCase).ToArray(),
            invalidEntries.Distinct(StringComparer.OrdinalIgnoreCase).ToArray());
    }

    public static bool IsLocalDevelopmentOrigin(string origin)
    {
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
        {
            return false;
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return uri.IsLoopback;
    }

    public static string? BuildExpectedIssuer(string? supabaseUrl, string? explicitIssuer = null)
    {
        if (!string.IsNullOrWhiteSpace(explicitIssuer))
        {
            return explicitIssuer.Trim().TrimEnd('/');
        }

        if (string.IsNullOrWhiteSpace(supabaseUrl))
        {
            return null;
        }

        return $"{supabaseUrl.Trim().TrimEnd('/')}/auth/v1";
    }

    public static string[] ParseAudiences(string? raw, bool includeDefaultAuthenticated)
    {
        var parsed = string.IsNullOrWhiteSpace(raw)
            ? []
            : raw
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Where(a => !string.IsNullOrWhiteSpace(a))
                .Distinct(StringComparer.Ordinal)
                .ToArray();

        if (parsed.Length > 0 || !includeDefaultAuthenticated)
        {
            return parsed;
        }

        return ["authenticated"];
    }

    private static string? NormalizeOrigin(string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri))
        {
            return null;
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttp, StringComparison.OrdinalIgnoreCase) &&
            !string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return $"{uri.Scheme}://{uri.Authority}";
    }
}
