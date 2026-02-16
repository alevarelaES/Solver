using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Solver.Api.Models;

namespace Solver.Api.Data;

public class SolverDbContext(DbContextOptions<SolverDbContext> options) : DbContext(options)
{
    public DbSet<AppDataMigration> AppDataMigrations => Set<AppDataMigration>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<CategoryGroup> CategoryGroups => Set<CategoryGroup>();
    public DbSet<CategoryPreference> CategoryPreferences => Set<CategoryPreference>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<BudgetPlanMonth> BudgetPlanMonths => Set<BudgetPlanMonth>();
    public DbSet<BudgetPlanGroupAllocation> BudgetPlanGroupAllocations => Set<BudgetPlanGroupAllocation>();
    public DbSet<SavingGoal> SavingGoals => Set<SavingGoal>();
    public DbSet<SavingGoalEntry> SavingGoalEntries => Set<SavingGoalEntry>();
    public DbSet<PortfolioHolding> PortfolioHoldings => Set<PortfolioHolding>();
    public DbSet<WatchlistItem> WatchlistItems => Set<WatchlistItem>();
    public DbSet<AssetPriceCache> AssetPriceCache => Set<AssetPriceCache>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Lowercase enum converters to match DB check constraints
        var accountTypeConverter = new ValueConverter<AccountType, string>(
            v => v.ToString().ToLowerInvariant(),
            v => Enum.Parse<AccountType>(v, ignoreCase: true));

        var transactionStatusConverter = new ValueConverter<TransactionStatus, string>(
            v => v.ToString().ToLowerInvariant(),
            v => Enum.Parse<TransactionStatus>(v, ignoreCase: true));
        var savingGoalTypeConverter = new ValueConverter<SavingGoalType, string>(
            v => v.ToString().ToLowerInvariant(),
            v => Enum.Parse<SavingGoalType>(v, ignoreCase: true));

