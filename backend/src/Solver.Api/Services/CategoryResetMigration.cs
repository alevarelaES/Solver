using System.Globalization;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Models;

namespace Solver.Api.Services;

public static class CategoryResetMigration
{
    private const string MigrationName = "reset_categories_to_daily_defaults_v1";

    private sealed record CategorySeed(
        string Name,
        AccountType Type,
        string Group,
        bool IsFixed
    );

    private static readonly IReadOnlyList<CategorySeed> Seeds =
    [
        new("Salaire", AccountType.Income, "Revenus", false),
        new("Freelance", AccountType.Income, "Revenus", false),
        new("Bonus", AccountType.Income, "Revenus", false),
        new("Remboursements", AccountType.Income, "Revenus", false),
        new("Autres revenus", AccountType.Income, "Revenus", false),

        new("Loyer", AccountType.Expense, "Charges fixes", true),
        new("Assurance maladie", AccountType.Expense, "Charges fixes", true),
        new("Internet", AccountType.Expense, "Charges fixes", true),
        new("Electricite", AccountType.Expense, "Charges fixes", true),
        new("Impots", AccountType.Expense, "Charges fixes", true),
        new("Autres charges fixes", AccountType.Expense, "Charges fixes", true),

        new("Spotify", AccountType.Expense, "Abonnements", false),
        new("Netflix", AccountType.Expense, "Abonnements", false),
        new("YouTube Premium", AccountType.Expense, "Abonnements", false),
        new("Telephone mobile", AccountType.Expense, "Abonnements", false),
        new("Autres abonnements", AccountType.Expense, "Abonnements", false),

        new("Courses", AccountType.Expense, "Activites", false),
        new("Restaurants", AccountType.Expense, "Activites", false),
        new("Shopping", AccountType.Expense, "Activites", false),
        new("Transport", AccountType.Expense, "Activites", false),
        new("Loisirs", AccountType.Expense, "Activites", false),
        new("Sante", AccountType.Expense, "Activites", false),
        new("Voyage", AccountType.Expense, "Activites", false),
        new("Amendes", AccountType.Expense, "Activites", false),
        new("Autres activites", AccountType.Expense, "Activites", false),

        new("ETF MSCI World", AccountType.Expense, "Investissements", false),
        new("ETF S&P 500", AccountType.Expense, "Investissements", false),
        new("Epargne", AccountType.Expense, "Investissements", false),
        new("Crypto", AccountType.Expense, "Investissements", false),
        new("Autres investissements", AccountType.Expense, "Investissements", false),
    ];

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
            await ResetUserCategoriesAsync(db, userId, ct);
        }

        await MarkAppliedAsync(db, ct);
    }

    private static async Task ResetUserCategoriesAsync(SolverDbContext db, Guid userId, CancellationToken ct)
    {
        var accounts = await db.Accounts
            .Where(a => a.UserId == userId)
            .OrderBy(a => a.CreatedAt)
            .ToListAsync(ct);
        if (accounts.Count == 0) return;

        var accountById = accounts.ToDictionary(a => a.Id, a => a);
        var accountByKey = accounts
            .GroupBy(AccountKey)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.Ordinal);

        foreach (var seed in Seeds)
        {
            var key = SeedKey(seed);
            if (accountByKey.ContainsKey(key)) continue;

            var created = new Account
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Name = seed.Name,
                Type = seed.Type,
                Group = seed.Group,
                IsFixed = seed.IsFixed,
                Budget = 0,
                CreatedAt = DateTime.UtcNow,
            };
            db.Accounts.Add(created);
            // Keep writes small to avoid large batched INSERTs on pooled connections.
            await db.SaveChangesAsync(ct);
            accountByKey[key] = created;
            accountById[created.Id] = created;
        }

        var transactions = await db.Transactions
            .Where(t => t.UserId == userId)
            .ToListAsync(ct);

        foreach (var t in transactions)
        {
            if (!accountById.TryGetValue(t.AccountId, out var oldAccount)) continue;
            var seed = ResolveTargetSeed(oldAccount);
            var key = SeedKey(seed);
            if (!accountByKey.TryGetValue(key, out var target)) continue;
            if (t.AccountId == target.Id) continue;
            t.AccountId = target.Id;
            await db.SaveChangesAsync(ct);
        }

        var defaultKeySet = Seeds.Select(SeedKey).ToHashSet(StringComparer.Ordinal);
        var toDelete = accountById.Values
            .Where(a => !defaultKeySet.Contains(AccountKey(a)))
            .ToList();

        if (toDelete.Count > 0)
        {
            foreach (var account in toDelete)
            {
                db.Accounts.Remove(account);
                await db.SaveChangesAsync(ct);
            }
        }

        var remaining = await db.Accounts
            .Where(a => a.UserId == userId)
            .OrderBy(a => a.Type)
            .ThenBy(a => a.Group)
            .ThenBy(a => a.Name)
            .ToListAsync(ct);

        var prefs = await db.CategoryPreferences
            .Where(p => p.UserId == userId)
            .ToListAsync(ct);
        var prefsByAccount = prefs.ToDictionary(p => p.AccountId, p => p);
        var remainingIds = remaining.Select(a => a.Id).ToHashSet();

        foreach (var p in prefs.Where(p => !remainingIds.Contains(p.AccountId)))
        {
            db.CategoryPreferences.Remove(p);
            await db.SaveChangesAsync(ct);
        }

        for (var i = 0; i < remaining.Count; i++)
        {
            var a = remaining[i];
            if (prefsByAccount.TryGetValue(a.Id, out var pref))
            {
                pref.SortOrder = i;
                pref.IsArchived = false;
                pref.UpdatedAt = DateTime.UtcNow;
                await db.SaveChangesAsync(ct);
                continue;
            }

            db.CategoryPreferences.Add(new CategoryPreference
            {
                AccountId = a.Id,
                UserId = userId,
                SortOrder = i,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);
        }
    }

    private static CategorySeed ResolveTargetSeed(Account account)
    {
        var name = Normalize(account.Name);
        var group = Normalize(account.Group);

        if (account.Type == AccountType.Income)
        {
            if (ContainsAny(name, "salaire", "salary")) return Seed("Salaire", AccountType.Income);
            if (ContainsAny(name, "freelance", "independant")) return Seed("Freelance", AccountType.Income);
            if (ContainsAny(name, "bonus", "prime")) return Seed("Bonus", AccountType.Income);
            if (ContainsAny(name, "rembourse", "refund")) return Seed("Remboursements", AccountType.Income);
            return Seed("Autres revenus", AccountType.Income);
        }

        if (ContainsAny(name, "loyer", "rent")) return Seed("Loyer", AccountType.Expense);
        if (ContainsAny(name, "assurance")) return Seed("Assurance maladie", AccountType.Expense);
        if (ContainsAny(name, "internet", "wifi", "fibre")) return Seed("Internet", AccountType.Expense);
        if (ContainsAny(name, "electr", "energie")) return Seed("Electricite", AccountType.Expense);
        if (ContainsAny(name, "impot", "tax")) return Seed("Impots", AccountType.Expense);
        if (ContainsAny(name, "spotify")) return Seed("Spotify", AccountType.Expense);
        if (ContainsAny(name, "netflix")) return Seed("Netflix", AccountType.Expense);
        if (ContainsAny(name, "youtube")) return Seed("YouTube Premium", AccountType.Expense);
        if (ContainsAny(name, "telephone", "mobile", "swisscom")) return Seed("Telephone mobile", AccountType.Expense);
        if (ContainsAny(name, "course", "epicer", "grocery")) return Seed("Courses", AccountType.Expense);
        if (ContainsAny(name, "restaurant", "restaurante")) return Seed("Restaurants", AccountType.Expense);
        if (ContainsAny(name, "shopping")) return Seed("Shopping", AccountType.Expense);
        if (ContainsAny(name, "transport", "train", "bus", "uber")) return Seed("Transport", AccountType.Expense);
        if (ContainsAny(name, "loisir", "cinema", "sport")) return Seed("Loisirs", AccountType.Expense);
        if (ContainsAny(name, "sante", "pharma", "medic")) return Seed("Sante", AccountType.Expense);
        if (ContainsAny(name, "voyage", "travel", "vacance")) return Seed("Voyage", AccountType.Expense);
        if (ContainsAny(name, "amende")) return Seed("Amendes", AccountType.Expense);
        if (ContainsAny(name, "etf", "msci")) return Seed("ETF MSCI World", AccountType.Expense);
        if (ContainsAny(name, "s&p", "sp500")) return Seed("ETF S&P 500", AccountType.Expense);
        if (ContainsAny(name, "epargne", "saving")) return Seed("Epargne", AccountType.Expense);
        if (ContainsAny(name, "crypto", "btc", "eth")) return Seed("Crypto", AccountType.Expense);

        if (ContainsAny(group, "abonn")) return Seed("Autres abonnements", AccountType.Expense);
        if (ContainsAny(group, "invest")) return Seed("Autres investissements", AccountType.Expense);
        if (ContainsAny(group, "fixe")) return Seed("Autres charges fixes", AccountType.Expense);
        return Seed("Autres activites", AccountType.Expense);
    }

    private static CategorySeed Seed(string name, AccountType type) =>
        Seeds.First(s => s.Name == name && s.Type == type);

    private static string SeedKey(CategorySeed s) =>
        $"{s.Type}|{Normalize(s.Name)}|{Normalize(s.Group)}";

    private static string AccountKey(Account a) =>
        $"{a.Type}|{Normalize(a.Name)}|{Normalize(a.Group)}";

    private static bool ContainsAny(string input, params string[] values) =>
        values.Any(v => input.Contains(v, StringComparison.Ordinal));

    private static string Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return string.Empty;
        var lowered = raw.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var sb = new StringBuilder(lowered.Length);
        foreach (var c in lowered)
        {
            var uc = CharUnicodeInfo.GetUnicodeCategory(c);
            if (uc != UnicodeCategory.NonSpacingMark) sb.Append(c);
        }
        return sb.ToString();
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
