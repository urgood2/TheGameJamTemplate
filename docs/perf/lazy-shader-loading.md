# Lazy Shader Loading

## Overview

Lazy shader loading is a performance optimization that defers shader compilation until first use, significantly reducing startup time by spreading compilation costs across gameplay.

## Problem Statement

The engine loads 80+ shaders at startup via `shaders::loadShadersFromJSON()`. Each shader requires compilation of vertex and fragment programs, blocking the main thread. This contributes significantly to initial load time.

**Before Lazy Loading:**
- All 80+ shaders compiled at startup
- Blocks main thread during compilation
- Shaders that are never used still pay compilation cost

**After Lazy Loading:**
- Only shader metadata stored at startup
- Compilation deferred until first `getShader()` call
- Compiled shaders cached for future use
- Unused shaders never compiled

## Configuration

Enable lazy shader loading in `assets/config.json`:

```json
{
  "performance": {
    "enable_lazy_shader_loading": true
  }
}
```

**Default:** `false` (disabled for backward compatibility)

## Implementation Details

### Architecture

1. **Shader Metadata Storage** (`ShaderMetadata` struct):
   - `vertexPath`: Path to vertex shader file
   - `fragmentPath`: Path to fragment shader file
   - `compiled`: Boolean flag tracking compilation status

2. **Loading Modes**:
   - **Eager (default)**: Original behavior - compile all shaders at startup
   - **Lazy**: Store metadata only, compile on first access

3. **Compilation Flow**:
   ```
   getShader(name)
   → Check loadedShaders cache
   → If not found and lazy loading enabled
      → compileShaderOnDemand(name)
      → Store in loadedShaders
      → Return compiled shader
   ```

### Key Functions

#### `shaders::loadShadersFromJSON()`
Modified to support two paths:
- **Lazy mode**: Store `ShaderMetadata`, skip compilation
- **Eager mode**: Compile immediately (original behavior)

#### `shaders::getShader()`
Updated to trigger lazy compilation:
```cpp
auto getShader(std::string shaderName) -> Shader {
    // Check cache
    if (loadedShaders.find(shaderName) != loadedShaders.end())
        return loadedShaders[shaderName];

    // Lazy compile if enabled
    if (enableLazyShaderLoading) {
        auto result = compileShaderOnDemand(shaderName);
        if (result.isOk())
            return result.value();
    }

    return {0};  // Not found
}
```

#### `compileShaderOnDemand()` (static helper)
Performs on-demand compilation:
1. Lookup shader metadata
2. Compile using stored paths
3. Cache in `loadedShaders`
4. Update modification times for hot-reload
5. Mark as compiled in metadata
6. Emit telemetry event

## Performance Impact

### Expected Gains

**Startup Time Reduction:**
- **No shaders used**: ~100% reduction (none compiled)
- **10 shaders used**: ~87.5% reduction (10/80 compiled)
- **All shaders used**: Minimal impact (compilation spread over time)

**Runtime Impact:**
- First access to shader: Small delay (compile on demand)
- Subsequent access: No overhead (cached)
- Hot-reload: Works identically for both modes

### Telemetry Events

The system emits the following events for monitoring:

- `shader_lazy_loading_mode`: Logged when lazy loading is enabled
  - `count`: Number of shaders with metadata stored
  - `platform`, `build_id`

- `shader_lazy_loaded`: Logged when a shader is compiled on demand
  - `name`: Shader name
  - `platform`, `build_id`

- `shader_lazy_load_failed`: Logged when on-demand compilation fails
  - `name`, `vertex_path`, `fragment_path`, `error`
  - `platform`, `build_id`

## Testing

### Manual Testing

1. **Enable lazy loading** in `assets/config.json`:
   ```json
   "performance": { "enable_lazy_shader_loading": true }
   ```

2. **Run with debug logging** to observe lazy compilation:
   ```bash
   just build-debug
   ./build/raylib-cpp-cmake-template
   ```

3. **Look for log messages**:
   - `Lazy shader loading enabled - storing metadata for X shaders`
   - `Lazy loading shader: <name>` (on first use)
   - `Lazy loaded shader: <name>` (on success)

4. **Compare startup times**:
   - Measure with lazy loading enabled vs disabled
   - Check `startup_timer::print_summary()` output

### Expected Behavior

- **No visual differences**: Rendering should be identical
- **Shader access**: No errors or warnings
- **Hot-reload**: F5 still works for shader reloading
- **Startup time**: Reduced with lazy loading enabled

## Limitations & Caveats

1. **First-Use Latency**:
   - First access to a shader may have a small delay
   - Noticeable only for complex shaders
   - Mitigated by caching after first compile

2. **Hot-Reload Compatibility**:
   - Hot-reload only works for compiled shaders
   - Metadata-only shaders not tracked until compiled
   - After first use, hot-reload works normally

3. **Error Reporting**:
   - Shader compilation errors deferred to first use
   - May cause runtime issues if shader is critical
   - Consider preloading critical shaders in startup sequence

## Future Enhancements

1. **Preload List**: Specify shaders to precompile at startup
   ```json
   "performance": {
     "enable_lazy_shader_loading": true,
     "preload_shaders": ["3d_skew", "holo", "flash"]
   }
   ```

2. **Background Compilation**: Compile shaders on worker threads
3. **Shader Prewarming**: Compile during loading screens
4. **Usage Analytics**: Track which shaders are actually used

## References

- Implementation: `src/systems/shaders/shader_system.{hpp,cpp}`
- Configuration: `assets/config.json`
- Initialization: `src/core/init.cpp` (`initSystems()`)
- Telemetry: See telemetry events section above

## Troubleshooting

### Issue: Shader not rendering

**Symptom**: Entity using shader appears broken/default

**Cause**: Lazy compilation failed

**Solution**:
1. Check logs for `shader_lazy_load_failed` errors
2. Verify shader paths in `assets/shaders/shaders.json`
3. Disable lazy loading to identify shader issues at startup

### Issue: Unexpected startup delay

**Symptom**: Game hangs briefly during gameplay

**Cause**: Many shaders compiled simultaneously on first use

**Solution**:
1. Profile which shaders are compiled when
2. Add critical shaders to preload list (future enhancement)
3. Spread shader usage over time (e.g., loading screens)

### Issue: Hot-reload not working

**Symptom**: F5 doesn't reload shader changes

**Cause**: Shader not compiled yet (metadata only)

**Solution**:
1. Use shader at least once to trigger compilation
2. Hot-reload will work after first use
3. Consider preloading shaders during development

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
