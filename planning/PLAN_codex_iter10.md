# Game #4 “Bargain” — Engineering Plan (vNext: specific, testable, parallel-first)

## 1) Outcome, Ship Gates, Definition of Done

### Product goal (one replayable vertical slice)
A deterministic, replayable 7-floor run loop:
- Floors 1–6: explore/combat → reach stairs
- Floor 7: boss (“Sin Lord”) → victory on defeat
- Death → game-over → restart → new seeded run
- Target run length: 10–15 minutes (balance last)

### Hard ship gates (must be true to ship)
- **No crash / no softlock:** For seeds `S1,S2,S3`, each run reaches **victory or death** with **0 crashes** and **0 softlocks**.
- **Deals rule correctness:**
  - At **every floor start:** a **forced** deal is shown (`must_choose=true`, `can_skip=false`) and sim cannot advance until chosen.
  - At **every level-up:** an **optional** deal is shown (`must_choose=false`, `can_skip=true`) and play continues on skip.
- **Content completeness:** exactly **21 deals** exist (7 sins × 3), with stable IDs.
- **Downside enforcement:** **21/21 downsides are asserted by automated tests** (≥1 robust assertion per deal that fails if downside is removed).
- **Determinism:** fixed `seed + scripted inputs` produces a stable **digest** across machines.

---

## 2) Constraints / Non-goals (locked)

### Gameplay constraints
- Turn-based, grid-based, FOV-limited exploration/combat.
- Player verbs: `Move` (4-way), `Attack` (directional), `Wait`.
- Enemy AI: deterministic chase + attack (no A*; BFS/distance field allowed).

### Non-goals
- No inventory/items/shops
- No save/load
- No meta-progression

### Engineering constraints
- All gameplay rules in **pure Lua sim** (no engine globals, rendering, IO, time).
- UI is a thin adapter: render from `world`, translate input → sim actions.
- All randomness via **one injected RNG** owned by sim (`world.rng`).

---

## 3) Repo Wiring + Ownership Rules (parallel-safe)

### Run modes
- `AUTO_START_BARGAIN=1` → auto-enter Bargain loop (highest precedence)
- Manual entry remains: `require("bargain.game").start()`

### Test runner integration (binary-driven)
- Reuse `assets/scripts/tests/test_runner.lua`.
- Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua`:
  - runs early, exits via `os.exit(0|1)`
  - invokes `require("tests.run_bargain_tests").run()`

Command:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### Hot-file policy (prevents merge fights)
- Only the “Integrator” bead edits `assets/scripts/core/main.lua`.
- Everyone else only adds/edits under:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/**` (except shared runner only by Integrator)

---

## 4) Architecture + “Contract Freeze” (M0 locks interfaces)

### Folder layout
- `assets/scripts/bargain/sim/` — pure deterministic simulation
- `assets/scripts/bargain/data/` — tables + `apply(world, player_id)` only
- `assets/scripts/bargain/ui/` — rendering + input + deal modal
- `assets/scripts/bargain/tests_support/` — fixtures/helpers for tests
- `assets/scripts/tests/` — `test_bargain_*.lua`, plus `run_bargain_tests.lua`

