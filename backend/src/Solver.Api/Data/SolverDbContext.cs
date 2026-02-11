using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage.ValueConversion;
using Solver.Api.Models;

namespace Solver.Api.Data;

public class SolverDbContext(DbContextOptions<SolverDbContext> options) : DbContext(options)
{
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<Transaction> Transactions => Set<Transaction>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // Lowercase enum converters to match DB check constraints
        var accountTypeConverter = new ValueConverter<AccountType, string>(
            v => v.ToString().ToLowerInvariant(),
            v => Enum.Parse<AccountType>(v, ignoreCase: true));

        var transactionStatusConverter = new ValueConverter<TransactionStatus, string>(
            v => v.ToString().ToLowerInvariant(),
            v => Enum.Parse<TransactionStatus>(v, ignoreCase: true));

        modelBuilder.Entity<Account>(entity =>
        {
            entity.ToTable("accounts");
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Name).HasColumnName("name");
            entity.Property(e => e.Type).HasColumnName("type").HasConversion(accountTypeConverter);
            entity.Property(e => e.Group).HasColumnName("group");
            entity.Property(e => e.IsFixed).HasColumnName("is_fixed");
            entity.Property(e => e.Budget).HasColumnName("budget");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at");

            entity.HasIndex(e => e.UserId);
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
    }
}
