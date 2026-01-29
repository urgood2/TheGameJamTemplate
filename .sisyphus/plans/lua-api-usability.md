# Lua API Usability Improvements

## TL;DR

> **Quick Summary**: Improve Lua scripting API usability by adding options-table wrappers for verbose functions, creating naming convention aliases, and updating documentation - all while maintaining full backward compatibility.
> 
> **Deliverables**:
> - Options-table wrappers for top 10 most-used verbose APIs (particles, sound, etc.)
> - Naming alias module for snake_case consistency
> - Updated API documentation with new patterns
> - Test suite verifying backward compatibility
> 
> **Estimated Effort**: Medium (5-8 tasks across ~15 files)
> **Parallel Execution**: YES - 3 waves
> **Critical Path**: Task 1 (audit) → Tasks 2-5 (wrappers) → Task 6 (aliases) → Tasks 7-8 (docs/tests)

---

## Context

### Original Request
Improve Lua API usability focusing on:
1. **Discoverability** - Hard to find the right function
2. **Verbosity** - Too much boilerplate for common operations
3. **Parameter clarity** - Unreliable autocomplete, unclear parameter order

### Interview Summary
**Key Discussions**:
- Scope: Comprehensive - all identified pain points
- Compatibility: Dual signatures (keep old APIs, add options-table alternatives)
- Documentation: Update alongside code changes
- Naming convention: Follow LuaRocks style guide (snake_case preferred)
- PhysicsBuilder already exists - skip raw `physics.AddCollider` wrappers

**Research Findings**:
- 51 functions with 5+ positional params found in Lua scripts
- `spawnCircularBurstParticles` (~50+ usages, 8 params) - HIGH priority
- `makeSwirlEmitter` (~10 usages, 6 params) - MEDIUM priority
- Good patterns exist: `timer.lua` dual-signature, `EntityBuilder`, `PhysicsBuilder`
- Naming: ~315 PascalCase, ~300 camelCase, ~500 snake_case (intentional dual-support in draw.lua)

### Metis Review
**Identified Gaps** (addressed):
- Scope creep risk: Limited to top 10 most-used APIs by grep count
- PhysicsBuilder overlap: Skip `physics.AddCollider` wrapper (PhysicsBuilder is preferred)
- Naming confusion: Add aliases only, document snake_case as preferred
- Test strategy: Build tests as necessary for each wrapper

---

## Work Objectives

### Core Objective
Reduce cognitive load when using Lua APIs by providing ergonomic options-table alternatives to verbose positional-parameter functions, while maintaining 100% backward compatibility.

### Concrete Deliverables
- `assets/scripts/core/particle_helpers.lua` - Options-table wrappers for particle functions
- `assets/scripts/core/sound_helpers.lua` - Options-table wrappers for sound functions  
- `assets/scripts/core/api_aliases.lua` - Snake_case aliases for common APIs
- `docs/api/lua_api_reference.md` - Updated with new patterns
- `assets/scripts/tests/test_api_wrappers.lua` - Backward compatibility test suite

### Definition of Done
- [ ] All existing code using positional signatures continues to work (zero regressions)
- [ ] New options-table signatures available for top 10 verbose APIs
- [ ] Snake_case aliases available for high-frequency camelCase/PascalCase functions
- [ ] Documentation updated with examples of both signatures
- [ ] Test file exercises both signatures for all wrapped functions

### Must Have
- Dual-signature support (positional + options table) for all wrappers
- Full backward compatibility - no breaking changes
- LuaLS type annotations (`---@param`, `---@return`) for all new functions
- Follow existing patterns (`timer.lua:88-134` for dual-signature, `draw.lua:102-131` for aliases)

### Must NOT Have (Guardrails)
- **NO C++ binding changes** - Lua wrappers only
- **NO removal of existing functions** - Only additions
- **NO behavior changes** - Wrappers must be 1:1 with originals
- **NO wrapping functions that have Builders** - EntityBuilder, PhysicsBuilder, ShaderBuilder already cover those
- **NO enforcing naming convention** - Only add aliases, never rename existing
- **NO scope expansion beyond top 10 APIs** without explicit approval
- **NO required parameters in new APIs** - All options must have sensible defaults

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Lua test files in `assets/scripts/tests/`)
- **User wants tests**: YES - build as necessary
- **Framework**: Custom Lua test runner (`assert` + `pcall` patterns)

