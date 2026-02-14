using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class CategoriesEndpoints
{
    public static void MapCategoriesEndpoints(this WebApplication app)
    {
        MapCategoryEndpoints(app);
        MapCategoryGroupEndpoints(app);
    }

    private static void MapCategoryEndpoints(WebApplication app)
    {
        var group = app.MapGroup("/api/categories");

        group.MapGet("/", async (SolverDbContext db, HttpContext ctx, bool includeArchived = false) =>
        {
            var userId = GetUserId(ctx);

            var accounts = await db.Accounts
                .Where(a => a.UserId == userId)
                .ToListAsync();

            var groupsById = await db.CategoryGroups
                .Where(g => g.UserId == userId)
                .ToDictionaryAsync(g => g.Id, g => g);

            var prefs = await db.CategoryPreferences
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
        });

        group.MapPost("/", async (CreateCategoryDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            var nameExists = await db.Accounts.AnyAsync(a =>
                a.UserId == userId &&
                a.Type == dto.Type &&
                a.Name.ToLower() == dto.Name.Trim().ToLower());
            if (nameExists)
            {
                return Results.BadRequest(new { error = "Categorie deja existante pour ce type" });
            }

            var categoryGroup = await ResolveOrCreateGroupAsync(db, userId, dto.Type, dto.GroupId, dto.Group);
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

            var maxSort = await db.CategoryPreferences
                .Where(p => p.UserId == userId)
                .Select(p => (int?)p.SortOrder)
                .MaxAsync() ?? -1;

            db.Accounts.Add(account);
            db.CategoryPreferences.Add(new CategoryPreference
            {
                AccountId = account.Id,
                UserId = userId,
                SortOrder = maxSort + 1,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync();

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
        });

        group.MapPut("/{id:guid}", async (Guid id, UpdateCategoryDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);

            var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);
            if (account is null) return Results.NotFound();

            var categoryGroup = await ResolveOrCreateGroupAsync(db, userId, dto.Type, dto.GroupId, dto.Group);
            if (categoryGroup is null)
            {
                return Results.BadRequest(new { error = "Groupe invalide" });
            }

            account.Name = dto.Name.Trim();
            account.Type = dto.Type;
            account.Group = categoryGroup.Name;
            account.GroupId = categoryGroup.Id;
            await db.SaveChangesAsync();

            return Results.Ok(new
            {
                id = account.Id,
                name = account.Name,
                type = account.Type == AccountType.Income ? "income" : "expense",
                group = account.Group,
                groupId = account.GroupId,
            });
        });

        group.MapPatch("/{id:guid}/archive", async (Guid id, ArchiveCategoryDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var exists = await db.Accounts.AnyAsync(a => a.Id == id && a.UserId == userId);
            if (!exists) return Results.NotFound();

            var pref = await db.CategoryPreferences.FirstOrDefaultAsync(p => p.AccountId == id && p.UserId == userId);
            if (pref is null)
            {
                var maxSort = await db.CategoryPreferences
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
                db.CategoryPreferences.Add(pref);
            }
            else
            {
                pref.IsArchived = dto.IsArchived;
                pref.UpdatedAt = DateTime.UtcNow;
            }

            await db.SaveChangesAsync();
            return Results.Ok(new { id, isArchived = dto.IsArchived });
        });

        group.MapPatch("/reorder", async (ReorderCategoriesDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var now = DateTime.UtcNow;

            var ids = dto.Items.Select(i => i.CategoryId).Distinct().ToList();
            var ownedIds = await db.Accounts
                .Where(a => a.UserId == userId && ids.Contains(a.Id))
                .Select(a => a.Id)
                .ToListAsync();

            if (ownedIds.Count != ids.Count)
            {
                return Results.BadRequest(new { error = "Certaines categories sont invalides" });
            }

            var existingPrefs = await db.CategoryPreferences
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

                db.CategoryPreferences.Add(new CategoryPreference
                {
                    AccountId = item.CategoryId,
                    UserId = userId,
                    SortOrder = item.SortOrder,
                    IsArchived = false,
                    CreatedAt = now,
                    UpdatedAt = now,
                });
            }

            await db.SaveChangesAsync();
            return Results.Ok(new { updated = dto.Items.Count });
        });
    }

    private static void MapCategoryGroupEndpoints(WebApplication app)
    {
        var group = app.MapGroup("/api/category-groups");

        group.MapGet("/", async (SolverDbContext db, HttpContext ctx, bool includeArchived = false) =>
        {
            var userId = GetUserId(ctx);

            var groups = await db.CategoryGroups
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
        });

        group.MapPost("/", async (CreateCategoryGroupDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var name = dto.Name.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                return Results.BadRequest(new { error = "Nom de groupe requis" });
            }

            var exists = await db.CategoryGroups.AnyAsync(g =>
                g.UserId == userId &&
                g.Type == dto.Type &&
                g.Name.ToLower() == name.ToLower());
            if (exists)
            {
                return Results.BadRequest(new { error = "Groupe deja existant" });
            }

            var maxSort = await db.CategoryGroups
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

            db.CategoryGroups.Add(created);
            await db.SaveChangesAsync();

            return Results.Created($"/api/category-groups/{created.Id}", new
            {
                id = created.Id,
                name = created.Name,
                type = created.Type == AccountType.Income ? "income" : "expense",
                sortOrder = created.SortOrder,
                isArchived = created.IsArchived,
            });
        });

        group.MapPut("/{id:guid}", async (Guid id, UpdateCategoryGroupDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var categoryGroup = await db.CategoryGroups.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
            if (categoryGroup is null) return Results.NotFound();

            var name = dto.Name.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                return Results.BadRequest(new { error = "Nom de groupe requis" });
            }

            var duplicate = await db.CategoryGroups.AnyAsync(g =>
                g.Id != id &&
                g.UserId == userId &&
                g.Type == categoryGroup.Type &&
                g.Name.ToLower() == name.ToLower());
            if (duplicate)
            {
                return Results.BadRequest(new { error = "Groupe deja existant" });
            }

            categoryGroup.Name = name;
            categoryGroup.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();

            await db.Database.ExecuteSqlInterpolatedAsync(
                $"UPDATE accounts SET \"group\" = {name} WHERE user_id = {userId} AND group_id = {id}");

            return Results.Ok(new
            {
                id = categoryGroup.Id,
                name = categoryGroup.Name,
                type = categoryGroup.Type == AccountType.Income ? "income" : "expense",
                sortOrder = categoryGroup.SortOrder,
                isArchived = categoryGroup.IsArchived,
            });
        });

        group.MapPatch("/{id:guid}/archive", async (Guid id, ArchiveCategoryGroupDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var categoryGroup = await db.CategoryGroups.FirstOrDefaultAsync(g => g.Id == id && g.UserId == userId);
            if (categoryGroup is null) return Results.NotFound();

            categoryGroup.IsArchived = dto.IsArchived;
            categoryGroup.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();

            return Results.Ok(new { id, isArchived = dto.IsArchived });
        });

        group.MapPatch("/reorder", async (ReorderCategoryGroupsDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var ids = dto.Items.Select(i => i.GroupId).Distinct().ToList();

            var groups = await db.CategoryGroups
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
                await db.SaveChangesAsync();
            }

            return Results.Ok(new { updated = dto.Items.Count });
        });
    }

    private static async Task<CategoryGroup?> ResolveOrCreateGroupAsync(
        SolverDbContext db,
        Guid userId,
        AccountType type,
        Guid? groupId,
        string? groupName
    )
    {
        if (groupId.HasValue)
        {
            var existingById = await db.CategoryGroups
                .FirstOrDefaultAsync(g => g.Id == groupId.Value && g.UserId == userId);
            if (existingById is null) return null;
            if (existingById.Type != type) return null;
            return existingById;
        }

        if (string.IsNullOrWhiteSpace(groupName)) return null;
        var normalizedName = groupName.Trim();

        var existingByName = await db.CategoryGroups
            .FirstOrDefaultAsync(g =>
                g.UserId == userId &&
                g.Type == type &&
                g.Name.ToLower() == normalizedName.ToLower());
        if (existingByName is not null) return existingByName;

        var maxSort = await db.CategoryGroups
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

        db.CategoryGroups.Add(created);
        await db.SaveChangesAsync();
        return created;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
