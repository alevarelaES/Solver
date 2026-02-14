using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Endpoints;

public static class AccountsEndpoints
{
    
    public static void MapAccountsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/accounts");

        group.MapGet("/", async (SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var accounts = await db.Accounts
                .Where(a => a.UserId == userId)
                .OrderBy(a => a.Group)
                .ThenBy(a => a.Name)
                .ToListAsync();

            return Results.Ok(accounts);
        });

        group.MapPost("/", async (CreateAccountDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var categoryGroup = await ResolveOrCreateGroupAsync(
                db,
                userId,
                dto.Type,
                dto.Group.Trim()
            );

            var account = new Account
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Name = dto.Name.Trim(),
                Type = dto.Type,
                Group = categoryGroup.Name,
                GroupId = categoryGroup.Id,
                IsFixed = dto.IsFixed,
                Budget = dto.Budget,
                CreatedAt = DateTime.UtcNow
            };

            db.Accounts.Add(account);
            await db.SaveChangesAsync();

            return Results.Created($"/api/accounts/{account.Id}", account);
        });

        group.MapPut("/{id:guid}", async (Guid id, UpdateAccountDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

            if (account is null) return Results.NotFound();

            var categoryGroup = await ResolveOrCreateGroupAsync(
                db,
                userId,
                dto.Type,
                dto.Group.Trim()
            );

            account.Name = dto.Name.Trim();
            account.Type = dto.Type;
            account.Group = categoryGroup.Name;
            account.GroupId = categoryGroup.Id;
            account.IsFixed = dto.IsFixed;
            account.Budget = dto.Budget;

            await db.SaveChangesAsync();
            return Results.Ok(account);
        });

        group.MapPatch("/{id:guid}/budget", async (Guid id, UpdateBudgetDto dto, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);
            if (account is null) return Results.NotFound();

            account.Budget = dto.Budget;
            await db.SaveChangesAsync();
            return Results.Ok(account);
        });

        group.MapDelete("/{id:guid}", async (Guid id, SolverDbContext db, HttpContext ctx) =>
        {
            var userId = GetUserId(ctx);
            var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

            if (account is null) return Results.NotFound();

            db.Accounts.Remove(account);
            await db.SaveChangesAsync();

            return Results.NoContent();
        });
    }

    private static async Task<CategoryGroup> ResolveOrCreateGroupAsync(
        SolverDbContext db,
        Guid userId,
        AccountType type,
        string groupName
    )
    {
        var normalized = groupName.Trim();
        var existing = await db.CategoryGroups.FirstOrDefaultAsync(g =>
            g.UserId == userId &&
            g.Type == type &&
            g.Name.ToLower() == normalized.ToLower());
        if (existing is not null) return existing;

        var maxSort = await db.CategoryGroups
            .Where(g => g.UserId == userId && g.Type == type)
            .Select(g => (int?)g.SortOrder)
            .MaxAsync() ?? -1;

        var created = new CategoryGroup
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Name = normalized,
            Type = type,
            SortOrder = maxSort + 1,
            IsArchived = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.CategoryGroups.Add(created);
        await db.SaveChangesAsync();
        return created;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
