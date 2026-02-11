using System.ComponentModel.DataAnnotations;
using Solver.Api.Models;

namespace Solver.Api.DTOs;

public record CreateAccountDto(
    [Required, MaxLength(100)] string Name,
    [Required] AccountType Type,
    [Required, MaxLength(50)] string Group,
    bool IsFixed,
    [Range(0, 10_000_000)] decimal Budget
);

public record UpdateAccountDto(
    [Required, MaxLength(100)] string Name,
    [Required] AccountType Type,
    [Required, MaxLength(50)] string Group,
    bool IsFixed,
    [Range(0, 10_000_000)] decimal Budget
);

public record UpdateBudgetDto([Range(0, 10_000_000)] decimal Budget);
