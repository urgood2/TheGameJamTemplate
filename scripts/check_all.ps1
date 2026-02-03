$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$LogPrefix = "[CHECK]"
$TotalSteps = 9
$CurrentStep = 0
$FailedSteps = @()

$DryRun = $false
$FailStep = $env:CHECK_ALL_FAIL_STEP
if (-not $FailStep) {
    $FailStep = 0
} else {
    $FailStep = [int]$FailStep
}

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--dry-run" { $DryRun = $true }
        "--fail-step" {
            if ($i + 1 -ge $args.Count) {
                Write-Host "$LogPrefix ERROR: --fail-step requires a step number"
                exit 2
            }
            $FailStep = [int]$args[$i + 1]
            $i++
        }
    }
}

function Log-Line {
    param([string]$Message)
    Write-Host "$LogPrefix $Message"
}

function Format-Duration {
    param([int]$Seconds)
    $mins = [int]($Seconds / 60)
    $secs = $Seconds % 60
    if ($mins -gt 0) {
        return "$mins" + "m " + "$secs" + "s"
    }
    return "$secs" + "s"
}

function Run-Cmd {
    param(
        [string]$Label,
        [scriptblock]$Action
    )
    Log-Line "  Running $Label..."
    if ($DryRun) {
        Log-Line "  DRY-RUN: $Label"
        return
    }
    & $Action
}

function Run-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    $script:CurrentStep++
    Log-Line "[$($script:CurrentStep)/$TotalSteps] $Name..."

    if ($script:FailStep -eq $script:CurrentStep) {
        Log-Line "  FAIL (forced)"
        $script:FailedSteps += "[$($script:CurrentStep)/$TotalSteps] $Name"
        return $false
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action
        $stopwatch.Stop()
        Log-Line ("  PASS ({0}s)" -f [int]$stopwatch.Elapsed.TotalSeconds)
        return $true
    } catch {
        $stopwatch.Stop()
        Log-Line ("  FAIL ({0}s)" -f [int]$stopwatch.Elapsed.TotalSeconds)
        $script:FailedSteps += "[$($script:CurrentStep)/$TotalSteps] $Name"
        return $false
    }
}

$StartTime = Get-Date

Log-Line "=========================================="
Log-Line "=== Full Verification Pipeline ==="
Log-Line "=========================================="
Log-Line ("Started at: {0}" -f (Get-Date -Format o))
Log-Line ""

Run-Step "Validating toolchain" { Run-Cmd "scripts/doctor.py" { python scripts/doctor.py } } | Out-Null
Run-Step "Regenerating inventories" {
    Run-Cmd "scripts/extract_sol2_bindings.py" { python scripts/extract_sol2_bindings.py }
    Run-Cmd "scripts/extract_components.py" { python scripts/extract_components.py }
} | Out-Null
Run-Step "Regenerating scope stats" { Run-Cmd "scripts/recount_scope_stats.py" { python scripts/recount_scope_stats.py } } | Out-Null
Run-Step "Regenerating doc skeletons" { Run-Cmd "scripts/generate_docs_skeletons.py" { python scripts/generate_docs_skeletons.py } } | Out-Null
Run-Step "Validating schemas" { Run-Cmd "scripts/validate_schemas.py" { python scripts/validate_schemas.py } } | Out-Null
Run-Step "Syncing registry from manifest" { Run-Cmd "scripts/sync_registry_from_manifest.py" { python scripts/sync_registry_from_manifest.py } } | Out-Null
Run-Step "Checking docs consistency" {
    Run-Cmd "scripts/validate_docs_and_registry.py" { python scripts/validate_docs_and_registry.py }
    Run-Cmd "scripts/link_check_docs.py" { python scripts/link_check_docs.py }
} | Out-Null
Run-Step "Checking evidence blocks" { Run-Cmd "scripts/sync_docs_evidence.py --check" { python scripts/sync_docs_evidence.py --check } } | Out-Null
Run-Step "Running test suite" {
    Run-Cmd "test harness" { ./scripts/run_tests.sh }
    Run-Cmd "coverage report" { lua -e "package.path='assets/scripts/?.lua;assets/scripts/?/init.lua;'..package.path; local cr=require('test.test_coverage_report'); local ok=cr.generate('test_output/results.json','test_output/coverage_report.md'); if not ok then os.exit(1) end" }
} | Out-Null

$TotalDuration = [int](New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds
$PassedSteps = $TotalSteps - $FailedSteps.Count

Log-Line ""
Log-Line "=========================================="
if ($FailedSteps.Count -eq 0) {
    Log-Line "=== FINAL RESULT: PASS ==="
    Log-Line "All $TotalSteps steps passed."
    Log-Line ("Total time: {0}" -f (Format-Duration -Seconds $TotalDuration))
    Log-Line ("Passed steps: {0}/{1}" -f $PassedSteps, $TotalSteps)
    exit 0
} else {
    Log-Line "=== FINAL RESULT: FAIL ==="
    Log-Line "Failed steps:"
    foreach ($step in $FailedSteps) {
        Log-Line "  - $step"
    }
    Log-Line ("Total time: {0}" -f (Format-Duration -Seconds $TotalDuration))
    Log-Line ("Passed steps: {0}/{1}" -f $PassedSteps, $TotalSteps)
    exit 1
}
