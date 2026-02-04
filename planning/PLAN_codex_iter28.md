# Game #4 “Bargain” — Engineering Plan (v16: contract-first, CI-gated determinism, parallel workstreams)

## 0) Outcome (what we’re shipping)
**An MVP that always produces a terminal outcome** for a **deterministic, replayable 7-floor run** where **Bargains are the primary progression mechanic**.

**Hard success criteria (all true):**
- Same `(seed, script_id)` ⇒ same **terminal outcome** + same **digest**.
- Runs always end in `victory` or `death` (no softlocks), with deterministic caps.
- CI exposes failures as a **single machine-parseable repro line** (JSON), with enough context to replay locally.

---

## 1) One proof command (local + CI)
### 1.1 Command sequence (required)
1. Build: `just build-debug-fast`
2. Headless tests: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### 1.2 Pass/Fail contract
**Pass =** exit code `0`, and:
- **Headless guarantee:** no window created; no render loop entered.
- All Bargain test suites pass.

**Fail =** exit code non-zero, and:
- stdout contains **exactly one** single-line JSON repro payload (see §8).

> Implementation note (decision gate): if `assets/scripts/core/main.lua` is not executed before window init, move the `RUN_BARGAIN_TESTS` early-exit into the C++ entrypoint. This is non-negotiable for “no window” CI.

---

## 2) CI gates (must be objective and cheap)
| Gate | What it proves | How CI checks it |
|---|---|---|
| A Determinism | identical digest for same input | run each case twice; compare digest strings |
| B Termination | no infinite loops / softlocks | assert `run_state ∈ {"victory","death"}` |
| C Deals catalog | stable IDs + full set | `count=21`, unique IDs, `7 sins × 3` complete |
| D Downside enforcement | every deal has measurable downside | baseline vs applied flips ≥1 metric |
| E No nondeterminism | no hidden randomness / iteration drift | static scan + runtime assertions in sim |
| F Repro fidelity | failures are actionable | exactly one JSON repro line on failure |

---

## 3) Parallelization strategy (contract-first boundary)
### 3.1 Layering rule (enforced)
- **Sim layer (deterministic):** world state, RNG, rules, deals, AI, procgen/FOV, digest, scripts/replay.
- **UI/engine layer (nondeterminism allowed):** rendering + input collection only.

**Rule:** UI can only emit `input` to `step(world, input)` and must never mutate `world` directly.

### 3.2 “Hot” files (integrator-owned, minimized)
- `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua`

Everything else must land in workstream-owned directories to keep merges parallel (see §7).

---

## 4) Frozen interfaces (contract-tested; unlocks parallel work)
### 4.1 World schema (minimum stable fields)
Required:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (integer; deterministic increments)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (only RNG)
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (append-only array)
- `world.deals.pending_offer` (`nil | offer`)
- `world.caps_hit` (bool)

Allowed debug-only (must not affect outcomes):
- `world.events` (append-only)
- `world.messages` (append-only)

