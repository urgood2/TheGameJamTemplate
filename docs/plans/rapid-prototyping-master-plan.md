# Rapid Prototyping Master Plan

**Date:** 2026-02-04
**Purpose:** Establish a repeatable workflow for rapid game prototyping using cass memory, project-specific plans, and constrained asset sets.

---

## Executive Summary

This document defines a structured approach to rapid prototyping that combines:
1. **Cass Memory** for procedural knowledge and pattern retrieval (used extensively)
2. **Automated Testing Harness** for verification-driven development
3. **Design Principles** derived from a327ex's Anchor philosophy
4. **Constrained Asset Pipeline** using dungeon_mode sprites exclusively
5. **Project Plan Templates** for consistent session bootstrapping
6. **Dwarf Fortress-Style Animation** for minimal art overhead

**Critical Rule:** New patterns are ONLY added to cass memory after being VERIFIED through working code with FULLY TESTED, verifiable output (logs, screenshots, metrics).

---

## Part 1: Session Bootstrap Protocol

### Pre-Session Checklist

```bash
# 1. Query cass for relevant patterns
cm context "your prototype concept" | head -40

# 2. Check playbook for anti-patterns to avoid
cm context "common mistakes prototype" | head -20

# 3. Verify asset availability
ls assets/images/dungeon_tiles/dungeon_mode/ | wc -l  # Should be 258

# 4. Read the prototype plan file (if exists)
cat docs/plans/prototypes/[prototype-name]-plan.md
```

### Session Start Message Template

When starting a new prototype session, provide Claude with this context:

```
Prototype: [NAME]
Goal: [One sentence description]
Constraints:
- Assets: dungeon_mode sprites only (258 tiles)
- Animation: DF-style (color, swap, blink, squeeze)
- Engine: TheGameJamTemplate (C++/Lua/Raylib)
- Desktop: Borderless window
Design Philosophy: Locality, No Bureaucracy, Intuition-First
```

### Copy-Paste Session Starter for Claude

Use this exact template at the start of any prototyping session:

```markdown
## Prototype Session: [NAME]

**Goal:** [One sentence]

**Phase:** [Bootstrap / Implementation / Polish]

**Current milestone:** [From plan, e.g., "Phase 2: Core Combat"]

### Context
- Plan file: `docs/plans/prototypes/[name]-plan.md`
- Code location: `assets/scripts/prototypes/[name]/`
- Constraints: dungeon_mode sprites, DF-style animation, borderless window

### Session objective
[Specific deliverable for this session, e.g., "Get single unit moving with pathfinding"]

### Cass query results
```
[Paste output of: cm context "[relevant query]" | head -30]
```

### Blockers/questions
- [Any unresolved design questions]
```

---

## Part 2: Cass Memory Integration

### Philosophy: Learn from Verified Patterns

Cass memory is the **primary knowledge source** for this workflow. It contains 5000+ rules learned from past coding sessions. Use it extensively:

- **Before starting ANY task** - query for relevant patterns
- **When debugging** - query for known failure modes
- **When implementing** - query for proven approaches
- **After completing** - contribute back verified patterns

### Extensive Usage Pattern

```bash
# Session start - always query context first
cm context "prototype dungeon generation" | head -40
cm context "lua entity behavior tree" | head -30
cm context "raylib borderless window" | head -20

# During implementation - query for specific patterns
cm context "timer animation tween lua"
cm context "collision detection chipmunk"

# When stuck - query for anti-patterns
cm context "common mistakes entity spawning"
cm context "debugging nil value lua"
```

### Effective Query Patterns

Different query styles yield different results:

| Query Type | Example | Best For |
|------------|---------|----------|
| **Concept + Context** | `cm context "timer animation lua"` | Finding specific techniques |
| **Anti-pattern** | `cm context "common mistakes entity"` | Avoiding known pitfalls |
| **System name** | `cm context "chipmunk collision"` | Understanding subsystems |
| **Error message** | `cm context "nil value table"` | Debugging known issues |
| **Workflow** | `cm context "prototype session start"` | Process guidance |

**Query tips:**
- Start broad, then narrow: `"entity"` → `"entity spawn"` → `"entity spawn combat"`
- Combine technical + conceptual: `"pathfinding efficient lua"`
- Include engine context: `"raylib texture load"` vs just `"texture load"`

### Contributing New Patterns (VERIFICATION REQUIRED)

**DO NOT add patterns to cass unless they meet ALL criteria:**

#### 1. Working Code
The pattern must come from code that actually runs without errors.

**BAD submission:**
```yaml
# Theoretical - NEVER DO THIS
rule: "Use coroutines for parallel entity updates"
context: "Lua performance"
# No verification - just speculation about what might work
```

