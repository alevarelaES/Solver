param(
  [switch]$FailOnFindings,
  [int]$MaxFindings = -1,
  [int]$SampleSize = 30
)

$ErrorActionPreference = 'Stop'

function Invoke-Rg {
  param(
    [string]$Pattern,
    [switch]$UsePcre2
  )

  $args = @()
  if ($UsePcre2) {
    $args += '--pcre2'
  }
  $args += @('-n', $Pattern, 'lib', '--glob', '*.dart')

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

$styleFrom = Invoke-Rg '(ElevatedButton|OutlinedButton|TextButton|FilledButton)\.styleFrom\('
$styleFrom = $styleFrom | Where-Object {
  $_ -notmatch 'core[\\/]theme[\\/]app_theme\.dart:' -and
  $_ -notmatch 'core[\\/]theme[\\/]app_component_styles\.dart:'
}

$hardRadius = Invoke-Rg '(?i)BorderRadius\.circular\(\s*(?!AppRadius|radius|_radius|borderRadius|widget\.borderRadius)' -UsePcre2
$hardRadius = $hardRadius | Where-Object {
  $_ -notmatch 'BorderRadius\.circular\(\s*(99|999)\)'
}
$hardHexColors = Invoke-Rg 'Color\(0x[0-9A-Fa-f]{8}\)'
$hardHexColors = $hardHexColors | Where-Object {
  $_ -notmatch 'core[\\/]theme[\\/]app_theme\.dart:'
}

$hardInsets = Invoke-Rg 'EdgeInsets\.(all|symmetric|fromLTRB|only)\([0-9]'

Print-Section 'Direct styleFrom outside theme helpers' $styleFrom
Print-Section 'BorderRadius.circular not based on AppRadius token' $hardRadius
Print-Section 'Hardcoded hex colors outside app_theme.dart' $hardHexColors
Print-Section 'Hardcoded EdgeInsets values' $hardInsets

$totalFindings =
  $styleFrom.Count +
  $hardRadius.Count +
  $hardHexColors.Count +
  $hardInsets.Count

Write-Host ""
Write-Host "=== UI Consistency Summary ==="
Write-Host "Total findings: $totalFindings"

if ($FailOnFindings -and $totalFindings -gt 0) {
  exit 1
}

if ($MaxFindings -ge 0 -and $totalFindings -gt $MaxFindings) {
  exit 1
}

exit 0