### 4.2 Entity schema (minimum stable fields)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`
- `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministically serialized set)
- `hooks` (`hook_name -> array`, stable order)

### 4.3 Offer schema (order is stable; no unordered iteration)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order)
- `must_choose: bool`
- `can_skip: bool`

### 4.4 Input API (exact set)
`step(world, input)` accepts:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

**Invalid input semantics (frozen):**
- returns `{ok=false, err="..."}`
- consumes actor’s turn
- never crashes; preserves invariants; deterministic

### 4.5 Phase machine (table-driven, test-locked)
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- forced offers pin `DEAL_CHOICE` until resolved
- enemy order: `speed desc`, tie-break `id asc`
- canonical direction order: `N, E, S, W` (no diagonals for MVP)

---

## 5) Determinism + termination enforcement (explicit mechanics)
### 5.1 RNG rule
Only `world.rng` may be used in sim. Forbidden in sim:
- `math.random`, time-based seeds, frame `dt`, engine globals, unordered iteration affecting outcomes

### 5.2 Iteration rule
No gameplay-critical `pairs()` / `next()` in sim-critical modules. Collections that matter must be:
- arrays in fixed order, or
- explicitly sorted with deterministic comparator + tie-breakers.

### 5.3 Deterministic caps (terminal on breach)
Constants (contract-tested):
- `MAX_INTERNAL_TRANSITIONS = 64`
- `MAX_STEPS_PER_RUN = 5000`
- bounded procgen attempt caps per floor, with deterministic fallback

On cap trip:
- `world.caps_hit=true`
- force terminal `world.run_state` (default `"death"`)
- emit repro payload (§8)

---

## 6) Test plan (files + explicit assertions)
### 6.1 Runner contract
Entry: `assets/scripts/tests/run_bargain_tests.lua`
- uses existing `describe/it/expect`
- stable stdout; on failure prints **exactly one** repro JSON line
- exit `0` on success; non-zero on any failure

### 6.2 Required suites (each maps to a CI gate)
**Contracts & harness**
- `assets/scripts/tests/bargain/contracts_spec.lua`
  - schema validation, phase rules, invalid-input semantics, cap behavior
- `assets/scripts/tests/bargain/determinism_static_spec.lua`
  - static scan bans nondeterministic APIs + bans `pairs()` in sim-critical scopes (explicit allowlist for non-sim paths)
- `assets/scripts/tests/bargain/digest_spec.lua`
  - digest stability across reruns + digest versioning rules + stable serialization checks

**Core behavior**
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
  - tiny fixed map: move/attack loop terminates; digest stable
- `assets/scripts/tests/bargain/ai_spec.lua`
  - deterministic targeting + tie-breaks + action order

**Worldgen & visibility**
- `assets/scripts/tests/bargain/floors_spec.lua`
  - fixed seed set: stairs reachable, connectivity/spawn invariants, deterministic fallback on cap
- `assets/scripts/tests/bargain/fov_spec.lua`
  - golden visible-set tests on canonical maps

**Deals**
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
  - exactly 21 deals, unique IDs, sins×3 coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`
  - 21 rows; each asserts ≥1 downside metric flips

**End-to-end determinism**
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
  - scripted full runs + golden digests; double-run determinism; terminal state assertion

### 6.3 Golden protocol (minimize churn)
Goldens under `assets/scripts/tests/bargain/goldens/**`
- Any golden update must include:
  - updated golden file(s)
  - a 1-line rationale adjacent to the golden
  - proof: two consecutive runs match for same `(seed, script_id)`

---

## 7) Workstreams (parallel, low-collision ownership)
### 7.1 Ownership table (exclusive edit zones)
| Stream | Owns | Produces | Depends on |
|---|---|---|---|
| Integrator (I) | `assets/scripts/core/main.lua`, `assets/scripts/tests/run_bargain_tests.lua` | headless early-exit + runner wiring + repro emission | none |
| Core Sim (C) | `assets/scripts/bargain/sim/**` | `step()`, caps, invariants, events/messages | I contracts |
| Digest/Scripts (R) | `assets/scripts/bargain/sim/digest/**`, `assets/scripts/tests/bargain/digest_spec.lua`, `assets/scripts/tests/bargain/run_scripts_spec.lua`, `goldens/**` | digest + replay scripts + goldens | C schema |
| Floors/FOV (F/V) | `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**` | procgen + FOV + invariants + goldens | C schema |
| Deals (D) | `assets/scripts/bargain/data/deals/**`, `assets/scripts/bargain/deals/**` | offers + apply hooks + 21 deals + downside metrics | C + R |
| Enemies/Boss (A) | `assets/scripts/bargain/enemies/**`, `assets/scripts/bargain/ai/**` | enemy templates + AI + boss + victory condition | C |
| UI Bridge (UI) | UI layer only | deal modal + HUD + victory/death screens mapping to inputs | C input API |

### 7.2 Merge strategy (keeps streams unblocked)
1. Land **contracts + stubs + harness** first (tests can assert “stub behavior” initially).
2. Each stream implements behind the frozen interfaces, touching only its owned paths.
3. Integrator resolves cross-stream wiring only in the two hot files.

---

## 8) Failure repro bundle (single JSON line, always)
### 8.1 Output contract
On any failure:
- print **exactly one** JSON object on a single stdout line
- exit non-zero

### 8.2 Minimum payload (must be sufficient to replay)
- `seed`, `script_id`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20; deterministic order)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional `world_snapshot_path` (only if deterministic serialization is guaranteed)

