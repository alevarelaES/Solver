using Solver.Api.DTOs;
using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class AccountsEndpoints
{
    public static void MapAccountsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/accounts");

        group.MapGet("/", (
            AccountsService service,
            HttpContext ctx) => service.GetAccountsAsync(ctx));
        group.MapPost("/", (
            CreateAccountDto dto,
            AccountsService service,
            HttpContext ctx) => service.CreateAccountAsync(dto, ctx));
        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateAccountDto dto,
            AccountsService service,
            HttpContext ctx) => service.UpdateAccountAsync(id, dto, ctx));
        group.MapPatch("/{id:guid}/budget", (
            Guid id,
            UpdateBudgetDto dto,
            AccountsService service,
            HttpContext ctx) => service.UpdateBudgetAsync(id, dto, ctx));
        group.MapDelete("/{id:guid}", (
            Guid id,
            AccountsService service,
            HttpContext ctx) => service.DeleteAccountAsync(id, ctx));
    }
}
