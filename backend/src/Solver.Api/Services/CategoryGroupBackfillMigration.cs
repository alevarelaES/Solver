using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Services;

public static class CategoryGroupBackfillMigration
{
    private const string MigrationName = "backfill_category_groups_v1";

    public static async Task ApplyAsync(SolverDbContext db, CancellationToken ct = default)
    {
        await EnsureInfraTablesAsync(db, ct);
        if (await IsAlreadyAppliedAsync(db, ct)) return;

        var userIds = await db.Accounts
            .Select(a => a.UserId)
            .Distinct()
            .ToListAsync(ct);

        foreach (var userId in userIds)
        {
            await BackfillUserAsync(db, userId, ct);
        }

        await MarkAppliedAsync(db, ct);
    }

    private static async Task BackfillUserAsync(SolverDbContext db, Guid userId, CancellationToken ct)
    {
        var accounts = await db.Accounts
            .Where(a => a.UserId == userId)
            .OrderBy(a => a.CreatedAt)
            .ToListAsync(ct);
        if (accounts.Count == 0) return;

        var groups = await db.CategoryGroups
            .Where(g => g.UserId == userId)
            .OrderBy(g => g.SortOrder)
            .ToListAsync(ct);

        var map = groups.ToDictionary(GroupKey, StringComparer.Ordinal);
        var maxSortByType = groups
            .GroupBy(g => g.Type)
            .ToDictionary(g => g.Key, g => g.Max(x => x.SortOrder));

        foreach (var account in accounts)
        {
            var groupName = NormalizeGroupName(account.Group, account.Type);
            var key = GroupKey(userId, account.Type, groupName);

            if (!map.TryGetValue(key, out var categoryGroup))
            {
                var nextSort = maxSortByType.TryGetValue(account.Type, out var maxSort)
                    ? maxSort + 1
                    : 0;
                maxSortByType[account.Type] = nextSort;

                categoryGroup = new CategoryGroup
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    Name = groupName,
                    Type = account.Type,
                    SortOrder = nextSort,
                    IsArchived = false,
                    CreatedAt = DateTime.UtcNow,
                    UpdatedAt = DateTime.UtcNow,
                };
                db.CategoryGroups.Add(categoryGroup);
                map[key] = categoryGroup;
            }

            if (account.GroupId != categoryGroup.Id)
            {
                account.GroupId = categoryGroup.Id;
            }
            if (!string.Equals(account.Group, categoryGroup.Name, StringComparison.Ordinal))
            {
                account.Group = categoryGroup.Name;
            }
        }

        await db.SaveChangesAsync(ct);
    }

    private static string GroupKey(CategoryGroup g) =>
        GroupKey(g.UserId, g.Type, g.Name);

    private static string GroupKey(Guid userId, AccountType type, string name) =>
        $"{userId}|{type}|{name.Trim().ToLowerInvariant()}";

    private static string NormalizeGroupName(string? raw, AccountType type)
    {
        if (!string.IsNullOrWhiteSpace(raw)) return raw.Trim();
        return type == AccountType.Income ? "Revenus" : "Depenses";
    }

    private static async Task EnsureInfraTablesAsync(SolverDbContext db, CancellationToken ct)
    {
        await db.Database.ExecuteSqlRawAsync(
            """
            CREATE TABLE IF NOT EXISTS app_data_migrations (
                name text PRIMARY KEY,
                applied_at timestamp with time zone NOT NULL DEFAULT now()
            );
            """,
            ct
        );
    }

    private static async Task<bool> IsAlreadyAppliedAsync(SolverDbContext db, CancellationToken ct)
        => await db.AppDataMigrations.AnyAsync(m => m.Name == MigrationName, ct);

    private static async Task MarkAppliedAsync(SolverDbContext db, CancellationToken ct)
    {
        if (await IsAlreadyAppliedAsync(db, ct)) return;
        db.AppDataMigrations.Add(
            new AppDataMigration
            {
                Name = MigrationName,
                AppliedAt = DateTime.UtcNow,
            }
        );
        await db.SaveChangesAsync(ct);
    }
}
