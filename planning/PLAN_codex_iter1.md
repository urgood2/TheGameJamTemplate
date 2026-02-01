# Descent (DCSS‑Lite) — Engineering Plan (Improved)

## 0) Scope, Constraints, Guardrails

### Goal
Ship a **DCSS-faithful traditional roguelike** (“Descent”) with **turn-based** movement/combat, **shadowcasting FOV**, **5 floors**, and a **boss on floor 5**, targeting **15–20 minute** runs.

### MVP Content Floor
- Species: **1** (Human)
- Background: **1** (Gladiator)
- God: **1** (Trog)
- Spells: **3**
- Enemies: **5** (+ boss placeholder acceptable until boss bead)

### Explicit Non‑Goals (must not ship in MVP)
- No save/load, no meta-progression
- No autoexplore
- No hunger, no branches
- No mouse support
- No inventory tetris (use list UX even if backend supports grid)
- No animation system beyond existing HitFX flashes

### Key Engineering Constraints
- Must support **multi-agent execution** with **Beads (`bd`)** and **Agent Mail file reservations**.
- Must be **test-driven** using the **existing Lua test runner** + existing in-engine test harness patterns.
- Must avoid external “spec-as-a-path-on-one-machine” dependencies.

---

## 1) Source of Truth: Spec Snapshot (make repo-self-contained)

### 1.1 Add a repo-local spec snapshot (required early)
Create `planning/descent_spec.md` containing:
- Combat formulas (exactly as below)
- HP/MP scaling and XP formulas (exactly as below)
- Floor size + encounter quotas (exactly as below)
- MVP content tables (species/background/god/spells/enemies)
- Boss phases requirements (if present in the design doc)

**Combat**
```lua
-- Melee
damage = weapon_base + str_modifier + species_bonus
hit_chance = 70 + (dex * 2) - (enemy_evasion * 2)

-- Ranged/Magic
damage = spell_base * (1 + int * 0.05) * species_multiplier
hit_chance = 80 + (skill * 3)

-- Defense
damage_taken = incoming - armor_value
evasion_chance = 10 + (dex * 2) + dodge_skill
```

**Scaling**
```lua
max_hp = (10 + species_hp_mod) * (1 + level * 0.15)
max_mp = (5 + species_mp_mod) * (1 + level * 0.1)
xp_for_level_n = 10 * n * species_xp_mod
```

**Floors**
- F1: 15×15, 5–8 enemies, guaranteed shop
- F2: 20×20, 8–12 enemies, first altar
- F3: 20×20, 10–15 enemies, second altar
- F4: 25×25, 12–18 enemies, third altar + miniboss
- F5: 15×15, 5 guards + BOSS

---

## 2) Build + Test Commands (canonical, verified in this repo)

### 2.1 Build
Fast single-config builds:
```bash
just build-debug-fast
# Run:
./build-debug/raylib-cpp-cmake-template
```

Default build dir (needed by some Justfile “UBS” recipes):
```bash
just build-debug
# Expected binary path used by UBS recipes:
./build/raylib-cpp-cmake-template
```

### 2.2 C++ unit tests (gtest)
```bash
just test
```

### 2.3 UBS (UI Baseline Suite) — required before commits that touch shared UI/layout
If baselines are not established in this branch, capture once:
```bash
just ui-baseline-capture
```
Before committing UI-impacting changes:
```bash
just ui-verify
```

### 2.4 Lua tests execution strategy (no system `lua` assumed)
There is **no requirement** that developers have `lua` installed; instead, run Lua tests **in-engine** via a dedicated env flag executed from `assets/scripts/core/main.lua` (pattern already exists for GOAP/UIValidator tests).

Canonical command (after adding `RUN_DESCENT_TESTS` hook):
```bash
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template
# Exit code must be 0 on pass, non-zero on failure.
```

---

## 3) Architecture (explicit module boundaries)

### 3.1 Lua module root
All new game code lives under:
- `assets/scripts/descent/**`

### 3.2 Core modules (MVP)
- `descent/init.lua` — mode entry, wiring, state ownership
- `descent/turn_manager.lua` — state machine + action economy
- `descent/map.lua` — tile grid, walkability, entity placement adapters
- `descent/fov.lua` — recursive shadowcasting (Lua) + explored/visible tracking
- `descent/dungeon.lua` — floor generation (templates + variation) + validation
- `descent/pathfinding.lua` — BFS for AI + reachability validation
- `descent/combat.lua` — math + deterministic RNG injection for tests
- `descent/items.lua` — item defs + pickup/use/equip APIs
- `descent/enemy.lua` — enemy defs + AI decision logic
- `descent/player.lua` — stats + actions + inventory hooks
- `descent/ui/**` — character creation, shop, HUD, victory/death

