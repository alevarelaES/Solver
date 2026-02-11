using dotenv.net;
using Microsoft.EntityFrameworkCore;
using Solver.Api.Data;
using Solver.Api.Endpoints;
using Solver.Api.Middleware;

DotEnv.Load(options: new DotEnvOptions(envFilePaths: [".env"]));

var builder = WebApplication.CreateBuilder(args);

// Database
var connectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
    ?? throw new InvalidOperationException("DB_CONNECTION_STRING is not set.");

builder.Services.AddDbContext<SolverDbContext>(options =>
    options.UseNpgsql(connectionString));

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy
            .SetIsOriginAllowed(origin => new Uri(origin).Host == "localhost")
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

var app = builder.Build();

// Health check (no auth required)
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// Pipeline order matters
app.UseCors();
app.UseMiddleware<SupabaseAuthMiddleware>();

// Endpoints
app.MapAccountsEndpoints();
app.MapTransactionsEndpoints();
app.MapDashboardEndpoints();

app.Run();
