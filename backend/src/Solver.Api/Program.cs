using dotenv.net;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Middleware;
using Solver.Api.Services;

DotEnv.Load(options: new DotEnvOptions(envFilePaths: [".env"]));

var builder = WebApplication.CreateBuilder(args);

// Database
var rawConnectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
    ?? throw new InvalidOperationException("DB_CONNECTION_STRING is not set.");

var connectionStringBuilder = new NpgsqlConnectionStringBuilder(rawConnectionString);
var dbHost = connectionStringBuilder.Host ?? string.Empty;
if (dbHost.Contains("pooler.supabase.com", StringComparison.OrdinalIgnoreCase))
{
    // Supabase pooler already manages pooling; local Npgsql pooling can create
    // connector lifecycle races on some Npgsql/EF combinations.
    connectionStringBuilder.Pooling = false;
    connectionStringBuilder.Multiplexing = false;
    connectionStringBuilder.NoResetOnClose = true;
}
var connectionString = connectionStringBuilder.ConnectionString;

builder.Services.AddDbContext<SolverDbContext>(options =>
    options.UseNpgsql(connectionString, npgsql =>
        npgsql.EnableRetryOnFailure(3, TimeSpan.FromSeconds(2), null)));

// Response compression (gzip)
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<GzipCompressionProvider>();
});

// CORS
var allowedOrigins = Environment.GetEnvironmentVariable("ALLOWED_ORIGINS");
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        if (!string.IsNullOrEmpty(allowedOrigins))
        {
            // Production: restrict to specific origins
            policy
                .WithOrigins(allowedOrigins.Split(','))
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
        else
        {
            // Development: allow localhost
            policy
                .SetIsOriginAllowed(origin => new Uri(origin).Host == "localhost")
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
    });
});

var app = builder.Build();

// HTTPS redirect in production
if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

// Lightweight schema bootstrap for category preferences.
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<SolverDbContext>();
    await db.Database.ExecuteSqlRawAsync("""
        CREATE TABLE IF NOT EXISTS category_groups (
            id uuid PRIMARY KEY,
            user_id uuid NOT NULL,
            name text NOT NULL,
            type text NOT NULL,
            sort_order integer NOT NULL DEFAULT 0,
            is_archived boolean NOT NULL DEFAULT false,
            created_at timestamp with time zone NOT NULL DEFAULT now(),
            updated_at timestamp with time zone NOT NULL DEFAULT now()
        );
        CREATE INDEX IF NOT EXISTS ix_category_groups_user_id
            ON category_groups (user_id);
        CREATE INDEX IF NOT EXISTS ix_category_groups_user_type_sort
            ON category_groups (user_id, type, sort_order);

        ALTER TABLE accounts ADD COLUMN IF NOT EXISTS group_id uuid NULL;
        CREATE INDEX IF NOT EXISTS ix_accounts_user_id_group_id
            ON accounts (user_id, group_id);
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'fk_accounts_group_id'
            ) THEN
                ALTER TABLE accounts
                ADD CONSTRAINT fk_accounts_group_id
                FOREIGN KEY (group_id)
                REFERENCES category_groups (id)
                ON DELETE SET NULL;
            END IF;
        END $$;

        CREATE TABLE IF NOT EXISTS category_preferences (
            account_id uuid NOT NULL,
            user_id uuid NOT NULL,
            sort_order integer NOT NULL DEFAULT 0,
            is_archived boolean NOT NULL DEFAULT false,
            created_at timestamp with time zone NOT NULL DEFAULT now(),
            updated_at timestamp with time zone NOT NULL DEFAULT now(),
            CONSTRAINT pk_category_preferences PRIMARY KEY (account_id, user_id),
            CONSTRAINT fk_category_preferences_account_id FOREIGN KEY (account_id)
                REFERENCES accounts (id) ON DELETE CASCADE
        );
        CREATE INDEX IF NOT EXISTS ix_category_preferences_user_id
            ON category_preferences (user_id);
        """);
    await CategoryResetMigration.ApplyAsync(db);
    await CategoryGroupBackfillMigration.ApplyAsync(db);
}

// Pipeline order matters
app.UseResponseCompression();
app.UseRouting();
app.UseCors();
app.UseMiddleware<SupabaseAuthMiddleware>();

// Endpoints
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapAccountsEndpoints();
app.MapCategoriesEndpoints();
app.MapTransactionsEndpoints();
app.MapDashboardEndpoints();
app.MapBudgetEndpoints();
app.MapAnalysisEndpoints();

app.Run();
