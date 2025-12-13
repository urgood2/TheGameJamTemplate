# Lua Developer Experience Improvements

**Date:** 2025-12-13
**Branch:** feature/binding-quality
**Status:** Approved

## Problem Statement

Lua development has friction points:
1. **Incomplete autocomplete** - Many bindings show `...any` instead of typed parameters
2. **Missing inline docs** - No descriptions when hovering over functions in IDE
3. **Silent errors** - Bare `pcall` usage swallows errors without logging
4. **Lost error context** - Deferred execution (timers/queues) loses registration site in errors

## Solution Overview

### Track A: Binding Quality Enforcement

**Goal:** Every binding in `chugget_code_definitions.lua` has named typed parameters, return types, and descriptions.

**Approach:**
1. Create audit script to parse definitions and identify incomplete bindings
2. Update C++ binding code with full `@param` annotations and descriptions
3. Regenerate definitions by launching game
4. Verify 100% coverage

**Files affected:**
- `src/systems/scripting/*.cpp` - Binding registration code
- `assets/scripts/chugget_code_definitions.lua` - Generated output

### Track B: Error Traceability

**Goal:** All Lua errors are logged with source file and line number, including deferred execution.

**Approach:**
1. Create `core/safe_call.lua` utility that wraps pcall with logging
2. Wrap timer/queue registration to capture call site context
3. Find and replace bare `pcall` usage across codebase

**Files affected:**
- `assets/scripts/core/safe_call.lua` (new)
- `assets/scripts/core/timer.lua` - Wrap registration functions
- Various Lua files using bare `pcall`

## Implementation Details

### Audit Script

```lua
-- Parses chugget_code_definitions.lua and reports:
-- 1. Functions with ...any parameters
-- 2. Functions missing @return
-- 3. Functions missing descriptions
-- Output: List grouped by module
```

### safe_call.lua

```lua
local function safe_call(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        local info = debug.getinfo(2, "Sl")
        log_error(string.format("[%s:%d] %s", info.source, info.currentline, err))
    end
    return ok, err
end
```

### Timer Context Capture

```lua
local original_after = timer.after
timer.after = function(delay, callback)
    local info = debug.getinfo(2, "Sl")
    local context = string.format("%s:%d", info.source, info.currentline)
    return original_after(delay, function(...)
        local ok, err = pcall(callback, ...)
        if not ok then
            log_error(string.format("[registered at %s] %s", context, err))
        end
    end)
end
```

## Success Criteria

1. Audit script reports 0 incomplete bindings
2. All timer/queue callbacks log registration site on error
3. No bare `pcall` usage remains in codebase
4. Existing tests pass (no breaking changes)

## Performance Considerations

- `debug.getinfo` called once at registration, not per-frame
- pcall wrapper adds ~nanoseconds per callback execution
- Acceptable tradeoff: debugging time saved >> runtime cost
