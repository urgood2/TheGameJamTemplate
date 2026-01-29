# Emscripten Build Optimization Analysis

**Date**: 2025-12-18
**Context**: Performance Audit Task 6.1 - Review Emscripten Build Flags
**Purpose**: Analyze current Emscripten/WASM build configuration and identify optimization opportunities

---

## Executive Summary

The project uses **two separate Emscripten build configurations**:
1. **CMake target** (lines 1175-1210): Used when building directly with `emcmake cmake`
2. **Custom CMake helper target** (lines 968-970): Used by `configure_web_build` custom target
3. **Justfile recipe** (justfile:215): Used by `just build-web` command

**Current optimization level**: `-Oz` (size optimization)
**Key finding**: Build uses size optimization instead of performance optimization, which is appropriate for web distribution but may impact runtime performance.

---

## Current Configuration Analysis

### 1. Optimization Level

**Current Settings**:
- **Compiler flags** (CMakeLists.txt:1178): `-Os`
- **Linker flags** (CMakeLists.txt:1208 & justfile:215): `-Oz`
- **Build type**: `RelWithDebInfo` (justfile:221)

**Analysis**:
- `-Os`: Size optimization (compiler)
- `-Oz`: Aggressive size optimization (linker)
- Using different optimization levels for compile vs link stages

**Issue**: Inconsistency between `-Os` (compile) and `-Oz` (link)

**Best Practice**: Use consistent optimization level across compile and link stages:
- `-O2`: Balanced optimization (good default)
- `-O3`: Maximum speed optimization
- `-Oz`: Maximum size optimization (current choice)

---

### 2. Link-Time Optimization (LTO)

**Current Status**: ❌ **NOT ENABLED**

**Analysis**:
- LTO is NOT explicitly enabled via `-flto` flag
- This is a significant missed optimization opportunity
- LTO can provide 10-30% performance improvements for C++ codebases

**Recommendation**: **Enable LTO for release builds**
```cmake
-flto=full  # or -flto for automatic mode
```

**Tradeoff**: Longer link times (~2-5x slower) but better runtime performance

---

### 3. SIMD Support

**Current Status**: ❌ **NOT ENABLED**

**Analysis**:
- WebAssembly SIMD (`-msimd128`) is NOT enabled
- Browser support: Chrome 91+, Firefox 89+, Safari 16.4+ (widely supported as of 2024)
- Can provide 2-4x speedup for vectorizable code (physics, rendering, math)

**Recommendation**: **Enable SIMD for modern browsers**
```cmake
-msimd128 -msse -msse2
```

**Tradeoff**: Requires modern browsers (2021+), ~5-10KB larger binary

---

### 4. Memory Configuration

**Current Settings**:
```cmake
# CMakeLists.txt:232
-s TOTAL_STACK=128MB

# CMakeLists.txt:1208 & justfile:215
-sTOTAL_MEMORY=512MB
-sALLOW_MEMORY_GROWTH=1
```

**Analysis**:
- ✅ Stack size: 128MB (generous, appropriate for deep call stacks)
- ✅ Initial memory: 512MB (reasonable for game engine)
- ✅ Memory growth enabled (good for avoiding OOM)

**Best Practice**: Current settings are appropriate. No changes recommended.

---

### 5. Exception Handling

**Current Settings**:
```cmake
# justfile:215 (but NOT in CMakeLists.txt:969)
-sDISABLE_EXCEPTION_CATCHING=0  # Exceptions ENABLED
```

**Issue**: Inconsistency between builds
- Justfile build: Exceptions enabled
- CMake helper target: Uses `-sNO_DISABLE_EXCEPTION_CATCHING=0` (confusing double negative)

**Analysis**:
- Exceptions are required for nlohmann::json library
- ✅ Correctly enabled in justfile
- ⚠️ Confusing flag name in CMake target

**Recommendation**: Use consistent flag across all builds:
```cmake
-sDISABLE_EXCEPTION_CATCHING=0  # Clear: exceptions enabled
```

---

### 6. Closure Compiler

**Current Settings**:
```cmake
# CMakeLists.txt:969
--closure 1  # ENABLED in helper target

# justfile:211 (comment)
# NOTE: --closure 1 removed because miniaudio/telemetry JS isn't closure-compatible
```

