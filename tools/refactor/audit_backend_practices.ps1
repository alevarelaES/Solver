param(
  [switch]$FailOnFindings,
  [int]$MaxFindings = -1,
  [int]$SampleSize = 30
)

$ErrorActionPreference = 'Stop'

$backendRoot = "backend/src/Solver.Api"
$endpointsRoot = "backend/src/Solver.Api/Endpoints"
$allowedSqlFiles = @(
  'backend/src/Solver.Api/Services/CategoryResetMigration.cs',
  'backend/src/Solver.Api/Services/CategoryGroupBackfillMigration.cs'
)

function Invoke-Rg {
  param(
    [string]$Pattern,
    [string]$Path = $backendRoot,
    [switch]$UsePcre2,
    [switch]$Multiline
  )

  $args = @()
  if ($UsePcre2) {
    $args += '--pcre2'
  }
  if ($Multiline) {
    $args += '-U'
  }
  $args += @('-n', $Pattern, $Path, '--glob', '*.cs')

  $result = @(& rg @args 2>$null)
  if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1) {
    throw "rg failed for pattern: $Pattern"
  }
  return $result
}

function Print-Section {
  param(
    [string]$Title,
    [string[]]$Items
  )

  Write-Host ""
  Write-Host "=== $Title ==="
  Write-Host "Count: $($Items.Count)"
  $Items | Select-Object -First $SampleSize | ForEach-Object { Write-Host " - $_" }
}

$inlineSqlInProgram = Invoke-Rg 'ExecuteSqlRawAsync\(' 'backend/src/Solver.Api/Program.cs'

$saveChangesInLoops = New-Object System.Collections.Generic.List[string]
$csFiles = Get-ChildItem -Path $backendRoot -Recurse -Filter *.cs
foreach ($file in $csFiles) {
  $lines = Get-Content $file.FullName
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch 'SaveChangesAsync\(') { continue }
    $depth = 0
    $pendingLoop = 0
    $activeLoopDepths = New-Object System.Collections.Generic.HashSet[int]
    $insideLoop = $false

    for ($j = 0; $j -le $i; $j++) {
      $line = $lines[$j]
      if ($line -match '\b(foreach|for|while)\s*\(') {
        $pendingLoop++
      }

      $chars = $line.ToCharArray()
      foreach ($ch in $chars) {
        if ($ch -eq '{') {
          $depth++
          while ($pendingLoop -gt 0) {
            $activeLoopDepths.Add($depth) | Out-Null
            $pendingLoop--
          }
          continue
        }

        if ($ch -eq '}') {
          if ($activeLoopDepths.Contains($depth)) {
            $activeLoopDepths.Remove($depth) | Out-Null
          }
          $depth--
        }
      }

      if ($j -eq $i -and $activeLoopDepths.Count -gt 0) {
        $insideLoop = $true
      }
    }

    if ($insideLoop) {
      $relative = $file.FullName.Replace((Get-Location).Path + '\', '')
      $saveChangesInLoops.Add("${relative}:$($i + 1): $($lines[$i].Trim())")
    }
  }
}

$toLowerInEndpoints = Invoke-Rg '\.(ToLower|ToLowerInvariant)\(' $endpointsRoot

$rawSqlUsages = Invoke-Rg '(ExecuteSqlRawAsync|ExecuteSqlInterpolatedAsync|FromSqlRaw|FromSqlInterpolated)\('
$rawSqlOutsideAllowed = $rawSqlUsages | Where-Object {
  $line = $_.ToString()
  $match = [regex]::Match($line, '^(.+?):\d+:')
  if (-not $match.Success) { return $true }
  $path = $match.Groups[1].Value.Replace('\', '/')
  -not ($allowedSqlFiles | ForEach-Object { $_.Replace('\', '/') } | Where-Object { $_ -eq $path })
}

Print-Section 'Inline SQL bootstrap in Program.cs' $inlineSqlInProgram
Print-Section 'SaveChangesAsync potentially inside loops' $saveChangesInLoops
Print-Section 'ToLower/ToLowerInvariant in endpoints' $toLowerInEndpoints
Print-Section 'Raw SQL usages outside migration/bootstrap services' $rawSqlOutsideAllowed

$totalFindings =
  $inlineSqlInProgram.Count +
  $saveChangesInLoops.Count +
  $toLowerInEndpoints.Count +
  $rawSqlOutsideAllowed.Count

Write-Host ""
Write-Host "=== Backend Practices Summary ==="
Write-Host "Total findings: $totalFindings"

if ($FailOnFindings -and $totalFindings -gt 0) {
  exit 1
}

if ($MaxFindings -ge 0 -and $totalFindings -gt $MaxFindings) {
  exit 1
}

exit 0