### Test Approach

Each wrapper task includes test cases verifying:
1. **Positional signature** (existing code) still works
2. **Options-table signature** (new ergonomic API) works
3. **Default values** applied correctly when options omitted
4. **Return values** identical between signatures

**Test File Structure:**
```lua
-- assets/scripts/tests/test_api_wrappers.lua
local function test_particle_helpers()
    -- Test 1: Positional (backward compat)
    spawnCircularBurstParticles(100, 200, 10, 1.0, RED, BLUE, "linear", "world")
    
    -- Test 2: Options table (new API)
    particle.burst({
        x = 100, y = 200,
        count = 10,
        duration = 1.0,
        startColor = RED,
        endColor = BLUE
    })
    
    print("✓ particle_helpers tests passed")
end
```

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately):
├── Task 1: Usage frequency audit (grep counts for all 51 functions)
└── Task 2: Create particle_helpers.lua skeleton with type annotations

Wave 2 (After Wave 1):
├── Task 3: Implement particle wrapper functions
├── Task 4: Create sound_helpers.lua with wrappers
└── Task 5: Create combat/projectile helpers (if in top 10)

Wave 3 (After Wave 2):
├── Task 6: Create api_aliases.lua for naming consistency
├── Task 7: Update documentation
└── Task 8: Create comprehensive test suite

