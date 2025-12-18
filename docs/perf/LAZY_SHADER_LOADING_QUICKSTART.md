# Lazy Shader Loading - Quick Start Guide

## TL;DR

Lazy shader loading defers shader compilation until first use, reducing startup time.

**Enable it:**
```json
// assets/config.json
{
  "performance": {
    "enable_lazy_shader_loading": true
  }
}
```

**Disable it:**
```json
{
  "performance": {
    "enable_lazy_shader_loading": false  // or omit entirely
  }
}
```

## How It Works

### Before (Eager Loading)
```
Startup:
  Load shader metadata ─┬─ Compile shader 1
                        ├─ Compile shader 2
                        ├─ ...
                        └─ Compile shader 80
  ↓
  Ready (after all shaders compiled)
```

### After (Lazy Loading)
```
Startup:
  Load shader metadata only
  ↓
  Ready (immediately)

Runtime:
  getShader("3d_skew") ──→ Not in cache ──→ Compile now ──→ Cache ──→ Return
  getShader("3d_skew") ──→ In cache ────────────────────────────→ Return
```

## Usage Examples

### Example 1: Reduce Startup Time for Release Build

**Scenario:** Your game takes 5 seconds to start, 2 seconds of which is shader compilation.

**Solution:**
```json
// assets/config.json
{
  "performance": {
    "enable_lazy_shader_loading": true
  }
}
```

**Result:**
- Startup time: 5s → 3s
- Shader compilation spread across gameplay
- First use of each shader: Small delay
- Subsequent uses: No overhead

### Example 2: Development Mode

**Scenario:** You're iterating on shaders and want immediate feedback.

**Solution:**
```json
// Keep lazy loading disabled (default)
{
  "performance": {
    "enable_lazy_shader_loading": false
  }
}
```

**Benefits:**
- Shader errors caught at startup
- Hot-reload (F5) works immediately
- No first-use delays during testing

### Example 3: Profile Both Modes

**Compare startup performance:**

```bash
# 1. Disable lazy loading
# Edit config.json: "enable_lazy_shader_loading": false
just build-release
./build/raylib-cpp-cmake-template
# Note startup time from logs

# 2. Enable lazy loading
# Edit config.json: "enable_lazy_shader_loading": true
just build-release
./build/raylib-cpp-cmake-template
# Note startup time from logs

# Compare results
```

## Monitoring

### Log Messages

**Lazy loading enabled:**
```
[info] Lazy shader loading enabled via config.json
[info] Lazy shader loading enabled - storing metadata for 80 shaders
```

**On first shader use:**
```
[debug] Lazy loading shader: 3d_skew
[info] Lazy loaded shader: 3d_skew
```

**If compilation fails:**
```
[error] [shader] Lazy load failed for 3d_skew: <error details>
[warn] Failed to lazy load shader 3d_skew: <error>
```

### Telemetry Events

Monitor these events in your analytics:

- `shader_lazy_loading_mode`: Logged at startup (count of shaders)
- `shader_lazy_loaded`: Each successful lazy compile
- `shader_lazy_load_failed`: Any compilation failures

## Troubleshooting

### Problem: Shader doesn't render

**Symptom:** Entity using shader appears broken/default

**Fix:**
1. Check logs for `shader_lazy_load_failed`
2. Verify shader paths in `assets/shaders/shaders.json`
3. Temporarily disable lazy loading to isolate issue

### Problem: Game stutters during gameplay

**Symptom:** Brief freezes when new effects appear

**Cause:** Multiple shaders being compiled simultaneously

**Fix:**
1. Identify which shaders cause stutters (check logs)
2. Consider preloading critical shaders (future enhancement)
3. Spread shader usage over time (e.g., loading screens)

### Problem: Hot-reload (F5) not working

**Symptom:** Shader changes don't apply when pressing F5

**Cause:** Shader not compiled yet (metadata only)

**Fix:**
1. Use the shader at least once to trigger compilation
2. Press F5 again - hot-reload will work now
3. Or disable lazy loading during development

## Performance Expectations

### Startup Time Reduction

| Shaders Used | Reduction |
|--------------|-----------|
| 10/80 | ~87.5% |
| 20/80 | ~75.0% |
| 40/80 | ~50.0% |
| 80/80 | Minimal |

### Runtime Impact

| Operation | Lazy (First) | Lazy (Cached) | Eager |
|-----------|--------------|---------------|-------|
| getShader() | 1-5ms | <0.1ms | <0.1ms |

## Best Practices

### ✅ DO:
- Enable for release builds to reduce startup time
- Profile both modes to measure actual gains
- Monitor telemetry for lazy load patterns
- Keep disabled during shader development

### ❌ DON'T:
- Rely on lazy loading to hide shader compile errors
- Enable without profiling first
- Forget to test first-use scenarios

## Migration Checklist

Enabling lazy loading for the first time:

- [ ] Backup current config.json
- [ ] Add `performance.enable_lazy_shader_loading: true`
- [ ] Build and run game
- [ ] Check logs for "Lazy shader loading enabled"
- [ ] Test gameplay - verify shaders render correctly
- [ ] Measure startup time (before/after)
- [ ] Monitor for any stuttering during gameplay
- [ ] Test hot-reload (F5) after using shaders
- [ ] Check telemetry for lazy load events

## Questions?

See comprehensive documentation: `docs/perf/lazy-shader-loading.md`

Report issues with:
- Log output
- Config settings
- Expected vs actual behavior
- Performance profile results
