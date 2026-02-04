# Game #4 “Bargain” — Engineering Plan (vNext)

## 0) Outcomes, Constraints, Non‑Goals

### Ship outcome (vertical slice)
A deterministic, replayable **7-floor run**:
- Floors 1–6: explore/combat → find stairs → descend
- Floor 7: boss (“Sin Lord”) → victory on defeat
- Player death → game over → restart → new seeded run
- No softlocks (including deal modal, no valid actions, stuck phase)

### Hard constraints (must hold)
- **All gameplay rules are pure Lua sim** (no rendering, IO, time, dt, engine globals)
- **UI is a thin adapter**: renders from `world`, translates input → sim input
- **Single injected RNG** owned by sim: `world.rng` (no `math.random`, no unordered iteration)
- Deterministic ordering everywhere: neighbors, offers, AI decisions, entity processing, hooks

### Explicit non‑goals (for this slice)
- No inventory/items/shops
- No save/load
- No meta-progression
- No pathfinding requirement beyond BFS/distance-field (no A* needed)

---

## 1) Definition of Done (Ship Gates)

### Gate A — “No crash / no softlock” (blocking)
For seeds `S1,S2,S3` with scripted inputs:
- Run always ends in **victory or death**
- **0 crashes**, **0 softlocks**, **0 infinite loops**
- Phase machine never stalls (always returns a next state)

### Gate B — Deal offer rules (blocking)
- **Every floor start**: forced deal offer
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance until chosen
- **Every level-up**: optional deal offer
  - `must_choose=false`, `can_skip=true`
  - skip returns to play immediately

### Gate C — Content completeness (blocking)
- Exactly **21 deals** exist (7 sins × 3)
- Deal IDs are stable + unique; each deal declares its `sin`

### Gate D — Downside enforcement (blocking, automated)
- **21/21 deals** have an automated test that proves a *gameplay* downside
- Test must fail if downside is removed (no “field exists” assertions)

### Gate E — Determinism digest (blocking)
- `seed + scripted inputs → digest` matches expected for `S1,S2,S3`
- Two consecutive runs on the same machine match bit-for-bit
- Stretch: digest matches across machines if no platform variance exists

---

## 2) Entry Points, Ownership, and “Hot Files”

### Run modes (entry)
- `AUTO_START_BARGAIN=1`: auto-enter Bargain loop (highest precedence)
- Manual entry remains: `require("bargain.game").start()`

### Test runner (single-command contract)
- Reuse `assets/scripts/tests/test_runner.lua`
- Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua` that:
  - runs early, exits `0` on pass, `1` on fail
  - calls `require("tests.run_bargain_tests").run()`

Command contract:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### Hot-file rule (merge-conflict minimization)
- Only **Integrator** edits:
  - `assets/scripts/core/main.lua`
  - `assets/scripts/tests/test_runner.lua` (only if unavoidable)
- Everyone else works under:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/**` (new test files OK)

---

## 3) Contract Freeze (M0): Interfaces That Unblock Parallel Work

