using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.DTOs;
using Solver.Api.Models;

namespace Solver.Api.Services;

public sealed class AccountsService
{
    private readonly SolverDbContext _db;

    public AccountsService(SolverDbContext db)
    {
        _db = db;
    }

    public async Task<IResult> GetAccountsAsync(HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var accounts = await _db.Accounts
            .Where(a => a.UserId == userId)
            .OrderBy(a => a.Group)
            .ThenBy(a => a.Name)
            .ToListAsync();

        return Results.Ok(accounts);
    }

    public async Task<IResult> CreateAccountAsync(CreateAccountDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var categoryGroup = await ResolveOrCreateGroupAsync(
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

        _db.Accounts.Add(account);
        await _db.SaveChangesAsync();

        return Results.Created($"/api/accounts/{account.Id}", account);
    }

    public async Task<IResult> UpdateAccountAsync(Guid id, UpdateAccountDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var account = await _db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (account is null) return Results.NotFound();

        var categoryGroup = await ResolveOrCreateGroupAsync(
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

        await _db.SaveChangesAsync();
        return Results.Ok(account);
    }

    public async Task<IResult> UpdateBudgetAsync(Guid id, UpdateBudgetDto dto, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var account = await _db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);
        if (account is null) return Results.NotFound();

        account.Budget = dto.Budget;
        await _db.SaveChangesAsync();
        return Results.Ok(account);
    }

    public async Task<IResult> DeleteAccountAsync(Guid id, HttpContext ctx)
    {
        var userId = GetUserId(ctx);
        var account = await _db.Accounts.FirstOrDefaultAsync(a => a.Id == id && a.UserId == userId);

        if (account is null) return Results.NotFound();

        _db.Accounts.Remove(account);
        await _db.SaveChangesAsync();

        return Results.NoContent();
    }

    private async Task<CategoryGroup> ResolveOrCreateGroupAsync(
        Guid userId,
        AccountType type,
        string groupName
    )
    {
        var normalized = groupName.Trim();
        var existing = await _db.CategoryGroups.FirstOrDefaultAsync(g =>
            g.UserId == userId &&
            g.Type == type &&
            EF.Functions.ILike(g.Name, normalized));
        if (existing is not null) return existing;

        var maxSort = await _db.CategoryGroups
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
        _db.CategoryGroups.Add(created);
        await _db.SaveChangesAsync();
        return created;
    }

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
