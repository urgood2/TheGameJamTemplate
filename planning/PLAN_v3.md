# Auto-Achra Master Implementation Plan

> **Doc version:** 2.0
> **Last updated:** 2026-02-04 (Asia/Seoul)
> **Scope:** `assets/scripts/prototypes/auto_achra/` prototype implementation
> **Key revisions (v1→v2):** hump.signal events, Forma-powered generation, data-driven autotiling, overland features (Phase 4), craftable multi-step behaviors, tile-aligned ASCII UI, tick-hash + run-hash determinism checks, stronger test strategy.

This document is a **standalone** implementation plan for Auto-Achra. It assumes an existing codebase with:
- a Lua runtime + entity scripting (`safe_script_get(eid)` style access),
- existing implementations for **JPS** pathfinding and **LOS** (line of sight),
  - *Note:* JPS needs rigorous testing; there may be caveats like not being able to reuse a JPS map data structure more than once per path request.
- existing **HitFX/particles/tween/timer** utilities,
- **hump.signal** available in the codebase,
- the project's existing **test harness** (to be integrated and expanded in the "Test Harness Refinement" phase at the end of this plan).

---

## 0) Operating Rules (Multi-Agent + Repo Policy)

### 0.1 Coordination + Ownership
- Use **Agent Mail** for coordination: announce interface changes, integration checkpoints, and file ownership.
- Reserve "chokepoint" files to avoid merge churn:
  - `assets/scripts/prototypes/auto_achra/main.lua`
  - `assets/scripts/prototypes/auto_achra/config.lua`
  - `assets/scripts/prototypes/auto_achra/systems/expedition_manager.lua`

### 0.2 Quality Gates (Required)
These gates exist specifically to keep the prototype **robust, deterministic, and mergeable** under multi-agent work.

- Run **UBS** before final QA and before each phase-integration merge (not required for every commit).
- Run **contract tests** before merge (see §4.7 + `debug/contract_tests.lua`).
- Keep every phase **demoable (recordable)** via:
  - deterministic seed,
  - a repeatable scenario (`debug/scenario_runner.lua`),
  - a deterministic **tick-hash** and **run-hash** (see §2.4).

### 0.3 Determinism Rules (Hard Rules)
To avoid "it only diverges sometimes" bugs:

- **All randomness** must go through `runtime/rng.lua` (ban `math.random` in this prototype).
- **Forma integration must use our RNG**, not its own implicit randomness:
  - Forma calls must be passed a deterministic random function derived from `runtime/rng.lua`.
- Avoid nondeterministic iteration:
  - do **not** use `pairs()` for gameplay-critical tables unless keys are sorted;
  - prefer arrays + `ipairs()` or explicit sorted key lists.
- Do not read wall-clock time during simulation; only use the fixed-step `sim_dt`.
- Entity iteration in systems must be stable:
  - iterate by deterministic ID order or cached arrays rebuilt deterministically.
- Avoid float drift in authoritative state:
  - authoritative positions are **tile coords + sub-tile fixed-point** (or quantized) in simulation;
  - rendering may interpolate floats.

### 0.4 "Signal Discipline" (hump.signal + Deterministic Events)
We will use `hump.signal` as the **fanout mechanism**, but we still need deterministic ordering.

Rules:
- Simulation does **not** emit directly to arbitrary listeners.
- Simulation **pushes structured events** into `runtime/events.lua` (append-only).
- At the end of a simulation tick, `runtime/events.lua` publishes events through a single `Signal` instance in a deterministic order:
  - **within-tick order is the queue order**
  - **event handler registration order is controlled** (registered once during init).

This gives you the convenience of `Signal:register(...)` while keeping determinism.

---

## 1) Target Experience & Milestones

### 1.1 North-Star Loop (Full Game)
1. Start in **Colony/Overland** → view resources/upgrades → start expedition
   - *(Future consideration: buildings that function like Ball x Pit — incremental-style production of resources)*
2. **Expedition** runs autonomously: explore → fight → gather → (recruit) → return
3. **Results** summary → transfer loot → back to Colony
4. Buy upgrades/unlocks → repeat with improved party

### 1.2 "Feels Good" Targets (non-negotiable goals)
- **Deterministic runs**: same seed + same version ⇒ same results (within a tolerance for purely visual FX).
- **4x speed stability**: no spiral-of-death on frame hitch; simulation steps are capped.
- **Readable autonomy**: players can understand *why* the party is doing something (HUD + goal/action text).
- **Craftable behaviors**: adding a new complex behavior should be "compose actions + tune a goal," not rewrite the AI.
- **Tile-first aesthetic**: gameplay UI looks tile-aligned ASCII (20×20 multiples), while using the native UI system underneath.
- **Visual style**: CRT shader (already in codebase) + palette quantize using **Resurrect 64 palette** (already in game). Tile scaling level should be configurable.
- **Fast iteration**: one command or menu option to start a known scenario.

### 1.3 Milestones
- **M0 (Phase 0)**: Prototype shell + deterministic time + deterministic RNG + Forma adapter + hump.signal-backed event pipeline + scenario runner + tick-hash.
- **M1 (Phase 1)**: Test room loop works (combat ↔ gather) with deterministic event stream + HUD.
- **M2 (Phase 2)**: Forma-driven multi-room dungeon + fog + exploration + minimap baseline.
- **M3 (Phase 3)**: Party coordination + formation + recruitment POI.
- **M4 (Phase 4)**: Overland features (trees, lakes, mineable walls/minerals) + interactions + dynamic path invalidation.
- **M5 (Phase 5)**: Inventory/capacity + return when full + manual extract + results + run history + achievements/milestones.
- **M6 (Phase 6)**: Colony progression + save/load + repeatable runs + ASCII gameplay UI.
- **M7 (Phase 7)**: Content + polish (enemy variety, tutorial, accessibility, perf pass).

---

## 2) Architecture (Deterministic Core + Clear Boundaries)