        modelBuilder.Entity<Account>(entity =>
        {
            entity.ToTable("accounts");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.Type).HasColumnName("type").HasConversion(accountTypeConverter);
            entity.Property(e => e.Group).HasColumnName("group");
            entity.Property(e => e.GroupId).HasColumnName("group_id");
            entity.Property(e => e.IsFixed).HasColumnName("is_fixed");
            entity.Property(e => e.Budget).HasColumnName("budget");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.GroupId });

            entity.HasOne(e => e.CategoryGroup)
                .WithMany(g => g.Accounts)
                .HasForeignKey(e => e.GroupId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        modelBuilder.Entity<CategoryGroup>(entity =>
        {
            entity.ToTable("category_groups");
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.Type).HasColumnName("type").HasConversion(accountTypeConverter);
            entity.Property(e => e.SortOrder).HasColumnName("sort_order");
            entity.Property(e => e.IsArchived).HasColumnName("is_archived");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);
        });

        modelBuilder.Entity<AppDataMigration>(entity =>
        {
            entity.ToTable("app_data_migrations");
            entity.HasKey(e => e.Name);
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.AppliedAt).HasColumnName("applied_at");
        });

        modelBuilder.Entity<Transaction>(entity =>
        {
            entity.ToTable("transactions");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.AccountId).HasColumnName("account_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Date).HasColumnName("date");
            entity.Property(e => e.Amount).HasColumnName("amount");
            entity.Property(e => e.Note).HasColumnName("note");
            entity.Property(e => e.Status).HasColumnName("status").HasConversion(transactionStatusConverter);
            entity.Property(e => e.IsAuto).HasColumnName("is_auto");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.Date });
            entity.HasIndex(e => e.AccountId);

            entity.HasOne(e => e.Account)
                .WithMany(a => a.Transactions)
                .HasForeignKey(e => e.AccountId);
        });

        modelBuilder.Entity<CategoryPreference>(entity =>
        {
            entity.ToTable("category_preferences");
            entity.HasKey(e => new { e.AccountId, e.UserId });

            entity.Property(e => e.AccountId).HasColumnName("account_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.SortOrder).HasColumnName("sort_order");
            entity.Property(e => e.IsArchived).HasColumnName("is_archived");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);

            entity.HasOne(e => e.Account)
                .WithMany()
                .HasForeignKey(e => e.AccountId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<BudgetPlanMonth>(entity =>
        {
            entity.ToTable("budget_plan_months");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Year).HasColumnName("year");
            entity.Property(e => e.Month).HasColumnName("month");
            entity.Property(e => e.ForecastDisposableIncome).HasColumnName("forecast_disposable_income");
            entity.Property(e => e.UseGrossIncomeBase).HasColumnName("use_gross_income_base");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.Year, e.Month }).IsUnique();
        });

        modelBuilder.Entity<BudgetPlanGroupAllocation>(entity =>
        {
            entity.ToTable("budget_plan_group_allocations");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.PlanMonthId).HasColumnName("plan_month_id");
            entity.Property(e => e.GroupId).HasColumnName("group_id");
            entity.Property(e => e.InputMode).HasColumnName("input_mode");
            entity.Property(e => e.PlannedPercent).HasColumnName("planned_percent");
            entity.Property(e => e.PlannedAmount).HasColumnName("planned_amount");
            entity.Property(e => e.Priority).HasColumnName("priority");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.PlanMonthId, e.GroupId }).IsUnique();

            entity.HasOne(e => e.PlanMonth)
                .WithMany(m => m.GroupAllocations)
                .HasForeignKey(e => e.PlanMonthId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Group)
                .WithMany()
                .HasForeignKey(e => e.GroupId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<SavingGoal>(entity =>
        {
            entity.ToTable("saving_goals");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.GoalType).HasColumnName("goal_type").HasConversion(savingGoalTypeConverter);
            entity.Property(e => e.TargetAmount).HasColumnName("target_amount");
            entity.Property(e => e.TargetDate).HasColumnName("target_date");
            entity.Property(e => e.InitialAmount).HasColumnName("initial_amount");
            entity.Property(e => e.MonthlyContribution).HasColumnName("monthly_contribution");
            entity.Property(e => e.AutoContributionEnabled).HasColumnName("auto_contribution_enabled");
            entity.Property(e => e.AutoContributionStartDate).HasColumnName("auto_contribution_start_date");
            entity.Property(e => e.Priority).HasColumnName("priority");
            entity.Property(e => e.IsArchived).HasColumnName("is_archived");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.Priority });
        });

        modelBuilder.Entity<SavingGoalEntry>(entity =>
        {
            entity.ToTable("saving_goal_entries");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.GoalId).HasColumnName("goal_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.EntryDate).HasColumnName("entry_date");
            entity.Property(e => e.Amount).HasColumnName("amount");
            entity.Property(e => e.Note).HasColumnName("note");
            entity.Property(e => e.IsAuto).HasColumnName("is_auto");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.EntryDate });
            entity.HasIndex(e => e.GoalId);

            entity.HasOne(e => e.Goal)
                .WithMany(g => g.Entries)
                .HasForeignKey(e => e.GoalId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<PortfolioHolding>(entity =>
        {
            entity.ToTable("portfolio_holdings");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Symbol).HasColumnName("symbol").HasMaxLength(20).IsRequired();
            entity.Property(e => e.Exchange).HasColumnName("exchange").HasMaxLength(20);
            entity.Property(e => e.Name).HasColumnName("name").HasMaxLength(255);
            entity.Property(e => e.AssetType).HasColumnName("asset_type").HasMaxLength(20).HasDefaultValue("stock");
            entity.Property(e => e.Quantity).HasColumnName("quantity").HasPrecision(18, 8);
            entity.Property(e => e.AverageBuyPrice).HasColumnName("average_buy_price").HasPrecision(18, 8);
            entity.Property(e => e.BuyDate).HasColumnName("buy_date");
            entity.Property(e => e.Currency).HasColumnName("currency").HasMaxLength(3).HasDefaultValue("USD");
            entity.Property(e => e.Notes).HasColumnName("notes");
            entity.Property(e => e.IsArchived).HasColumnName("is_archived");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.Symbol });
        });

        modelBuilder.Entity<WatchlistItem>(entity =>
        {
            entity.ToTable("watchlist_items");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Symbol).HasColumnName("symbol").HasMaxLength(20).IsRequired();
            entity.Property(e => e.Exchange).HasColumnName("exchange").HasMaxLength(20);
            entity.Property(e => e.Name).HasColumnName("name").HasMaxLength(255);
            entity.Property(e => e.AssetType).HasColumnName("asset_type").HasMaxLength(20).HasDefaultValue("stock");
            entity.Property(e => e.SortOrder).HasColumnName("sort_order");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => new { e.UserId, e.Symbol }).IsUnique();
        });

        modelBuilder.Entity<AssetPriceCache>(entity =>
        {
            entity.ToTable("asset_price_cache");
            entity.HasKey(e => e.Symbol);
            entity.Property(e => e.Symbol).HasColumnName("symbol").HasMaxLength(20);
            entity.Property(e => e.Exchange).HasColumnName("exchange").HasMaxLength(20);
            entity.Property(e => e.Price).HasColumnName("price").HasPrecision(18, 8);
            entity.Property(e => e.PreviousClose).HasColumnName("previous_close").HasPrecision(18, 8);
            entity.Property(e => e.ChangePercent).HasColumnName("change_percent").HasPrecision(8, 4);
            entity.Property(e => e.Currency).HasColumnName("currency").HasMaxLength(3).HasDefaultValue("USD");
            entity.Property(e => e.FetchedAt).HasColumnName("fetched_at");

            entity.HasIndex(e => e.FetchedAt);
        });
    }
}
