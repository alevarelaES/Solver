using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class CategoriesService
{
    private readonly SolverDbContext _db;

    public CategoriesService(SolverDbContext db)
    {
        _db = db;
    }

    public async Task<IResult> GetCategoriesAsync(HttpContext ctx, bool includeArchived = false)
    {
        var userId = GetUserId(ctx);

        var accounts = await _db.Accounts
            .Where(a => a.UserId == userId)
            .ToListAsync();

        var groupsById = await _db.CategoryGroups
            .Where(g => g.UserId == userId)
            .ToDictionaryAsync(g => g.Id, g => g);

        var prefs = await _db.CategoryPreferences
            .Where(p => p.UserId == userId)
            .ToDictionaryAsync(p => p.AccountId, p => p);

        var rows = accounts
            .Select((a, i) =>
            {
                var hasPref = prefs.TryGetValue(a.Id, out var pref);
                var sortOrder = hasPref ? pref!.SortOrder : i;
                var isArchived = hasPref && pref!.IsArchived;

                CategoryGroup? linkedGroup = null;
                if (a.GroupId.HasValue)
                {
                    groupsById.TryGetValue(a.GroupId.Value, out linkedGroup);
                }

                return new
                {
                    id = a.Id,
                    name = a.Name,
                    type = a.Type == AccountType.Income ? "income" : "expense",
                    group = linkedGroup?.Name ?? a.Group,
                    groupId = linkedGroup?.Id,
                    sortOrder,
                    isArchived,
                };
            })
            .Where(c => includeArchived || !c.isArchived)
            .OrderBy(c => c.type)
            .ThenBy(c => c.sortOrder)
            .ThenBy(c => c.name)
            .ToList();

        return Results.Ok(rows);
    }

    public async Task<IResult> CreateCategoryAsync(CreateCategoryDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        var nameExists = await _db.Accounts.AnyAsync(a =>
            a.UserId == userId &&
            a.Type == dto.Type &&
            EF.Functions.ILike(a.Name, dto.Name.Trim()));
        if (nameExists)
        {
            return Results.BadRequest(new { error = "Categorie deja existante pour ce type" });
        }

        var categoryGroup = await ResolveOrCreateGroupAsync(userId, dto.Type, dto.GroupId, dto.Group);
        if (categoryGroup is null)
        {
            return Results.BadRequest(new { error = "Groupe invalide" });
        }

        var account = new Account
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = dto.Name.Trim(),
            Type = dto.Type,
            Group = categoryGroup.Name,
            GroupId = categoryGroup.Id,
            IsFixed = false,
            Budget = 0,
            CreatedAt = DateTime.UtcNow,
        };

        var maxSort = await _db.CategoryPreferences
            .Where(p => p.UserId == userId)
            .Select(p => (int?)p.SortOrder)
            .MaxAsync() ?? -1;

        _db.Accounts.Add(account);
        _db.CategoryPreferences.Add(new CategoryPreference
        {
            AccountId = account.Id,
            UserId = userId,
            SortOrder = maxSort + 1,
            IsArchived = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync();

        return Results.Created($"/api/categories/{account.Id}", new
        {
            id = account.Id,
            name = account.Name,
            type = account.Type == AccountType.Income ? "income" : "expense",
            group = account.Group,
            groupId = account.GroupId,
            sortOrder = maxSort + 1,
            isArchived = false,
        });
    }

    public async Task<IResult> UpdateCategoryAsync(Guid id, UpdateCategoryDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);

        var account = await _db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);
        if (account is null) return Results.NotFound();

        var categoryGroup = await ResolveOrCreateGroupAsync(userId, dto.Type, dto.GroupId, dto.Group);
        if (categoryGroup is null)
        {
            return Results.BadRequest(new { error = "Groupe invalide" });
        }

        account.Name = dto.Name.Trim();
        account.Type = dto.Type;
        account.Group = categoryGroup.Name;
        account.GroupId = categoryGroup.Id;
        await _db.SaveChangesAsync();

        return Results.Ok(new
        {
            id = account.Id,
            name = account.Name,
            type = account.Type == AccountType.Income ? "income" : "expense",
            group = account.Group,
            groupId = account.GroupId,
        });
    }

    public async Task<IResult> ArchiveCategoryAsync(Guid id, ArchiveCategoryDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var exists = await _db.Accounts.AnyAsync(a => a.Id == id && a.UserId == userId);
        if (!exists) return Results.NotFound();

        var pref = await _db.CategoryPreferences.FirstOrDefaultAsync(p => p.AccountId == id && p.UserId == userId);
        if (pref is null)
        {
            var maxSort = await _db.CategoryPreferences
                .Where(p => p.UserId == userId)
                .Select(p => (int?)p.SortOrder)
                .MaxAsync() ?? -1;

            pref = new CategoryPreference
            {
                AccountId = id,
                UserId = userId,
                SortOrder = maxSort + 1,
                IsArchived = dto.IsArchived,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            };
            _db.CategoryPreferences.Add(pref);
        }
        else
        {
            pref.IsArchived = dto.IsArchived;
            pref.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync();
        return Results.Ok(new { id, isArchived = dto.IsArchived });
    }

    public async Task<IResult> ReorderCategoriesAsync(ReorderCategoriesDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var now = DateTime.UtcNow;

        var ids = dto.Items.Select(i => i.CategoryId).Distinct().ToList();
        var ownedIds = await _db.Accounts
            .Where(a => a.UserId == userId && ids.Contains(a.Id))
            .Select(a => a.Id)
            .ToListAsync();

        if (ownedIds.Count != ids.Count)
        {
            return Results.BadRequest(new { error = "Certaines categories sont invalides" });
        }

        var existingPrefs = await _db.CategoryPreferences
            .Where(p => p.UserId == userId && ids.Contains(p.AccountId))
            .ToDictionaryAsync(p => p.AccountId, p => p);

        foreach (var item in dto.Items)
        {
            if (existingPrefs.TryGetValue(item.CategoryId, out var pref))
            {
                pref.SortOrder = item.SortOrder;
                pref.UpdatedAt = now;
                continue;
            }

            _db.CategoryPreferences.Add(new CategoryPreference
            {
                AccountId = item.CategoryId,
                UserId = userId,
                SortOrder = item.SortOrder,
                IsArchived = false,
                CreatedAt = now,
                UpdatedAt = now,
            });
        }

        await _db.SaveChangesAsync();
        return Results.Ok(new { updated = dto.Items.Count });
    }

    public async Task<IResult> GetCategoryGroupsAsync(HttpContext ctx, bool includeArchived = false)
    {
        var userId = GetUserId(ctx);

        var groups = await _db.CategoryGroups
            .Where(g => g.UserId == userId && (includeArchived || !g.IsArchived))
            .OrderBy(g => g.Type)
            .ThenBy(g => g.SortOrder)
            .ThenBy(g => g.Name)
            .Select(g => new
            {
                id = g.Id,
                name = g.Name,
                type = g.Type == AccountType.Income ? "income" : "expense",
                sortOrder = g.SortOrder,
                isArchived = g.IsArchived,
            })
            .ToListAsync();

        return Results.Ok(groups);
    }

    public async Task<IResult> CreateCategoryGroupAsync(CreateCategoryGroupDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var name = dto.Name.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            return Results.BadRequest(new { error = "Nom de groupe requis" });
        }

        var exists = await _db.CategoryGroups.AnyAsync(g =>
            g.UserId == userId &&
            g.Type == dto.Type &&
            EF.Functions.ILike(g.Name, name));
        if (exists)
        {
            return Results.BadRequest(new { error = "Groupe deja existant" });
        }

        var maxSort = await _db.CategoryGroups
            .Where(g => g.UserId == userId && g.Type == dto.Type)
            .Select(g => (int?)g.SortOrder)
            .MaxAsync() ?? -1;

        var created = new CategoryGroup
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = name,
            Type = dto.Type,
            SortOrder = maxSort + 1,
            IsArchived = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.CategoryGroups.Add(created);
        await _db.SaveChangesAsync();

        return Results.Created($"/api/category-groups/{created.Id}", new
        {
            id = created.Id,
            name = created.Name,
            type = created.Type == AccountType.Income ? "income" : "expense",
            sortOrder = created.SortOrder,
            isArchived = created.IsArchived,
        });
    }

    public async Task<IResult> UpdateCategoryGroupAsync(Guid id, UpdateCategoryGroupDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var categoryGroup = await _db.CategoryGroups.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
        if (categoryGroup is null) return Results.NotFound();

        var name = dto.Name.Trim();
        if (string.IsNullOrWhiteSpace(name))
        {
            return Results.BadRequest(new { error = "Nom de groupe requis" });
        }

        var duplicate = await _db.CategoryGroups.AnyAsync(g =>
            g.Id != id &&
            g.UserId == userId &&
            g.Type == categoryGroup.Type &&
            EF.Functions.ILike(g.Name, name));
        if (duplicate)
        {
            return Results.BadRequest(new { error = "Groupe deja existant" });
        }

        categoryGroup.Name = name;
        categoryGroup.UpdatedAt = DateTime.UtcNow;
        var linkedAccounts = await _db.Accounts
            .Where(a => a.UserId == userId && a.GroupId == id)
            .ToListAsync();
        foreach (var account in linkedAccounts)
        {
            account.Group = name;
        }
        await _db.SaveChangesAsync();

        return Results.Ok(new
        {
            id = categoryGroup.Id,
            name = categoryGroup.Name,
            type = categoryGroup.Type == AccountType.Income ? "income" : "expense",
            sortOrder = categoryGroup.SortOrder,
            isArchived = categoryGroup.IsArchived,
        });
    }

    public async Task<IResult> ArchiveCategoryGroupAsync(Guid id, ArchiveCategoryGroupDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var categoryGroup = await _db.CategoryGroups.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
        if (categoryGroup is null) return Results.NotFound();

        categoryGroup.IsArchived = dto.IsArchived;
        categoryGroup.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Results.Ok(new { id, isArchived = dto.IsArchived });
    }

    public async Task<IResult> ReorderCategoryGroupsAsync(ReorderCategoryGroupsDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var ids = dto.Items.Select(i => i.GroupId).Distinct().ToList();

        var groups = await _db.CategoryGroups
            .Where(g => g.UserId == userId && ids.Contains(g.Id))
            .ToDictionaryAsync(g => g.Id, g => g);

        if (groups.Count != ids.Count)
        {
            return Results.BadRequest(new { error = "Certains groupes sont invalides" });
        }

        foreach (var item in dto.Items)
        {
            var entity = groups[item.GroupId];
            entity.SortOrder = item.SortOrder;
            entity.UpdatedAt = DateTime.UtcNow;
        }
        await _db.SaveChangesAsync();

        return Results.Ok(new { updated = dto.Items.Count });
    }

    private async Task<CategoryGroup?> ResolveOrCreateGroupAsync(
        Guid userId,
        AccountType type,
        Guid? groupId,
        string? groupName
    )
    {
        if (groupId.HasValue)
        {
            var existingById = await _db.CategoryGroups
                .FirstOrDefaultAsync(g => g.Id == groupId.Value && g.UserId == userId);
            if (existingById is null) return null;
            if (existingById.Type != type) return null;
            return existingById;
        }

        if (string.IsNullOrWhiteSpace(groupName)) return null;
        var normalizedName = groupName.Trim();

        var existingByName = await _db.CategoryGroups
            .FirstOrDefaultAsync(g =>
                g.UserId == userId &&
                g.Type == type &&
                EF.Functions.ILike(g.Name, normalizedName));
        if (existingByName is not null) return existingByName;

        var maxSort = await _db.CategoryGroups
            .Where(g => g.UserId == userId && g.Type == type)
            .Select(g => (int?)g.SortOrder)
            .MaxAsync() ?? -1;

        var created = new CategoryGroup
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = normalizedName,
            Type = type,
            SortOrder = maxSort + 1,
            IsArchived = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.CategoryGroups.Add(created);
        await _db.SaveChangesAsync();
        return created;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
