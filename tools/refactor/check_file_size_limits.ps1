param(
  [int]$ViewMaxLines = 800,
  [int]$OtherMaxLines = 500
)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$files = Get-ChildItem lib -Recurse -Filter *.dart
$violations = @()

foreach ($f in $files) {
  $lines = (Get-Content $f.FullName).Length
  $rel = [regex]::Replace(
    $f.FullName,
    '^' + [regex]::Escape($root) + '\\\\?',
    '',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  ).Replace('\', '/')
  $isView = $rel -match '/views/'
  $limit = if ($isView) { $ViewMaxLines } else { $OtherMaxLines }
  if ($lines -gt $limit) {
    $violations += [PSCustomObject]@{
      File = $rel
      Lines = $lines
      Limit = $limit
      Type = if ($isView) { 'view' } else { 'other' }
    }
  }
}

if ($violations.Count -eq 0) {
  Write-Host "OK: no file exceeds limits (views=$ViewMaxLines, other=$OtherMaxLines)."
  exit 0
}

Write-Host "File size violations:"
$violations | Sort-Object Lines -Descending | Format-Table -AutoSize
exit 1
