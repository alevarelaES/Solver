param(
  [string]$FrontendEnvPath = ".env.local",
  [string]$BackendEnvPath = "backend/src/Solver.Api/.env",
  [switch]$FailOnWarnings
)

$ErrorActionPreference = "Stop"
$warnings = New-Object System.Collections.Generic.List[string]

function Read-EnvFile {
  param([string]$Path)

  $values = @{}
  if (-not (Test-Path $Path)) {
    return $values
  }

  foreach ($rawLine in Get-Content $Path) {
    $line = $rawLine.Trim()
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
      continue
    }

    $idx = $line.IndexOf("=")
    if ($idx -lt 1) {
      continue
    }

    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1)
    $values[$key] = $value
  }

  return $values
}

function Get-EnvValue {
  param(
    [hashtable]$Map,
    [string]$Key
  )

  if ($Map.ContainsKey($Key)) {
    return [string]$Map[$Key]
  }

  return ""
}

function Add-CheckResult {
  param(
    [string]$Label,
    [bool]$Success,
    [string]$Details
  )

  $status = if ($Success) { "OK" } else { "WARN" }
  Write-Host "[$status] $Label - $Details"
  if (-not $Success) {
    $warnings.Add("$Label - $Details")
  }
}

function Try-Get-DbHost {
  param([string]$ConnectionString)

  if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    return ""
  }

  if ($ConnectionString.StartsWith("postgres://", [System.StringComparison]::OrdinalIgnoreCase) -or
      $ConnectionString.StartsWith("postgresql://", [System.StringComparison]::OrdinalIgnoreCase)) {
    try {
      $uri = [System.Uri]::new($ConnectionString)
      return $uri.Host
    }
    catch {
      return ""
    }
  }

  foreach ($segment in $ConnectionString.Split(";")) {
    $part = $segment.Trim()
    if ([string]::IsNullOrWhiteSpace($part)) {
      continue
    }

    $idx = $part.IndexOf("=")
    if ($idx -lt 1) {
      continue
    }

    $key = $part.Substring(0, $idx).Trim().ToLowerInvariant()
    $value = $part.Substring($idx + 1).Trim()
    if ($key -eq "host" -or $key -eq "server") {
      return $value
    }
  }

  return ""
}

function GetPartFromConnectionStringValue {
  param(
    [string]$ConnectionString,
    [string]$Key
  )

  if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
    return ""
  }

  if ($ConnectionString.StartsWith("postgres://", [System.StringComparison]::OrdinalIgnoreCase) -or
      $ConnectionString.StartsWith("postgresql://", [System.StringComparison]::OrdinalIgnoreCase)) {
    try {
      $uri = [System.Uri]::new($ConnectionString)
      switch ($targetKey) {
        "host" { return $uri.Host }
        "port" { return [string]$uri.Port }
        "username" {
          $userInfo = $uri.UserInfo
          if ([string]::IsNullOrWhiteSpace($userInfo)) { return "" }
          $parts = $userInfo.Split(":", 2, [System.StringSplitOptions]::None)
          return [System.Uri]::UnescapeDataString($parts[0])
        }
        "user id" {
          $userInfo = $uri.UserInfo
          if ([string]::IsNullOrWhiteSpace($userInfo)) { return "" }
          $parts = $userInfo.Split(":", 2, [System.StringSplitOptions]::None)
          return [System.Uri]::UnescapeDataString($parts[0])
        }
        "password" {
          $userInfo = $uri.UserInfo
          if ([string]::IsNullOrWhiteSpace($userInfo)) { return "" }
          $parts = $userInfo.Split(":", 2, [System.StringSplitOptions]::None)
          if ($parts.Length -lt 2) { return "" }
          return [System.Uri]::UnescapeDataString($parts[1])
        }
      }
    }
    catch {
      return ""
    }
  }

  $targetKey = $Key.Trim().ToLowerInvariant()
  foreach ($segment in $ConnectionString.Split(";")) {
    $part = $segment.Trim()
    if ([string]::IsNullOrWhiteSpace($part)) {
      continue
    }

    $idx = $part.IndexOf("=")
    if ($idx -lt 1) {
      continue
    }

    $name = $part.Substring(0, $idx).Trim().ToLowerInvariant()
    if ($name -eq $targetKey) {
      return $part.Substring($idx + 1).Trim()
    }
  }

  return ""
}

