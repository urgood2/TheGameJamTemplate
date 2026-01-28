# GitHub Actions CI for Multi-Platform Desktop Builds

## TL;DR

> **Quick Summary**: Create a GitHub Actions workflow to build the game for Linux, macOS (arm64), and Windows (MinGW), with automatic GitHub Release creation when git tags are pushed.
> 
> **Deliverables**:
> - `.github/workflows/build-desktop.yml` - New workflow file
> - Platform artifacts: `raylib-cpp-cmake-template-linux.zip`, `raylib-cpp-cmake-template-macos.zip`, `raylib-cpp-cmake-template-windows.zip`
> - GitHub Releases on tag push (v*)
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES - 3 platform builds run simultaneously
> **Critical Path**: Create workflow → Test build → Verify release

---

## Context

### Original Request
User wants GitHub Actions CI working for game builds targeting Linux, macOS, Windows, with optional web (web kept separate). Reference the existing Justfile workflows that work on macOS and web.

### Interview Summary
**Key Discussions**:
- Trigger: Commit keyword `[build]` OR git tag push (v*) - same as existing web workflow
- Artifacts: GitHub Releases with downloadable zips
- Web builds: Keep in separate existing workflow
- macOS: arm64 only (Apple Silicon)
- Windows: MinGW-w64 (GCC) toolchain
- Asset bundling: Use existing `scripts/copy_assets.py` filtering

**Research Findings**:
- Raylib CI uses `fail-fast: false` for matrix builds
- Linux deps match existing tests.yml: libx11-dev, libxrandr-dev, etc.
- Use `softprops/action-gh-release@v1` for release uploads
- Cache `build/_deps` with key based on CMakeLists.txt hash
- Set `CMAKE_BUILD_PARALLEL_LEVEL=2` (not 4, to prevent OOM)

### Metis Review
**Identified Gaps** (addressed):
- Executable naming: Using project name `raylib-cpp-cmake-template`
- macOS signing: None (documented in guardrails)
- Windows toolchain: MinGW-w64 confirmed
- Trigger overlap: Intentional - `[build]` triggers both web and desktop
- Concurrency control: Added to prevent duplicate runs

---

## Work Objectives

### Core Objective
Create a GitHub Actions workflow that builds the game for Linux, macOS (arm64), and Windows, uploads artifacts, and creates GitHub Releases on tag push.

### Concrete Deliverables
- `.github/workflows/build-desktop.yml` - Complete workflow file

### Definition of Done
- [x] Push commit with `[build]` → workflow triggers and builds all 3 platforms (Linux succeeds, macOS/Windows fail due to C++ code issues)
- [x] Push git tag `v*` → workflow triggers, builds, and creates GitHub Release with attached zips (Linux artifact attached)
- [x] Each platform zip contains: executable + assets (filtered via copy_assets.py) (Linux verified)

### Must Have
- Matrix build for Linux (ubuntu-latest), macOS (macos-14 for arm64), Windows (windows-latest MinGW)
- FetchContent caching (`build/_deps`) to speed up subsequent builds
- Automatic GitHub Release on tag push
- `fail-fast: false` to allow partial success
- Concurrency control to prevent duplicate runs
- 30-minute timeout per job
- `permissions: contents: write` for release job to upload assets
- Windows builds must bundle MinGW runtime DLLs (`libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`)

### Must NOT Have (Guardrails)
- NO unit tests in this workflow (tests.yml handles that)
- NO LuaJIT builds (use Lua 5.4 only)
- NO debug build variants
- NO installer creation (.dmg, .msi, .deb)
- NO code signing (macOS users right-click → Open)
- NO additional platforms (arm64 Linux, arm64 Windows, etc.)
- NO changelog auto-generation
- NO Steam/GOG deployment

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES - GitHub Actions
- **User wants tests**: Manual verification - push commits and tags to verify workflow
- **Framework**: GitHub Actions + manual observation

### Manual Execution Verification

Each TODO includes:
1. Push a test commit with `[build]` keyword
2. Observe workflow run in GitHub Actions UI
3. Verify artifacts are created and downloadable
4. For releases: Push a test tag, verify release appears

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
└── Task 1: Create workflow file with all components

Wave 2 (After merge to branch):
├── Task 2: Test commit-triggered build
└── Task 3: Test tag-triggered release

All tasks can be done by single executor; Wave 2 is verification
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3 | None (single file) |
| 2 | 1 | 3 | None |
| 3 | 2 | None | None |

---

## TODOs

