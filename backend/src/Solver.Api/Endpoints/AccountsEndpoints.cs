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
            var account = new Account
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Name = dto.Name,
                Type = dto.Type,
                Group = dto.Group,
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

            account.Name = dto.Name;
            account.Type = dto.Type;
            account.Group = dto.Group;
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

    private static Guid GetUserId(HttpContext ctx) => (Guid)ctx.Items["UserId"]!;
}