Write-Host "=== Env Security Check ==="

$frontend = Read-EnvFile -Path $FrontendEnvPath
$backend = Read-EnvFile -Path $BackendEnvPath

if (-not (Test-Path $FrontendEnvPath)) {
  Add-CheckResult "Frontend env file" $false "$FrontendEnvPath missing"
}
else {
  Add-CheckResult "Frontend env file" $true "$FrontendEnvPath found"
}

if (-not (Test-Path $BackendEnvPath)) {
  Add-CheckResult "Backend env file" $false "$BackendEnvPath missing"
}
else {
  Add-CheckResult "Backend env file" $true "$BackendEnvPath found"
}

Write-Host ""
Write-Host "=== Frontend checks ==="
Add-CheckResult "SUPABASE_URL (frontend)" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $frontend "SUPABASE_URL"))) "must be set"
Add-CheckResult "SUPABASE_ANON_KEY (frontend)" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $frontend "SUPABASE_ANON_KEY"))) "must be set"
Add-CheckResult "API_BASE_URL (frontend)" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $frontend "API_BASE_URL"))) "must be set"

Write-Host ""
Write-Host "=== Backend checks ==="
$dbConnection = Get-EnvValue $backend "DB_CONNECTION_STRING"
$dbRuntimeConnection = Get-EnvValue $backend "DB_RUNTIME_CONNECTION_STRING"
$dbMigrationsConnection = Get-EnvValue $backend "DB_MIGRATIONS_CONNECTION_STRING"
$dbApplyMigrations = (Get-EnvValue $backend "DB_APPLY_MIGRATIONS_ON_STARTUP").Trim().ToLowerInvariant()
$allowHsFallback = (Get-EnvValue $backend "AUTH_ALLOW_HS256_FALLBACK").Trim().ToLowerInvariant()
$jwtSecret = Get-EnvValue $backend "JWT_SECRET"

Add-CheckResult "DB_CONNECTION_STRING" (-not [string]::IsNullOrWhiteSpace($dbConnection)) "must be set"
if (-not [string]::IsNullOrWhiteSpace($dbRuntimeConnection)) {
  Add-CheckResult "DB_RUNTIME_CONNECTION_STRING" $true "set"
}
Add-CheckResult "SUPABASE_URL (backend)" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $backend "SUPABASE_URL"))) "must be set"

Write-Host ""
Write-Host "=== Shell override checks ==="
$sensitiveKeys = @(
  "DB_CONNECTION_STRING",
  "DB_RUNTIME_CONNECTION_STRING",
  "DB_MIGRATIONS_CONNECTION_STRING",
  "SUPABASE_URL",
  "AUTH_ALLOW_HS256_FALLBACK",
  "DB_APPLY_MIGRATIONS_ON_STARTUP",
  "JWT_SECRET"
)
foreach ($k in $sensitiveKeys) {
  $fileValue = Get-EnvValue $backend $k
  $processValue = [Environment]::GetEnvironmentVariable($k)
  if (-not [string]::IsNullOrWhiteSpace($processValue)) {
    if ([string]::IsNullOrWhiteSpace($fileValue)) {
      Add-CheckResult "Process env override: $k" $false "present in current shell but missing in .env (may override runtime)"
    }
    elseif ($processValue -ne $fileValue) {
      Add-CheckResult "Process env override: $k" $false "differs from .env (may override runtime)"
    }
    else {
      Add-CheckResult "Process env override: $k" $true "matches .env"
    }
  }
}

if ([string]::IsNullOrWhiteSpace($allowHsFallback)) {
  Add-CheckResult "AUTH_ALLOW_HS256_FALLBACK" $false "should be explicitly set (true/false)"
}
else {
  Add-CheckResult "AUTH_ALLOW_HS256_FALLBACK" $true "value is set"
}

