param(
    [string]$BuildId = ""
)

$ErrorActionPreference = "Stop"

# Move to repo root (script lives in scripts/)
Set-Location -Path (Resolve-Path (Join-Path $PSScriptRoot ".."))

# Resolve build id
if (-not $BuildId) {
    try {
        $BuildId = (git describe --tags --always --dirty).Trim()
    } catch {
        # git missing; fallback
        $BuildId = ""
    }
}
if (-not $BuildId) {
    $BuildId = "local-web-build"
}

$env:ITCH_BUILD_ID = $BuildId
$env:CRASH_REPORT_BUILD_ID = $BuildId

# Pick emsdk location
$emsdkRoot = $env:EMSDK
if (-not $emsdkRoot -or -not (Test-Path $emsdkRoot)) {
    $emsdkRoot = "D:/emsdk"
}
$emsdkBat = Join-Path $emsdkRoot "emsdk_env.bat"
if (-not (Test-Path $emsdkBat)) {
    throw "emsdk_env.bat not found at $emsdkBat. Set EMSDK env var to your emsdk root."
}

# Activate emsdk using the .bat variant to avoid PowerShell parsing issues
cmd /c "`"$emsdkBat`" >nul" | Out-Null

# Configure with emcmake (Ninja + response files to dodge command line limits)
$linkFlags = '-sUSE_GLFW=3 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -sASSERTIONS=1 -sDISABLE_EXCEPTION_CATCHING=0 -sLEGACY_VM_SUPPORT=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 --closure 1 -sEXPORTED_RUNTIME_METHODS=ccall,cwrap,HEAPF32,HEAP32,HEAPU8'
emcmake cmake -S . -B build-emc -G Ninja `
    -DPLATFORM=Web -DCMAKE_BUILD_TYPE=RelWithDebInfo `
    "-DCMAKE_EXE_LINKER_FLAGS=$linkFlags" "-DCMAKE_EXECUTABLE_SUFFIX=.html" `
    -DCCACHE_PROGRAM= -DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER= `
    -DCMAKE_NINJA_FORCE_RESPONSE_FILE=ON `
    -DITCH_BUILD_ID=$BuildId -DCRASH_REPORT_BUILD_ID=$BuildId | Write-Output

# Ensure assets exist in build-emc for file_packager
if (Test-Path "build-emc/assets") {
    Remove-Item -Recurse -Force "build-emc/assets"
}
New-Item -ItemType Directory -Force -Path "build-emc/assets" | Out-Null
robocopy "assets" "build-emc/assets" /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
$robocopyExit = $LASTEXITCODE
if ($robocopyExit -gt 3) {
    throw "Asset copy failed (robocopy exit code $robocopyExit)"
}

# Build
cmake --build build-emc --parallel | Write-Output

# Post-process: rename, inject snippet, gzip, zip
Copy-Item -Path "build-emc/raylib-cpp-cmake-template.html" -Destination "build-emc/index.html" -Force
powershell -ExecutionPolicy Bypass -NoProfile -File "cmake/inject_snippet.ps1" `
    -HtmlPath "build-emc/index.html" -SnippetPath "cmake/inject_snippet.html"

$gzip = Get-Command gzip -ErrorAction SilentlyContinue
if (-not $gzip) {
    throw "gzip not found in PATH; install gzip (e.g., from Git for Windows or GnuWin32)."
}
& $gzip.Path -9 -kf "build-emc/raylib-cpp-cmake-template.wasm"
& $gzip.Path -9 -kf "build-emc/raylib-cpp-cmake-template.data"

cmake -E tar cf "raylib-cpp-cmake-template_web.zip" --format=zip `
    index.html raylib-cpp-cmake-template.wasm.gz raylib-cpp-cmake-template.data.gz `
    raylib-cpp-cmake-template.js assets `
    --working-dir "build-emc"

# Push to itch.io
$butler = Get-Command butler -ErrorAction SilentlyContinue
if (-not $butler) {
    $butler = "D:/butler-windows-amd64/butler.exe"
}
if (-not (Test-Path $butler)) {
    throw "butler not found. Ensure it is in PATH or install to D:/butler-windows-amd64."
}

& $butler push "raylib-cpp-cmake-template_web.zip" "chugget/testing:web" --userversion $BuildId