Critical Path: Task 1 → Task 3 → Task 7
Parallel Speedup: ~40% faster than sequential
```

### Dependency Matrix

| Task | Depends On | Blocks | Can Parallelize With |
|------|------------|--------|---------------------|
| 1 | None | 2, 3, 4, 5 | None (must be first) |
| 2 | 1 | 3 | None |
| 3 | 2 | 7, 8 | 4, 5 |
| 4 | 1 | 7, 8 | 3, 5 |
| 5 | 1 | 7, 8 | 3, 4 |
| 6 | 1 | 7 | 3, 4, 5 |
| 7 | 3, 4, 5, 6 | 8 | None |
| 8 | 3, 4, 5, 6 | None | 7 |

---

## TODOs

- [ ] 1. **Audit: Measure actual API usage frequency**

  **What to do**:
  - Grep all 51 identified verbose functions across `assets/scripts/`
  - Count usages for each, excluding test files and archived scripts
  - Rank by frequency to identify top 10 targets
  - Document which functions are already covered by Builders (exclude those)

  **Must NOT do**:
  - Don't count usages in `scripts_archived/`
  - Don't include functions already wrapped by EntityBuilder/PhysicsBuilder/ShaderBuilder

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Read-only grep/analysis task, no code changes
  - **Skills**: None needed
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not a git operation

  **Parallelization**:
  - **Can Run In Parallel**: NO (must complete first to prioritize other tasks)
  - **Parallel Group**: Wave 1 (solo)
  - **Blocks**: Tasks 2, 3, 4, 5, 6
  - **Blocked By**: None

  **References**:
  - `assets/scripts/util/util.lua:664-900` - Particle spawn functions to audit
  - `assets/scripts/core/entity_factory.lua:664` - `spawnCircularBurstParticles` definition
  - `assets/scripts/combat/projectile_system.lua:2139-2173` - Projectile spawn functions
  - `src/systems/sound/sound_system.cpp:166-425` - Sound API bindings

  **Acceptance Criteria**:
  ```bash
  # Produces ranked list of functions with usage counts
  # Example output format:
  # 1. spawnCircularBurstParticles: 52 usages
  # 2. makeSwirlEmitter: 11 usages
  # 3. playSoundEffect: 45 usages (but only 3 params - SKIP)
  # ...
  # TOP 10 TARGETS: [list]
  # EXCLUDED (Builder coverage): physics.AddCollider, etc.
  ```

  **Commit**: NO (analysis only, no files created)

---

- [ ] 2. **Create particle_helpers.lua module skeleton**

  **What to do**:
  - Create `assets/scripts/core/particle_helpers.lua`
  - Add module boilerplate following `timer.lua` singleton pattern
  - Add LuaLS type annotations for all options classes
  - Export module via `_G.__PARTICLE_HELPERS__` singleton guard

  **Must NOT do**:
  - Don't implement function bodies yet (just skeleton)
  - Don't modify any existing files

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Small file creation with clear template
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5, 6)
  - **Blocks**: Task 3
  - **Blocked By**: Task 1

  **References**:
  - `assets/scripts/core/timer.lua:1-50` - Singleton guard pattern
  - `assets/scripts/core/timer.lua:160-190` - Options class annotations pattern
  - `assets/scripts/core/entity_builder.lua:59-78` - Options class example

  **Acceptance Criteria**:
  ```lua
  -- File exists at assets/scripts/core/particle_helpers.lua
  -- Contains:
  -- 1. Singleton guard: if _G.__PARTICLE_HELPERS__ then return ... end
  -- 2. @class annotations for ParticleBurstOpts, ParticleSwirlOpts, etc.
  -- 3. Stub functions: particle.burst(opts_or_x, ...), particle.swirl(opts_or_x, ...)
  -- 4. Module export: _G.__PARTICLE_HELPERS__ = particle; return particle
  
  local particle = require("core.particle_helpers")
  assert(type(particle.burst) == "function", "burst function exists")
  ```

  **Commit**: YES
  - Message: `feat(lua): add particle_helpers module skeleton with type annotations`
  - Files: `assets/scripts/core/particle_helpers.lua`

---

- [ ] 3. **Implement particle wrapper functions**

  **What to do**:
  - Implement dual-signature wrappers for top particle functions from audit
  - Follow `timer.lua:88-134` pattern: check `type(arg1) == "table"` first
  - Each wrapper calls original function with extracted/defaulted params
  - Add comprehensive LuaLS annotations

  **Must NOT do**:
  - Don't modify original particle functions in `util.lua`
  - Don't change any existing behavior
  - Don't add required parameters (all optional with defaults)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Straightforward wrapper implementation following clear pattern
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 4, 5)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: Task 2

  **References**:
  - `assets/scripts/core/timer.lua:88-134` - Dual-signature detection pattern
  - `assets/scripts/core/entity_factory.lua:664-700` - `spawnCircularBurstParticles` signature
  - `assets/scripts/util/util.lua:885-920` - `makeSwirlEmitter` signature
  - `assets/scripts/core/particles.lua:89-150` - Color handling patterns

  **Acceptance Criteria**:
  ```lua
  local particle = require("core.particle_helpers")
  
  -- Test 1: Positional signature (backward compat)
  particle.burst(100, 200, 10, 1.0, Col(255,0,0), Col(0,0,255), "linear", "world")
  
  -- Test 2: Options table (new ergonomic API)
  particle.burst({
      x = 100, y = 200,
      count = 10,
      duration = 1.0,
      startColor = Col(255, 0, 0),
      endColor = Col(0, 0, 255),
      -- easing and space use defaults
  })
  
  -- Both produce identical visual results
  print("✓ particle.burst dual-signature works")
  ```

  **Commit**: YES
  - Message: `feat(lua): implement particle_helpers with dual-signature wrappers`
  - Files: `assets/scripts/core/particle_helpers.lua`

---

- [ ] 4. **Create sound_helpers.lua with wrappers**

  **What to do**:
  - Create `assets/scripts/core/sound_helpers.lua`
  - Add dual-signature wrappers for verbose sound functions (if in top 10)
  - Follow same patterns as particle_helpers.lua

  **Must NOT do**:
  - Don't modify C++ sound bindings
  - Don't wrap functions with <5 params (not verbose enough to matter)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Follows established pattern from particle_helpers
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 5)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: Task 1

  **References**:
  - `src/systems/sound/sound_system.cpp:166-200` - `playSoundEffect` binding
  - `assets/scripts/core/particle_helpers.lua` - Pattern to follow (from Task 3)
  - `assets/scripts/core/timer.lua:88-134` - Dual-signature pattern

  **Acceptance Criteria**:
  ```lua
  local sound = require("core.sound_helpers")
  
  -- Only if playSoundEffect or similar is in top 10 AND has 5+ params
  -- If not, this task produces empty module with comment explaining why
  
  -- Test: Options table for sound (if applicable)
  sound.play({
      name = "click",
      volume = 0.8,
      pitch = 1.2,
      category = "ui"
  })
  ```

  **Commit**: YES
  - Message: `feat(lua): add sound_helpers module with dual-signature wrappers`
  - Files: `assets/scripts/core/sound_helpers.lua`

---

- [ ] 5. **Create combat/projectile helpers (if in top 10)**

  **What to do**:
  - If audit shows combat/projectile functions in top 10, create wrappers
  - Create `assets/scripts/combat/projectile_helpers.lua` if needed
  - Follow dual-signature pattern

  **Must NOT do**:
  - Don't duplicate functionality already in `ProjectileSystem`
  - Don't wrap if usage count is low

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Conditional task, follows established pattern

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4)
  - **Blocks**: Tasks 7, 8
  - **Blocked By**: Task 1

  **References**:
  - `assets/scripts/combat/projectile_system.lua:2139-2173` - Projectile spawn functions
  - `assets/scripts/combat/projectile_examples.lua:386` - `spawnSpread` function
  - Task 1 output - usage frequency data

  **Acceptance Criteria**:
  ```lua
  -- If projectile functions are in top 10:
  local proj = require("combat.projectile_helpers")
  proj.spawn_basic({
      x = 100, y = 200,
      angle = 0,
      speed = 300,
      damage = 10,
      owner = player_entity
  })
  
  -- If NOT in top 10, create file with comment:
  -- "No projectile functions met the top-10 threshold. See audit results."
  ```

  **Commit**: YES (even if empty module)
  - Message: `feat(lua): add projectile_helpers module (conditional on audit)`
  - Files: `assets/scripts/combat/projectile_helpers.lua`

---

- [ ] 6. **Create api_aliases.lua for naming consistency**

  **What to do**:
  - Create `assets/scripts/core/api_aliases.lua`
  - Add snake_case aliases for frequently-used camelCase/PascalCase functions
  - Follow `draw.lua:102-131` pattern for alias tables
  - Document that snake_case is preferred for new code (per LuaRocks style guide)

  **Must NOT do**:
  - Don't rename existing functions
  - Don't remove any existing names
  - Don't enforce convention (just add options)

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Simple alias table creation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 3, 4, 5)
  - **Blocks**: Task 7
  - **Blocked By**: Task 1

  **References**:
  - `assets/scripts/core/draw.lua:102-131` - Existing alias pattern
  - `https://github.com/luarocks/lua-style-guide` - Naming convention reference
  - `assets/scripts/chugget_code_definitions.lua` - All available API names

  **Acceptance Criteria**:
  ```lua
  require("core.api_aliases")  -- Auto-installs aliases
  
  -- Both work:
  getEntityByAlias("player")  -- Original camelCase
  get_entity_by_alias("player")  -- New snake_case alias
  
  -- Verify alias table structure
  assert(_G.get_entity_by_alias == _G.getEntityByAlias)
  print("✓ api_aliases installed correctly")
  ```

  **Commit**: YES
  - Message: `feat(lua): add api_aliases module for snake_case naming consistency`
  - Files: `assets/scripts/core/api_aliases.lua`