if ($allowHsFallback -eq "false") {
  Add-CheckResult "JWT_SECRET policy" ([string]::IsNullOrWhiteSpace($jwtSecret)) "must be empty/removed when fallback=false"
}
elseif ($allowHsFallback -eq "true") {
  Add-CheckResult "JWT_SECRET policy" (-not [string]::IsNullOrWhiteSpace($jwtSecret)) "must be set when fallback=true"
}
else {
  Add-CheckResult "JWT_SECRET policy" $false "cannot validate because AUTH_ALLOW_HS256_FALLBACK is invalid"
}

$runtimeConnectionEffective = if ([string]::IsNullOrWhiteSpace($dbRuntimeConnection)) {
  $dbConnection
}
else {
  $dbRuntimeConnection
}

$dbHost = Try-Get-DbHost -ConnectionString $runtimeConnectionEffective
$migrationsHost = Try-Get-DbHost -ConnectionString $dbMigrationsConnection
$usesPooler = $dbHost.ToLowerInvariant().Contains("pooler.supabase.com")
$migrationUsesPooler = $migrationsHost.ToLowerInvariant().Contains("pooler.supabase.com")
$runtimeUser = (GetPartFromConnectionStringValue -ConnectionString $runtimeConnectionEffective -Key "username")
if ([string]::IsNullOrWhiteSpace($runtimeUser)) {
  $runtimeUser = (GetPartFromConnectionStringValue -ConnectionString $runtimeConnectionEffective -Key "user id")
}

if ([string]::IsNullOrWhiteSpace($dbApplyMigrations)) {
  Add-CheckResult "DB_APPLY_MIGRATIONS_ON_STARTUP" $false "should be explicitly set (true/false)"
}
else {
  Add-CheckResult "DB_APPLY_MIGRATIONS_ON_STARTUP" $true "value is set"
}

if ($usesPooler) {
  if ([string]::Equals($runtimeUser, "postgres", [System.StringComparison]::OrdinalIgnoreCase)) {
    Add-CheckResult "Pooler username policy" $false "pooler host should use username postgres.<project-ref>, not plain postgres"
  }
  else {
    Add-CheckResult "Pooler username policy" $true "username format looks compatible with pooler"
  }

  if ($dbApplyMigrations -eq "true") {
    Add-CheckResult "Pooler migration safety" (-not [string]::IsNullOrWhiteSpace($dbMigrationsConnection)) "needs DB_MIGRATIONS_CONNECTION_STRING when startup migrations are enabled"
    if (-not [string]::IsNullOrWhiteSpace($dbMigrationsConnection)) {
      Add-CheckResult "DB_MIGRATIONS_CONNECTION_STRING host" (-not $migrationUsesPooler) "must use direct host (not pooler)"
    }
  }
  elseif ($dbApplyMigrations -eq "false") {
    Add-CheckResult "Pooler migration safety" $true "startup migrations disabled, safe with pooler"
  }
  else {
    Add-CheckResult "Pooler migration safety" $false "DB_APPLY_MIGRATIONS_ON_STARTUP should be true/false"
  }
}
elseif (-not [string]::IsNullOrWhiteSpace($dbHost)) {
  Add-CheckResult "Pooler migration safety" $true "runtime DB connection does not use pooler"
}
else {
  Add-CheckResult "Pooler migration safety" $false "could not parse DB_CONNECTION_STRING host"
}

Write-Host ""
Write-Host "=== Optional provider keys ==="
Add-CheckResult "TWELVE_DATA_API_KEY" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $backend "TWELVE_DATA_API_KEY"))) "recommended for market features"
Add-CheckResult "FINNHUB_API_KEY" (-not [string]::IsNullOrWhiteSpace((Get-EnvValue $backend "FINNHUB_API_KEY"))) "recommended for market features"

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Warnings: $($warnings.Count)"
if ($warnings.Count -gt 0) {
  $warnings | ForEach-Object { Write-Host " - $_" }
}

if ($FailOnWarnings -and $warnings.Count -gt 0) {
  exit 1
}

exit 0