**GOOD submission:**
```yaml
# Verified through actual implementation
rule: "Use timer.during() for continuous effects like shake, timer.after() for one-shots like flash"
context: "Lua animation, timer module"
verified_by: "damage_shake in combat_system.lua:142"
evidence: "Console output: [ANIM] shake completed frames=12 duration=0.2s"
```

#### 2. Fully Tested Output
Must have verifiable proof the code works:

| Verification Type | Example |
|-------------------|---------|
| **Console logs** | `[DEBUG] Entity spawned at (120, 80), size: 16x16` |
| **Screenshot** | Visual proof of rendering, UI layout, etc. |
| **Metrics** | Performance numbers, frame times, entity counts |
| **Test output** | `PASS: test_entity_spawn (0.003s)` |

#### 3. Documented Context
Include WHERE and WHEN the pattern applies:

```yaml
# Good pattern submission
rule: "Use timer.during() for continuous effects, timer.after() for one-shots"
context: "Lua animation system, timer module"
verified_by: "damage_shake animation in combat_system.lua"
evidence: "Console: [ANIM] shake completed, duration=0.2s"
```

### Verification Workflow

```
1. Implement feature
2. Run automated test harness (when available)
3. Capture verifiable output:
   - Logs with location/size/state info
   - Screenshots of visual features
   - Test pass/fail results
4. If verified, extract pattern for cass
5. Submit with evidence reference
```

### Verification Log Format

When verifying a pattern, log with this format:

```lua
-- In your Lua code
print(string.format("[VERIFY] %s | pos: (%.1f, %.1f) | size: %dx%d | state: %s",
    entity.name, entity.x, entity.y, entity.w, entity.h, entity.state))

-- Example output:
-- [VERIFY] hero_knight | pos: (120.0, 80.0) | size: 16x16 | state: idle
```

### Automated Test Harness Integration

*(Coming soon - will be merged to master)*

> **TODO:** Document actual commands when harness is merged. Update this section with:
> - Actual `just` command name
> - Real output format
> - Assertion syntax
> - Integration examples

The automated game testing harness will provide:
- Headless execution for CI/CD
- State capture at key frames
- Regression detection
- Performance benchmarking

**Planned usage pattern (placeholder - update when merged):**

```bash
# Run test harness against prototype
just test-harness prototypes/auto-achra

# Expected output:
# [HARNESS] Frame 0: 4 entities spawned
# [HARNESS] Frame 60: Combat initiated, 2 enemies in range
# [HARNESS] Frame 120: Player HP: 85/100
# [HARNESS] PASS: All assertions met (2.4s)
```

**Integration with cass:**

```bash
# After harness passes, patterns can be submitted
cm add --verified-by "test-harness:auto-achra:frame120" \
       --rule "Spawn enemies at room centers, not doorways"
```

### Pattern Submission: WHERE and HOW

**Playbook location (VPS):**
```bash
# Playbook lives on VPS at:
ubuntu@161.97.94.111:~/.cass-memory/playbook.yaml

# SSH access:
ssh -i ~/.ssh/acfs_ed25519 ubuntu@161.97.94.111
# Or use alias: vps
```

**Submission methods:**

1. **Direct VPS edit** (for immediate additions):
```bash
vps  # Connect to VPS
vim ~/.cass-memory/playbook.yaml
# Add rule at end of appropriate section
```

2. **Local sync workflow** (preferred):
```bash
# After verifying pattern locally, sync to VPS:
cm-sync  # Pulls latest from VPS to local

# Edit local playbook:
vim ~/.cass-memory/playbook.yaml

# Push back to VPS:
scp ~/.cass-memory/playbook.yaml ubuntu@161.97.94.111:~/.cass-memory/
```

**Rule format in playbook.yaml:**
```yaml
- rule: "Your verified pattern here"
  context: "system, module, or situation"
  tags: [prototype, animation, combat]  # optional
  verified: "file:line or test name"     # required
```

### When NOT to Use This Workflow

This rapid prototyping workflow is optimized for specific scenarios. Don't use it when:

| Situation | Why Not | Better Approach |
|-----------|---------|-----------------|
| **Production feature for main game** | Need full testing, code review, integration | Standard development workflow |
| **Engine-level changes (C++)** | Requires deeper testing, affects everything | Careful incremental development |
| **UI/UX polish pass** | Needs iteration with real users | Dedicated UI session with playtesting |
| **Performance optimization** | Needs profiling, not just "make it work" | Profile-first workflow |
| **Multiplayer/networking** | Complexity too high for rapid iteration | Architecture-first approach |
| **Asset-heavy work** | Dungeon_mode constraint doesn't fit | Different asset pipeline |
| **Learning new system** | Exploration, not shipping | Sandbox/spike approach |

