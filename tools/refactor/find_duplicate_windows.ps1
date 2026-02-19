param(
  [int]$WindowSize = 10,
  [int]$MinOccurrences = 3
)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$files = Get-ChildItem lib -Recurse -Filter *.dart
$map = @{}

foreach ($f in $files) {
  $rel = [regex]::Replace(
    $f.FullName,
    '^' + [regex]::Escape($root) + '\\\\?',
    '',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  ).Replace('\', '/')
  $lines = Get-Content $f.FullName
  if ($lines.Length -lt $WindowSize) { continue }

  for ($i = 0; $i -le $lines.Length - $WindowSize; $i++) {
    $window = $lines[$i..($i + $WindowSize - 1)] |
      ForEach-Object { ($_ -replace '\\s+', ' ').Trim() } |
      Where-Object { $_ -ne '' -and -not $_.StartsWith('//') }

    if ($window.Count -lt $WindowSize) { continue }

    $key = ($window -join "`n")
    if (-not $map.ContainsKey($key)) { $map[$key] = @() }
    $map[$key] += "${rel}:$($i + 1)"
  }
}

$dups = $map.GetEnumerator() |
  Where-Object { $_.Value.Count -ge $MinOccurrences } |
  Sort-Object { $_.Value.Count } -Descending |
  Select-Object -First 20

if ($dups.Count -eq 0) {
  Write-Host "No repeated windows found with WindowSize=$WindowSize and MinOccurrences=$MinOccurrences"
  exit 0
}

Write-Host "Potential duplicated code windows:"
foreach ($d in $dups) {
  Write-Host "`nOccurrences: $($d.Value.Count)"
  $d.Value | Select-Object -First 6 | ForEach-Object { Write-Host " - $_" }
}