### 2.1 Prototype State Machine
States: `COLONY` ↔ `EXPEDITION` → `RESULTS` → `COLONY`
Entry point: `assets/scripts/prototypes/auto_achra/main.lua`

### 2.2 Deterministic Simulation + Speed Control
- Deterministic seed per run (displayed on-screen).
- Fixed-step simulation (clamp real `dt`, cap max sim steps/frame) to keep 4x stable.
- Time scale options: `1x / 2x / 4x`.
- Deterministic unit update scheduling:
  - AI "thinking" is throttled but deterministic (e.g., staggered by stable unit index).

### 2.3 Simulation vs Presentation (No Cross-Contamination)
- Simulation is authoritative; rendering/UI are observers.
- Systems mutate simulation state; UI **never** mutates simulation directly.
- Visual FX/audio/UI feedback are driven by the **deterministic event queue**.
- Optional: render interpolation is purely cosmetic.

### 2.4 Determinism Checking: Tick-Hash + Run-Hash
We will use **two hashes**:

1) **Tick-hash** (debug/dev): computed every N ticks (e.g., 30) from a stable subset of state:
   - stable unit ordering,
   - positions (quantized),
   - HP values,
   - inventory totals,
   - fog reveal counts (not animation),
   - RNG cursor state (if exposed).

2) **Run-hash** (results): computed when leaving EXPEDITION:
   - seed,
   - world layout hash (dungeon/overland),
   - total kills, gathered totals, recruits, casualties,
   - elapsed sim ticks,
   - extracted reason.

These are your determinism regression checks.

### 2.5 RNG & Forma Integration
- `runtime/rng.lua` is the **only** randomness source.
- Provide a Forma-compatible random function:
  - Forma expects a `random()`-like function returning floats in [0,1) (and/or `math.random` style args depending on usage).
  - Implement `rng:as_random01()` and `rng:as_math_random()` adapters so Forma can be fed deterministic randomness without using global `math.random`.
- **Single RNG stream** per expedition (and optional substreams by domain).
  - Use it for: dungeon gen, spawns, combat rolls, loot rolls, AI tie-breaks.
  - Substreams: `rng:fork("dungeon")`, `rng:fork("combat")` (still deterministic)

### 2.6 Command Buffer + Lifecycle Discipline
To avoid "entity removed mid-iteration" and other nondeterministic behavior:
- Systems **enqueue commands** (damage, heal, despawn, spawn, inventory add, tile change).
- `systems/lifecycle_system.lua` applies commands at a single deterministic point in the tick order.
- Events are emitted deterministically when commands apply (not "whenever").

### 2.7 System Tick Order (Deterministic)
Order below is the default for EXPEDITION state:

1. `ExpeditionManager.update(sim_dt)` (orchestrates run state + end conditions)
2. `NavigationSystem.update(sim_dt)` (path requests, caches, budgets)
3. `MovementSystem.update(sim_dt)` (path follow + collision/avoidance + position)
4. `VisibilitySystem.update(sim_dt)` (fog reveal based on updated positions)
5. `Coordinator.update(sim_dt)` (Phase 3+; party assignments/reservations)
6. `AI.tick_units(sim_dt)` (GOAP-lite goal selection + action execution; throttled)
7. `CombatSystem.update(sim_dt)` (produces damage commands + combat events)
8. `GatheringSystem.update(sim_dt)` (produces harvest + inventory commands + events)
9. `InventorySystem.update(sim_dt)` (bookkeeping, fullness, valuation)
10. `RecruitmentSystem.update(sim_dt)` (Phase 3+; produces recruit commands + events)
11. `TerrainSystem.update(sim_dt)` (Phase 4+; applies tile changes + invalidation)
12. `AchievementsSystem.update(sim_dt)` (Phase 5+; evaluates milestones, emits events)
13. `LifecycleSystem.update(sim_dt)` (apply queued commands; finalize despawns/spawns)
14. UI update + draw (reads state; consumes event queue for FX/audio/notifications)

### 2.8 World Representation: Layered Tiles + Dynamic Terrain
World is a tile grid with layers:
- `terrain`: floor/wall/water/etc.
- `feature`: trees, rocks, doors, props
- `resource`: ore nodes, mineral veins, mineable walls
  - *Minerals* should look "embedded in walls" with distinct sprites when visible via LOS (hidden otherwise)
  - *Mineable walls* should have scattered "overlay debris" characters (selection from tileset) in a faded color for variety and to indicate they may contain resources
- `fog`: visibility states

Dynamic terrain changes must be supported (mining walls, building decorations), which implies:
- pathfinding cache invalidation when walkability changes,
- LOS/fog updates when opacity changes.

### 2.9 AI Model: Craftable Multi-Step Behaviors (GOAP-lite → GOAP-compose)
We keep GOAP-lite *feel*, but the architecture must support multi-step emergent behaviors.

Key upgrades:
- **Action graph composition**:
  - actions still have `preconditions/effects/cost`, but can optionally declare a `subplan()` that expands into a deterministic list of actions (macro-actions).
- **Planner modes**:
  - Phase 1–2: greedy "best valid action"
  - Phase 3+: short-horizon planning (2–5 steps) using deterministic beam search or A* on action graph (bounded).
- **Blackboard + reservations**:
  - party-level memory and target reservation to prevent dogpiles and enable coordinated multi-step plans.
- **Robustness controls**:
  - replanning cooldown,
  - unreachable target blacklist (with decay),
  - stale target validation,
  - goal hysteresis.

### 2.10 Data-Driven Definitions (Single Source of Truth)
To prevent duplicated stats across factories/systems/UI:
- Canonical registries live in `data/`:
  - `data/resources.lua`, `data/units.lua`, `data/enemies.lua`, `data/upgrades.lua`, `data/achievements.lua`
