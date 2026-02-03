# Bootstrap development environment for Python automation scripts.
# Usage: .\scripts\bootstrap_dev.ps1
#
# Creates/updates a Python venv and installs all dependencies.
# Idempotent: safe to run multiple times.

$ErrorActionPreference = "Stop"

# Resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VenvDir = Join-Path $ProjectRoot ".venv"
$Requirements = Join-Path $ScriptDir "requirements.txt"

Write-Host "[BOOTSTRAP] === Bootstrap Dev Environment ===" -ForegroundColor Cyan
Write-Host "[BOOTSTRAP] Project root: $ProjectRoot"
Write-Host "[BOOTSTRAP] Venv location: $VenvDir"

# Check Python availability
$PythonCmd = $null
foreach ($cmd in @("python3", "python", "py")) {
    try {
        $version = & $cmd --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $PythonCmd = $cmd
            Write-Host "[BOOTSTRAP] Python: $version"
            break
        }
    } catch {
        continue
    }
}

if (-not $PythonCmd) {
    Write-Host "[BOOTSTRAP] ERROR: Python not found" -ForegroundColor Red
    Write-Host "[BOOTSTRAP]   Install: winget install Python.Python.3.11"
    exit 1
}

# Create venv if not exists
if (-not (Test-Path $VenvDir)) {
    Write-Host "[BOOTSTRAP] Creating virtual environment..."
    & $PythonCmd -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BOOTSTRAP] ERROR: Failed to create venv" -ForegroundColor Red
        exit 1
    }
    Write-Host "[BOOTSTRAP] Venv created at $VenvDir"
} else {
    Write-Host "[BOOTSTRAP] Venv already exists, updating..."
}

# Activate venv
$ActivateScript = Join-Path $VenvDir "Scripts\Activate.ps1"
if (-not (Test-Path $ActivateScript)) {
    Write-Host "[BOOTSTRAP] ERROR: Activation script not found at $ActivateScript" -ForegroundColor Red
    exit 1
}

# Source the activation script
. $ActivateScript
Write-Host "[BOOTSTRAP] Venv activated"

# Upgrade pip
Write-Host "[BOOTSTRAP] Upgrading pip..."
& pip install --upgrade pip --quiet

# Install requirements
if (Test-Path $Requirements) {
    Write-Host "[BOOTSTRAP] Installing dependencies from requirements.txt..."
    & pip install -r $Requirements --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[BOOTSTRAP] ERROR: pip install failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "[BOOTSTRAP] Dependencies installed"
} else {
    Write-Host "[BOOTSTRAP] WARNING: requirements.txt not found at $Requirements" -ForegroundColor Yellow
}

# Sanity check - verify key packages
Write-Host "[BOOTSTRAP] Verifying installation..."
$SanityErrors = 0

$packages = @("pytest", "jsonschema", "yaml")
foreach ($pkg in $packages) {
    try {
        & python -c "import $pkg" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[BOOTSTRAP]   WARNING: $pkg not importable" -ForegroundColor Yellow
            $SanityErrors++
        }
    } catch {
        Write-Host "[BOOTSTRAP]   WARNING: $pkg not importable" -ForegroundColor Yellow
        $SanityErrors++
    }
}

if ($SanityErrors -eq 0) {
    Write-Host "[BOOTSTRAP] Sanity check: PASSED" -ForegroundColor Green
} else {
    Write-Host "[BOOTSTRAP] Sanity check: $SanityErrors package(s) failed to import" -ForegroundColor Yellow
}

Write-Host "[BOOTSTRAP] === Complete ===" -ForegroundColor Cyan
Write-Host "[BOOTSTRAP] To activate: . $VenvDir\Scripts\Activate.ps1"
Write-Host "[BOOTSTRAP] To run tests: pytest scripts/tests -q"
