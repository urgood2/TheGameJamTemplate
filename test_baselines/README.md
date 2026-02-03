# Visual Baselines

Visual baselines are reference screenshots for visual regression testing. The test harness compares captured screenshots against these baselines to detect unintended visual changes.

## Directory Structure

```
test_baselines/
├── README.md              # This file
├── visual_tolerances.json # Per-test tolerance overrides
├── visual_quarantine.json # Tests quarantined due to flakiness
└── screenshots/
    └── <platform_key>/
        └── <renderer>/
            └── <resolution>/
                └── <safe_test_id>.png
```

## Platform Key Definition

Platform keys are computed deterministically from environment properties:

| Component | Values | Detection Method |
|-----------|--------|------------------|
| os | linux, macos, windows | `jit.os` or `_G.globals.platform.os` |
| arch | x64, arm64 | `jit.arch` or `_G.globals.platform.arch` |
| renderer | opengl, vulkan, metal, d3d11 | `_G.globals.renderer` |
| gpu_vendor | nvidia, amd, intel, apple | Best-effort from renderer info |
| resolution | {width}x{height} | `_G.globals.screenWidth/Height` |

**Example**: `linux-x64-opengl-nvidia-1920x1080`

The test harness uses this key to locate the correct baseline:
```
test_baselines/screenshots/linux/opengl/1920x1080/smoke.screenshot.placeholder.png
```

## Recording Baselines

Baselines are recorded ONLY when explicitly requested. **Never record baselines in CI.**

### From Lua:
```lua
local TestRunner = require("test.test_runner")
TestRunner.run({ record_baselines = true })
```

### From Command Line:
```bash
./build/raylib-cpp-cmake-template --scene test --record-baselines
```

### Workflow for Adding/Updating Baselines:

1. Run tests locally with `--record-baselines`
2. Review captured screenshots visually
3. Commit only the baselines you intend to update
4. Run `python scripts/check_baseline_size.py` before pushing

## Tolerance Configuration

Tolerances control how strictly screenshots must match baselines.

### Default Tolerances

| Metric | Default | Description |
|--------|---------|-------------|
| `pixel_diff_threshold` | 0.01 | Maximum fraction of different pixels (0.0-1.0) |
| `ssim_threshold` | 0.98 | Minimum structural similarity (0.0-1.0) |

### Per-Test Overrides

Edit `visual_tolerances.json` to override tolerances for specific tests:

```json
{
  "schema_version": "1.0",
  "default_tolerance": {
    "pixel_diff_threshold": 0.01,
    "ssim_threshold": 0.98
  },
  "per_test_overrides": {
    "rendering.shader.bloom": {
      "pixel_diff_threshold": 0.05,
      "ssim_threshold": 0.95,
      "reason": "Bloom intensity varies by GPU"
    }
  }
}
```

## Harness Behavior

1. **Baseline exists**: Compare captured screenshot with tolerance
   - **Match**: PASS
   - **Mismatch**: FAIL, generate diff artifacts

2. **No baseline**: PASS with `NeedsBaseline` flag
   - Test passes but logs warning
   - Artifact indicates baseline should be recorded

3. **Mismatch artifacts** (written to `test_output/artifacts/<test_id>/`):
   - `baseline.png` - Copy of expected baseline
   - `actual.png` - Captured screenshot
   - `diff.png` - Visual difference highlight
   - `metrics.json` - Comparison metrics

## Quarantine System

Quarantine flaky visual tests that fail intermittently due to GPU/driver differences.

### Adding to Quarantine

Edit `visual_quarantine.json`:

```json
{
  "schema_version": "1.0",
  "quarantined_tests": [
    {
      "test_id": "rendering.shader.bloom",
      "reason": "GPU-dependent bloom intensity",
      "owner": "@developer_handle",
      "issue_link": "https://github.com/org/repo/issues/123",
      "added_date": "2026-02-01",
      "expires_date": "2026-02-15"
    }
  ]
}
```

### Required Fields

| Field | Required | Description |
|-------|----------|-------------|
| `test_id` | Yes | Test identifier |
| `reason` | Yes | Why the test is quarantined |
| `owner` | Yes | Responsible developer |
| `issue_link` | Yes | Tracking issue/task |
| `added_date` | Yes | When quarantine started |
| `expires_date` | Yes | Auto-expires (max 14 days) |

### Quarantine Behavior

- **PR CI**: Quarantined tests run but do NOT fail the build
- **Nightly CI**: Quarantined tests DO fail (surfacing lingering issues)
- **Expiry**: Tests auto-unquarantine after `expires_date`

## Size Governance

Visual baselines can bloat the repository. Size limits are enforced:

| Threshold | Action |
|-----------|--------|
| 50MB PR delta | WARN (review carefully) |
| 200MB PR delta | FAIL (requires approval) |

### Checking Baseline Size

Before committing baseline changes:

```bash
python scripts/check_baseline_size.py
```

Sample output:
```
[BASELINE-SIZE] Scanning test_baselines/screenshots/...
[BASELINE-SIZE] Current size: 12.5MB
[BASELINE-SIZE] PR delta: +2.3MB (within limits)
[BASELINE-SIZE] Status: PASS
```

### Git LFS (Recommended)

For large baseline sets, enable Git LFS:

```bash
# .gitattributes
test_baselines/screenshots/**/*.png filter=lfs diff=lfs merge=lfs -text
```

## Troubleshooting

### "No baseline found"
- Baseline may not exist for your platform/renderer/resolution
- Run with `--record-baselines` to create it
- Check platform key matches expected directory

### "Visual diff exceeds tolerance"
- Review diff artifacts in `test_output/artifacts/<test_id>/`
- If change is intentional: update baseline
- If change is flaky: add to quarantine with tracking issue

### "Baseline size check failed"
- Optimize image sizes (consider lossy compression)
- Review if all changed baselines are necessary
- Consider Git LFS for large baseline sets

## Best Practices

1. **Record baselines on clean builds** - Avoid recording during iterative development
2. **One platform at a time** - Record baselines per-platform to avoid cross-platform issues
3. **Review diffs visually** - Don't blindly update baselines
4. **Document tolerance overrides** - Always include `reason` field
5. **Keep quarantine short** - Max 14 days, with tracking issue
6. **Monitor size growth** - Check before each PR with baseline changes