- Factories read from `data/*` and attach runtime fields (HP current, AI state).
- UI reads from `data/*` for names/icons/values.
- **Use the existing localization system** for all end-user displayed text (already in the codebase).
- Validation on boot (Phase 0/1): missing fields cause a loud error in dev builds.

### 2.11 Events, Telemetry, and Profiling
- `runtime/events.lua`: deterministic event queue.
- **hump.signal** (`Signal`) is used as:
  - a publish/subscribe surface for UI/FX/audio,
  - but publishing happens only after simulation tick in deterministic order.
- `runtime/profiler.lua`: lightweight per-system timing (dev toggle).
- Debug HUD shows: goal/action/target per unit, path failures, per-system ms, tick-hash/run-hash.

---

## 3) UI Architecture (Tile-Aligned ASCII Visual UI on Native UI System)

### 3.1 High-level UI Decision
- Keep **ImGui** for debug/developer panels only.
- Gameplay UI is built using the codebase's **native UI system** (C++ `UIElementTemplateNode` builder, command buffer rendering).
- Visual aesthetic is **ASCII tile UI**:
  - everything aligned to 20×20 pixel multiples,
  - borders/icons from CP437/dungeon atlas sprites,
  - layout and spacing are constrained to feel "grid-built."

### 3.2 UI Panels (Gameplay)
- **Resource panel**: top-left; icons + counts (+ per-tick deltas if useful).
- **Upgrade panel**: right sidebar; scrollable list; each entry shows:
  - icon + name + short effect summary,
  - cost + buy button,
  - tooltip with details/prereqs.
- **Party/expedition status** (EXPEDITION): bottom-left or bottom bar:
  - party HP, current goal/action text, inventory fullness.
- **Minimap** (EXPEDITION): bottom-right or integrated into sidebar.

### 3.3 Achievement/Milestone System (UI + Data)
- 4 categories:
  - resource thresholds,
  - upgrade milestones,
  - creature population,
  - time-based.
- Achievements fire deterministic events and appear as **toast notifications**.

### 3.4 Border Style System (Configurable)
- Single-line box style by default (┌─┐│└┘) using sprites.
- Border style is configurable and swappable via `config.lua`:
  - sprite IDs for corners/edges/fill,
  - padding rules.

### 3.5 Window/Viewport Rules
- **Viewport should be configurable** (default: 30×20 tile playfield visible).
- Architecture: transparent window with multiple "viewports" rendered as opaque images:
  - Game world viewport (main playfield)
  - UI viewport(s) (can be adjacent or separate from game world)
- The transparent window is resizable; this allows UI to appear adjacent or separate from the main game world viewport as needed (useful when game world viewport is constrained).
- Tile scaling level should be configurable.
- All gameplay UI positions/sizes are integer tile units (converted to pixels at render time).

---

## 4) Canonical File Structure (Single Source of Truth)

```
assets/scripts/prototypes/auto_achra/
├── main.lua
├── config.lua
├── test_harness.lua
├── runtime/
│   ├── time.lua                 # fixed-step + time scale helpers
│   ├── rng.lua                  # deterministic RNG + Forma adapters
│   ├── events.lua               # deterministic event queue + hump.signal bridge
│   ├── signal_bus.lua           # centralized hump.signal registrations
│   └── profiler.lua             # dev profiling overlay helpers
├── vendor/
│   ├── forma/                   # vendored Forma (Lua) or wrapper import
│   └── hump/                    # (optional) if hump not already in core
├── data/
│   ├── resources.lua            # ore/gem/wood/food + value + sprites
│   ├── units.lua                # knight/mage/rogue/miner base stats + unlock keys
│   ├── enemies.lua              # rat/skeleton/goblin/... base stats + behavior tags
│   ├── upgrades.lua             # canonical upgrade registry + costs + prereqs
│   └── achievements.lua         # milestone registry + thresholds
├── world/
│   ├── tiles.lua
│   ├── autotile/
│   │   ├── rulesets.lua         # registry of rulesets + sprite mapping
│   │   └── blob47.lua           # 47-tile blob rules
│   ├── dungeon_gen.lua          # Forma-driven generation wrapper
│   ├── overland_gen.lua         # Forma-driven overland features
│   ├── fog.lua
│   ├── los.lua                  # wrapper for existing LOS code
│   ├── pathfinding.lua
│   ├── camera.lua
│   ├── spawn.lua                # enemy/resource/recruit placement rules
│   └── terrain_edits.lua        # deterministic tile edits + invalidation
├── entities/
│   ├── entity_helpers.lua       # safe_script_get + schema validation helpers
│   ├── unit_factory.lua
│   ├── enemy_factory.lua
│   ├── resource_factory.lua
│   ├── units/                   # optional per-unit overrides / visuals
│   ├── enemies/                 # optional per-enemy overrides / visuals
│   └── npcs/                    # recruitable prisoner/lost ally
├── ai/
│   ├── world_state.lua          # sensed facts + target selection
│   ├── blackboard.lua           # party shared memory + reservations
│   ├── goap_actions.lua
│   ├── behaviors.lua            # goals + priority scoring
│   ├── planner.lua              # supports greedy + bounded multi-step
│   ├── ticker.lua               # AI tick scheduling + cooldowns
│   ├── coordinator.lua          # party role/target assignment (Phase 3+)
│   └── formation.lua            # follow offsets + cohesion helpers
├── systems/
│   ├── expedition_manager.lua
│   ├── navigation_system.lua    # path requests + caching + budgets
│   ├── movement_system.lua      # path follow + separation + movement intents
│   ├── visibility_system.lua    # fog reveal scheduling
│   ├── lifecycle_system.lua     # apply queued commands; spawn/despawn discipline
│   ├── combat_system.lua
│   ├── gathering_system.lua
│   ├── inventory_system.lua
│   ├── recruitment_system.lua
│   ├── achievements_system.lua  # evaluates milestones, emits events
│   └── terrain_system.lua       # mining/chopping/building tile changes
├── colony/
│   ├── colony_state.lua
│   ├── meta_progression.lua     # upgrade effects + unlock pipeline
│   ├── colony_screen.lua
│   └── save_system.lua
├── ui/
│   ├── ascii_ui/
│   │   ├── ui_constants.lua     # tile size, sprite ids, colors
│   │   ├── border_styles.lua
│   │   └── layout_helpers.lua   # tile-aligned layout primitives
│   ├── expedition_hud.lua
│   ├── results_screen.lua
│   ├── resource_panel.lua
│   ├── upgrade_panel.lua
│   ├── party_status.lua
│   ├── minimap.lua
│   └── notifications.lua        # toast feed driven by events
└── debug/
    ├── scenario_runner.lua      # deterministic demo scenarios by seed
    ├── replay.lua               # optional: record/replay inputs + events
    ├── contract_tests.lua       # schema + API contract checks (run in UBS)
    └── golden_runs.lua          # seeds + expected tick/run hashes
```

