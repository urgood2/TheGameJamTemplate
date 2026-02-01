# Descent Evidence Directory

This directory contains evidence artifacts for the Descent (DCSS-Lite roguelike mode) MVP implementation.

## Directory Structure

```
.sisyphus/evidence/descent/
├── README.md                    # This file
├── <bead-id>/                   # Per-bead evidence directories
│   ├── summary.md               # Required: summary of work done
│   ├── run.log                  # Required: test run output (via tee)
│   ├── *.png                    # Optional: screenshots
│   └── seeds.txt                # Optional: seeds used for testing
└── soak/                        # H3 soak test evidence
    └── soak.md                  # 5-run soak results
```

## Required Artifacts per Bead

Every closed Descent bead **must** include:

### 1. summary.md (Required)

Summary of implementation with:
- Files created/modified
- Acceptance criteria verification (table format preferred)
- Key design decisions
- Commands used for verification
- Agent name and date

### 2. run.log or test.log (Required for code changes)

Captured test output using `tee`:

```bash
# Descent tests
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template 2>&1 | tee .sisyphus/evidence/descent/<BEAD_ID>/run.log

# C++ unit tests (if C++ touched)
just test 2>&1 | tee .sisyphus/evidence/descent/<BEAD_ID>/unit_tests.log

# UI Baseline verification (if shared UI/layout touched)
just ui-verify 2>&1 | tee .sisyphus/evidence/descent/<BEAD_ID>/ui_verify.log
```

### 3. Screenshots (Required for UI/visual changes)

For UI or visual behavior changes:
- `<feature>_screenshot.png` - Primary screenshot
- Before/after comparisons where applicable
- FOV visualization for FOV-related work

### 4. Seeds Used (Recommended for determinism work)

When testing deterministic behavior, document seeds:
- In summary.md under "Seeds Used" section
- Or in a separate `seeds.txt` file

## When UBS (UI Baseline Suite) is Required

Run `just ui-verify` **before closing** if you modified any of:

- `assets/scripts/ui/ui_syntax_sugar.lua` (DSL primitives)
- `assets/scripts/ui/ui_scale.lua` (scaling calculations)
- `assets/scripts/ui/ui_box.lua` (box layout engine)
- Any file in `assets/scripts/ui/showcase/` (showcase gallery)
- Any file affecting core layout math

Capture output:
```bash
just build-debug
just ui-verify 2>&1 | tee .sisyphus/evidence/descent/<BEAD_ID>/ui_verify.log
```

## Closing Beads with Evidence

After completing work:

```bash
# Create evidence directory
mkdir -p .sisyphus/evidence/descent/<BEAD_ID>

# Write summary
cat > .sisyphus/evidence/descent/<BEAD_ID>/summary.md << 'SUMMARY'
# <BEAD_ID>: <Title>

## Implementation Summary
...

## Acceptance Criteria
| Criterion | Status |
|-----------|--------|
| ... | ✅ |

## Commands Used
...

## Agent
- Agent: <YourAgentName>
- Date: YYYY-MM-DD
SUMMARY

# Run tests and capture output
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template 2>&1 | tee .sisyphus/evidence/descent/<BEAD_ID>/run.log

# Close the bead
bd close <BEAD_ID> --session "descent-mvp"
bd comments add <BEAD_ID> --file .sisyphus/evidence/descent/<BEAD_ID>/summary.md
```

## Test Commands Reference

### Build (choose one)

```bash
# Preferred (if just available)
just build-debug

# Fallback
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_UNIT_TESTS=OFF && cmake --build build -j
```

### Descent Tests (after A2 is merged)

```bash
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template 2>&1 | tee /tmp/descent_tests.log
echo "exit=$?"
```

Exit codes:
- `0` = All tests passed
- `1` = Tests failed, timeout, or module load error

### C++ Unit Tests

```bash
just test 2>&1 | tee /tmp/unit_tests.log
# or
cmake -B build -DENABLE_UNIT_TESTS=ON && cmake --build build --target unit_tests -j && ./build/tests/unit_tests --gtest_color=yes
```

### UI Baseline Suite

```bash
# Capture baselines (before refactors)
just ui-baseline-capture 2>&1 | tee /tmp/ui_baseline_capture.log

# Verify baselines (after changes)
just ui-verify 2>&1 | tee /tmp/ui_verify.log
```

### Headless Testing (Linux with Xvfb)

```bash
command -v xvfb-run && xvfb-run -a env AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template 2>&1 | tee /tmp/descent_tests.log
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ENABLE_DESCENT=1` | Show Descent entry in main menu |
| `AUTO_START_DESCENT=1` | Boot directly into Descent mode |
| `RUN_DESCENT_TESTS=1` | Run test runner and exit 0/1 |
| `DESCENT_SEED=<int>` | Force deterministic seed |
| `AUTO_EXIT_AFTER_TEST=1` | Ensure tests terminate |

## Notes

- All Descent code must be testable without `ENABLE_DESCENT=1`
- Logs should be committed to evidence directories (not /tmp)
- Screenshots are preferred as PNG format
- Keep summary.md concise but complete
