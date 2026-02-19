using Solver.Api.DTOs;
using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class TransactionsEndpoints
{
    public static void MapTransactionsEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/transactions");

        group.MapGet("/", (
            TransactionsService service,
            HttpContext ctx,
            Guid? accountId,
            string? status,
            int? month,
            int? year,
            string? search,
            bool showFuture = false,
            int page = 1,
            int pageSize = 50) => service.GetTransactionsAsync(
                ctx,
                accountId,
                status,
                month,
                year,
                search,
                showFuture,
                page,
                pageSize));

        group.MapGet("/upcoming", (
            TransactionsService service,
            HttpContext ctx,
            int days = 30) => service.GetUpcomingAsync(ctx, days));

        group.MapGet("/projection/yearly", (
            TransactionsService service,
            HttpContext ctx,
            int? year) => service.GetProjectionYearlyAsync(ctx, year));

        group.MapPost("/", (
            CreateTransactionDto dto,
            TransactionsService service,
            HttpContext ctx) => service.CreateTransactionAsync(dto, ctx));

        group.MapPost("/batch", (
            BatchTransactionDto dto,
            TransactionsService service,
            HttpContext ctx) => service.CreateBatchAsync(dto, ctx));

        group.MapPost("/repayment-plan", (
            RepaymentPlanDto dto,
            TransactionsService service,
            HttpContext ctx) => service.CreateRepaymentPlanAsync(dto, ctx));

        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateTransactionDto dto,
            TransactionsService service,
            HttpContext ctx) => service.UpdateTransactionAsync(id, dto, ctx));

        group.MapDelete("/{id:guid}", (
            Guid id,
            TransactionsService service,
            HttpContext ctx) => service.DeleteTransactionAsync(id, ctx));
    }
}