**Signs you've outgrown this workflow:**
- Prototype is >2000 lines of Lua
- Multiple sessions without completing milestones
- Need features outside dungeon_mode sprites
- Debugging takes longer than implementing
- "I need to refactor before adding more"

**Graduation path:**
When a prototype proves valuable, transition to:
1. Proper plan document with architecture decisions
2. Move code to main codebase structure
3. Add tests for core systems
4. Full code review cycle

---

## Part 3: Design Principles (from a327ex)

### Core Values

#### 1. Locality Above All
Code should be understandable by looking at **one place**. This serves:
- Human cognition (limited working memory)
- LLM cognition (finite context window)
- Solo developer workflow (must understand own code months later)

**Evaluation question:** Does this keep related things together, or scatter them?

**Concrete violations to avoid:**

| Violation | Why It's Bad | Better Approach |
|-----------|--------------|-----------------|
| Entity behavior split across 5 system files | Must read all 5 to understand one entity | All behavior in entity's own file |
| Animation triggers scattered in combat, movement, UI systems | Can't find why entity flashes red | Animation decisions co-located with behavior |
| Config in JSON, behavior in Lua, rendering in C++ | Three places for one concept | Keep related logic together, even if mixed languages |
| Event bus connecting unrelated systems | Hidden coupling, hard to trace flow | Direct function calls where possible |

**Acceptable locality tradeoffs:**
- Shared utility functions (timer, math helpers) in common module
- Core engine bindings in C++ (performance-critical)
- Asset loading abstracted away (not gameplay logic)

#### 2. No Bureaucracy

**Avoid excessive ceremony:**
- Configuration objects, registration systems
- Message passing when direct mutation works
- Implicit event systems when explicit calls work
- Abstract factory patterns for simple object creation

**Acceptable pragmatic exceptions:**
- Basic imports/exports (we already do this in the codebase)
- Autonomous building when working in flywheel subagent swarm setup
- Shared utility modules for genuinely common operations

**Evaluation question:** Does this require ceremony to use, or does it just work?

#### 3. Intuition-First Design
- "Would this feel right to use?" matters as much as "Is this technically sound?"
- Aesthetic judgments are valid and often primary
- Exploring the possibility space matters more than committing early
- Conversation is the design tool — specs are artifacts, not contracts

### Feature Evaluation Checklist

When reviewing a feature or system, ask:
1. Does the engine already have this?
2. Does this fit the locality principle?
3. What's the bureaucracy cost?
4. Is this C-level (performance-critical) or Lua-level (game logic)?
5. Does the solo developer actually need this?
6. Would it feel right to use?

**Feature flags:**
- "Worth stealing" — fits philosophy, solves real problem
- "Interesting but doesn't fit" — clever but violates principles
- "Engine already has this" — covered by existing design
- "Worth discussing" — unclear fit, needs conversation

---

## Part 4: Working Style

### When to Ask vs Proceed

**Ask first:**
- Architecture decisions
- API design choices
- Design decisions (gameplay feel, mechanics, UI)
- Anything that could be done multiple valid ways
- When uncertain about intent or priorities

**Proceed, then explain:**
- Implementation details where the path is clear
- Performance optimization (get it working first)

### Pacing Rules
- Work incrementally — complete one piece, test, get feedback
- After completing a task, give the user a turn before starting the next
- Don't chain tasks or build large systems autonomously
- One method at a time — small incremental changes

### Code Changes
- Present code for review before writing — show snippet, ask "Does this look right?"
- Never run the executable — user will run and test themselves
- Build after changes, but don't execute

---

## Part 5: Asset Pipeline

### Visual Sprite Reference

**Quick preview command:**
```bash
# Open sprite folder in Finder (macOS)
open assets/images/dungeon_tiles/dungeon_mode/

# Or list with preview names
ls assets/images/dungeon_tiles/dungeon_mode/*.png | head -20
```

**Sprite sheet viewer:**
If you have a sprite sheet viewer tool, the full set is at:
`assets/images/dungeon_tiles/dungeon_mode/`

