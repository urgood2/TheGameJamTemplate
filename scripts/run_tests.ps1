$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

$LogPrefix = "[CI]"

function Log-Line {
    param([string]$Message)
    Write-Host "$LogPrefix $Message"
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    try {
        $raw = Get-Content -Path $Path -Raw
        if (-not $raw) {
            return $null
        }
        return $raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Get-JsonValue {
    param(
        $Object,
        [string]$Path
    )
    if ($null -eq $Object) {
        return $null
    }
    $current = $Object
    foreach ($part in $Path.Split(".")) {
        if (-not $part) {
            continue
        }
        if ($null -eq $current) {
            return $null
        }
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        } else {
            return $null
        }
    }
    return $current
}

function Get-Text {
    param($Value, [string]$Fallback)
    if ($null -eq $Value -or $Value -eq "") {
        return $Fallback
    }
    return "$Value"
}

function Get-BoolText {
    param($Value, [string]$Fallback)
    if ($null -eq $Value) {
        return $Fallback
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { "true" } else { "false" })
    }
    return "$Value"
}

function Log-PartialResults {
    $status = Read-JsonFile "test_output/status.json"
    if ($null -eq $status) {
        Log-Line "  Partial results: unknown"
        return
    }
    $pcount = Get-JsonValue $status "passed_count"
    $fcount = Get-JsonValue $status "failed"
    $scount = Get-JsonValue $status "skipped"
    Log-Line ("  Partial results: {0}/{1}/{2}" -f (Get-Text $pcount "0"), (Get-Text $fcount "0"), (Get-Text $scount "0"))
}

function Log-FailedTests {
    $results = Read-JsonFile "test_output/results.json"
    if ($null -eq $results) {
        return
    }
    $tests = Get-JsonValue $results "tests"
    if ($null -eq $tests) {
        return
    }
    foreach ($entry in $tests) {
        $status = Get-JsonValue $entry "status"
        if ($null -eq $status) {
            continue
        }
        if ("$status".ToLowerInvariant() -ne "fail") {
            continue
        }
        $testId = Get-JsonValue $entry "test_id"
        $message = Get-JsonValue $entry "error.message"
        if ($null -eq $message -or $message -eq "") {
            $message = "error"
        }
        Log-Line ("  - {0}: {1}" -f (Get-Text $testId "unknown"), $message)
    }
}

$osDescription = "unknown"
$archDescription = "unknown"
try {
    $osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim()
    $archDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
} catch {
    $osDescription = $env:OS
    $archDescription = $env:PROCESSOR_ARCHITECTURE
}

$gitCommit = "unknown"
$gitBranch = "unknown"
try {
    $gitCommit = (& git rev-parse HEAD 2>$null) -join ""
    if (-not $gitCommit) { $gitCommit = "unknown" }
} catch { }
try {
    $gitBranch = (& git rev-parse --abbrev-ref HEAD 2>$null) -join ""
    if (-not $gitBranch) { $gitBranch = "unknown" }
} catch { }

$engineExe = Join-Path $ProjectRoot "build\raylib-cpp-cmake-template.exe"
$engineAlt = Join-Path $ProjectRoot "build\raylib-cpp-cmake-template"
$enginePath = $engineAlt
if (Test-Path $engineExe) {
    $enginePath = $engineExe
}

New-Item -ItemType Directory -Force -Path "test_output" | Out-Null

Log-Line "=========================================="
Log-Line "=== Test Suite CI Wrapper ==="
Log-Line "=========================================="
Log-Line ("Started at: {0}" -f (Get-Date -Format o))
Log-Line ("Platform: {0} {1}" -f $osDescription, $archDescription)
Log-Line ("Git commit: {0}" -f $gitCommit)
Log-Line ("Git branch: {0}" -f $gitBranch)

Log-Line "Starting engine with test scene..."
Log-Line ("Command: {0} --scene test" -f $enginePath)

$engineExit = 0
try {
    & $enginePath --scene test 2>&1 | Tee-Object -FilePath "test_output/test_log.txt"
    $engineExit = $LASTEXITCODE
} catch {
    $engineExit = $LASTEXITCODE
}

Log-Line ("Engine exited with code {0}" -f $engineExit)

Log-Line "Checking run_state.json..."
if (-not (Test-Path "test_output/run_state.json")) {
    Log-Line "  File exists: no"
    Log-Line "CRASH DETECTED: run_state.json missing OR in_progress=true"
    Log-Line "  Last test started: unknown"
    Log-PartialResults
    Log-Line "=========================================="
    Log-Line "=== RESULT: CRASH ==="
    Log-Line "=========================================="
    Log-Line "Exit code: 2"
    exit 2
}

$runState = Read-JsonFile "test_output/run_state.json"
$inProgress = Get-JsonValue $runState "in_progress"
$lastStarted = Get-JsonValue $runState "last_test_started"
$lastCompleted = Get-JsonValue $runState "last_test_completed"

Log-Line "  File exists: yes"
Log-Line ("  in_progress: {0}" -f (Get-BoolText $inProgress "unknown"))
Log-Line ("  last_test_completed: {0}" -f (Get-Text $lastCompleted "unknown"))

if ($inProgress -eq $true) {
    Log-Line "CRASH DETECTED: run_state.json missing OR in_progress=true"
    Log-Line ("  Last test started: {0}" -f (Get-Text $lastStarted "unknown"))
    Log-PartialResults
    Log-Line "=========================================="
    Log-Line "=== RESULT: CRASH ==="
    Log-Line "=========================================="
    Log-Line "Exit code: 2"
    exit 2
}

Log-Line "Checking status.json..."
if (-not (Test-Path "test_output/status.json")) {
    Log-Line "ERROR: status.json not generated"
    Log-Line "=========================================="
    Log-Line "=== RESULT: FAILURE ==="
    Log-Line "=========================================="
    Log-Line "Exit code: 1"
    exit 1
}

$status = Read-JsonFile "test_output/status.json"
$passed = Get-JsonValue $status "passed"
$total = Get-JsonValue $status "total"
$passedCount = Get-JsonValue $status "passed_count"
$failedCount = Get-JsonValue $status "failed"
$skipped = Get-JsonValue $status "skipped"
$duration = Get-JsonValue $status "duration_ms"

Log-Line ("  passed: {0}" -f (Get-BoolText $passed "unknown"))
Log-Line ("  total: {0}, passed: {1}, failed: {2}, skipped: {3}" -f (Get-Text $total "0"), (Get-Text $passedCount "0"), (Get-Text $failedCount "0"), (Get-Text $skipped "0"))
Log-Line ("  duration: {0}ms" -f (Get-Text $duration "0"))

if ($passed -eq $true) {
    Log-Line "=========================================="
    Log-Line "=== RESULT: SUCCESS ==="
    Log-Line "=========================================="
    Log-Line "Exit code: 0"
    exit 0
}

Log-Line "=========================================="
Log-Line "=== RESULT: FAILURE ==="
Log-Line "=========================================="
Log-Line "Exit code: 1"
Log-Line "Failed tests:"
Log-FailedTests
Log-Line "See test_output/report.md for details"
exit 1
