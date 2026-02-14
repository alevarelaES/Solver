using dotenv.net;
using Microsoft.AspNetCore.ResponseCompression;
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

// Pipeline order matters
app.UseResponseCompression();
app.UseRouting();
app.UseCors();
app.UseMiddleware<SupabaseAuthMiddleware>();

// Endpoints
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
app.MapAccountsEndpoints();
app.MapTransactionsEndpoints();
app.MapDashboardEndpoints();
app.MapBudgetEndpoints();
app.MapAnalysisEndpoints();

app.Run();