---

## 5) Shared Contracts (Agents Must Not Diverge)

### 5.1 Contract Versioning
- Define `CONTRACT_VERSION = 2` in `config.lua` (bumped due to new UI/events/world changes).
- Any change to shared contracts **must** bump the version and be announced via Agent Mail.

### 5.2 Entity Script Schema (Minimum Set)
All units/enemies/resources must support `safe_script_get(eid)` returning:

Common:
- `uid` (stable numeric id used for deterministic ordering)
- `type`, `faction`
- `tile = {x,y}` (authoritative)
- `subtile = {fx, fy}` (optional fixed-point within tile)
- `sprite_id`
- `tags` (array or set)

Damageable:
- `health`, `max_health`

Units:
- `unit_type`, `damage`, `speed`, `sight_radius`, `role`
- `ai = { goal_id?, action_id?, target_uid?, cooldowns = {...} }`

Enemies:
- `enemy_type`, `damage`, `speed`, `sight_radius`, `behavior_tags`

Resources/Features:
- `resource_type?`, `amount?`, `depleted?`
- `feature_type?` (`tree`, `lake`, `mineable_wall`, etc.)
- `blocks_movement?`, `blocks_los?`

Recruitables:
- `is_recruitable`, `recruit_unit_type`, `recruit_message`, `recruited = false`

**Validation rule:** `entities/entity_helpers.lua` provides `validate_entity_schema(eid)` and the contract test must run it on representative spawns.

### 5.3 World API
`world` objects must provide:
- `get_tile(x,y) -> tile`
- `set_tile(x,y, tile_def)` **(queued via TerrainSystem in simulation)**
- `is_walkable(x,y)`, `is_opaque(x,y)`
- `world_to_tile(pos)`, `tile_to_world(x,y)`
- `find_path(start_tile, end_tile) -> path|nil, reason`
- `find_nearest_unexplored(from_tile, fog) -> tile|nil`
- `has_line_of_sight(from_tile, to_tile) -> bool`
- `get_visible_tiles(from_tile, sight_radius) -> tile_list`
- `invalidate_nav_area(aabb_or_tiles)` (for dynamic edits; deterministic batching)

Optional (Phase 1/2 performance):
- `nav_request_path(request) -> request_id` (queued; resolved by NavigationSystem deterministically)

### 5.4 AI Action API
Each action in `ai/goap_actions.lua`:
- `id`, `preconditions`, `effects`, `cost(unit, ws) -> number`
- `start(unit, ctx)`
- `step(unit, ctx, sim_dt) -> done|false, failed|false`
- `abort(unit, ctx)`
- `timeout_s`
- optional `expand(unit, ctx) -> {action_id,...}` for macro-actions

Rules:
- Actions should not despawn/spawn entities directly; enqueue commands/events instead.
- Actions that move should call `MovementSystem.request_move(...)` (no bespoke movement).

### 5.5 Deterministic Events
All simulation events are pushed to `runtime/events.lua` with stable payload fields:
- include `tick` and relevant `uid`s (not raw entity pointers).

Action events:
- `action_started(action_id, unit_uid, target_uid?)`
- `action_completed(action_id, unit_uid, target_uid?)`
- `action_failed(action_id, unit_uid, reason)`

Combat/gathering events:
- `damage_applied(attacker_uid, target_uid, amount)`
- `entity_died(entity_uid, killer_uid?)`
- `resource_harvested(unit_uid, node_uid, resource_type, amount)`

Terrain events:
- `tile_changed(x, y, from_id, to_id, reason)`

Achievement events:
- `achievement_unlocked(achievement_id)`

Run events:
- `unit_recruited(unit_uid, recruit_type)`
- `inventory_full(capacity, used)`
- `expedition_extracted(reason)`  # e.g., full / manual / tpk

### 5.6 hump.signal Bridge Contract
- `runtime/signal_bus.lua` defines which high-level signals exist and which payload tables they receive.
- The bridge publishes **only after** simulation tick completes:
  - `Signal:emit("auto_achra:event", event)` (single channel) OR
  - typed channels: `Signal:emit("auto_achra:damage", payload)` etc.
- UI registers listeners once at init; no dynamic register/unregister during sim.

### 5.7 Tests & Acceptance Proof
Every acceptance criterion in phases must have **at least one proof path**:
- **automated**: contract tests, golden runs, determinism hashes, unit tests for data registries
- **manual** (allowed only for visuals): recorded scenario checklists

A later "Test Harness Refinement" phase (end of plan) formalizes full integration with the codebase harness.

---

## 6) Phase Plan (Tasks, Dependencies, Acceptance)

## Phase 0 — Scaffolding & Deterministic Core (Goal: runnable shell + determinism backbone)

### 0.1 Prototype entry + state machine
- Files: `main.lua`, `systems/expedition_manager.lua` (stub), `colony/colony_screen.lua` (stub), `ui/results_screen.lua` (stub)
- Deliverable: prototype launches, switches states, cleans up state on transition
- Acceptance:
  - No errors launching prototype
  - State transitions: `COLONY → EXPEDITION → RESULTS → COLONY`

