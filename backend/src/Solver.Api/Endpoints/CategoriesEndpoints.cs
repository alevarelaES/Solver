using Solver.Api.DTOs;
using Solver.Api.Services;

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

        group.MapGet("/", (
            CategoriesService service,
            HttpContext ctx,
            bool includeArchived = false) => service.GetCategoriesAsync(ctx, includeArchived));

        group.MapPost("/", (
            CreateCategoryDto dto,
            CategoriesService service,
            HttpContext ctx) => service.CreateCategoryAsync(dto, ctx));

        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateCategoryDto dto,
            CategoriesService service,
            HttpContext ctx) => service.UpdateCategoryAsync(id, dto, ctx));

        group.MapPatch("/{id:guid}/archive", (
            Guid id,
            ArchiveCategoryDto dto,
            CategoriesService service,
            HttpContext ctx) => service.ArchiveCategoryAsync(id, dto, ctx));

        group.MapPatch("/reorder", (
            ReorderCategoriesDto dto,
            CategoriesService service,
            HttpContext ctx) => service.ReorderCategoriesAsync(dto, ctx));
    }

    private static void MapCategoryGroupEndpoints(WebApplication app)
    {
        var group = app.MapGroup("/api/category-groups");

        group.MapGet("/", (
            CategoriesService service,
            HttpContext ctx,
            bool includeArchived = false) => service.GetCategoryGroupsAsync(ctx, includeArchived));

        group.MapPost("/", (
            CreateCategoryGroupDto dto,
            CategoriesService service,
            HttpContext ctx) => service.CreateCategoryGroupAsync(dto, ctx));

        group.MapPut("/{id:guid}", (
            Guid id,
            UpdateCategoryGroupDto dto,
            CategoriesService service,
            HttpContext ctx) => service.UpdateCategoryGroupAsync(id, dto, ctx));

        group.MapPatch("/{id:guid}/archive", (
            Guid id,
            ArchiveCategoryGroupDto dto,
            CategoriesService service,
            HttpContext ctx) => service.ArchiveCategoryGroupAsync(id, dto, ctx));

        group.MapPatch("/reorder", (
            ReorderCategoryGroupsDto dto,
            CategoriesService service,
            HttpContext ctx) => service.ReorderCategoryGroupsAsync(dto, ctx));
    }
}