---

- [ ] 7. **Update API documentation**

  **What to do**:
  - Update `docs/api/lua_api_reference.md` with new wrapper patterns
  - Add examples showing both positional and options-table signatures
  - Document that snake_case is preferred convention (link to LuaRocks guide)
  - Add migration guide section for moving to new patterns

  **Must NOT do**:
  - Don't remove documentation of old patterns (they still work)
  - Don't mark old patterns as "wrong" (just "verbose alternative")

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: Documentation-focused task
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: NO (needs all wrappers complete)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: Tasks 3, 4, 5, 6

  **References**:
  - `docs/api/lua_api_reference.md` - Existing API docs
  - `docs/api/timer_docs.md` - Timer API documentation pattern
  - `assets/scripts/core/particle_helpers.lua` - New API to document (from Task 3)
  - `https://github.com/luarocks/lua-style-guide` - Convention reference

  **Acceptance Criteria**:
  ```markdown
  # docs/api/lua_api_reference.md should contain:
  
  ## Ergonomic API Patterns
  
  ### Options Tables (Recommended)
  [Examples of new pattern]
  
  ### Naming Conventions
  - snake_case is preferred (per LuaRocks style guide)
  - camelCase/PascalCase still work via aliases
  
  ### Migration Guide
  [Before/after examples]
  ```

  **Commit**: YES
  - Message: `docs: update API reference with ergonomic wrapper patterns`
  - Files: `docs/api/lua_api_reference.md`

