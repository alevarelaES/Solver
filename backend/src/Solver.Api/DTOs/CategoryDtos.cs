using System.ComponentModel.DataAnnotations;
using Solver.Api.Models;

namespace Solver.Api.DTOs;

public record CreateCategoryDto(
    [Required, MaxLength(100)] string Name,
    [Required] AccountType Type,
    Guid? GroupId,
    [MaxLength(50)] string? Group
);

public record UpdateCategoryDto(
    [Required, MaxLength(100)] string Name,
    [Required] AccountType Type,
    Guid? GroupId,
    [MaxLength(50)] string? Group
);

public record ArchiveCategoryDto(bool IsArchived);

public record ReorderCategoriesDto(
    [Required] List<ReorderCategoryItemDto> Items
);

public record ReorderCategoryItemDto(
    [Required] Guid CategoryId,
    [Range(0, 10_000)] int SortOrder
);

public record CreateCategoryGroupDto(
    [Required, MaxLength(50)] string Name,
    [Required] AccountType Type
);

public record UpdateCategoryGroupDto(
    [Required, MaxLength(50)] string Name
);

public record ArchiveCategoryGroupDto(bool IsArchived);

public record ReorderCategoryGroupsDto(
    [Required] List<ReorderCategoryGroupItemDto> Items
);

public record ReorderCategoryGroupItemDto(
    [Required] Guid GroupId,
    [Range(0, 10_000)] int SortOrder
);