### 0.2 Config + tuning constants
- File: `config.lua`
- Include:
  - time scales, fixed-step settings, AI tick interval
  - map size defaults (include 30×20 viewport), sprite IDs, capacities
  - `CONTRACT_VERSION = 2`
  - UI border style config
  - determinism flags (e.g., disable reveal animations at 4x)
- Acceptance:
  - No "magic numbers" outside `config.lua` for core tuning
  - Config supports overriding seed/map size for debugging

### 0.3 Deterministic time scaling
- Files: `runtime/time.lua`, `main.lua`
- Implement: fixed-step loop (clamp dt; cap sim steps/frame), `time_scale` multiplier
- Acceptance:
  - 4x speed does not spiral on frame hitch
  - Seed displayed on-screen in EXPEDITION

### 0.4 Deterministic RNG backbone + Forma adapters
- File: `runtime/rng.lua`
- Implement:
  - stable algorithm (PCG/XorShift; consistent across platforms)
  - helpers: `next_u32`, `range_int(a,b)`, `float01()`
  - substreams: `rng:fork("dungeon")`, `rng:fork("combat")`
  - Forma adapters: `as_random01()` and `as_math_random()`
- Acceptance:
  - UBS gate: no `math.random` usage in `auto_achra/`
  - Deterministic RNG cursor is stable across runs

### 0.5 Deterministic event queue + hump.signal bridge
- Files: `runtime/events.lua`, `runtime/signal_bus.lua`
- Implement:
  - deterministic queue (`push(event)`), drained after tick
  - publish via hump.signal in a deterministic order
- Acceptance:
  - Events can be emitted without nil crashes
  - Event ordering stable within a tick
  - UI can subscribe via `Signal` without affecting simulation determinism

### 0.6 Scenario runner + contract tests + tick-hash scaffolding
- Files: `debug/scenario_runner.lua`, `debug/contract_tests.lua`, `debug/golden_runs.lua`
- Deliverables:
  - Deterministic scenario entry: `Phase1_TestRoom(seed)`
  - Contract tests validate entity schemas + world API availability
  - Tick-hash computed every N ticks (printed to log)
- Acceptance:
  - Running same scenario twice prints same tick-hash sequence (for fixed build)
  - Contract tests fail loudly on drift

### 0.7 Forma vendoring + minimal wrapper
- Files: `vendor/forma/*` (or dependency import), `world/dungeon_gen.lua` wrapper stub
- Acceptance:
  - Forma can be required in prototype without modifying global RNG
  - Wrapper can generate a trivial deterministic pattern (smoke test)

---

## Phase 1 — Core Loop in a Test Room (Goal: fight → gather loop with clean systems)

### 1.1 Test harness scene
- File: `test_harness.lua` and/or `debug/scenario_runner.lua`
- Spawns: 1 unit, 1 enemy, 1 ore node; supports reset without restarting
- Acceptance:
  - `require(...test_harness).init()` spawns scene reliably
  - Camera centers on unit; entities visible with dungeon_mode sprites
  - Reset returns to identical initial state for same seed
  - Deterministic event stream on each run

### 1.2 Minimal tiles + navigation wrapper
- Files: `world/tiles.lua`, `world/pathfinding.lua`, `systems/navigation_system.lua`
- Implement:
  - walkable grid + JPS wrapper (use existing codebase implementation)
  - request queue + path cache (budgeted)
- Acceptance:
  - Unit can path to enemy and ore in test room
  - Unreachable path returns `nil, reason`
  - Path requests are capped per tick (no hitch at 4x)

### 1.3 Movement system
- File: `systems/movement_system.lua`
- Implement:
  - `request_move_to_tile(uid, tile)` or `request_follow_path(uid, path)`
  - simple separation/avoidance
  - stuck detection + deterministic recovery (repath, nudge, abort)
- Acceptance:
  - Unit moves smoothly/reliably along path
  - No jitter/overshoot loops at 4x

### 1.4 Combat + gathering systems w/ visual hooks
- Files: `systems/combat_system.lua`, `systems/gathering_system.lua`, `systems/lifecycle_system.lua`
- Use: existing HitFX + particles (flash/shake on hit; sparkle on gather; spin+fade on death)
- Discipline:
  - combat produces damage commands; lifecycle applies and emits events
  - gathering produces harvest commands; lifecycle emits events
- Acceptance:
  - Damage reduces HP, triggers FX, death removes entity after animation
  - Ore harvest anim + sparkle; node depletes visually
  - No mid-tick entity deletion crashes (lifecycle owns despawn)
  - FX triggered by events only (no sim/UI cross writes)

### 1.5 Inventory system (party inventory)
- File: `systems/inventory_system.lua`
- Model:
  - `party_inventory = { capacity, items_by_type = { ore=n, ... } }`
  - capacity computed from party size + upgrades
- Acceptance:
  - Inventory full detection works
  - Harvest respects capacity

### 1.6 AI: baseline GOAP-lite actions + ticker
- Files: `ai/world_state.lua`, `ai/goap_actions.lua`, `ai/planner.lua`, `ai/behaviors.lua`, `ai/ticker.lua`
- Goals (priority): `combat`, `gather`, `explore` (stub), `idle`
  - *Idle visual*: color-shaded blinking (same character, but slightly different shades of an adjacent color to indicate idle state)
- Phase 1 actions: `move_to_target`, `attack_enemy`, `gather_resource`, `idle`
- Safety: timeouts, replanning cooldown, stale validation
- Acceptance:
  - Unit sequence: idle → attack enemy → gather ore → idle
  - No stuck states; action events emitted

### 1.7 Debug HUD (ImGui OK) + minimal ASCII HUD stub
- Files: `ui/expedition_hud.lua`, `ui/ascii_ui/*` (stubs)
- Displays:
  - seed, time scale, tick-hash (when available)
  - current goal/action, target IDs, inventory fullness
  - optional per-system profiler overlay (dev toggle)
