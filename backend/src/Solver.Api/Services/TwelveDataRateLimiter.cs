namespace Solver.Api.Services;

public class TwelveDataRateLimiter
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    private int _callsThisMinute;
    private int _callsToday;
    private DateTime _minuteStart = DateTime.UtcNow;
    private DateTime _dayStart = DateTime.UtcNow.Date;

    private const int MaxPerMinute = 7;  // limit is 8, keep margin
    private const int MaxPerDay = 780;   // limit is 800, keep margin

    public async Task<bool> TryAcquireAsync()
    {
        await _semaphore.WaitAsync();
        try
        {
            var now = DateTime.UtcNow;

            if ((now - _minuteStart).TotalMinutes >= 1)
            {
                _callsThisMinute = 0;
                _minuteStart = now;
            }

            if (now.Date > _dayStart)
            {
                _callsToday = 0;
                _dayStart = now.Date;
            }

            if (_callsThisMinute >= MaxPerMinute || _callsToday >= MaxPerDay)
                return false;

            _callsThisMinute++;
            _callsToday++;
            return true;
        }
        finally
        {
            _semaphore.Release();
        }
    }
}
