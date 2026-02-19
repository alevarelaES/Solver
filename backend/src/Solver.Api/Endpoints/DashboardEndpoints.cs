using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class DashboardEndpoints
{
    public static void MapDashboardEndpoints(this WebApplication app)
    {
        app.MapGet("/api/dashboard", (
            int? year,
            DashboardService service,
            HttpContext ctx) => service.GetDashboardAsync(year, ctx));
    }
}