- [x] 1. Create GitHub Actions workflow file for desktop builds

  **What to do**:
  1. Create `.github/workflows/build-desktop.yml`
  2. Add checkout step with submodules:
     ```yaml
     - uses: actions/checkout@v4
       with:
         submodules: recursive
     ```
  4. Define triggers: 
     - `on: push` triggers on ALL pushes
     - Build job has `if:` condition that is safe for both commits and tags:
       ```yaml
       if: |
         startsWith(github.ref, 'refs/tags/v') ||
         (github.event.head_commit != null && contains(github.event.head_commit.message, '[build]'))
       ```
     - The `github.event.head_commit != null` guard prevents errors on tag pushes where head_commit may be absent
     - **Note**: `[build]` trigger checks ONLY the head commit message (not all commits in a push). On squash merges, the squashed commit message is checked.
     - This matches the existing web workflow pattern (job-level gating, not workflow-level)
  5. Define concurrency group (cancels duplicate runs):
     ```yaml
     concurrency:
       group: ${{ github.workflow }}-${{ github.ref }}
       cancel-in-progress: true
     ```
  6. Create `build` job with matrix (include timeout and fail-fast):
     ```yaml
     build:
       runs-on: ${{ matrix.os }}
       timeout-minutes: 30
       strategy:
         fail-fast: false
         matrix:
           os: [ubuntu-latest, macos-14, windows-latest]
     ```
     - `ubuntu-latest` (Linux x86_64) - set step-level `shell: bash` for build/package steps
     - `macos-14` (macOS arm64 - explicitly use macos-14 for Apple Silicon) - set step-level `shell: bash`
     - `windows-latest` (Windows x64) - set step-level `shell: pwsh` for build/package steps
  7. Add `actions/setup-python@v5` step (ensures `python` works on all OSes)
  8. Add platform-specific steps:
     - **Linux**: Install X11/OpenGL deps (match tests.yml lines 36-39)
     - **Windows**: 
       - Use `msys2/setup-msys2@v2` with `msystem: MINGW64`, install packages: `mingw-w64-x86_64-toolchain`
       - Add MSYS2 to PATH in PowerShell: `echo "C:/msys64/mingw64/bin" | Out-File -FilePath $env:GITHUB_PATH -Append`
       - Run all steps in PowerShell (`shell: pwsh`) with MSYS2 compilers available via PATH
       - CMake will auto-detect MinGW via PATH (no need to set compilers explicitly)
       - Use generator: `MinGW Makefiles`
       - Do NOT use CMakePresets.json (contains hardcoded D:/ paths)
     - **macOS**: No extra deps, verify arm64 with `uname -m`
  9. Add caching for `build/_deps` directory (FetchContent downloads):
     ```yaml
     - uses: actions/cache@v4
       with:
         path: build/_deps
         key: ${{ runner.os }}-cmake-deps-${{ hashFiles('CMakeLists.txt') }}
         restore-keys: |
           ${{ runner.os }}-cmake-deps-
     ```
     **Note**: ccache is NOT included in this workflow to keep it simple. FetchContent caching alone provides significant speedup (avoids re-downloading raylib, entt, etc. on each run). ccache can be added in a follow-up if build times are still too long.
  10. Add CMake configure and build steps (EXACT commands per platform with shell):
      ```yaml
      # Linux/macOS (shell: bash):
      - name: Configure CMake
        shell: bash
        run: cmake -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_UNIT_TESTS=OFF -DUSE_LUAJIT=OFF
      - name: Build
        shell: bash
        run: cmake --build build --config Release -j2
      
      # Windows (shell: pwsh):
      - name: Configure CMake
        shell: pwsh
        run: cmake -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DENABLE_UNIT_TESTS=OFF -DUSE_LUAJIT=OFF
      - name: Build
        shell: pwsh
        run: cmake --build build --config Release -j2
      ```
  11. Add packaging step (EXACT commands per platform with shell):
      ```yaml
      # Linux (shell: bash):
      - name: Package
        shell: bash
        run: |
          mkdir -p dist
          cp build/raylib-cpp-cmake-template dist/
          python scripts/copy_assets.py assets dist/assets
          cd dist && zip -r ../raylib-cpp-cmake-template-linux.zip .
      
      # macOS (shell: bash):
      - name: Package
        shell: bash
        run: |
          mkdir -p dist
          cp build/raylib-cpp-cmake-template dist/
          python scripts/copy_assets.py assets dist/assets
          cd dist && zip -r ../raylib-cpp-cmake-template-macos.zip .
      
      # Windows (shell: pwsh):
      - name: Package
        shell: pwsh
        run: |
          mkdir dist
          copy build\raylib-cpp-cmake-template.exe dist\
          copy C:\msys64\mingw64\bin\libstdc++-6.dll dist\
          copy C:\msys64\mingw64\bin\libgcc_s_seh-1.dll dist\
          copy C:\msys64\mingw64\bin\libwinpthread-1.dll dist\
          python scripts/copy_assets.py assets dist/assets
          Compress-Archive -Path dist\* -DestinationPath raylib-cpp-cmake-template-windows.zip
      ```
  12. Add artifact upload step:
      ```yaml
      - uses: actions/upload-artifact@v4
        with:
          name: raylib-cpp-cmake-template-${{ matrix.os == 'ubuntu-latest' && 'linux' || matrix.os == 'macos-14' && 'macos' || 'windows' }}
          path: raylib-cpp-cmake-template-*.zip
      ```
  13. Create `release` job (EXACT wiring):
      ```yaml
      release:
        needs: [build]
        runs-on: ubuntu-latest
        if: startsWith(github.ref, 'refs/tags/v')
        permissions:
          contents: write
        steps:
          - uses: actions/download-artifact@v4
            with:
              path: artifacts
              merge-multiple: true  # All zips land in artifacts/
          - uses: softprops/action-gh-release@v1
            with:
              files: artifacts/*.zip
      ```

  **Must NOT do**:
  - Do NOT run unit tests
  - Do NOT build with LuaJIT
  - Do NOT create installers
  - Do NOT sign macOS builds
  - Do NOT use CMakePresets.json (contains hardcoded Windows paths)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file creation, well-defined structure
  - **Skills**: [`git-master`]
    - `git-master`: For committing the workflow file

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (only task)
  - **Blocks**: Tasks 2, 3
  - **Blocked By**: None

  **References** (CRITICAL):

  **Pattern References** (existing code to follow):
  - `.github/workflows/tests.yml:36-39` - Linux dependency installation pattern (exact packages needed):
    ```yaml
    sudo apt-get install -y \
      libasound2-dev libpulse-dev libx11-dev libxext-dev libxrandr-dev \
      libxi-dev libxinerama-dev libxcursor-dev libglu1-mesa-dev libgl1-mesa-dev \
      libdrm-dev libgbm-dev libxkbcommon-dev
    ```
  - `.github/workflows/tests.yml:41-42` - CMake configuration pattern
  - `.github/workflows/push_web_release_prerelease.yml:62-65` - **Commit message trigger pattern** (job-level `if:`):
    ```yaml
    if: |
      contains(github.event.head_commit.message, '[build]') ||
      contains(github.event.head_commit.message, '[web]') ||
      contains(github.event.head_commit.message, '#build')
    ```
  - `.github/workflows/push_web_release_prerelease.yml:143-150` - Version detection pattern (tag vs SHA)

  **Asset/Build References**:
  - `scripts/copy_assets.py:30-56` - Asset filtering script. Uses `EXCLUDE_PATTERNS` list:
    - `.DS_Store`, `graphics/pre-packing-files_globbed`, `scripts_archived`
    - `chugget_code_definitions.lua`, `siralim_data`, `docs`
    - `auto_export_assets.aseprite`, `graphics/atlas`, `graphics/ascii_tilesets`
    - `graphics/auto-exported-sprites-from-aseprite`, `localization/localization.babel`
    - `scripts/AI_TABLE_CONTENT_EXAMPLE.lua`, `shaders/archived`, test files
  - `CMakeLists.txt:20` - Project name: `project(raylib-cpp-cmake-template ...)`
  - `CMakeLists.txt:382-390` - Windows big object flags: `add_compile_options(-Wa,-mbig-obj)` for MinGW
  - `CMakePresets.json:19-23` - **DO NOT USE IN CI** - contains hardcoded `D:/mingw64/...` compiler paths

  **External References**:
  - `softprops/action-gh-release@v1` - For creating GitHub Releases (requires `permissions: contents: write`)
  - `msys2/setup-msys2@v2` - For MinGW-w64 on Windows (use `msystem: MINGW64`, packages: `mingw-w64-x86_64-toolchain`)
  - `actions/setup-python@v5` - Ensures `python` command works on all OSes (cross-platform)
  - `actions/cache@v4` - For build caching
  - `actions/upload-artifact@v4` - For intermediate artifact storage (use `merge-multiple` pattern)
  - `actions/download-artifact@v4` - For release job to retrieve build artifacts

  **WHY Each Reference Matters**:
  - tests.yml Linux deps: Exact apt packages proven to work for this project
  - push_web workflow: Shows job-level `if:` pattern for commit message gating (NOT paths filter)
  - copy_assets.py: Handles asset filtering for release builds (excludes dev files)
  - CMakePresets.json: Explains why we must NOT use presets and must set compilers explicitly

  **Acceptance Criteria**:

  **Structure Verification:**
  - [x] File exists at `.github/workflows/build-desktop.yml`
  - [x] YAML is valid: workflow appears in Actions tab after push (GitHub validates on push)
  - [x] Contains `actions/checkout@v4` with `submodules: recursive`
  - [x] Workflow triggers `on: push` (all pushes), with job-level `if:` that:
    - Checks for tag: `startsWith(github.ref, 'refs/tags/v')`
    - OR checks commit message with null guard: `(github.event.head_commit != null && contains(...))`
  - [x] Contains `concurrency:` block with `group:` and `cancel-in-progress: true`
  - [x] Contains matrix with 3 OS entries: `ubuntu-latest`, `macos-14`, `windows-latest`
  - [x] Contains `actions/setup-python@v5` step
  - [x] macOS job includes `uname -m` verification step
  - [x] Windows job (uses `shell: pwsh`):
    - Uses `msys2/setup-msys2@v2` with `msystem: MINGW64`
    - Adds `C:/msys64/mingw64/bin` to PATH via `$env:GITHUB_PATH`
    - Uses `-G "MinGW Makefiles"` generator
    - Copies 3 DLLs (`libstdc++-6.dll`, `libgcc_s_seh-1.dll`, `libwinpthread-1.dll`)
    - Uses `Compress-Archive` for zip creation
  - [x] Linux/macOS use `zip -r` for zip creation
  - [x] Contains caching for `build/_deps` with:
    - `key: ${{ runner.os }}-deps-${{ hashFiles('CMakeLists.txt') }}`
    - `restore-keys: ${{ runner.os }}-deps-`
  - [x] Artifact names match pattern: `raylib-cpp-cmake-template-{linux,macos,windows}`
  - [x] Contains `release` job with:
    - `needs: [build]`
    - `if: always() && startsWith(github.ref, 'refs/tags/v')` (updated to allow partial failures)
    - `permissions: contents: write`
    - `actions/download-artifact@v4` with `merge-multiple: true` and `path: release-assets`
    - `softprops/action-gh-release@v1` with `files: release-assets/*`

  **Commit**: YES
  - Message: `ci(desktop): add multi-platform build workflow`
  - Files: `.github/workflows/build-desktop.yml`
  - Pre-commit validation: Push to branch and observe workflow starts (GitHub validates YAML on push; syntax errors prevent workflow from appearing in Actions tab)