### 8.3 Snapshot rules (if enabled)
- deterministic filename from `(seed, script_id, turn)`
- serializer enforces stable key ordering (no raw table iteration order)

---

## 9) Milestones (each ends with CI-green proof command)
### M0 — Harness + contracts (unblocks everything)
**Deliverables**
- Headless early-exit path (`RUN_BARGAIN_TESTS`), guaranteed before any window init
- Test runner + repro JSON emission
- `contracts_spec.lua` + minimal `sim_smoke_spec.lua` green (even with sim stubs)

**Exit tests**
- proof command passes
- explicit test that window init is not called in headless mode

### M1 — Core sim loop + caps + digest v1 baseline
**Deliverables**
- deterministic `step()` loop with caps + terminal enforcement
- digest v1 + stable serialization rules

**Exit tests**
- `sim_smoke_spec.lua` covers move/attack/enemy acts/terminal outcome
- `digest_spec.lua` proves “same case twice ⇒ same digest”

### M2 — Floors + FOV invariants
**Deliverables**
- procgen with reachability guarantee or deterministic fallback on cap
- FOV + canonical golden maps

**Exit tests**
- `floors_spec.lua` green on a committed bounded seed list
- `fov_spec.lua` goldens green

### M3 — Deals system + 21 deals + downside enforcement
**Deliverables**
- offer generation at `floor_start` + `level_up`
- deal apply plumbing (hooks)
- 21 deals with stable IDs + measurable downsides

**Exit tests**
- `deals_loader_spec.lua`: 21 unique IDs, sins×3
- `deals_downside_spec.lua`: 21/21 flips ≥1 metric (see §10)

### M4 — Enemies + boss + explicit victory/death
**Deliverables**
- deterministic enemy templates + chase/attack AI
- boss + victory condition on floor 7

**Exit tests**
- scripted tests include at least one `victory` and one `death`
- `ai_spec.lua` asserts ordering + tie-breakers

### M5 — Minimal UI bridge (sim unchanged)
**Deliverables**
- deal UI modal maps to `deal_choose` / `deal_skip`
- HUD + victory/death screen + restart

**Exit checks**
- manual smoke checklist on a known `(seed, script_id)`
- static scan/allowlist proves no sim logic leaks into UI scope

### M6 — Full-run scripts + determinism goldens
**Deliverables**
- scripts `S1,S2,S3` (fixed input sequences hitting meaningful mechanics)
- golden digests for each `(seed, script_id)`

**Exit tests**
- `run_scripts_spec.lua` green
- CI gates A+B green for all cases (double-run + terminal state)

---

## 10) Deals catalog contract (stable IDs + downside metrics)
### 10.1 IDs and cardinality
- ID format: `<sin>.<index>` (e.g., `wrath.1`)
- Exactly `7 sins × 3 deals = 21`
- After Gate C is green: **append-only** (no renames/remaps; only additive beyond MVP)

### 10.2 Downside definition (must be precise + shared by tests)
For each deal, run the same deterministic script twice:
- baseline: never apply
- applied: apply at earliest legal moment

Assert ≥1 metric flips:
- `hp_lost_total`
- `turns_elapsed`
- `damage_dealt_total` / `damage_taken_total`
- `kills_required` (when relevant)
- `visible_tiles_count` (FOV)
- `forced_actions_count` / `denied_actions_count` (input constraints)

---

## 11) Risk register (only mitigations that are test-backed)
- Lua iteration nondeterminism → ordered iteration helpers + `determinism_static_spec.lua`
- Hidden randomness/time in UI/engine → headless suite never boots UI; static scan bans time/RNG in sim scopes
- Procgen infinite loops/unreachable stairs → attempt caps + invariants tests + deterministic fallback + repro payload
- “Downside is toothless” → downside metric flip required for every deal
- Golden churn → digest versioning + per-golden rationale + double-run proof requirement

---

## 12) Beads (bd) workflow integration (how work is tracked)
For each milestone, split into bead-sized units with a named exit test (suite + file). Each bead must:
1. BV triage what’s ready
2. Claim bead (set `in_progress`)
3. Implement + tests
4. Close bead + notify via Agent Mail (touched contracts, suites to rerun, any golden changes)

Per-bead operational rules:
- reserve owned paths (exclusive) before edits
- land code + tests together
- keep PRs atomic to one stream unless it’s Integrator wiring