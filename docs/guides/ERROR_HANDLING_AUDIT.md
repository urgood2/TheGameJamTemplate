# Error Handling Audit Report

Generated: 2026-01-09
Branch: cpp-refactor (Phase 4)

## Summary

| Category | Count | Status |
|----------|-------|--------|
| Result<T,E> implementation | Complete | ✅ |
| tryWithLog usage | 8 sites | ✅ |
| safeLuaCall usage | 36 sites | ✅ |
| Unit tests | 17 | ✅ |
| Policy documentation | Complete | ✅ |

## Current Infrastructure

### Result<T,E> Template (`src/util/error_handling.hpp`)

Fully implemented with:
- `isOk()` / `isErr()` - status checks
- `value()` - access success value
- `error()` - access error string
- `valueOr(default)` - fallback on error
- `valueOrThrow()` - convert to exception

### Helper Functions

| Function | Purpose | Usage Count |
|----------|---------|-------------|
| `tryWithLog(fn, ctx)` | Wrap callable, catch exceptions, log with context | 8 |
| `loadWithRetry(loader, retries, delay)` | Retry failed loads with exponential backoff | 2 |
| `safeLuaCall(lua, fn, args...)` | Safe Lua function call by name | 15 |
| `safeLuaCall(fn, ctx, args...)` | Safe prebound Lua function call | 21 |

### Lua Binding Macros

```cpp
LUA_BINDING_TRY
    // code that might throw
LUA_BINDING_CATCH_RETURN(default_value)  // for non-void returns
LUA_BINDING_CATCH_VOID                    // for void returns
```

## Test Coverage

| Test Case | Status |
|-----------|--------|
| safeLuaCall by name succeeds | ✅ |
| safeLuaCall by name handles void return | ✅ |
| safeLuaCall by name fails for missing function | ✅ |
| safeLuaCall prebound function succeeds | ✅ |
| safeLuaCall prebound function catches exceptions | ✅ |
| safeLuaCall returns errors from Lua runtime | ✅ |
| safeLuaCall handles nil function gracefully | ✅ |
| tryWithLog returns value on success | ✅ |
| tryWithLog catches std::exception | ✅ |
| tryWithLog handles void return | ✅ |
| tryWithLog catches unknown exception | ✅ |
| loadWithRetry succeeds after retry | ✅ |
| loadWithRetry returns last error after exhaustion | ✅ |
| Result::valueOrThrow throws on error | ✅ |
| Result::valueOrThrow returns value on success | ✅ |
| Result::valueOr returns default on error | ✅ |
| Result::valueOr returns value on success | ✅ |

## Usage by System

### Asset Loading (`src/core/init.cpp`)
- Uses raw try-catch for filesystem operations
- Logs with `[init]` prefix
- Falls back gracefully on optional asset failures

### Sound System (`src/systems/sound/sound_system.cpp`)
- Uses try-catch for JSON parsing
- Logs with `[sound]` prefix
- Returns early on config errors

### Lua Callbacks
All wrapped with `safeLuaCall`:
- `main.init/update/draw`
- AI action start/finish/abort hooks
- Timer callbacks
- Controller nav focus/select hooks
- Camera.with callbacks
- Layer queue/execute init lambdas
- Physics collision callbacks
- Script coroutines
- Text wait coroutines

### Physics (`src/systems/physics/`)
- Uses assertions for invariant checks
- Logs warnings for recoverable errors
- No Result<T> usage (could benefit from migration)

### Render Stack (`src/systems/layer/render_stack_error.hpp`)
- Custom `RenderStackError` exception
- Provides depth, reason, context
- Tested in `test_render_stack_safety.cpp`

## Recommendations

### Low Risk, High Value
1. ✅ Add missing Result<T,E> tests (DONE - Phase 4.2)
2. ✅ Add tryWithLog void return test (DONE - Phase 4.2)
3. ✅ Add unknown exception test (DONE - Phase 4.2)

### Medium Risk, Medium Value
1. Convert `init.cpp` try-catch blocks to tryWithLog (optional)
   - Current code works; conversion adds consistency but risk
2. Add Result<T,E> to physics body creation
   - Would improve error propagation

### Not Recommended
1. Wholesale conversion of working try-catch to tryWithLog
   - High risk of introducing bugs
   - Low benefit for existing working code

## Error Prefixes

| System | Prefix |
|--------|--------|
| Asset loading | `[asset]` |
| Lua callbacks | `[lua]` |
| Physics | `[physics]` |
| Rendering | `[render]` |
| Engine context | `[ctx]` |
| Initialization | `[init]` |
| Sound | `[sound]` |
| Registry | `[registry]` |

## Verification Commands

```bash
# Count tryWithLog usage
grep -rn "tryWithLog" src/ --include="*.cpp" --include="*.hpp" | wc -l

# Count safeLuaCall usage
grep -rn "safeLuaCall" src/ --include="*.cpp" --include="*.hpp" | wc -l

# Run error handling tests
./build/tests/unit_tests --gtest_filter="ErrorHandling.*"

# Check for raw try-catch (may be intentional)
grep -rn "catch\s*(" src/core/init.cpp src/systems/sound/ --include="*.cpp"
```

## Conclusion

The error handling infrastructure is **mature and well-tested**. The Phase 4 audit found:
- No critical gaps in coverage
- Consistent use of safeLuaCall for Lua boundaries
- Well-documented error handling policy

Minor improvements made:
- Added 6 new test cases for Result<T,E> edge cases
- Updated audit documentation

No major refactoring recommended - existing patterns work well.