### `world` required schema (tests enforce)
- `world.grid`
- `world.entities` (map: `id -> entity`)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (only randomness source)
- `world.deals.applied` (map: `deal_id -> true`)
- `world.deals.history` (array of `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended (adopt once → frozen):
- `world.stairs` (`{x,y}` or nil)
- `world.events` (append-only deterministic structs from `step`)
- `world.messages` (append-only deterministic structs for UI)

### `entity` required schema (tests enforce)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministic access only; no unordered iteration assumptions)
- `hooks` (hook_name → array; callback order is stable and explicit)

### Deal offer struct (no table iteration)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers` = array of deal IDs (stable order)
- `must_choose` (bool)
- `can_skip` (bool)

### Sim input encoding + invalid-action policy (tests enforce)
Inputs to `step(world, input)`:
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`
- Deal choose: `{type="deal_choose", deal_id="..."}`
- Deal skip: `{type="deal_skip"}`

Invalid input behavior:
- Return `{ok=false, err="..."}` **and consume the actor’s turn**

### Phase machine (frozen)
Phases:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`

Deterministic rules:
- Forced offers keep sim in `DEAL_CHOICE` until chosen
- Enemy processing order: `speed desc`, tie-break `id asc`
- Neighbor order is fixed (e.g., `N,E,S,W`) everywhere it matters
- Any tie-break must be explicit (movement choice, targeting, offer ordering)

---

## 4) Modules and Artifacts (parallel lanes)

### Core sim API (contract tests in M0)
- `assets/scripts/bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
- `assets/scripts/bargain/sim/step.lua`
  - `step(world, input) -> {world, events, ok, err?}`

### Lane-owned modules (each ships with unit tests)
- Grid: `bargain/sim/grid.lua` (bounds, occupancy, neighbor order)
- Turn/phase: `bargain/sim/turn_system.lua` (phase progression, turn consumption, deal gating)
- Combat: `bargain/sim/combat.lua` (damage semantics, RNG usage rules)
- FOV: `bargain/sim/fov.lua` (occlusion + memory model)
- Floors/procgen: `bargain/sim/floors.lua` + `bargain/data/floors.lua`
- Enemies/AI: `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`
- Deals: `bargain/sim/deals.lua` + `bargain/data/sins/*.lua`

### Integrator bridge (minimal, deterministic)
- `assets/scripts/bargain/game.lua`
  - orchestrates sim + UI without adding time/randomness
  - consumes events/messages; never mutates sim outside `step`

---

## 5) Test Strategy (fast, deterministic, failure-localizing)

### Test entry
- `assets/scripts/tests/run_bargain_tests.lua` aggregates all Bargain tests
- Tests run with `RUN_BARGAIN_TESTS=1` and exit via test runner hook

### Test suites (minimum)
Unit:
- `test_bargain_grid.lua`
- `test_bargain_turn_system.lua`
- `test_bargain_combat.lua`
- `test_bargain_fov.lua`
- `test_bargain_enemy_ai.lua`

Data/contract:
- `test_bargain_contracts.lua` (schemas, phase machine, invalid action policy)
- `test_bargain_data_loading.lua` (21 deals, stable IDs, all sins present)
- `test_bargain_deals_downsides.lua` (21-row downside table)

Integration:
- `test_bargain_smoke.lua` (tiny fixed map; one enemy; no procgen)
- `test_bargain_determinism.lua` (seed+inputs → expected digest)

### Fixture rules
- Unit tests use tiny hand-authored maps (no procgen snapshots)
- Procgen tests are invariants-only over bounded seeds (terminate within N steps)
- No rendering, no frame timing, no OS/time calls

### Downside enforcement pattern (table-driven, 21 rows)
For each deal:
- Arrange: minimal `world`, deterministic RNG, scripted actions (1–10)
- Act: apply deal, run steps until downside should manifest
- Assert: *observable negative effect* (must change outcome), e.g.:
  - combat outcome flips under fixed script
  - per-turn drain triggers on `END_TURN`
  - action restriction returns `ok=false` and consumes turn
  - self-damage triggers on move/attack
  - XP penalty delays level-up under fixed script

---

## 6) Determinism Harness and Digest Spec (test-owned)

### RNG contract (hard)
- `world.rng` is the sole randomness source
- RNG API is explicit (e.g., `next_int(min,max)`); ban implicit randomness
- Offers/procgen/AI must use RNG only through this API

### Digest payload (canonical order, no table iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- Player stats/pos: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- Entities: sorted by `id`; serialize `(id,kind,x,y,hp,selected_flags)`
- Applied deals: sorted lexicographically
- Optional: deterministic `deals.history` summary (only if needed)

### Scripted-input determinism test
- Fixture seeds (define once in `assets/scripts/tests/fixtures/bargain_seeds.lua`):
  - `S1=0x00C0FFEE`, `S2=0x00BADA55`, `S3=0x00DEADBEEF`
- Fixture action scripts include deal choices when prompted (50–200 actions)
- Expected digests live in `assets/scripts/tests/fixtures/bargain_expected_digests.lua`
- Update rule: changing expected digests requires a short note next to each changed digest explaining the intentional rule change

---

## 7) Milestones (deliverables + acceptance criteria)

### M0 — Wiring + Contract Freeze (unblocks parallel)
Deliver:
- Test hook + aggregator
- Stub modules with correct exports
- Contract tests for schemas, inputs, phase machine, RNG injection, deal gating
Accept:
- `RUN_BARGAIN_TESTS=1 ...` exits `0` on pass, `1` on fail
- Two consecutive test runs produce identical outputs

### M1 — Core Sim Loop (fixed tiny map)
Deliver:
- Grid collision/movement, phase stepping, combat resolution
Accept:
- Unit tests for grid/turn/combat pass
- Smoke test: player kills 1 enemy on a fixed 5×5 map without desync

### M2 — FOV + Floors invariants (bounded deterministic procgen)
Deliver:
- FOV occlusion + memory model
- Floor generator meets invariants for floors 1–7
Accept:
- FOV/floors tests pass
- No unbounded loops; deterministic per seed

### M3 — Deals (21) + downside enforcement (content gate)
Deliver:
- Forced floor-start offer; optional level-up offer
- All 21 deals implemented with benefits + test-visible downsides
- 21-row downside enforcement suite passes
Accept:
- Data loading proves 21 stable IDs, no dupes, all sins present
- Offer rule tests pass + 21/21 downsides pass

### M4 — Enemies + Boss + Win/Lose transitions
Deliver:
- Enemy templates + deterministic chase/attack
- Boss on floor 7; victory/death + restart
Accept:
- AI unit tests pass
- Boss defeat sets `run_state="victory"`
- Player HP ≤ 0 sets `run_state="death"`

### M5 — Minimal UX flows (no sim logic)
Deliver:
- Deal modal (forced vs optional)
- HUD (HP/stats/deals/floor/turn)
- Victory/death screens + restart
Accept:
- Manual checklist with exact steps recorded (seed, actions, expected screens)

### M6 — Full-run determinism gate (S1–S3)
Deliver:
- Digest implementation + fixtures + scripted input runner
- Full 7-floor deterministic scripts for `S1,S2,S3`
Accept:
- Determinism tests pass for `S1,S2,S3` reliably

### M7 — Balance pass (separate, last)
Deliver:
- `bargain/data/balance.lua` as the single tuning surface
- 3 recorded seeded runs (seed + input script + outcome + duration)
Accept:
- Average completion time ~10–15 minutes
- At least one seed is winnable without debug hooks

---

## 8) Parallel Work Plan (lanes, dependencies, bead-sized tasks)

### Lanes (can run concurrently after M0)
- Integrator: test hook + aggregator + `bargain/game.lua` bridge
- Sim Core: grid + turn_system + combat
- Procgen/FOV: fov + floors invariants + generator
- AI/Enemies: enemy data + deterministic AI
- Deals/Content: deals core + 7 sin files (3 deals each)
- Determinism: digest + scripted input runner + golden fixtures
- UI: modal/HUD/screens (start after contracts stabilize)

### Bead definition (testable “done”)
- Module bead: implemented + dedicated unit tests + deterministic ordering specified
- Sin bead: one `bargain/data/sins/<sin>.lua` containing 3 deals + 3 downside assertions
- Floors bead: invariants tests first, generator second; bounded seeds covered
- UI bead: one UX flow + manual checklist entry; *no* sim logic changes

### Dependency graph (explicit)
- M0 contracts → (Sim Core, Deals, FOV/Floors, AI, Determinism) in parallel
- (Sim Core + AI + Floors) → integration smoke → determinism golden runs
- UI starts once contracts + offer flow are stable
- Balance last (after M6 determinism gate)

---

## 9) Risks and Mitigations (keep determinism stable)

- Lua table iteration nondeterminism → ban in critical paths; use sorted arrays everywhere
- Hidden randomness/time in UI/bridge → enforce via determinism golden tests
- Hook callback order drift → store hooks in arrays; never iterate maps for execution
- Procgen infinite loops → invariants + explicit iteration caps + failing tests on cap hit
- Deal downsides “not actually negative” → require table-driven scripted assertions that flip outcomes

---