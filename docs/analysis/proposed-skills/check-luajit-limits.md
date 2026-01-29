---
name: check-luajit-limits
description: Use when Lua files fail to load or when working with large Lua files - checks for LuaJIT resource limits including the 200 local variable limit
---

# Check LuaJIT Limits Skill

## When to Use

Trigger this skill when:
- `too many local variables (limit is 200)` error
- Large Lua file suddenly fails to load
- Lua loading failed with no clear error
- Working with files over 5000 lines

## LuaJIT Resource Limits

| Limit | Value | Error Message |
|-------|-------|---------------|
| Local variables per function | 200 | `too many local variables (limit is 200)` |
| Upvalues per function | 60 | `too many upvalues` |
| Constant pool | 65536 | `constant table overflow` |
| Jump distance | 32767 | `control structure too long` |

## The 200 Local Variable Problem

**Root Cause:** Each file-scope `local` declaration counts toward the limit. Large files accumulate these.

```lua
-- gameplay.lua line 1-8665: accumulates locals
local sound1 = loadSound("a.wav")
local sound2 = loadSound("b.wav")
-- ... 198 more locals
local something = {}  -- Line 8666: BOOM! Limit exceeded
```

## Detection

### Quick Count

```bash
# Count file-scope local declarations
grep -c "^local " assets/scripts/gameplay.lua
# Warning if > 150
```

### Detailed Analysis

```bash
# Find all local declarations with line numbers
grep -n "^local " assets/scripts/gameplay.lua | head -50
```

## Solutions

### Solution 1: Group Related Locals into Tables

```lua
-- BEFORE: 10 locals
local footstep1 = loadSound("step1.wav")
local footstep2 = loadSound("step2.wav")
-- ... 8 more

-- AFTER: 1 local
local sounds = {
    footsteps = {
        loadSound("step1.wav"),
        loadSound("step2.wav"),
        -- ... 8 more
    }
}
```

### Solution 2: Use Modules

```lua
-- BEFORE: All in gameplay.lua
local playerConfig = { hp = 100, speed = 5 }
local enemyConfig = { hp = 50, damage = 10 }

-- AFTER: Split to modules
local player_config = require("config.player")  -- 1 local
local enemy_config = require("config.enemy")    -- 1 local
```

### Solution 3: Use _G for Truly Global Data

```lua
-- For data that must be globally accessible
_G.GAME_CONFIG = {
    player = { hp = 100 },
    enemy = { hp = 50 }
}

-- Access without local
print(GAME_CONFIG.player.hp)
```

## Refactoring Checklist

When consolidating locals:

1. [ ] Identify groups of related locals (sounds, configs, entities)
2. [ ] Create grouping table
3. [ ] Update all references (find-replace)
4. [ ] Test loading
5. [ ] Verify functionality unchanged

## Prevention

For large files (>3000 lines):
- Prefer tables over multiple locals for related data
- Extract modules for distinct functionality
- Review local count periodically

```lua
-- At file start, add comment tracking
-- LOCAL COUNT: ~150/200 (last checked: 2026-01-14)
```

## Verification

After refactoring:
1. File loads without error
2. All functionality works
3. Local count reduced to safe level (<150)

```bash
# Verify local count dropped
grep -c "^local " assets/scripts/gameplay.lua
# Should be significantly lower
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