- Controls:
  - toggle debug overlay
  - cycle 1x/2x/4x
  - optional dev controls: pause / single-step
- Acceptance:
  - Debug info always safe to render (nil-safe)
  - Time scale affects all systems consistently
  - Seed/time scale/tick-hash visible

### 1.8 Phase 1 Integration Demo
- Scenario: enemy present + ore present; verify autonomous switching
- Acceptance:
  - Completes loop in < 30 seconds at 1x
  - Produces "GIF/video-ready" deterministic run from seed
  - Same seed ⇒ same loop outcome + same tick-hash sequence

---

## Phase 2 — The World (Goal: Forma dungeon + fog + exploration + minimap)

### 2.1 Forma-driven multi-room dungeon generation
- Files: `world/dungeon_gen.lua`, `world/tiles.lua`
- Approach:
  - Use Forma builders to create connected rooms/corridors (deterministic)
  - Output: tile grid + entrance + exits/spawns
- Acceptance:
  - Determinism: same seed ⇒ identical layout hash
  - All rooms reachable from entrance
  - Completes in < 100ms for default size

### 2.2 Fog of war + LOS + visibility scheduling
- Files: `world/fog.lua`, `world/los.lua`, `systems/visibility_system.lua`
- Tile states: `HIDDEN`, `SEEN`, `VISIBLE` (per tile)
- Use existing LOS implementation from codebase
- Optimization:
  - recompute visibility only on tile change or capped interval
  - maintain `dirty_tiles` list; avoid full-grid clears each tick
  - merge reveals deterministically (stable unit order)
- Animated Reveals (Presentation-only):
  - When tiles transition HIDDEN→VISIBLE, fog should "fade away" with animation (sequence of textured sprites from tileset simulating smoke dissipating)
  - When tiles transition VISIBLE→SEEN (moving away), fog should animate back IN with reverse fade effect
  - Queue newly revealed/hidden tiles; stagger animation (0.05s per tile)
  - Auto-disable or reduce reveal animation at 4x (config flag)
- Acceptance:
  - LOS blocked by walls
  - Hidden tiles not rendered (or black); seen dim; visible full
  - 4x speed stable

### 2.3 Data-driven autotiling (extensible sprites/config)
- Files: `world/autotile/rulesets.lua`, `world/autotile/blob47.lua`, `config.lua`
- Requirements:
  - tileset rules read from data tables (not hardcoded)
  - can add custom sprites (same dimensions) later
  - supports swapping configs without rewriting code
  - 47-tile blob pattern or 16-tile simplified (config selects)
- Acceptance:
  - Walls/shorelines connect cleanly
  - Switching rulesets changes visuals without changing map data
  - Structure walls seamlessly connect (no mismatched edges)

### 2.4 World rendering + camera
- Files: `world/camera.lua`, update `main.lua` draw path
- Features:
  - camera follows party center; optional pan override; bounds clamp
  - render culling: only draw visible/seen tiles and nearby entities
- Note: Codebase already has a springy camera implementation — consider using it, with optional user-facing setting to disable extra springiness/dampening.
- Acceptance:
  - Stable 60fps at default map size; only visible/seen tiles drawn

### 2.5 Spawn rules for enemies/resources/recruits
- File: `world/spawn.lua`
- Rules:
  - spawn density caps
  - distance-based difficulty
  - non-overlap constraints
  - deterministic sampling using `runtime/rng.lua`
- Acceptance:
  - No spawns inside walls/entrance; sensible distribution
  - Same seed ⇒ identical spawns (if definitions unchanged)

### 2.6 Exploration behavior
- Updates: `ai/behaviors.lua`, `ai/world_state.lua`, `ai/goap_actions.lua`
- Add: `explore` goal + `move_to_frontier_cluster`
- Robustness:
  - Unreachable frontiers blacklisted temporarily
  - Prefer "frontier clusters" over single tiles to reduce dithering
- Acceptance:
  - Unit explores reliably without dithering
  - Path failures recover without corner-stuck behavior

### 2.7 Minimap baseline (ASCII style)
- File: `ui/minimap.lua`
- Shows: explored tiles (SEEN/VISIBLE), fogged regions, party dot(s), entrance marker
- Note: Since we use grid visuals, minimap may need to be an exception and allow for smaller-scale rendering (sub-tile resolution).
- Acceptance:
  - Reads fog state; efficient update; readable at 4x

### 2.8 Phase 2 Integration Demo
- Scenario: generated dungeon, ore nodes placed; unit explores and gathers
- Acceptance:
  - Majority of map explored within ~2 minutes (tunable)
  - No corner-stuck behavior; path failures recover
  - Determinism: same seed ⇒ same explored count + same gathered total

---

## Phase 3 — Party Dynamics (Goal: coordinated multi-unit expedition + recruitment)

### 3.1 Unit archetypes + roles
- Files: `entities/unit_factory.lua`, `data/units.lua`
- Include roles from your ecosystem:
  - Knight / Mage / Rogue (combat/explore roles)
  - Miner / Lumberjack / Collector / Builder (economy/overland roles)
- Acceptance:
  - Party spawns with correct sprites/stats; role visible

### 3.2 Party blackboard + coordinator + reservations
- Files: `ai/coordinator.lua`, `ai/blackboard.lua`
- Responsibilities:
  - leader selection + reassignment on death
  - target distribution via reservations (avoid overkill/dogpiles)
  - role-based intent hints (tank front / ranged back / miner safe)
  - "need help" pings for protect behavior
- Acceptance:
  - Reduced dogpiles; stable target assignment
  - Coordinator runs fast (< 2ms for 4 units)

### 3.3 Formation + follow behavior
- Files: `ai/formation.lua`, GOAP action `follow_leader`
- Movement integration:
  - formation outputs desired tiles/offsets; MovementSystem executes
  - separation prevents perfect overlap