**Issue**: Inconsistency between builds
- CMake helper target: Closure enabled
- Justfile build: Closure disabled

**Analysis**:
- Closure compiler can reduce JS glue code size by 30-50%
- But causes runtime errors with some libraries (miniaudio, telemetry)

**Recommendation**: **Remove Closure from CMake helper target** to match justfile
```cmake
# Remove --closure 1 from line 969
```

---

### 7. Debug Information

**Current Settings**:
```cmake
-gsource-map  # Source maps for debugging
-sASSERTIONS=1  # Runtime assertions
```

**Analysis**:
- ✅ Source maps: Excellent for debugging production issues
- ⚠️ Assertions: Good for debugging, but add ~10-20% runtime overhead

**Recommendation**: Make assertions conditional on build type:
```cmake
# For RelWithDebInfo: Keep -sASSERTIONS=1
# For Release: Use -sASSERTIONS=0
```

---

### 8. WebGL Configuration

**Current Settings**:
```cmake
-sUSE_GLFW=3
-sFULL_ES2=1  # Required for raylib client-side vertex arrays
-sFULL_ES3=1
-sMIN_WEBGL_VERSION=2
-sMAX_WEBGL_VERSION=2
```

**Analysis**:
- ✅ WebGL 2.0 target (good browser support)
- ✅ FULL_ES2/ES3 enabled (required for raylib)
- No issues identified

---

### 9. Advanced Optimizations (Not Currently Used)

**Available but not enabled**:

#### a. `-flto=full` (Link-Time Optimization)
- **Impact**: 10-30% performance improvement
- **Cost**: 2-5x longer link times
- **Recommendation**: **Enable for release builds**

#### b. `-msimd128` (WebAssembly SIMD)
- **Impact**: 2-4x speedup for vectorizable code
- **Cost**: ~5-10KB binary size, requires modern browsers
- **Recommendation**: **Enable with fallback check**

#### c. `-fno-rtti` (Disable RTTI)
- **Impact**: 5-10% binary size reduction
- **Cost**: No dynamic_cast, typeid
- **Recommendation**: Investigate if RTTI is needed

#### d. `-fno-exceptions` (Disable exceptions)
- **Impact**: 10-15% binary size reduction
- **Cost**: Cannot use try/catch
- **Recommendation**: **NOT recommended** (needed for nlohmann::json)

#### e. `-ffast-math` (Aggressive math optimizations)
- **Impact**: 5-10% performance improvement for math-heavy code
- **Cost**: Non-IEEE 754 compliant (can break physics)
- **Recommendation**: **Avoid** (physics engine requires strict IEEE 754)

#### f. `-fvisibility=hidden` (Symbol visibility)
- **Impact**: Faster dynamic linking, smaller binary
- **Cost**: Must explicitly export needed symbols
- **Recommendation**: Low priority (minimal impact on WASM)

#### g. `--closure-args="--compilation_level ADVANCED_OPTIMIZATIONS"`
- **Impact**: Maximum JS glue code reduction
- **Cost**: Breaks most third-party JS code
- **Recommendation**: **Avoid** (incompatible with miniaudio/telemetry)

---

## Recommended Optimization Levels

### Option 1: Balanced (Speed + Size) - **RECOMMENDED**

**Use case**: Best default for most users

```cmake
# Compile flags
-O3  # Maximum speed optimization

# Link flags
-O3
-flto=full  # Link-time optimization
-sASSERTIONS=0  # Disable assertions for release
-gsource-map  # Keep source maps for debugging
```

**Expected impact**:
- +15-25% runtime performance vs current `-Oz`
- +10-20% binary size vs current `-Oz`
- +2-5x link time vs current

**Tradeoff**: Slightly larger WASM file, significantly faster runtime

---

### Option 2: Maximum Speed - **HIGH PERFORMANCE**

**Use case**: Prioritize performance over download size

```cmake
# Compile flags
-O3
-msimd128 -msse -msse2  # Enable SIMD

# Link flags
-O3
-flto=full
-msimd128
-sASSERTIONS=0
-gsource-map
```

**Expected impact**:
- +30-50% runtime performance vs current `-Oz`
- +20-30% binary size vs current `-Oz`
- Requires modern browsers (2021+)

**Tradeoff**: Larger download, much faster runtime

---

### Option 3: Minimum Size (Current) - **DOWNLOAD SPEED**

