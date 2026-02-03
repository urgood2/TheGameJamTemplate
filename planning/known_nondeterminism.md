# Known Non-Determinism Sources

This document lists known sources of non-deterministic behavior that can cause
test flakes, particularly for visual/screenshot tests. Each section includes
affected tests, mitigations, and configuration guidance.

## GPU Rendering Differences
### Description
Different GPUs (and different drivers for the same GPU) may produce slightly
different pixel values for the same rendering operations.

### Affected Tests
- Tests tagged with "visual"
- All screenshot comparisons

### Mitigation
- Use pixel-diff tolerance (default: 0.1% pixels may differ)
- Use SSIM threshold (default: 0.98)
- Configure per-platform baselines

### Configuration
```json
// test_baselines/visual_tolerances.json
{
  "default": {
    "pixel_diff_percent": 0.1,
    "ssim_threshold": 0.98
  },
  "overrides": {
    "ui.panel.shadow_effect": {
      "pixel_diff_percent": 0.5,
      "reason": "Shadow blur varies by GPU"
    }
  }
}
```

## Font Rasterization Variations
### Description
Font rendering differs between operating systems and font engines.

### Affected Tests
- Tests with text rendering
- UI tests with labels

### Mitigation
- Use bitmap fonts for critical text tests
- Set explicit font hash in test_output/capabilities.json
- Maintain platform-specific baselines

### Configuration
```json
// test_output/capabilities.json (recorded by test harness)
{
  "environment": {
    "fonts": {
      "default_font_hash": "sha256:..."
    }
  }
}
```

## Time-Based Animations
### Description
Frame-time dependent animations produce different results based on system
performance and timing jitter.

### Affected Tests
- Animation tests
- Particle effect tests
- Tween tests

### Mitigation
- Use fixed frame counts (test_utils.step_frames(N))
- Disable vsync for deterministic frame pacing (where possible)
- Capture at specific frame numbers, not elapsed time

### Configuration
```lua
-- Use frame stepping in tests
test_utils.step_frames(30)
test_utils.capture_screenshot("ui.panel.after_30_frames")
```

## Floating Point Precision
### Description
Different CPUs/compilers may produce slightly different floating point results.

### Affected Tests
- Physics simulation tests
- Math-heavy calculations

### Mitigation
- Use epsilon comparisons (test_utils.assert_near)
- Round to significant digits for display comparisons
- Test invariants, not exact values

### Configuration
```lua
test_utils.assert_near(actual, expected, 1e-4, "Value within tolerance")
```

## RNG State
### Description
Random number generators produce different sequences without fixed seeds.

### Affected Tests
- Particle systems
- Procedural generation
- Combat damage rolls

### Mitigation
- Call math.randomseed(FIXED_SEED) at test start
- Reset any engine RNG in test_utils.reset_world()
- Document any additional RNG sources

### Configuration
```lua
math.randomseed(12345)
```

## Platform-Specific Baseline Routing
Baselines are stored per platform/renderer/resolution:

```
test_baselines/screenshots/<platform>/<renderer>/<resolution>/
```

When tests run on a new environment, ensure baselines exist for the matching
triplet. If they do not, capture new baselines first and document any variance
in tolerances or overrides.

## Logging Guidance
When non-determinism affects a test, log in the following format:

```
[NONDETERMINISM] Test: ui.panel.shadow_effect
[NONDETERMINISM] Source: GPU rendering differences
[NONDETERMINISM] Tolerance applied: pixel_diff_percent=0.5
[NONDETERMINISM] Actual diff: 0.3% (within tolerance)
[NONDETERMINISM] See: planning/known_nondeterminism.md#gpu-rendering-differences
```