- Acceptance:
  - Cohesion maintained; combat can override follow when threatened

### 3.4 Protect ally behavior
- Update: `ai/behaviors.lua`
- Knight prioritizes attackers of wounded allies (threshold configurable)
- Acceptance:
  - Protection interrupts normal behavior when ally endangered

### 3.5 Recruitment POI
- Files: `systems/recruitment_system.lua`, `entities/npcs/*`
- Behavior:
  - auto-recruit on proximity (idempotent)
  - sparkle + notification event; joins coordinator; inventory capacity updates (more colonists → more inventory; may need refinement)
- Acceptance:
  - Recruitment is idempotent; capacity updates

### 3.6 Phase 3 Integration Demo
- Scenario: start with Knight leader; recruit Mage; fight group; mine; recruit Miner
- Acceptance:
  - Role specialization observable (tank/ranged/gather)
  - No AI deadlocks as party size changes

---

## Phase 4 — Overland Features + Dynamic Terrain (Goal: trees/lakes/mineable walls + interactions)

### 4.1 Forma overland feature generator
- File: `world/overland_gen.lua`
- Features:
  - trees/forests clusters
  - lakes/ponds with shoreline
  - mineable walls + mineral veins
  - decorative props (Phase 7 polish)
- Acceptance:
  - Same seed ⇒ identical overland hash
  - Feature placement respects walkability/constraints

### 4.2 Terrain system: mining/chopping/building tile edits
- Files: `systems/terrain_system.lua`, `world/terrain_edits.lua`
- Implement deterministic commands:
  - `dig_wall(x,y)` → becomes floor + drops minerals
  - `chop_tree(x,y)` → becomes stump/floor + drops wood
  - `build_decor(x,y, kind)` (decorative only per scope)
- Acceptance:
  - Pathfinding invalidation works (no walking through walls until dug)
  - Fog/LOS updates correctly when opacity changes

### 4.3 AI actions for overland interactions
- Update: `ai/goap_actions.lua`, `ai/behaviors.lua`
- Add actions:
  - `mine_wall`, `chop_tree`, `pickup_loot`, `build_decor`
- Acceptance:
  - Miner prefers mineable walls/minerals
  - Lumberjack targets trees
  - Collector handles loose pickups
  - Builder places decorative structures (no gameplay effect)

### 4.4 Phase 4 Integration Demo
- Scenario: dungeon/overland with trees, mineable walls; party mines, chops, builds
- Acceptance:
  - Dynamic terrain changes work; paths update
  - No stuck states due to path invalidation

---

## Phase 5 — Resource Loop + Achievements (Goal: return/extract/results + milestones)

### 5.1 Resource definitions + valuation
- File: `data/resources.lua`
- Define: `ore/gem/wood/food` with sprite + value + stack rules
- Acceptance:
  - Results screen and upgrades reference same canonical defs

### 5.2 Return-to-entrance + manual extract + end conditions
- Updates: `ai/behaviors.lua`, `ai/goap_actions.lua`, `systems/expedition_manager.lua`, `ui/expedition_hud.lua`
- End conditions:
  - **Success (full extract):** `inventory_full` and party reaches entrance
  - **Success (manual extract):** player hits "Extract Now" and party reaches entrance
  - **Failure:** all party dead (TPK)
- Behavior conditions:
  - Return overrides exploration/gather when inventory is full
  - Return can also trigger when health is low (configurable)
- Acceptance:
  - Return overrides exploration/gather when full
  - Manual extract button works
  - Clean transition to RESULTS; entities cleaned up

### 5.3 Results summary + run-hash
- Files: `systems/expedition_manager.lua`, `ui/results_screen.lua`
- Summary:
  - duration, enemies defeated, resources gathered, recruits, casualties, seed, `run_hash`, extract reason
- Acceptance:
  - Summary accurate under time scaling
  - Run-hash displayed and stored in run history

### 5.4 Achievements system + notifications
- Files: `data/achievements.lua`, `systems/achievements_system.lua`, `ui/notifications.lua`
- 4 categories: resource thresholds, upgrade milestones, creature population, time-based
- Acceptance:
  - Deterministic unlock evaluation
  - Toast shows and is logged

### 5.5 Phase 5 Integration Demo
- Scenario: dungeon with enough ore to fill capacity; party returns; results shown; achievements fire
- Acceptance:
  - End-to-end expedition completes in 3–5 minutes hands-off
  - Resource totals correct; failure path also works
  - Manual extract path also works

---

## Phase 6 — Colony Integration (Goal: upgrades/unlocks + save/load + ASCII gameplay UI)

### 6.1 Colony state + meta progression
- Files: `colony/colony_state.lua`, `colony/meta_progression.lua`, `data/upgrades.lua`
- Tracks: resources, unlocks, owned upgrades, expedition_count, tutorial_seen, run_history (last N)
- Acceptance:
  - Resource add/spend validated; unlock flags consistent
  - Purchases validated; effects apply next run deterministically

### 6.2 Save/load with versioning + corruption safety
- File: `colony/save_system.lua`
- Requirements:
  - atomic writes (write temp then rename)
  - safe defaults on missing/corrupt save
  - version migrations
  - optional checksum for quick corruption detection
- Acceptance:
  - Restart preserves colony resources/upgrades/settings
  - Corrupt save does not crash; falls back to defaults + warns

### 6.3 Colony screen UI + expedition prep
- File: `colony/colony_screen.lua`
- Shows:
  - resources, available upgrades, party selection (starting unit)
  - last run summary + last `run_hash`
  - "start expedition" options: seed override (dev), time scale default
- Acceptance:
  - Start Expedition launches with correct unlocks/upgrades applied