### Contract Freeze: world schema (tests enforce required shape)
Required:
- `world.grid`
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (string enum)
- `world.floor_num` (1–7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (single RNG)
- `world.deals.applied` (deal_id → true)
- `world.deals.history` (ordered `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended (adopt once → frozen):
- `world.stairs` (`{x,y}` or nil)
- `world.messages` (append-only deterministic structs)
- `world.debug_flags` (tests-only; must not affect release determinism)

### Deal offer struct (frozen)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers` = array of deal IDs (**stable order**, no table iteration)
- `must_choose` (bool)
- `can_skip` (bool)

### Entity schema (frozen)
Required:
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministic map)
- `hooks` (hook_name → array of callbacks; callback order stable)

### Action encoding + invalid action behavior (frozen)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid action policy (tests enforce):
- Return `{ok=false, err="..."}` and **consume actor’s turn** (deterministic).

### Phase machine (frozen)
Phases:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`

Rules:
- If `pending_offer.must_choose=true`, sim stays in `DEAL_CHOICE` until a deal is chosen.
- Enemy order deterministic: sort by `speed`, tie-break by `id`.

---

## 5) Module APIs (each ships with its tests)

Each bead implements **one module + its tests**; tests define semantics so UI doesn’t invent rules.

- `bargain/sim/grid.lua`: movement, occupancy invariants, stable neighbor order.
- `bargain/sim/turn_system.lua`: phase stepping + deal gating + deterministic enemy order.
- `bargain/sim/combat.lua`: attack resolution with frozen damage semantics (RNG only via `world.rng`).
- `bargain/sim/fov.lua`: occlusion + memory (`VISIBLE → SEEN`).
- `bargain/sim/floors.lua` + `bargain/data/floors.lua`: `generate(...)` with invariant tests (not layout snapshots).
- `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`: deterministic chase/attack with explicit tie-breaks.
- `bargain/sim/deals.lua` + `bargain/data/sins/*.lua`: 21 stable deals + offer rules + apply rules.

Integrator-owned:
- `bargain/game.lua`: orchestrates sim + UI bridge; optional deterministic debug hooks.

---

## 6) Test Strategy (fast, deterministic, downside-enforcing)

### Required test modules (minimum set)
- `test_bargain_grid.lua`
- `test_bargain_turn_system.lua`
- `test_bargain_combat.lua`
- `test_bargain_fov.lua`
- `test_bargain_enemy_ai.lua`
- `test_bargain_deals.lua` (offer rules + 21-row downside table)
- `test_bargain_data_loading.lua` (21 deals, stable IDs, no dupes)
- `test_bargain_floors.lua` (invariants only)
- `test_bargain_game_smoke.lua` (multi-floor minimal run)
- `test_bargain_determinism.lua` (digest gate)

### Fixture rules (keeps tests stable)
- Unit tests use tiny hand-authored maps (no procgen).
- Procgen tests are invariants-only with bounded seeds.
- No rendering, no frame timing, no OS/time calls.

### Mandatory downside enforcement pattern (table-driven)
For each of 21 deals:
- Setup minimal `world` + `player`.
- Apply deal.
- Execute 1–3 sim steps/actions.
- Assert an observable gameplay downside (e.g., stat penalty changes combat outcome, per-turn drain triggers after `END_TURN`, action restriction yields `{ok=false,...}` and consumes turn, self-damage triggers on move/attack, XP reduction changes level-up timing).

---

## 7) Determinism Digest (precise spec; test-owned)

### Digest contents (stable order; no table iteration)
Serialize:
- `floor_num`, `turn`, `phase`, `run_state`
- player: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: `(id,kind,x,y,hp,flags_subset)` sorted by `id`
- applied deal IDs sorted lexicographically

### Determinism rules (tests enforce)
- Never rely on Lua table iteration for digest/offers.
- Explicit ordering for offers, AI tie-breaks, enemy processing.
- Only `world.rng` provides randomness (`math.random`, time, OS forbidden).

### Scripted input determinism test
- Provide action lists (50–200 actions) that also choose deals when prompted.
- Gate: `seed + actions → digest == expected` for `S1,S2,S3`.

---

## 8) Milestones (deliverables + exact acceptance)

### M0 — Wiring + Contract Freeze (unblocks parallel work)
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `assets/scripts/tests/run_bargain_tests.lua`
- stubs with correct exports
- contract tests for world schema, action encoding, phase machine, offer gating  
Accept:
- `RUN_BARGAIN_TESTS=1 <binary>` exits `0` on pass, `1` on fail
- two consecutive runs produce identical results

### M1 — Core Sim Loop on tiny fixed map
Deliver:
- grid movement/collision, phase loop, combat resolution  
Accept:
- `grid/turn/combat` tests pass
- smoke: fixed 5×5 map, player can kill one enemy without desync

### M2 — FOV + Floors invariants (deterministic bounded gen)
Deliver:
- FOV occlusion + memory
- floor generator meets invariants for floors 1–7  
Accept:
- `fov/floors` tests pass
- generation has no unbounded loops; deterministic for fixed seed

### M3 — Deals (21) + 21/21 downside tests (content ship gate)
Deliver:
- forced floor-start offer; optional level-up offer
- all 21 deals implemented with real benefits + test-visible downsides
- 21-row downside enforcement table  
Accept:
- data loading proves 21 stable IDs, no dupes, all sins present
- deal tests prove offer rules + 21/21 downside enforcement

### M4 — Enemies + Boss + Win/Lose
Deliver:
- enemy templates + chase/attack AI
- boss on floor 7
- victory/death transitions  
Accept:
- AI tests pass
- boss defeat → `run_state="victory"`
- player HP ≤ 0 → `run_state="death"` and restart works

### M5 — UI Flows + Minimal UX
Deliver:
- deal modal (forced vs optional skip)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart  
Accept:
- short manual checklist note recorded (and optionally a UI smoke test)

### M6 — Determinism Hardening (digest gate)
Deliver:
- stable orchestrator in `bargain/game.lua` (no hidden time/randomness)
- full-run scripted tests for `S1,S2,S3`
- digest expectations for `S1,S2,S3`  
Accept:
- full-run smoke passes for `S1,S2,S3`
- digest matches expected across two machines

### M7 — Balance Pass (time-to-complete target)
Deliver:
- `data/balance.lua` single tuning surface
- 3 timed seeded runs recorded (inputs + outcome + duration)  
Accept:
- average completion time ~10–15 minutes
- at least one seed winnable without debug hooks

---

## 9) Parallel Work Breakdown (Beads-ready)

### Work lanes (low merge conflict, clear contracts)
- **Integrator/Wiring:** main hook, test aggregator, `bargain/game.lua` bridge
- **Sim Core:** `grid`, `turn_system`, `combat`
- **Procgen/FOV:** `fov`, `floors` invariants + generator
- **AI/Enemies:** `enemy_ai`, `enemies` data
- **Deals/Content:** `deals` core + 7 “sin beads” (3 deals each + 3 downside assertions)
- **Determinism Harness:** `digest` + scripted input helpers + determinism tests
- **UI:** deal modal + HUD + screens (after sim contracts stable)

### Bead templates (definition)
- **Module bead:** implement one module + its dedicated test file(s).
- **Sin bead:** implement `bargain/data/sins/<sin>.lua` (3 deals) + 3 downside rows in `test_bargain_deals.lua`.
- **Floors bead:** add/adjust invariants + generator changes + invariants tests.
- **UI bead:** one UX flow + (optional) smoke automation + a short checklist note.

### Dependency graph (simple)
- M0 → (Sim Core, Deals scaffold, FOV/Floors, AI, Digest harness) in parallel  
- (Sim Core + Deals + Floors + AI) → smoke run → determinism gate → UI → balance

---

## 10) Coordination Rules (multi-agent + Beads)
- Use BV to identify ready beads; claim a bead (`in_progress`) before starting.
- Reserve files (exclusive) before edits; keep hot files integrator-only.
- Contract changes: update tests first → module updates → integrator updates → notify dependents via Agent Mail.
- Keep beads small and mergeable: “one module / one sin / one UI feature.”