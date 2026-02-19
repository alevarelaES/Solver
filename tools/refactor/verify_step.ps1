param(
  [switch]$SkipFlutter,
  [switch]$SkipBackend,
  [switch]$SkipBackendAudit,
  [switch]$SkipEnvSecurityAudit,
  [switch]$SkipTests,
  [switch]$SkipUiAudit,
  [bool]$FailOnUiFindings = $true,
  [int]$MaxUiFindings = 0,
  [bool]$FailOnBackendFindings = $true,
  [int]$MaxBackendFindings = 0,
  [bool]$FailOnWarnings = $true
)

$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$failures = New-Object System.Collections.Generic.List[string]

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action,
    [switch]$FailOnBackendWarnings
  )

  Write-Host ""
  Write-Host "=== $Name ==="
  try {
    $stepOutput = @(& $Action 2>&1)
    foreach ($line in $stepOutput) {
      Write-Host $line
    }

    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
    if ($exitCode -ne 0) {
      $failures.Add("$Name (exit $exitCode)")
      Write-Host "FAILED: $Name"
      return
    }

    if ($FailOnWarnings -and $FailOnBackendWarnings) {
      $warningLines = $stepOutput |
        ForEach-Object { $_.ToString() } |
        Where-Object {
          $_ -match '(?i)\bwarning\b' -and
          $_ -match '(?i)\b(MSB|CS|NU|CA|IDE|NETSDK|SYSLIB|ASP|RZ|IL)\d{3,6}\b'
        }

      if ($warningLines.Count -gt 0) {
        $failures.Add("$Name (warnings detected)")
        Write-Host "FAILED: $Name"
        Write-Host "Warnings treated as errors:"
        $warningLines | ForEach-Object { Write-Host " - $_" }
        return
      }
    }

    Write-Host "OK: $Name"
  }
  catch {
    $failures.Add("$Name ($($_.Exception.Message))")
    Write-Host "FAILED: $Name"
  }
}

if (-not $SkipFlutter) {
  if (Test-Path (Join-Path $root "pubspec.yaml")) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
      Invoke-Step "Flutter analyze" {
        flutter analyze --fatal-infos --fatal-warnings
      }

      $hasFlutterTests = Test-Path (Join-Path $root "test")
      if (-not $SkipTests -and $hasFlutterTests) {
        Invoke-Step "Flutter test" {
          flutter test
        }
      }
    }
    else {
      $failures.Add("Flutter toolchain unavailable")
      Write-Host "FAILED: Flutter toolchain unavailable"
    }
  }
}

if (-not $SkipBackend) {
  $apiCsproj = Join-Path $root "backend/src/Solver.Api/Solver.Api.csproj"
  if (Test-Path $apiCsproj) {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
      Invoke-Step "Backend build" -FailOnBackendWarnings {
        if ($FailOnWarnings) {
          dotnet build $apiCsproj -nologo /warnaserror /p:TreatWarningsAsErrors=true /p:MSBuildTreatWarningsAsErrors=true
        }
        else {
          dotnet build $apiCsproj -nologo
        }
      }

      if (-not $SkipTests) {
        $testProjects = Get-ChildItem -Path (Join-Path $root "backend") -Recurse -Filter *.csproj |
          Where-Object { $_.Name -match "Test" }
        foreach ($tp in $testProjects) {
          $name = "Backend test: $($tp.FullName.Replace($root + '\', ''))"
          Invoke-Step $name -FailOnBackendWarnings {
            if ($FailOnWarnings) {
              dotnet test $tp.FullName -nologo /warnaserror /p:TreatWarningsAsErrors=true /p:MSBuildTreatWarningsAsErrors=true
            }
            else {
              dotnet test $tp.FullName -nologo
            }
          }
        }
      }
    }
    else {
      $failures.Add("dotnet toolchain unavailable")
      Write-Host "FAILED: dotnet toolchain unavailable"
    }
  }
}

if (-not $SkipUiAudit) {
  $uiAuditScript = Join-Path $root "tools/refactor/audit_ui_consistency.ps1"
  if (Test-Path $uiAuditScript) {
    Invoke-Step "UI consistency audit" {
      if ($FailOnUiFindings) {
        if ($MaxUiFindings -ge 0) {
          powershell -ExecutionPolicy Bypass -File $uiAuditScript -MaxFindings $MaxUiFindings
        }
        else {
          powershell -ExecutionPolicy Bypass -File $uiAuditScript -FailOnFindings
        }
      }
      else {
        powershell -ExecutionPolicy Bypass -File $uiAuditScript
      }
    }
  }
}

if (-not $SkipBackendAudit) {
  $backendAuditScript = Join-Path $root "tools/refactor/audit_backend_practices.ps1"
  if (Test-Path $backendAuditScript) {
    Invoke-Step "Backend practices audit" {
      if ($FailOnBackendFindings) {
        if ($MaxBackendFindings -ge 0) {
          powershell -ExecutionPolicy Bypass -File $backendAuditScript -MaxFindings $MaxBackendFindings
        }
        else {
          powershell -ExecutionPolicy Bypass -File $backendAuditScript -FailOnFindings
        }
      }
      else {
        powershell -ExecutionPolicy Bypass -File $backendAuditScript
      }
    }
  }
}

if (-not $SkipEnvSecurityAudit) {
  $envSecurityScript = Join-Path $root "tools/refactor/check_env_security.ps1"
  if (Test-Path $envSecurityScript) {
    Invoke-Step "Env security check" {
      if ($FailOnWarnings) {
        powershell -ExecutionPolicy Bypass -File $envSecurityScript -FailOnWarnings
      }
      else {
        powershell -ExecutionPolicy Bypass -File $envSecurityScript
      }
    }
  }
}

Write-Host ""
Write-Host "=== Verification Summary ==="
if ($failures.Count -eq 0) {
  Write-Host "ALL CHECKS PASSED"
  exit 0
}

Write-Host "FAILED CHECKS:"
foreach ($f in $failures) {
  Write-Host " - $f"
}
exit 1