**Use case**: Minimize download time for slow connections

```cmake
# Compile flags
-Oz  # Current setting

# Link flags
-Oz
-flto=full  # Add LTO even for size builds
-sASSERTIONS=0
-gsource-map
```

**Expected impact**:
- +5-10% runtime performance vs current (from LTO)
- -5-10% binary size vs current (from LTO)
- Similar or smaller download size

**Tradeoff**: Slowest runtime, smallest download

---

## Build Configuration Consistency Issues

### Issue 1: Three Different Build Paths

**Problem**: Three separate Emscripten configurations with slightly different flags:

1. **Direct CMake build** (CMakeLists.txt:1175-1210)
   - Used when running `emcmake cmake` directly
   - Flags: `-Os`, `-sTOTAL_MEMORY=512MB`, `--closure 1` **missing**

2. **CMake helper target** (CMakeLists.txt:968-970)
   - Used by `configure_web_build` custom target
   - Flags: `-Oz`, `-sALLOW_MEMORY_GROWTH=1`, `--closure 1`

3. **Justfile recipe** (justfile:215)
   - Used by `just build-web` (most common)
   - Flags: `-Oz`, `-sALLOW_MEMORY_GROWTH=1`, **no closure**, more exports

**Recommendation**: **Unify all three configurations** to use the same flags

---

### Issue 2: Inconsistent Memory Settings

**Problem**:
- Direct CMake: `-sTOTAL_MEMORY=512MB` (fixed size)
- Helper target + Justfile: `-sALLOW_MEMORY_GROWTH=1` (dynamic growth)

**Recommendation**: Use `-sALLOW_MEMORY_GROWTH=1` consistently (current justfile approach is correct)

---

### Issue 3: Missing Exports in CMake Builds

**Problem**:
- Justfile includes: `-sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,...` (needed for audio/telemetry)
- CMake builds: **Missing these exports** (will cause runtime errors)

**Recommendation**: Add exports to CMake builds

---

## Recommended Changes

### Priority 1: Fix Consistency Issues (Required)

**File**: `CMakeLists.txt`

**Changes**:

```cmake
# Line 969: Update helper target flags to match justfile
set(_emscripten_link_flags "-sUSE_GLFW=3 -sFULL_ES2=1 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -gsource-map -sASSERTIONS=1 -sDISABLE_EXCEPTION_CATCHING=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,stringToUTF8OnStack,UTF8ToString,stringToUTF8,lengthBytesUTF8")

# Line 1208: Update direct build flags to match justfile
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -sUSE_GLFW=3 -sFULL_ES2=1 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sASSERTIONS=1 -sWASM=1 -Oz -Wall -sALLOW_MEMORY_GROWTH=1 -sFORCE_FILESYSTEM=1 -sDISABLE_EXCEPTION_CATCHING=0 -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,stringToUTF8OnStack,UTF8ToString,stringToUTF8,lengthBytesUTF8 --preload-file assets/${EXCLUDE_FLAGS} --shell-file ${CMAKE_SOURCE_DIR}/src/minshell.html")

# Line 1178: Match link optimization level
SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Oz")  # Changed from -Os
```

**Impact**: Eliminates runtime errors from missing exports, ensures consistent behavior

---

### Priority 2: Enable LTO (Recommended)

**File**: `CMakeLists.txt` and `justfile`

**Changes**:

```cmake
# CMakeLists.txt:969 - Add to _emscripten_link_flags
-flto=full

# CMakeLists.txt:1208 - Add to CMAKE_EXE_LINKER_FLAGS
-flto=full

# justfile:215 - Add to LINK_FLAGS
-flto=full
```

**Impact**: +5-15% performance, +10-30% link time

---

### Priority 3: Conditional Assertions (Recommended)

**File**: `CMakeLists.txt` and `justfile`

**Changes**:

```cmake
# For Release builds: -sASSERTIONS=0
# For RelWithDebInfo: -sASSERTIONS=1 (current)
# For Debug: -sASSERTIONS=2 (additional checks)
```

**Impact**: +10-20% runtime performance for Release builds

---

### Priority 4: Enable SIMD (Optional, High Impact)

**File**: `CMakeLists.txt` and `justfile`

**Changes**:

```cmake
# Add to compile flags
-msimd128 -msse -msse2

# Add to link flags
-msimd128
```

