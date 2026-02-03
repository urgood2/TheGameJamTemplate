# Known Non-Determinism Sources

This document lists known sources of non-deterministic behavior that can cause
visual and logic test flakes, with mitigations and configuration references.

## GPU Rendering Differences
### Description
Different GPUs and driver versions can produce slightly different pixels for the
same render pass (shader math, precision, blending, and texture sampling).

### Affected Tests
- tests tagged with `visual`
- all screenshot comparisons

### Mitigation
- Use tolerance thresholds for pixel diff + SSIM.
- Prefer deterministic render paths (disable dynamic exposure, noise, etc.).
- Capture baselines per platform/renderer/resolution.

### Configuration
`test_baselines/visual_tolerances.json`:
```json
{
  "schema_version": "1.0",
  "default_tolerance": {
    "pixel_diff_threshold": 0.01,
    "ssim_threshold": 0.98
  },
  "per_test_overrides": {
    "ui.panel.shadow_effect": {
      "pixel_diff_threshold": 0.05,
      "ssim_threshold": 0.95,
      "reason": "Shadow blur varies by GPU"
    }
  }
}
```

## Font Rasterization Variations
### Description
Font rendering differs between operating systems and font engines, affecting
kerning, hinting, and glyph rasterization.

### Affected Tests
- UI tests with text rendering
- screenshot comparisons containing labels or text blocks

### Mitigation
- Use bitmap fonts for critical visual tests.
- Pin font assets and versions.
- Record font hash/capability metadata in `test_output/capabilities.json`.

### Configuration
`test_output/capabilities.json` should capture font metadata when available
(e.g., `font_hash`, `font_engine`). Use per-test tolerance overrides when text
is visually unstable.

## Time-Based Animations
### Description
Animations driven by real time or variable frame times can diverge across
machines due to performance differences.

### Affected Tests
- animation tests
- particle effect tests
- tween tests

### Mitigation
- Advance with fixed frame counts (`test_utils.step_frames(N)`), not wall time.
- Disable vsync where supported for deterministic stepping.
- Capture screenshots at deterministic frame numbers.

### Configuration
- Use test harness utilities that step fixed frames.
- Record fixed-step configuration in `test_output/capabilities.json` when set.

## Floating Point Precision
### Description
Different CPUs, compilers, and SIMD paths can produce small floating point
differences that accumulate over time.

### Affected Tests
- physics simulation tests
- math-heavy calculations

### Mitigation
- Use epsilon comparisons (`test_utils.assert_near`).
- Round or clamp values for comparisons when appropriate.
- Assert invariants rather than exact values for long-running simulations.

### Configuration
Document tolerances at the test level (e.g., `assert_near` epsilon) and include
expected ranges in test descriptions.

## RNG State
### Description
Random number generators produce different sequences without fixed seeds or
when external RNG state leaks between tests.

### Affected Tests
- particle systems
- procedural generation
- combat damage rolls

### Mitigation
- Call `math.randomseed(FIXED_SEED)` at test start.
- Reset engine RNG (via `test_utils.reset_world()`).
- Avoid shared RNG state across tests.

### Configuration
Document fixed seeds in tests and ensure `test_utils.reset_world()` is called
between test cases.

## Platform-Specific Baseline Routing
Visual baselines are stored by platform/renderer/resolution. The harness selects
baselines using a computed platform key (OS, arch, renderer, GPU vendor, and
resolution). See `test_baselines/README.md` for full details and examples.

Baseline path format:
```
test_baselines/screenshots/<platform_key>/<renderer>/<resolution>/<safe_test_id>.png
```

Example platform key: `linux-x64-opengl-nvidia-1920x1080`

## Logging Requirements
When non-determinism affects a test:
```
[NONDETERMINISM] Test: ui.panel.shadow_effect
[NONDETERMINISM] Source: GPU rendering differences
[NONDETERMINISM] Tolerance applied: pixel_diff_threshold=0.05
[NONDETERMINISM] Actual diff: 0.03 (within tolerance)
[NONDETERMINISM] See: planning/known_nondeterminism.md#gpu-rendering-differences
```