### 3.3 Determinism contract (mandatory)
- All procgen/combat randomness must route through a `descent.rng` adapter that supports:
  - seeded RNG for reproduction
  - deterministic test RNG (`fixed rolls` / `scripted sequence`)
- Bug reports must include seed + floor number + player position.

---

## 4) Test Strategy (actionable + automatable)

### 4.1 Test tiers
1) **Embedded Lua unit tests** (`RUN_DESCENT_TESTS=1`)  
   - Pure logic: combat math, FOV, dungeon validity, AI decisions, inventory rules  
   - Must be fast (<2s typical) and deterministic.

2) **C++ unit tests** (`just test`)  
   - Must remain green; Descent work must not regress engine.

3) **UBS** (`just ui-verify`)  
   - Required when touching shared UI/layout systems.  
   - Descent-only UI files do not require UBS unless they modify shared primitives.

4) **Manual playtests**  
   - Required for every milestone that changes loop flow (stairs, boss, victory/death).

### 4.2 In-engine test runner hook (required early)
Add a hook in `assets/scripts/core/main.lua`:
- If `RUN_DESCENT_TESTS=1`, run filtered tests and `os.exit(0|1)`.

Acceptance:
- Running `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits with correct code.

---

## 5) Coordination Protocol (Agent Mail + Beads)

### 5.1 File reservation (mandatory before edits)
Before editing, reserve the exact files/globs you’ll touch (exclusive) via Agent Mail MCP.
- Reserve narrowly (e.g. `assets/scripts/descent/turn_manager.lua`, not `assets/scripts/**`).

### 5.2 Beads workflow (repo rule)
“BV” in `AGENTS.md` maps to **`bd ready`**.

Triage:
```bash
bd ready --limit 50 --sort hybrid
```

Claim:
```bash
bd update <ID> --claim --actor "<your_name>"
```

Close:
```bash
bd close <ID> --session "descent-mvp" --actor "<your_name>"
bd comments add <ID> --message "Summary + commands run + evidence paths" --actor "<your_name>"
```

Dependencies:
```bash
bd dep add <BLOCKED_ID> <BLOCKER_ID> --type blocks
bd dep cycles
```

### 5.3 Multi-agent rules of engagement
- Each bead must declare:
  - owned files/globs
  - acceptance tests (exact command lines)
  - evidence artifacts (paths under `.sisyphus/evidence/`)
- No bead may change shared UI/layout without also running UBS and documenting it in the bead comment.

---

## 6) Milestones (gated, testable)

### M0 — Harness + Spec (1–2 days)
- Repo-local spec snapshot exists
- `RUN_DESCENT_TESTS` hook exists and is CI-friendly
- Descent mode can be entered (even if stub UI/map)

### M1 — Single-floor playable loop (2–4 days)
- Character creation → spawn on floor → move → FOV updates → fight → die screen

### M2 — Five floors + stairs (2–4 days)
- All floors generate valid, connected maps
- Stairs transitions work end-to-end

### M3 — MVP completion (3–6 days)
- Shops, altars/god, spells/level-up, boss, victory screen
- 5 consecutive full runs without crash

### M4 — Post-MVP expansion (optional)
- Add remaining species/backgrounds/gods/spells/enemies

---

## 7) Beads Backlog (decomposed, parallelizable)

> Naming convention: titles prefixed with `[Descent]`.  
> Dependency notation: `Blocks:` indicates prerequisite beads.

### Epic: `[Descent] MVP`
Create this as a parent bead (type `epic`), then attach children via `--parent <EPIC_ID>`.

---

### Wave A — Harness / Spec / Entry (parallel)

#### A1 — `[Descent] Add repo-local spec snapshot`
- Blocks: none
- Touches: `planning/descent_spec.md`
- Acceptance:
  - File exists and includes formulas + floor quotas + MVP tables
- Evidence: `.sisyphus/evidence/descent_spec_snapshot.md` (optional copy/paste of key tables)

#### A2 — `[Descent] Add test execution hook (RUN_DESCENT_TESTS)`
- Blocks: none
- Touches: `assets/scripts/core/main.lua`, `assets/scripts/tests/test_descent_*.lua`
- Acceptance:
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits `0` when empty suite
  - Exits `1` when a test intentionally fails
- Failure modes to handle:
  - missing modules → fail with `os.exit(1)` and clear console message

#### A3 — `[Descent] Add mode entry point + menu integration (stub)`
- Blocks: none
- Touches: menu/router Lua + `assets/scripts/descent/init.lua`
- Acceptance:
  - Descent can be entered from menu (or gated by env flag)
  - Returns cleanly to main menu on exit/error
- Rollback:
  - Mode entry behind `ENABLE_DESCENT=1` env flag until M1 passes

---

### Wave B — Core loop skeleton (parallel where safe)

#### B1 — `[Descent] Module skeleton + wiring contract`
- Blocks: A3
- Touches: `assets/scripts/descent/**` (initial files only)
- Acceptance:
  - `require("descent.init")` succeeds in-engine
  - `RUN_DESCENT_TESTS` loads Descent modules without side effects

#### B2 — `[Descent] Turn manager state machine + action economy`
- Blocks: B1
- Own files: `assets/scripts/descent/turn_manager.lua`
- Acceptance tests (in-engine):
  - initial state is `PLAYER_TURN`
  - transitions: `PLAYER_TURN -> ENEMY_TURN -> PLAYER_TURN`
  - terminal: `GAME_OVER`, `VICTORY`
- Edge cases:
  - enemy list mutation during iteration (kills/summons)
  - no enemies present
  - player death during enemy turn

#### B3 — `[Descent] Tile grid + rendering (use existing cp437/atlas first)`
- Blocks: B1
- Own files: `assets/scripts/descent/map.lua`
- Acceptance:
  - draws walls/floors/player using existing sprite assets already in `assets/graphics/sprites-*.json`
  - map coordinates ↔ pixel coordinates correct at all floor sizes
- Failure modes:
  - missing sprite name → must render a fallback glyph and log once

#### B4 — `[Descent] Input context (WASD + numpad) + bump-to-attack routing`
- Blocks: B2, B3
- Acceptance:
  - movement consumes a turn only if move is legal
  - bumping into enemy triggers melee attack action
  - invalid moves do not advance turn
- Edge cases:
  - diagonal movement into corner (blocked)
  - held keys / repeat behavior doesn’t skip turns

#### B5 — `[Descent] FOV (recursive shadowcasting) + explored vs visible`
- Blocks: B3
- Acceptance:
  - visibility recalculated after player movement
  - explored tiles persist after leaving LOS
- Edge cases:
  - bounds clipping at edges
  - player tile always visible
  - walls block light correctly
  - radius configurable per floor (default constant ok)

---

### Wave C — Procgen + Navigation (parallel)

#### C1 — `[Descent] RNG adapter + seed plumbing`
- Blocks: B1
- Acceptance:
  - A fixed seed produces identical floor layouts and enemy placements
  - Seed logged/displayed in HUD and death/victory screen

#### C2 — `[Descent] Dungeon generation (templates + variation) + validation`
- Blocks: C1, B3
- Acceptance (tests must assert all):
  - start and stairs are placed on walkable tiles
  - start → stairs path exists (BFS)
  - enemy/item placement never overlaps walls or each other
  - per-floor size and quota rules enforced
- Failure handling:
  - if generation fails N attempts (e.g. 50), fall back to a simple rectangular room + corridor and log seed

#### C3 — `[Descent] Stairs + floor transitions (1→5)`
- Blocks: C2, B4
- Acceptance:
  - moving onto stairs generates next floor and preserves player state
  - floor index tracked; floor 5 spawns boss arena rules

---

### Wave D — Combat + AI (parallel)

#### D1 — `[Descent] Combat math (melee + magic) with clamping and rounding rules`
- Blocks: B2, C1
- Acceptance:
  - hit chance clamped to `[5, 95]` (explicit)
  - damage floors at `0` after armor
  - deterministic RNG in tests (no flaky rolls)
- Edge cases:
  - negative stats not allowed (validate data)
  - armor > raw damage
  - multiple modifiers (species/god/status) applied in defined order (documented)

#### D2 — `[Descent] Enemy definitions (MVP 5) + AI decide_action`
- Blocks: B5, C2, C1
- Acceptance:
  - adjacent → attack
  - visible → path toward player
  - not visible → idle
- Edge cases:
  - no path → idle (do not crash)
  - fast/slow speed behavior matches turn energy rules

#### D3 — `[Descent] Enemy turn execution + collision-safe movement`
- Blocks: D2, B2, B3
- Acceptance:
  - enemies do not move into occupied tiles
  - enemies process in stable order (id order) for determinism

---

### Wave E — Player state + Items + UI (parallel with careful file ownership)

#### E1 — `[Descent] Player stats model + leveling (HP/MP/XP formulas)`
- Blocks: C1, D1
- Acceptance:
  - XP thresholds match spec
  - leveling recalculates HP/MP
  - level-up triggers spell selection (stub acceptable until spells bead)

#### E2 — `[Descent] Item defs + inventory list UX + equip/use`
- Blocks: B3, C1
- Acceptance:
  - pickup/drop/use works
  - equip applies stats (weapon_base, armor_value)
- Edge cases:
  - full inventory (define max; enforce)
  - using item with no valid target (no-op + message)

#### E3 — `[Descent] Scroll identification (MVP: scrolls only)`
- Blocks: E2
- Acceptance:
  - unknown scrolls have randomized labels per run (seeded)
  - once identified, future scrolls of that type show true name
- Failure modes:
  - label collision must be prevented (unique labels per run)

#### E4 — `[Descent] Character creation UI (species/background)`
- Blocks: B3, E1, E2
- Acceptance:
  - cannot start without selecting both
  - starting gear applied correctly
  - screenshot evidence stored in `.sisyphus/evidence/`

---

### Wave F — Meta Systems (shops, gods, spells)

#### F1 — `[Descent] Shop system (F1 guaranteed) + buy/sell + reroll`
- Blocks: E2, C2
- Acceptance:
  - stock generated per floor with seed
  - purchase removes gold and adds item
  - reroll consumes currency and replaces stock
- Edge cases:
  - insufficient gold blocks purchase
  - full inventory blocks purchase (must allow cancel/refund)

#### F2 — `[Descent] God system (MVP: Trog) + altar interaction`
- Blocks: C2, E1
- Acceptance:
  - altar appears on required floors
  - worship state persists across floors
  - conduct “no spellcasting” enforced (spell cast blocked with message)
- Failure modes:
  - god UI must not soft-lock input (must always allow exit)

#### F3 — `[Descent] Spells (MVP 3) + targeting + mana usage`
- Blocks: E1, D1, B5
- Acceptance:
  - spell selection on level-up (modal UI)
  - cast checks MP and LOS rules
  - damage uses spec magic formula
- Edge cases:
  - cast with insufficient MP
  - target out of LOS
  - self-target vs enemy-target rules explicit

---

### Wave G — Boss + Endings + Polish (late, gated)

#### G1 — `[Descent] Boss floor rules + boss AI + phase transitions`
- Blocks: C3, D1, D3, E1
- Acceptance:
  - boss exists on floor 5 with required adds/guards
  - phases trigger at defined HP thresholds
  - win condition triggers victory state
- Failure handling:
  - if boss script errors, fail into death screen with seed + error text (so runs don’t hang)

#### G2 — `[Descent] Victory + Death screens (stats + seed + time)`
- Blocks: G1, C1
- Acceptance:
  - displays: seed, turns taken, final level, kills, cause of death / victory
  - returns to main menu cleanly

#### G3 — `[Descent] MVP integration pass + crash-free 5-run soak`
- Blocks: A1–G2
- Acceptance:
  - 5 full runs without crash (record in `.sisyphus/evidence/descent_soak_runs.md`)
  - run duration within 15–20 minutes (record at least 3 timed runs)
- Calibration knobs (explicit, allowed post-MVP):
  - enemy HP, spawn counts, floor dimensions, shop frequency

---

### Wave H — Art swap (de-risked; not on critical path)

#### H1 — `[Descent] Dungeon_mode tileset import + atlas rebuild`
- Blocks: M1 (recommended), optional earlier if not blocking
- Acceptance:
  - new sprites are present in atlas JSON
  - map rendering uses new sprite names without regressions
- Failure modes:
  - missing TexturePacker CLI → document GUI steps; do not block core gameplay

---

## 8) Rollout Plan (safe integration)

### Phase 1: Hidden mode
- Land Descent behind `ENABLE_DESCENT=1` env flag and/or “Dev” submenu entry.
- Default builds do not show Descent to end users.

### Phase 2: Soft launch
- After M2, enable Descent in main menu but label as **“Experimental”**.
- Require `RUN_DESCENT_TESTS` and `just test` green before merge.

### Phase 3: MVP launch
- After M3 soak + timing targets met, remove “Experimental” label.
- Keep seed always visible for bug reporting.

### Rollback
- One-line rollback path: disable menu entry + ignore mode routing; leave Descent code in place.

---

## 9) Failure Modes Checklist (must be explicitly tested)

- Procgen fails to place stairs/start → fallback generator triggers, logs seed
- Turn manager deadlock (state never returns to `PLAYER_TURN`) → watchdog asserts in debug
- Enemy AI pathfinding returns nil path → enemy idles (no crash)
- FOV indexes out of bounds → bounds clamp + test
- Combat randomness makes tests flaky → all tests use injected deterministic RNG
- UI modal locks input → every modal must have explicit cancel/back mapping
- Data tables malformed → validate on load; fail fast with clear error + module name

---

## 10) Final “Done” Checklist (MVP)

- Character creation (species + background) works
- Turn-based movement/combat works (no skipped turns)
- Shadowcasting FOV correct (visible vs explored)
- 5 floors with correct size/quotas and functional stairs
- Items: pickup/equip/use; scroll identification works
- Shops work; reroll works
- God system works (Trog) and conduct enforced
- Spells work (3) with targeting + MP
- Boss fight on floor 5; victory screen on win; death screen on loss
- `just test` passes
- `RUN_DESCENT_TESTS` passes with correct exit code
- UBS run documented for any shared UI changes (`just ui-verify`)
- 5-run soak evidence recorded under `.sisyphus/evidence/`