**Impact**: +20-40% performance for physics/math code, requires modern browsers

**Caveat**: Test browser compatibility with target audience

---

## Testing Recommendations

### 1. Performance Benchmarking

**Baseline**: Current `-Oz` build
**Test configurations**:
1. `-O3` (no LTO)
2. `-O3 -flto=full`
3. `-O3 -flto=full -msimd128`

**Metrics to measure**:
- WASM file size
- Load time (gzipped)
- Frame time (60 FPS target)
- Physics step time
- Script execution time

**Tools**:
- Chrome DevTools Performance tab
- WebAssembly.instantiateStreaming() timing
- Tracy profiler (native builds for comparison)

---

### 2. Compatibility Testing

**Browsers to test**:
- Chrome 91+ (SIMD support)
- Firefox 89+ (SIMD support)
- Safari 16.4+ (SIMD support)
- Mobile browsers (iOS Safari, Chrome Android)

**Test scenarios**:
- Initial load on slow connection (3G simulation)
- Long gameplay session (memory leaks)
- Hot code paths (physics, rendering)

---

## Summary of Recommendations

### Immediate Actions (Required)

1. ✅ **Fix consistency issues** (Priority 1)
   - Unify flags across all three build paths
   - Add missing exports to CMake builds
   - Remove `--closure 1` from helper target

### Performance Improvements (Recommended)

2. ✅ **Enable LTO** (Priority 2)
   - Add `-flto=full` to all release builds
   - Expected: +5-15% performance, minimal size impact

3. ✅ **Make assertions conditional** (Priority 3)
   - `-sASSERTIONS=0` for Release
   - `-sASSERTIONS=1` for RelWithDebInfo (current)
   - Expected: +10-20% performance for Release

### Advanced Optimizations (Optional)

4. ⚠️ **Consider SIMD** (Priority 4)
   - Add `-msimd128` if targeting modern browsers
   - Expected: +20-40% performance for vectorizable code
   - Requires browser compatibility testing

5. ⚠️ **Investigate RTTI usage**
   - If not needed, add `-fno-rtti` for size reduction
   - Requires code audit

### Not Recommended

- ❌ `-ffast-math`: Breaks physics accuracy
- ❌ `--closure ADVANCED`: Incompatible with third-party JS
- ❌ `-fno-exceptions`: Required by nlohmann::json

---

## Benchmarking Plan

### Phase 1: Baseline Measurement

1. Build current configuration
2. Measure WASM size (raw + gzipped)
3. Measure load time (cold + warm cache)
4. Profile frame time (min/avg/max/p99)
5. Profile physics step time

### Phase 2: LTO Testing

1. Apply Priority 2 changes (LTO)
2. Repeat all Phase 1 measurements
3. Compare results

### Phase 3: Optimization Level Testing

1. Test `-O2` vs `-O3` vs `-Oz`
2. Measure performance vs size tradeoff
3. Determine best default

### Phase 4: SIMD Testing (if applicable)

1. Apply SIMD flags
2. Test browser compatibility
3. Measure performance gains
4. Decide on default or opt-in basis

---

## File Modification Summary

### Files to modify:

1. **CMakeLists.txt** (3 locations)
   - Line 969: Update `_emscripten_link_flags`
   - Line 1178: Update compiler flags
   - Line 1208: Update direct build linker flags

2. **justfile** (1 location)
   - Line 215: Add LTO flag to `LINK_FLAGS`

3. **Documentation** (recommended)
   - Add build configuration notes to README
   - Document browser compatibility requirements

---

## Conclusion

**Current state**: Build uses aggressive size optimization (`-Oz`) with some inconsistencies between build paths.

**Main issues**:
1. Three different build configurations with different flags
2. Missing runtime exports in CMake builds
3. No Link-Time Optimization enabled

**Recommended path forward**:
1. **Fix consistency issues** (immediate, required)
2. **Enable LTO** (quick win, +5-15% performance)
3. **Benchmark and decide** on `-O2` vs `-O3` vs `-Oz`
4. **Consider SIMD** if targeting modern browsers

**Expected outcome**:
- Consistent, predictable builds across all methods
- +5-30% performance improvement (depending on optimization choices)
- Slightly larger WASM file (acceptable for performance gains)
- Better developer experience (single source of truth for flags)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
