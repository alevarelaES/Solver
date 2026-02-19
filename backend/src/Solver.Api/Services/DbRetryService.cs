using Microsoft.EntityFrameworkCore;
using Npgsql;
using Solver.Api.Data;
using System.Net.Sockets;

namespace Solver.Api.Services;

public sealed class DbRetryService
{
    public Task<DbRetryResult<T>> ExecuteAsync<T>(
        IServiceScopeFactory scopeFactory,
        Func<SolverDbContext, Task<T>> operation,
        int maxAttempts = 3,
        int baseDelayMs = 120,
        bool clearPoolsOnRetry = false,
        CancellationToken cancellationToken = default)
    {
        var attempts = Math.Max(1, maxAttempts);
        var delay = Math.Max(1, baseDelayMs);
        return ExecuteCoreAsync(
            scopeFactory,
            operation,
            attempts,
            delay,
            clearPoolsOnRetry,
            attempt: 1,
            cancellationToken);
    }

    private async Task<DbRetryResult<T>> ExecuteCoreAsync<T>(
        IServiceScopeFactory scopeFactory,
        Func<SolverDbContext, Task<T>> operation,
        int maxAttempts,
        int baseDelayMs,
        bool clearPoolsOnRetry,
        int attempt,
        CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();

        try
        {
            var value = await operation(db);
            return new DbRetryResult<T>(true, value, null);
        }
        catch (Exception ex) when (IsTransientNpgsqlFailure(ex))
        {
            if (attempt >= maxAttempts)
            {
                return new DbRetryResult<T>(false, default, ex);
            }

            if (clearPoolsOnRetry)
            {
                NpgsqlConnection.ClearAllPools();
            }

            await Task.Delay(baseDelayMs * attempt, cancellationToken);
            return await ExecuteCoreAsync(
                scopeFactory,
                operation,
                maxAttempts,
                baseDelayMs,
                clearPoolsOnRetry,
                attempt + 1,
                cancellationToken);
        }
    }

    private static bool IsTransientNpgsqlFailure(Exception ex)
    {
        for (Exception? current = ex; current is not null; current = current.InnerException)
        {
            if (current is PostgresException pgEx)
            {
                if (string.Equals(pgEx.SqlState, "XX000", StringComparison.Ordinal)
                    && pgEx.MessageText.Contains("DbHandler exited", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                if (string.Equals(pgEx.SqlState, "57P01", StringComparison.Ordinal)
                    || string.Equals(pgEx.SqlState, "53300", StringComparison.Ordinal))
                {
                    return true;
                }
            }

            if (current is TimeoutException
                || current is SocketException)
            {
                return true;
            }

            if (current is ObjectDisposedException disposed)
            {
                var objectName = disposed.ObjectName ?? string.Empty;
                if (objectName.Contains("ManualResetEventSlim", StringComparison.Ordinal)
                    || objectName.Contains("Npgsql", StringComparison.Ordinal))
                {
                    return true;
                }
            }

            if (current is DbUpdateException updateEx)
            {
                var innerName = (updateEx.InnerException as ObjectDisposedException)?.ObjectName ?? string.Empty;
                if (innerName.Contains("ManualResetEventSlim", StringComparison.Ordinal)
                    || innerName.Contains("Npgsql", StringComparison.Ordinal))
                {
                    return true;
                }
            }

            var msg = current.Message ?? string.Empty;
            if (msg.Contains("Cannot access a disposed object", StringComparison.OrdinalIgnoreCase)
                && msg.Contains("Npgsql", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (msg.Contains("DbHandler exited", StringComparison.OrdinalIgnoreCase)
                || msg.Contains("connection is broken", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }
}

public sealed record DbRetryResult<T>(bool Succeeded, T? Value, Exception? LastError);