---

- [ ] 8. **Create comprehensive test suite**

  **What to do**:
  - Create `assets/scripts/tests/test_api_wrappers.lua`
  - Test both signatures for every wrapped function
  - Test that defaults are applied correctly
  - Test that aliases work correctly
  - Add to test runner if one exists

  **Must NOT do**:
  - Don't test C++ bindings directly (just Lua wrappers)
  - Don't test functions that weren't wrapped

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Test file creation following patterns
  - **Skills**: None needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 7)
  - **Parallel Group**: Wave 3
  - **Blocks**: None
  - **Blocked By**: Tasks 3, 4, 5, 6

  **References**:
  - `assets/scripts/tests/test_lua_api_improvements.lua` - Existing test patterns
  - `assets/scripts/tests/test_timer_scope.lua` - Timer test examples
  - All wrapper modules from Tasks 3, 4, 5, 6

  **Acceptance Criteria**:
  ```lua
  -- Run test file:
  -- dofile("assets/scripts/tests/test_api_wrappers.lua")
  
  -- Expected output:
  -- ✓ particle.burst positional signature works
  -- ✓ particle.burst options signature works
  -- ✓ particle.burst defaults applied correctly
  -- ✓ sound.play positional signature works (if applicable)
  -- ✓ api_aliases snake_case works
  -- ✓ api_aliases original names preserved
  -- 
  -- ALL TESTS PASSED: 12/12
  ```

  **Commit**: YES
  - Message: `test: add comprehensive test suite for API wrappers`
  - Files: `assets/scripts/tests/test_api_wrappers.lua`

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 2 | `feat(lua): add particle_helpers module skeleton` | particle_helpers.lua | Module loads without error |
| 3 | `feat(lua): implement particle_helpers wrappers` | particle_helpers.lua | Dual-signature test passes |
| 4 | `feat(lua): add sound_helpers module` | sound_helpers.lua | Module loads without error |
| 5 | `feat(lua): add projectile_helpers module` | projectile_helpers.lua | Module loads without error |
| 6 | `feat(lua): add api_aliases module` | api_aliases.lua | Aliases resolve correctly |
| 7 | `docs: update API reference` | lua_api_reference.md | Docs render correctly |
| 8 | `test: add API wrapper test suite` | test_api_wrappers.lua | All tests pass |

---

## Success Criteria

### Verification Commands
```bash
# Build and run game (no regressions)
just build-debug && ./build/raylib-cpp-cmake-template

# In Lua console, run test suite
dofile("assets/scripts/tests/test_api_wrappers.lua")
# Expected: ALL TESTS PASSED
```

### Final Checklist
- [ ] All existing game code works unchanged (backward compatibility)
- [ ] New options-table APIs available for top 10 verbose functions
- [ ] Snake_case aliases available for common functions
- [ ] Documentation updated with examples
- [ ] Test suite passes with both signature types
- [ ] No C++ changes made (Lua-only)
- [ ] All "Must NOT Have" guardrails respected