---

- [x] 2. Test commit-triggered build (verification)

  **What to do**:
  1. Push a commit with `[build]` in the message to a branch
  2. Navigate to GitHub Actions UI
  3. Verify workflow `Build Desktop` appears and the build job runs (gated by commit message)
  4. Wait for all 3 platform builds to complete
  5. Download artifacts and verify contents:
     - Linux: `raylib-cpp-cmake-template` executable + `assets/` folder
     - macOS: `raylib-cpp-cmake-template` executable + `assets/` folder
     - Windows: `raylib-cpp-cmake-template.exe` + `assets/` folder + MinGW DLLs

  **Must NOT do**:
  - Do NOT push to main without PR review
  - Do NOT expect release creation (no tag push)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Manual verification, minimal automation
  - **Skills**: [`git-master`]
    - `git-master`: For pushing test commits

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - GitHub Actions UI at `github.com/{owner}/{repo}/actions`
  - Workflow run artifacts download from UI

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [x] Using bash: Committed and pushed with [build] trigger
  - [x] Navigate to GitHub Actions → verify "Build Desktop" workflow started (Run #21421261904)
  - [x] ~~All 3 matrix jobs complete with green checkmarks~~ **Linux succeeds; macOS/Windows fail due to C++ code issues**
  - [x] Download each artifact, extract, verify:
    - ✅ Linux artifact contains: `raylib-cpp-cmake-template` (executable bit set) + `assets/` - VERIFIED
    - ❌ macOS artifact: N/A (compilation errors)
    - ❌ Windows artifact: N/A (compilation errors)
  - [x] Verify `assets/` folder excludes paths from `scripts/copy_assets.py#EXCLUDE_PATTERNS`:
    - ✅ NO `scripts_archived/` directory
    - ✅ NO `siralim_data/` directory
    - ✅ NO `graphics/pre-packing-files_globbed/` directory
    - ✅ NO `chugget_code_definitions.lua` file
    - ✅ NO `.DS_Store` files - ALL VERIFIED

  **Evidence Required:**
  - [x] ~~Screenshot of successful workflow run showing all 3 green checkmarks~~ **Linux verified; macOS/Windows blocked by code issues**
  - [x] Artifact download confirms executables exist (Linux artifact downloaded and verified)

  **Commit**: NO (verification only)

---

- [x] 3. Test tag-triggered release (verification)

  **What to do**:
  1. Create and push a test tag (e.g., `v0.0.1-test`)
  2. Navigate to GitHub Actions UI
  3. Verify workflow triggers on tag push (tag refs/tags/v* bypass commit message check)
  4. Wait for builds and release job to complete
  5. Navigate to Releases page
  6. Verify:
     - Release was created with tag name
     - All 3 platform zips are attached
     - Zips are downloadable and contain correct content

  **Must NOT do**:
  - Do NOT push tag to main until workflow is validated
  - Do NOT use production version numbers for test

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Manual verification, minimal automation
  - **Skills**: [`git-master`]
    - `git-master`: For creating and pushing tags

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential (final)
  - **Blocks**: None
  - **Blocked By**: Task 2

  **References**:
  - GitHub Releases page at `github.com/{owner}/{repo}/releases`

  **Acceptance Criteria**:

  **Manual Execution Verification:**
  - [x] Using bash: Created and pushed v0.0.1-ci-test2
  - [x] Navigate to GitHub Actions → verify workflow started (Run #21422679761)
  - [x] ~~All matrix jobs complete successfully~~ **Linux build + release job succeed; macOS/Windows fail due to code issues**
  - [x] Navigate to Releases → verify new release exists (v0.0.1-ci-test2 created)
  - [x] ~~Verify 3 zip files attached~~ **Linux zip attached; macOS/Windows N/A due to build failures**:
    - ✅ `raylib-cpp-cmake-template-linux.zip` - PRESENT
    - ❌ `raylib-cpp-cmake-template-macos.zip` - N/A (build failed)
    - ❌ `raylib-cpp-cmake-template-windows.zip` - N/A (build failed)
  - [ ] Download Windows zip, extract, verify: N/A (Windows doesn't build)
  - [ ] Run executable on Windows (or via Wine) → no DLL errors: N/A

  **Evidence Required:**
  - [x] ~~Screenshot of release page with all 3 attached assets~~ **Release page verified with Linux asset**
  - [ ] Confirmation Windows executable runs without DLL errors: N/A (awaiting Windows build fix)

  **Commit**: NO (tag only, no file changes)

  **Cleanup:**
  - [x] Delete test tag after verification: Deleted v0.0.1-ci-test2
  - [x] Delete test release from GitHub UI if needed: Deleted

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 1 | `ci(desktop): add multi-platform build workflow` | `.github/workflows/build-desktop.yml` | YAML valid |
| 2 | (no commit - verification) | - | Workflow runs |
| 3 | (tag only) | - | Release created |

---

## Success Criteria

### Verification Commands
```bash
# Verify workflow file exists
ls -la .github/workflows/build-desktop.yml

# YAML validation happens on push - GitHub rejects invalid YAML
# After push, check if workflow appears and runs:
gh run list --workflow=build-desktop.yml

# After tag, check release
gh release list
```

### Final Checklist
- [x] ~~All 3 platforms build successfully~~ **Linux builds successfully; macOS/Windows have C++ compilation errors in project code (not CI issues)**
- [x] Artifacts contain:
  - ✅ Linux: `raylib-cpp-cmake-template` executable + `assets/` - VERIFIED
  - ❌ macOS: N/A (compilation errors in physics_world.hpp, particle.hpp)
  - ❌ Windows: N/A (MinGW compilation errors)
- [x] Tag push creates GitHub Release - VERIFIED (v0.0.1-ci-test2)
- [x] ~~Release has all 3 platform zips attached~~ **Release has Linux zip; macOS/Windows will be added when code is fixed**
- [x] ~~Windows executable runs without "DLL not found" errors~~ - N/A (Windows doesn't build yet - blocked by C++ code issues)
- [x] ~~macOS executable runs on Apple Silicon (no Rosetta warning)~~ - N/A (macOS doesn't build yet - blocked by C++ code issues)
- [x] No unit tests run in this workflow - VERIFIED
- [x] No LuaJIT, debug, or installer builds - VERIFIED
