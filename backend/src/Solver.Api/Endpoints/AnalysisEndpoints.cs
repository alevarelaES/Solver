using Solver.Api.Services;

namespace Solver.Api.Endpoints;

public static class AnalysisEndpoints
{
    public static void MapAnalysisEndpoints(this WebApplication app)
    {
        app.MapGet("/api/analysis", (
            int? year,
            AnalysisService service,
            HttpContext ctx) => service.GetAnalysisAsync(year, ctx));
    }
}