**See also:** [Full sprite index](#appendix-sprite-index-dungeon_mode) at end of document.

### Available Sprite Sets

#### dungeon_mode (258 sprites)
Primary prototyping tileset with semantic naming.

**Characters (dm_144-159):**
| ID | Name | Use |
|----|------|-----|
| dm_144 | hero_knight | Player/melee unit |
| dm_145 | hero_mage | Caster unit |
| dm_146 | hero_rogue | Fast/stealth unit |
| dm_147 | hero_archer | Ranged unit |
| dm_148-155 | skeleton, zombie, ghost, slime, rat, bat, spider, snake | Basic enemies |
| dm_156-159 | goblin, orc, troll, dragon | Advanced enemies |

**Equipment (dm_160-191):**
| Range | Category |
|-------|----------|
| dm_160-167 | Weapons (sword, dagger, axe, mace, staff, bow, crossbow) |
| dm_168-173 | Armor (shields, helmet, armor, boots, gloves) |
| dm_174-175 | Accessories (ring, amulet) |
| dm_176-184 | Consumables (potions, scrolls, books, wands, orbs) |
| dm_185-191 | Valuables (gems, keys, coins) |

**Terrain (dm_192-231):**
| Range | Category |
|-------|----------|
| dm_192-195 | Floors (stone, wood, dirt, grass) |
| dm_196-199 | Walls (stone, cave, mossy, cracked) |
| dm_200-203 | Hazards (water, deep water, lava, pit) |
| dm_204-223 | Props (trees, rocks, torches, furniture, graves) |
| dm_224-231 | Effects (explosion, smoke, sparkle, blood, web, traps) |
| dm_232-239 | Status icons (poison, fire, ice, shock, HP/mana bars) |

**UI (dm_240-255):**
| Range | Category |
|-------|----------|
| dm_240-250 | Box drawing (corners, edges, T-junctions, cross) |
| dm_251-254 | Shading (light, medium, heavy, full block) |

#### dungeon_437 (256 sprites)
CP437 ASCII tileset for true roguelike aesthetic.

**Quick reference:**
- 0-31: Symbols and arrows
- 32-127: Standard ASCII
- 128-255: Extended characters (box drawing, shading, special)

### Asset Retrieval Pattern

```lua
-- Load by semantic name
local hero = load_sprite("dungeon_mode/dm_144_hero_knight.png")

-- Load by ID for procedural generation
local function get_dungeon_sprite(id)
    return string.format("dungeon_mode/dm_%03d_*.png", id)
end

-- Eagle MCP tag search (when needed)
-- eagle.search({ tags = {"character", "warrior"} })
```

---

## Part 6: Animation System (Dwarf Fortress Style)

### Core Techniques

Since we're using minimal single-frame sprites, animation happens through:

#### 1. Color Tinting

**Foreground only:**
```lua
-- Flash white on hit (fg only)
entity.fg_tint = {1, 1, 1, 1}
timer.after(0.1, function() entity.fg_tint = nil end)
```

**Background only:**
```lua
-- Highlight selection (bg only)
entity.bg_tint = {0.3, 0.3, 0.6, 0.5}
```

**Both together:**
```lua
-- Poison effect: green fg + dark green bg
entity.fg_tint = {0.2, 0.9, 0.2, 1}
entity.bg_tint = {0, 0.3, 0, 0.5}
timer.after(0.3, function()
    entity.fg_tint = nil
    entity.bg_tint = nil
end)
```

**Pulsing effect:**
```lua
-- Poison green pulse
entity.fg_tint = lerp_color(normal, {0.2, 0.8, 0.2}, sin(time * 4))
```

#### 2. Sprite Swapping
```lua
-- Walking: swap between 2-3 variant sprites
local walk_frames = {"dm_144_hero_knight", "dm_144_hero_knight_alt"}
entity.sprite = walk_frames[math.floor(time * 4) % #walk_frames + 1]

-- Damaged: swap to damaged variant
entity.sprite = entity.health < 0.3 and "damaged" or "normal"
```

#### 3. Blinking

**Entire sprite blink (visibility toggle):**
```lua
-- Invincibility blink (fast)
entity.visible = math.floor(time * 10) % 2 == 0

-- Attention blink (slow)
entity.visible = math.floor(time * 2) % 2 == 0 or not entity.needs_attention

-- Timed blink sequence
timer.during(0.5, function()
    entity.visible = not entity.visible
end, function()
    entity.visible = true  -- ensure visible at end
end)
```

**Alpha blink (softer effect):**
```lua
-- Fade blink instead of hard on/off
entity.alpha = 0.3 + 0.7 * math.abs(math.sin(time * 6))
```

#### 4. Transform Effects

**Squeeze/Stretch:**
```lua
-- Jump squash
entity.scale_x = 1.2
entity.scale_y = 0.8
timer.tween(0.15, entity, {scale_x = 1, scale_y = 1}, 'out-elastic')

-- Hit squeeze
entity.scale_x = 0.7
entity.scale_y = 1.3
timer.tween(0.1, entity, {scale_x = 1, scale_y = 1}, 'out-quad')
```

**Shake:**
```lua
-- Damage shake
entity.shake_offset = {x = 0, y = 0}
timer.during(0.2, function()
    entity.shake_offset.x = random(-3, 3)
    entity.shake_offset.y = random(-3, 3)
end, function()
    entity.shake_offset = {x = 0, y = 0}
end)
```

**Rotation:**
```lua
-- Death spin
timer.tween(0.5, entity, {rotation = math.pi * 2}, 'out-quad')
```

**DynamicMotion (engine feature):**
```lua
-- DynamicMotion provides pre-built motion patterns
-- Access via entity's motion component

-- Hover/float effect
entity:add_motion("hover", {amplitude = 4, frequency = 2})

-- Wobble on damage
entity:add_motion("wobble", {intensity = 0.3, decay = 0.1})

-- Orbit around point
entity:add_motion("orbit", {center = {x, y}, radius = 20, speed = 1})

-- Combine multiple motions
entity:add_motion("hover", {...})
entity:add_motion("wobble", {...})  -- both apply simultaneously
```

#### 5. Position Offsets
```lua
-- Hop on selection
timer.tween(0.1, entity, {offset_y = -8}, 'out-quad', function()
    timer.tween(0.1, entity, {offset_y = 0}, 'in-quad')
end)

-- Breathing bob
entity.offset_y = sin(time * 2) * 2
```

### Animation Timing Guidelines

| Effect Type | Duration | Notes |
|-------------|----------|-------|
| **Hit flash** | 0.05-0.1s | Very quick, single frame feel |
| **Damage shake** | 0.15-0.25s | Longer = more dramatic |
| **Selection hop** | 0.1s up + 0.1s down | Snappy feedback |
| **Death fade** | 0.3-0.5s | Allow player to see result |
| **Spawn pop** | 0.15-0.2s overshoot + 0.1s settle | Elastic feel |
| **Blink cycle** | 0.05-0.1s per state | Fast for urgency, slow for attention |
| **Breathing bob** | 2-3s cycle | Subtle, ambient |
| **Walk cycle** | 0.1-0.15s per frame | Depends on movement speed |

**Easing recommendations:**
- `out-quad` — most attacks, impacts (fast start, slow end)
- `in-quad` — anticipation, wind-up (slow start, fast end)
- `out-elastic` — bouncy, juicy feedback
- `linear` — mechanical motion, constant speed
- `in-out-quad` — smooth transitions

### Animation Presets

```lua
AnimPresets = {
    hit_flash = function(e)
        e.tint = WHITE
        timer.after(0.1, function() e.tint = nil end)
    end,

    damage_shake = function(e)
        -- 0.2s shake with decreasing intensity
    end,

    select_hop = function(e)
        -- quick up-down hop
    end,

    death_spin_fade = function(e)
        -- rotate + fade alpha + optional scale down
    end,

    spawn_pop = function(e)
        e.scale_x, e.scale_y = 0, 0
        timer.tween(0.2, e, {scale_x = 1.2, scale_y = 1.2}, 'out-quad', function()
            timer.tween(0.1, e, {scale_x = 1, scale_y = 1}, 'in-quad')
        end)
    end,
}
```

---

## Part 7: Prototype Template

### File Structure

```
docs/plans/prototypes/
├── [name]-plan.md           # Design document
├── [name]-session-log.md    # Session notes (optional)
└── [name]-decisions.md      # Key decisions made (optional)

assets/scripts/prototypes/
└── [name]/
    ├── main.lua             # Entry point
    ├── config.lua           # Constants, tuning values
    ├── entities.lua         # Entity definitions
    └── systems.lua          # Game systems
```

### New Prototype vs Extend Existing

**Start NEW prototype when:**
- Core mechanic is fundamentally different
- Different genre or gameplay feel
- Exploring unrelated design space
- Previous prototype is "done" (shipped or abandoned)
- Want clean slate without baggage

**EXTEND existing prototype when:**
- Adding feature to working prototype
- Iterating on proven mechanic
- Testing variation of existing system
- Building on established entity/system definitions
- Reusing significant code (>30% overlap)

**Decision checklist:**
```
□ Does this share >50% entities with existing prototype?
  → YES: Extend existing
□ Does this need different core loop?
  → YES: New prototype
□ Am I avoiding extending because the code is messy?
  → Clean up first, then extend
□ Would this benefit from existing prototype's infrastructure?
  → YES: Extend (don't rebuild dungeon gen, pathfinding, etc.)
□ Is the existing prototype abandoned/stale (>2 weeks untouched)?
  → Consider new prototype with lessons learned
```

### Plan Document Template

```markdown
# [Prototype Name] Design Plan

**Date:** YYYY-MM-DD
**Concept:** [One paragraph description]
**Inspirations:** [Game references]

---

## Core Loop

[Describe the 30-second core gameplay loop]

## Entities

| Entity | Sprite | Behavior |
|--------|--------|----------|
| ... | dm_XXX | ... |

## Systems

### [System Name]
- Purpose:
- Key mechanics:
- Interactions with other systems:

## Milestone Targets

1. [ ] Basic rendering + movement
2. [ ] Core mechanic functional
3. [ ] Win/lose conditions
4. [ ] Polish pass (animations, feedback)

## Questions / Decisions Needed

- [ ] Question 1?
- [ ] Question 2?

## Lessons Learned

<!-- Fill this out as you work on the prototype -->

### What Worked Well
- [Pattern or approach that was effective]
- [Tool or technique that saved time]

### What Didn't Work
- [Approach that was abandoned and why]
- [Assumption that proved wrong]

### Patterns to Extract for Cass
<!-- Only add after VERIFICATION -->
- [ ] Pattern: [description]
  - Verified by: [test/log/screenshot]
  - Context: [when to apply]

### Would Do Differently Next Time
- [Retrospective insight]
```

---

## Part 8: Example Prototype - Auto-Achra Colony

### Concept

An **automated roguelike colony sim** inspired by Path of Achra meets Dwarf Fortress:
- Units explore dungeon automatically using AI behaviors
- Player can optionally select upgrades OR let AI pick
- Colony grows, acquires resources, unlocks new unit types
- Desktop borderless app for ambient play

### Design Principles Applied

**Locality:** All unit behavior defined in single entity file, not scattered across systems
**No Bureaucracy:** Direct state mutation, no message bus for simple interactions
**Intuition-First:** If idle-watching a unit feels boring, add more visual feedback

### Entity Mapping

| Entity | Sprite | Role |
|--------|--------|------|
| Knight | dm_144 | Melee tank, high HP |
| Mage | dm_145 | Ranged caster, AoE |
| Rogue | dm_146 | Fast scout, finds secrets |
| Archer | dm_147 | Ranged DPS |
| Skeleton | dm_148 | Basic melee enemy |
| Slime | dm_151 | Splits on death |
| Dragon | dm_159 | Boss enemy |
| Chest | dm_213 (crate) | Loot container |
| Floor | dm_192 | Dungeon floor |
| Wall | dm_196 | Dungeon wall |

### Core Systems

#### 1. Auto-Behavior System (GOAP-Based)

Uses the engine's existing GOAP (Goal-Oriented Action Planning) system for intelligent, composable AI behaviors.

**GOAP Basics:**
```lua
-- Define goals (desired world states)
Goals = {
    survive = {health = ">20%"},
    explore = {tiles_explored = "increasing"},
    combat = {enemies_nearby = 0},
    loot = {nearby_items = 0},
}

-- Define actions (how to achieve goals)
Actions = {
    attack = {
        preconditions = {enemy_in_range = true, has_weapon = true},
        effects = {enemies_nearby = -1},
        cost = 1,
    },
    heal = {
        preconditions = {has_potion = true, health = "<50%"},
        effects = {health = "+30%"},
        cost = 2,
    },
    move_to_enemy = {
        preconditions = {enemy_visible = true},
        effects = {enemy_in_range = true},
        cost = distance_to_enemy,
    },
    retreat = {
        preconditions = {health = "<20%"},
        effects = {distance_from_enemy = "far"},
        cost = 1,
    },
}

-- GOAP planner finds optimal action sequence
local plan = goap.plan(unit.world_state, unit.current_goal, Actions)
```

**Composing Complex Behaviors:**
```lua
-- Multi-step behaviors emerge from goal/action composition
-- Knight: high survive priority + melee actions = tank behavior
-- Mage: ranged attack actions + retreat actions = glass cannon
-- Rogue: low-cost move actions + backstab bonus = flanker

UnitProfiles = {
    knight = {
        goals = {survive = 10, combat = 8, protect_ally = 7},
        action_bonuses = {attack = -1, defend = -2},  -- cheaper
    },
    mage = {
        goals = {combat = 10, survive = 6},
        action_bonuses = {cast_spell = -2, retreat = -1},
    },
}
```

**ImGui Debugging (Critical for GOAP):**
```lua
-- Enable GOAP debug overlay
debug.goap_overlay = true

-- Shows for selected entity:
-- - Current goal and priority scores
-- - Available actions and their costs
-- - Planned action sequence
-- - World state (preconditions satisfied/unsatisfied)
-- - Why actions were rejected

-- ImGui window displays:
imgui.window("GOAP Debug - " .. entity.name, function()
    imgui.text("Current Goal: " .. entity.current_goal)
    imgui.separator()
    imgui.text("World State:")
    for k, v in pairs(entity.world_state) do
        imgui.text("  " .. k .. " = " .. tostring(v))
    end
    imgui.separator()
    imgui.text("Action Plan:")
    for i, action in ipairs(entity.action_plan) do
        imgui.text("  " .. i .. ". " .. action.name .. " (cost: " .. action.cost .. ")")
    end
end)
```

**Behavioral Landscape Visualization:**
```lua
-- See all possible behaviors at a glance
debug.show_behavior_landscape = true

-- Displays grid showing:
-- - All entities and their current goals
-- - Action availability matrix
-- - Inter-entity relationships (protect targets, threat assessment)
-- - Color-coded by behavior type (aggressive=red, defensive=blue, etc.)
```

#### 2. Upgrade System
```lua
-- Upgrades offered at intervals
-- Player can select OR enable auto-pick
UpgradeSystem = {
    offer_upgrade = function()
        local choices = generate_upgrades(3)
        if settings.auto_pick then
            apply_upgrade(ai_select_best(choices))
        else
            show_upgrade_ui(choices)
        end
    end
}
```

#### 3. Animation (DF-Style)
- **Idle:** Slow breathing bob (2px vertical)
- **Walking:** Sprite swap between 2 frames + position lerp
- **Attack:** Squeeze toward target + white flash
- **Damage:** Red tint + shake
- **Death:** Spin + fade

### Window Configuration

```lua
-- Borderless desktop app
config = {
    window = {
        borderless = true,
        resizable = true,
        transparent_bg = false,
        always_on_top = false,  -- optional for widget mode
    },
    render = {
        pixel_scale = 4,        -- 16x16 tiles at 64x64 display
    }
}
```

### Systems: Must-Have vs Nice-to-Have

**MUST-HAVE (Core Loop):**
| System | Why Essential |
|--------|---------------|
| Tile rendering | Can't see anything without it |
| Unit movement + pathfinding | Core of "auto" gameplay |
| GOAP AI with basic goals | Units must act autonomously |
| Simple combat (attack/damage/death) | Dungeon needs danger |
| Basic dungeon room | Somewhere to explore |
| HP display | Player needs feedback |

**NICE-TO-HAVE (Depth):**
| System | Adds What |
|--------|-----------|
| BSP dungeon generation | Variety, replayability |
| Multiple unit types | Strategic depth |
| Upgrade system | Progression feeling |
| Colony base view | Meta-game loop |
| Loot/inventory | Reward mechanism |
| Fog of war | Exploration tension |
| Boss encounters | Climax moments |

**CUT IF NEEDED (Polish):**
| System | Can Live Without |
|--------|------------------|
| Sound effects | Visual feedback sufficient |
| Save/load | Session-based OK for prototype |
| Borderless widget mode | Standard window fine |
| Auto-upgrade AI | Manual selection works |

### Milestones with Scope

| Phase | Milestone | Scope Estimate | Deliverable |
|-------|-----------|----------------|-------------|
| **1** | Dungeon rendering | Small | Single room with floor/wall tiles rendering correctly |
| **2** | Unit movement | Small | One knight moving via click or auto-wander |
| **3** | Pathfinding | Medium | A* or simple pathfinding around obstacles |
| **4** | GOAP AI setup | Medium | Basic explore/idle goals working with imgui debug |
| **5** | Combat basics | Medium | Attack action, damage numbers, death animation |
| **6** | Enemy spawning | Small | Skeletons spawn in room, have combat AI |
| **7** | Party system | Medium | 4 unit types with different GOAP profiles |
| **8** | Dungeon generation | Medium | BSP rooms + corridors |
| **9** | Upgrade system | Medium | 3-choice upgrade UI between runs |
| **10** | Colony base | Large | Separate view, resource tracking, unit management |
| **11** | Polish pass | Variable | Animations, juice, borderless window |

**Recommended stopping points:**
- **Playable demo:** After Phase 6 (one unit type vs enemies)
- **Feature complete:** After Phase 9 (full loop without colony)
- **Full vision:** After Phase 11

---

## Part 9: Quick Reference

### Cass Memory Commands

```bash
cm context "query"           # Get relevant rules
cm context "query" | head -N # Limit results
cm-sync                      # Sync from VPS
```

### Build Commands

```bash
just build-debug             # Debug build
just build-debug-ninja       # Faster with Ninja
./build/raylib-cpp-cmake-template  # Run (user does this, not Claude)
```

### Lua Runtime Debug

```bash
(./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|Lua)"
```

### Common Lua Patterns

```lua
-- Safe entity access
if ensure_entity(eid) then ... end

-- Safe script access
local script = safe_script_get(eid)
local health = script_field(eid, "health", 100)

-- Timer patterns
timer.after(delay, callback)
timer.every(interval, callback)
timer.tween(duration, target, values, easing, callback)
timer.during(duration, update_callback, finish_callback)
```

### Common Debugging Patterns

**1. Entity not appearing:**
```lua
-- Check if entity exists
print("[DEBUG] Entity exists:", ensure_entity(eid))

-- Check position (is it off-screen?)
local pos = get_position(eid)
print("[DEBUG] Position:", pos.x, pos.y)

-- Check visibility/alpha
local sprite = get_sprite(eid)
print("[DEBUG] Visible:", sprite.visible, "Alpha:", sprite.alpha)

-- Check layer/z-order
print("[DEBUG] Layer:", get_layer(eid), "Z:", get_z(eid))
```

**2. GOAP AI not acting:**
```lua
-- Enable GOAP debug
debug.goap_overlay = true

-- Check world state
print("[DEBUG] World state:")
for k, v in pairs(entity.world_state) do
    print("  ", k, "=", v)
end

-- Check if any actions are valid
print("[DEBUG] Valid actions:")
for _, action in ipairs(Actions) do
    if goap.preconditions_met(entity.world_state, action) then
        print("  ", action.name, "cost:", action.cost)
    end
end

-- Check current goal
print("[DEBUG] Current goal:", entity.current_goal)
```

**3. Animation not playing:**
```lua
-- Verify timer is running
print("[DEBUG] Timer active:", timer.is_active())

-- Check tween target values
print("[DEBUG] Scale:", entity.scale_x, entity.scale_y)
print("[DEBUG] Offset:", entity.offset_x, entity.offset_y)
print("[DEBUG] Tint:", entity.tint)

-- Verify callback is being called
timer.after(0.1, function()
    print("[DEBUG] Timer callback fired!")
    -- your animation code
end)
```

**4. Collision not working:**
```lua
-- Check collision layers
print("[DEBUG] Collision mask:", entity.collision_mask)
print("[DEBUG] Collision layer:", entity.collision_layer)

-- Verify physics body exists
print("[DEBUG] Has physics:", entity.physics_body ~= nil)

-- Check body type
print("[DEBUG] Body type:", entity.body_type)  -- static, dynamic, kinematic
```

**5. Quick grep for errors:**
```bash
# Run and capture errors
(./build/raylib-cpp-cmake-template 2>&1 & sleep 5; kill $!) | grep -E "(error|Error|nil|VERIFY|DEBUG)"

# Count specific entity types
(./build/raylib-cpp-cmake-template 2>&1 & sleep 5; kill $!) | grep -c "Entity spawned"
```

---

## Appendix: Sprite Index (dungeon_mode)

<details>
<summary>Full sprite list (click to expand)</summary>

| ID | Name | Category |
|----|------|----------|
| 000 | blank | UI |
| 001-002 | face_happy, face_happy_filled | Symbols |
| 003-006 | heart, diamond, club, spade | Card suits |
| 007-010 | bullets, circles | Shapes |
| 011-012 | male_symbol, female_symbol | Symbols |
| 013-015 | music_note, music_notes, sun | Symbols |
| 016-031 | triangles, arrows | Arrows |
| 032-047 | space, punctuation | Text |
| 048-057 | digits 0-9 | Numbers |
| 058-064 | punctuation | Text |
| 065-090 | letters A-Z | Text |
| 091-096 | brackets, special | Text |
| 097-122 | letters a-z | Text |
| 123-143 | special characters | Text |
| 144-147 | hero_knight, hero_mage, hero_rogue, hero_archer | Heroes |
| 148-155 | skeleton, zombie, ghost, slime, rat, bat, spider, snake | Basic enemies |
| 156-159 | goblin, orc, troll, dragon | Advanced enemies |
| 160-167 | sword, sword_long, dagger, axe, mace, staff, bow, crossbow | Weapons |
| 168-173 | shields, helmet, armor, boots, gloves | Armor |
| 174-175 | ring, amulet | Accessories |
| 176-184 | potions, scrolls, books, wands, orbs | Magic items |
| 185-191 | gems, keys, coins | Valuables |
| 192-195 | floors (stone, wood, dirt, grass) | Terrain |
| 196-199 | walls (stone, cave, mossy, cracked) | Terrain |
| 200-203 | water, deep_water, lava, pit | Hazards |
| 204-223 | props (trees, rocks, furniture, etc.) | Environment |
| 224-231 | effects (explosion, smoke, etc.) | FX |
| 232-239 | status icons | UI |
| 240-254 | box drawing, shading | UI |
| 255 | blank_end | UI |

</details>

---

*Last updated: 2026-02-04 (v2 - implemented 14 improvements from review)*
