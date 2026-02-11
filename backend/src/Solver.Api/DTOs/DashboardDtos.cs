namespace Solver.Api.DTOs;

public record MonthCellDto(decimal Total, int PendingCount, int CompletedCount);

public record AccountMonthlyDto(
    Guid AccountId,
    string AccountName,
    string AccountType,
    Dictionary<int, MonthCellDto> Months);

public record GroupDto(
    string GroupName,
    List<AccountMonthlyDto> Accounts);

public record DashboardDto(
    decimal CurrentBalance,
    decimal CurrentMonthIncome,
    decimal CurrentMonthExpenses,
    decimal ProjectedEndOfMonth,
    decimal BalanceBeforeYear,
    List<GroupDto> Groups);