### 6.4 ASCII tile UI implementation (gameplay)
- Files: `ui/resource_panel.lua`, `ui/upgrade_panel.lua`, `ui/ascii_ui/*`
- Requirements:
  - grid alignment (20px multiples)
  - CP437/dungeon atlas sprites for borders/icons
  - scrollable upgrade list
  - keep ImGui debug panels
- Acceptance:
  - UI readable at 1x and 4x
  - No layout jitter (tile-aligned constraints enforced)

### 6.5 Phase 6 Integration Demo
- Scenario: run expedition → return → buy upgrade → run again; verify upgrade effect; restart game and verify persistence
- Acceptance:
  - "One more run" loop works reliably across restarts
  - Run history shows last N summaries

---

## Phase 7 — Content + Polish (Goal: feel + balance + perf)

### 7.1 Enemy roster + behaviors
- Files: `data/enemies.lua`, optional `entities/enemies/*`
- Minimum: rat, bat, skeleton, goblin, orc, spider (distinct stats/behaviors)
- Acceptance:
  - Variety observable; spawn scaling by distance/floor

### 7.2 Expedition HUD completion
- Update: `ui/expedition_hud.lua`, `ui/party_status.lua`, `ui/minimap.lua`, `ui/notifications.lua`
- Add:
  - party health bars, inventory fullness meter, minimap w/ fog, floor indicator
  - speed control UI, extract button
- Acceptance:
  - High glance value; non-intrusive; readable at 4x

### 7.3 Audio feedback (driven by deterministic events)
- Events: hit, death, gather, upgrade purchase, expedition start/end, recruit
- Sound effects can be derived from **Eagle MCP**, which will be hooked up by implementation time. Tags will be placed on SFX and music so they can be fetched easily.
- Acceptance:
  - Volume-safe at 4x; respects volume settings

### 7.4 Tutorial/onboarding
- First-run tips overlay; objective hint; dismiss + saved
- Acceptance:
  - Teaches loop in < 60 seconds; never repeats once dismissed

### 7.5 Performance + stability pass
- AI tick interval tuning (default ~0.2s), path budgets/caches, fog update optimization
- Leak checks across repeated runs
- Acceptance:
  - Stable frame time at default map size + party size cap
  - No memory growth across 10 consecutive runs

---

## Post-Plan: Test Harness Exploration & Refinement Phase (Required)

You explicitly requested "foolproof tests" using your **existing codebase test harness**, but we can't claim harness integration is complete until we:
- examine how the harness runs Lua tests (bootstrap, assertions, fixtures),
- determine how it handles deterministic scenarios and golden data,
- refactor tests to run in CI reliably.

**This phase happens after the plan above is implemented**, and its job is to:
1. integrate `debug/contract_tests.lua` + `debug/golden_runs.lua` into the harness as first-class test suites,
2. convert each phase's acceptance criteria into automated assertions where possible,
3. add a "golden seed bank" with expected run-hashes,
4. add coverage for edge cases (unreachable paths, dynamic tile edits, save corruption, etc.).

Deliverable: one command in the harness runs all Auto-Achra tests headlessly and fails fast with actionable logs.

---

## 7) Parallel Execution Plan (3–5 Agents)

### 7.1 Workstreams (Directory Ownership)
- **Agent A — Integration/Runtime**:
  - `main.lua`, `runtime/*`, `systems/expedition_manager.lua`, `systems/lifecycle_system.lua`,
  - `debug/*`, `colony/save_system.lua`
- **Agent B — AI/GOAP**:
  - `ai/*`
- **Agent C — World/Gen**:
  - `world/*`, `vendor/forma/*`
- **Agent D — Systems/Entities**:
  - `systems/*`, `entities/*`, `data/*`
- **Agent E — UI/Colony**:
  - `ui/*`, `colony/*`

### 7.2 Integration Checkpoints
- **IC0** after Phase 0: determinism backbone + Forma adapter + hump.signal bridge
- **IC1** after Phase 1: AI loop works in test harness
- **IC2** after Phase 2: dungeon+fog+explore+minimap works
- **IC3** after Phase 3: party+coordinator+recruit works
- **IC4** after Phase 4: overland features + dynamic terrain stable
- **IC5** after Phase 5: results + achievements stable
- **IC6** after Phase 6: save/load + ASCII UI stable

### 7.3 Coordination Requirements
- Any change to shared contracts (World API, entity script schema, AI action API, event names) must be announced via Agent Mail before merging.
- Keep modules loosely coupled:
  - UI reads state + consumes events,
  - systems mutate state + emit events,
  - avoid cross-calling into UI from systems.

---

## 8) Risk Mitigations (Built-In)

- **Planner/AI complexity creep**:
  - bounded multi-step planning only (hard caps), fall back to greedy
- **GOAP thrashing**:
  - replanning cooldown + goal hysteresis + action timeouts
- **Dynamic terrain invalidation bugs**:
  - central TerrainSystem with deterministic batching + explicit invalidation calls
- **Pathfinding cost**:
  - request queue + per-tick budget + caching + invalidation
- **Fog cost**:
  - incremental reveal + recompute scheduling
- **Determinism drift**:
  - ban `math.random`, enforce sorted iteration, use tick/run hashes + golden seeds
- **UI drift from tile alignment**:
  - single "tile layout helper" that rejects non-multiple sizes in dev builds
- **Save corruption**:
  - atomic writes + version migrations + checksum optional
- **Unreachable targets**:
  - pathfinding returns reason; AI blacklists targets temporarily and chooses next best
- **High time-scale instability**:
  - fixed-step sim + max steps/frame,
  - degrade/disable nonessential reveal animations at 4x
- **Scope creep**:
  - no Phase 7 features merged until Phase 6 loop is complete and stable

---

## 9) Definition of Done (Per-Phase) — Quick Checklist

A phase is "done" when:
- it meets all acceptance criteria in its section,
- it is demoable from `debug/scenario_runner.lua`,
- UBS + contract tests pass,
- no new nondeterminism: same seed ⇒ same tick-hashes/run-hash for the primary scenario.