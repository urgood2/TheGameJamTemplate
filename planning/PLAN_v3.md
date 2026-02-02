# Master Implementation Plan — Demo Content Spec v3 (v3 Revision)

> **Revision Notes (v3):** This revision builds on v2's determinism foundation by adding replay robustness, RNG discipline, and debuggability infrastructure. Key changes from v2:
> - **CommandStream** (semantic commands) replaces raw input capture — replays survive UI changes
> - **Explicit Determinism Tier** defined (Tier A required for v3, Tier B deferred)
> - **SimClock hardening** with spiral-of-death protection + replay config validation
> - **Entity Identity Contract** — monotonic eids, never reused, with `entity_kind` for tracing
> - **EventBus deferred dispatch** — nested emits complete after current dispatch finishes
> - **RNG Streams formalized** — named streams, explicit `rng` passing, `math.random` forbidden
> - **DamageSystem as pipeline** — `DamageContext`, modifier registry, `damage_taken` event
> - **Skill immediate execution** — origin-tagged events excluded from triggering snapshot (responsive skills without feedback loops)
> - **status_removed event** + payload `reason` field for cleaner status event contract
> - **CardPipeline versioning** — `deck_hash` includes `content_build.build_hash` + `card_pipeline_version`
> - **Lifecycle scoping** — `name`/`domain` metadata for leak hunting + `dump()` helper
> - **Trace hashing + diff tool** — standardized trace hash spec, trace_diff.lua, golden replay CI gate
> - **ReactionSystem proc guards** — max reactions per frame, cooldowns, stable ordering
> - **ContentRegistry migrations** — deprecated ID mapping, warnings list
> - **Codex UI** + surfaced run_seed for player/tester sharing
> - **Agent F (Tools + QA)** — dedicated owner for determinism tooling

---

## 1) Goals & Deliverables

Ship the complete Demo Content Spec v3 as a cohesive, data-driven feature set:

- **Identity:** 4 gods + 2 classes selectable at run start
- **Combat:** melee arc support + status stack decay
- **Skills:** 32 skills (8 per element) with element-lock + multi-trigger support
- **Forms:** 4 timed transformation forms with aura ticking
- **Cards/Wands:** starter wands + 6 shop wands; ~40 cards (at minimum: 12 modifiers + 16 elemental actions + required starter actions)
- **Items:** 15 artifacts + 12 equipment pieces
- **Economy/Progression:** skill points by level + stage-based shop inventory (equipment → wands → artifacts)
- **Engineering:** compiled content registry + deterministic simulation + replay/debug tooling
  - seeded RNG streams (formalized, named, explicit passing)
  - fixed-step sim with spiral-of-death protection
  - **semantic command capture** + replay runner (dev-only OK)
  - deterministic ordering rules enforced (Lua-safe)
- **UX:** Codex UI (skills/cards/items/statuses/forms) + surfaced run_seed for sharing/debug

### 1.1 Determinism Tier (explicit)

Define determinism tier up front to avoid false expectations:

- **Tier A (required for v3):** deterministic within the same engine build + same content_build + same replay_version
- **Tier B (nice-to-have later):** deterministic across engine builds (requires stricter floating-point/physics constraints)

---

## 2) Canonical Contracts (Naming, IDs, Events, Update Order)

### 2.0 Content Registry + Schema Versioning

All data modules (skills/cards/wands/items/statuses/avatars) declare `schema_version = 3` and are loaded through a single compiler:

- `assets/scripts/core/content_registry.lua`
  - builds `{ list, by_id, id_to_idx }` per content type
  - **assigns stable integer `idx`: sort by string ID before assigning idx** (no file-order dependence)
  - performs reference linking (wand templates → card defs, starter loadouts → items, etc.)
  - hard-fails with actionable errors (no silent nil fall-through)
  - emits `content_build = { schema_version, build_hash, id_maps, sim_dt, engine_build }`
  - **supports migrations:**
    - `assets/scripts/core/content_migrations.lua`
    - maps deprecated IDs → canonical IDs (skills/cards/items/statuses)
    - supports "deleted" IDs with actionable errors ("replay references removed content: ...")
  - **emits warnings list (dev-only)** for non-fatal authoring issues (missing description, no icon, unreachable skill, unused card)
- Centralize authored ID strings in one place for code usage:
  - `assets/scripts/core/ids.lua` (elements, events, status IDs, form IDs, equipment slots, tiers)

**Save/replay rule:** store string IDs in persisted data; resolve to idx at runtime via registry mapping.

---

### 2.1 Canonical IDs & Naming

- IDs are string keys in data/UI, but runtime systems should prefer registry indices (`idx`) once content is compiled.
- **Elements:** `fire`, `ice`, `lightning`, `void`, `physical`
- **God IDs:** `pyr`, `glah`, `vix`, `nihil`
  - allow `"nil"` as a deprecated alias resolved by ContentRegistry (backwards compatibility)
- **Class IDs:** `channeler`, `seer`
- **Statuses (stacking model):** `scorch`, `freeze`, `charge`, `doom`, `inflame`
  - Each status definition includes: `max_stacks`, `stack_mode` (add/refresh/replace), `decay{interval, stacks_per_tick}`, `tags[]`
- **Forms (timed):** `fireform`, `iceform`, `stormform`, `voidform`
- **Cards:**
  - Modifiers: `MOD_*`
  - Actions: `ACTION_*`
- **Wands:** `WandTemplates.*` keys are **UPPER_SNAKE_CASE**
  - Starters: `VOID_EDGE`, `SIGHT_BEAM`
  - Shop wands: `RAGE_FIST`, `STORM_WALKER`, `FROST_ANCHOR`, `SOUL_SIPHON`, `PAIN_ECHO`, `EMBER_PULSE`

---

### 2.2 Event Contract (SkillSystem + items depend on this)

Define and emit a stable set of gameplay events via a thin EventBus adapter (can wrap existing `signal`).

#### 2.2.1 EventBus API (authoritative)

- `EventBus.begin_frame(frame, t)`
  - resets `seq=0`
  - resets per-frame buffers (if used)
- `EventBus.emit(type, payload)`
  - increments `seq`
  - constructs `Event = { type, frame, seq, t, phase, payload }`
  - **if called during dispatch:** event is queued and dispatched after current event completes
  - returns the `Event`
- `EventBus.emit_deferred(type, payload)`
  - same as emit, but explicitly guarantees dispatch occurs after current dispatch completes
  - EventBus internally treats all emits during dispatch as deferred for safety
- `EventBus.set_phase(phase)`
  - sets current phase for debugging: `"movement"`, `"combat"`, `"status"`, `"skills"`, `"cleanup"`
- `EventBus.connect(type, handler, opts)`
  - `opts.priority` (higher runs earlier), default `0`
  - ties are stable by registration order
  - **all connections must go through Lifecycle** (see 2.4), which enforces deterministic connect paths

**Rules:**
- Events are **immutable facts**:
  - listeners MUST NOT mutate `Event` or `payload`
  - dev-only: freeze event/payload via metatable to error on writes
- Events are **not cancellable** and do not support stop-propagation.
- `emit()` during dispatch is allowed but **dispatch is deferred** until current event completes.

#### 2.2.2 Event Envelope (all events use this structure)

```lua
Event = {
    type = "event_name",
    frame = number,      -- sim frame number
    seq = number,        -- per-frame sequence for deterministic ordering
    t = number,          -- sim time (accumulated fixed-step time)
    phase = string,      -- optional: system phase for trace/debug
    payload = { ... }    -- event-specific data
}
```

**Entity References:** Always use `source_eid` / `target_eid` (stable entity IDs), never live table references.

**Entity ID Contract:**
- `eid` is a monotonic integer assigned at spawn; **never reused within a run**
- despawned eids are never reassigned
- payload may include `source_kind` / `target_kind` for trace readability (e.g., `"player"`, `"enemy"`, `"projectile"`, `"pickup"`)

#### 2.2.3 Standard Payload Shapes

```lua
payload.damage = {
    amount = number,
    element = string,
    is_dot = bool,
    is_crit = bool,
    tags = {},           -- e.g., {"melee", "skill"} for filtering
    damage_id = string,  -- unique per damage instance
    source_kind = string -- "wand", "skill", "aura", "item", "reaction"
}

payload.status = {
    id = string,
    new_stacks = number,
    old_stacks = number,
    source_eid = entity_id,   -- who caused the change (or nil if system/decay)
    reason = string           -- "apply"|"refresh"|"decay"|"cleanse"|"expire"
}

payload.hit = {
    damage = { ... },    -- damage payload
    position = vec2,
    knockback = vec2 or nil
}

payload.kill = {
    final_damage = { ... },
    overkill = number
}
```

#### 2.2.4 Canonical Events (envelope-only)

All emitted via `EventBus.emit(type, payload)`:

- `player_hit_enemy` — `{ source_eid, target_eid, hit = { ... } }`
- `damage_dealt` — `{ source_eid, target_eid, damage = { ... } }`
- `damage_taken` — `{ source_eid, target_eid, damage = { ... } }` *(NEW: target-side view for "when you take damage" passives)*
- `enemy_killed` — `{ source_eid, target_eid, kill = { ... } }` *(killer is source, enemy is target)*
- `player_damaged` — `{ source_eid, target_eid, damage = { ... } }` *(damager is source, player is target)*
- `status_applied` — `{ target_eid, status = { ... } }`
- `status_stack_changed` — `{ target_eid, status = { ... } }`
- `status_removed` — `{ target_eid, status = { id, old_stacks, source_eid, reason } }` *(NEW)*
- `wave_start` — `{ wave_index = number }`
- `frame_end` — `{ frame = number }`
- `form_activated` — `{ target_eid = entity_id, form_id = string }`
- `form_expired` — `{ target_eid = entity_id, form_id = string }`

**Dev-Only Introspection Events (can be compiled out):**
- `wand_triggered` — `{ wand_id, owner_eid, trigger_type }`
- `skill_fired` — `{ skill_id, player_eid, reason = { ... } }`
- `item_procced` — `{ item_id, owner_eid, reason = { ... } }`
- `reaction_triggered` — `{ reaction_id, source_eid, target_eid, reason = { ... } }`

---

### 2.5 Command Contract (NEW, replay-critical)

Introduce a semantic command stream consumed by simulation:

- `assets/scripts/core/command_stream.lua`
  - `CommandStream.begin_frame(frame)` — reset per-frame buffer
  - `CommandStream.push(cmd)` — assigns `(frame, seq)` and stores in per-frame buffer
  - `CommandStream.get_frame_commands()` — returns stable-ordered list (by seq)

Commands are plain tables with a strict schema (validated dev-only):

```lua
cmd = { type="move", x=number, y=number }
cmd = { type="aim", x=number, y=number }
cmd = { type="trigger_wand", slot=number }
cmd = { type="learn_skill", skill_id=string }
cmd = { type="shop_buy", offer_index=number }
cmd = { type="shop_reroll", lock_offer_index=number|nil }
cmd = { type="select_god_class", god_id=string, class_id=string }
```

**Replay rule:** record CommandStream (plus run_seed + content_build + sim_dt + replay_version), not raw input device states.

**Why semantic commands?**
- Raw inputs (keys/mouse) are tied to UI layout, frame timing, and platform quirks
- UI changes (button reorder, focus changes) break raw-input replays
- Semantic commands are UI-agnostic intent that survives refactoring

---

### 2.3 Update Order (single source of truth in main loop) — CRITICAL

Wire the runtime to guarantee deterministic behavior. The order below is mandatory for correct multi-trigger skill resolution.

#### 2.3.1 Determinism requirement: fixed-step simulation

- Gameplay systems run on fixed `sim_dt` (e.g. 1/60).
- Render dt is accumulated and drives `N` sim steps per render frame.
- **Clamp catch-up to avoid spiral-of-death:**
  - `max_sim_steps_per_render = 4` (tunable)
  - `max_accumulator = sim_dt * max_sim_steps_per_render`
  - if exceeded: drop excess with a dev warning counter (and optionally pause replay determinism checks)
- `Event.frame` refers to **sim frame**, not render frame.

**Replay/build invariants:**
- replay stores `{ sim_dt, max_sim_steps_per_render, run_seed, content_build.build_hash, replay_version }`
- replay invalid if these mismatch current build config (fail fast with message)

#### 2.3.2 Stable iteration rule (critical in Lua)

Any time gameplay applies effects to a set/map of entities, order MUST be deterministic:
- sort by stable `eid` or registry `idx`, OR
- accumulate into array then sort before applying.

#### 2.3.3 Mandatory per-sim-frame order

```
0.  Begin-frame: increment `frame`, EventBus.begin_frame(frame, t), reset per-frame buffers
0.5 CommandStream.begin_frame(frame); map raw input/UI → semantic commands; store in command buffer
1.  Movement/physics integration (produces collisions/overlaps but does not apply damage yet)
2.  TriggerSystem update (distance traveled / stand still / timers) → may enqueue wand triggers
3.  Combat resolution (melee arcs, projectiles, queued wand actions)
4.  Status tick/decay + Aura ticks (MUST occur BEFORE SkillSystem.end_frame)
5.  Skill event capture happens via EventBus listeners during steps 3–4
6.  Exactly once per sim frame: SkillSystem.end_frame() (consumes the sim frame EventBus buffer)
7.  Cleanup (despawn, unregister hooks tied to dead entities, end-of-frame assertions)
8.  UI (render-only)
9.  EventBus.emit("frame_end", { frame = frame }) if desired (or include in step 7)
```

**Invariant:** Any system that can cause `damage_dealt`, `status_*`, or `enemy_killed` MUST run before step 6.

---

### 2.4 Effect Lifecycle Contract (required for reliability)

All passives/triggers (skills, artifacts, equipment, wand triggers, forms) must register via a single lifecycle manager:

- `assets/scripts/core/lifecycle.lua`
  - `Lifecycle.bind(owner_eid, handle, opts)` tracks subscriptions/timers/resources
    - `opts.name` (string) for debugging — identifies what registered it
    - `opts.domain` ("wand"|"artifact"|"equipment"|"skill"|"form") — groups handles for leak hunting
  - `Lifecycle.cleanup_owner(owner_eid)` runs automatically on death/despawn/unequip
  - prevents double-register, supports idempotent re-grant
  - provides helpers:
    - `Lifecycle.on_event(owner_eid, event_type, fn, opts)`
    - `Lifecycle.set_timer(owner_eid, timer_handle)`
    - `Lifecycle.assert_no_raw_connects()` (dev-only)
    - `Lifecycle.dump(owner_eid)` (dev-only): list live handles grouped by domain/name

**Rule:** Content authors never call raw `signal.connect` / timer APIs directly; they go through Lifecycle.

**Example:**
```lua
-- WRONG: raw signal usage leaks handlers
signal.connect("damage_dealt", function(...) ... end)

-- CORRECT: lifecycle-managed with debugging info
Lifecycle.bind(owner_eid, signal.connect("damage_dealt", function(...) ... end), {
    name = "fire_skill_on_damage",
    domain = "skill"
})
-- or use helper:
Lifecycle.on_event(owner_eid, "damage_dealt", function(...) ... end, {
    name = "fire_skill_on_damage",
    domain = "skill"
})
```

---

### 2.6 RNG Contract (NEW, determinism-critical)

Formalize RNG to prevent cross-system randomness coupling:

- `assets/scripts/core/rng.lua`
  - implements deterministic algorithm (PCG32 or xoroshiro128+)
  - **forbid `math.random` in gameplay code** (dev-only runtime check via global hook)
- **Named streams** derived from `run_seed`:
  - `rng_shop` — shop inventory generation, rerolls
  - `rng_loot` — loot drops, item rolls
  - `rng_combat` — damage variance, crit rolls, spread
  - `rng_ai` — enemy behavior randomness
  - `rng_visual` — particles, VFX (can be non-deterministic if desired)
- **Local RNG derivation** for isolated contexts:
  - `rng = Rng.derive("wand", frame, wand_id, trigger_seq)` — unique RNG for each wand trigger
  - prevents "shop reroll changes projectile spread" coupling
- **Card actions and skills take `rng` explicitly** — no hidden `math.random`

```lua
-- WRONG: hidden global RNG coupling
local damage = base_damage * (1 + math.random() * 0.1)

-- CORRECT: explicit RNG stream
local damage = base_damage * (1 + rng:random() * 0.1)
```

---

## 3) Multi-Agent Execution Plan (4–6 agents)

### 3.1 Workstreams

Recommended 6 agents (collapsible to 4):

- **Agent 0 — Core Infrastructure (NEW)**
  - ContentRegistry, EventBus, Lifecycle, SimClock wiring in `main.lua`
  - CommandStream, RNG module
  - Dev-only validators, replay tooling stubs, ordering assertions
- **Agent A — Combat Runtime**
  - `assets/scripts/combat/*` (MeleeArc, DamageSystem, AuraSystem, ReactionSystem integration points)
  - `assets/scripts/wand/wand_actions.lua` (only combat action routing)
- **Agent B — Identity + Run Start UI**
  - `assets/scripts/data/avatars.lua`
  - `assets/scripts/ui/god_select_panel.lua`
  - minimal wiring hooks requested from Agent 0
- **Agent C — SkillSystem Core**
  - `assets/scripts/core/skill_system.lua`
  - `assets/scripts/ui/skills_panel.lua` (lock messaging + point display)
- **Agent D — Cards + Wands Content**
  - `assets/scripts/data/cards/*`
  - `assets/scripts/data/starter_wands.lua`
  - `assets/scripts/core/card_pipeline.lua`
  - `assets/scripts/core/card_eval_order_test.lua`
- **Agent E — Items + Economy**
  - `assets/scripts/data/artifacts.lua`, `assets/scripts/data/equipment.lua`
  - shop core + UI
  - `assets/scripts/core/progression.lua` or existing integration

- **Agent F — Tools + QA (NEW, single throat to choke)**
  - validator + determinism harness + replay runner polish
  - trace hashing + trace diff tool
  - CI gate scripts (headless run + golden replay checks)
  - Codex UI (reads from ContentRegistry)

### 3.2 File Ownership to Avoid Conflicts

- Heavy data edits split into submodules; original entry file is an aggregator:
  - `assets/scripts/data/skills.lua` requires:
    - `assets/scripts/data/skills/fire.lua`
    - `assets/scripts/data/skills/ice.lua`
    - `assets/scripts/data/skills/lightning.lua`
    - `assets/scripts/data/skills/void.lua`
  - `assets/scripts/data/cards.lua` requires:
    - `assets/scripts/data/cards/modifiers.lua`
    - `assets/scripts/data/cards/actions_fire.lua`
    - `assets/scripts/data/cards/actions_ice.lua`
    - `assets/scripts/data/cards/actions_lightning.lua`
    - `assets/scripts/data/cards/actions_void.lua`
    - `assets/scripts/data/cards/actions_physical.lua` (if `ACTION_MELEE_SWING` lives here)
- Only **one** agent touches `assets/scripts/core/main.lua` at a time (Agent 0 owns wiring; others request hook points).

### 3.3 Integration Gates

- No merges until each workstream passes its local smoke checklist.
- Run **UBS** as the final pre-merge gate (repo policy).
- Add **"golden replay" gate** (dev-only OK for v3): at least 1 short replay must pass determinism checks on CI.

---

## 4) Phases, Tasks, Dependencies, Acceptance Gates

## Phase 0 — Audit & Alignment (must complete first)

### 0.1 Combat/Status/Wand/UI Audit
Identify:
- existing StatusEngine API and status storage shape
- wand action dispatch + card evaluation context shape
- current signal/event names already emitted
- shop/progression entrypoints and stage concepts
- how entity IDs/handles work (or add them if missing)
- whether we can inject a `run_seed` at run start

**Output:** short "Integration Notes" doc + confirmed adapter plan (EventBus, DamageSystem use points).

### 0.2 Lock Spec Interpretation (final rule)
Element lock rule (authoritative):
- Player may invest in **up to 3 distinct elements**
- The **first skill learned** in an element marks that element as invested
- After the **third distinct element** is invested, the element set is locked; learning skills from any other element fails with a clear reason

### 0.3 Core Infrastructure (MUST land before Phase 1+)
Implement and wire:
- `content_registry.lua` compile step + hard-fail validation + stable `idx` assignment + `content_build` + migrations support
- `content_migrations.lua` for deprecated ID mapping
- `ids.lua` constants (or generated IDs if desired later)
- `EventBus` adapter with deterministic ordering + `begin_frame()` + deferred emit semantics
- `lifecycle.lua` (bind/cleanup + helpers + name/domain metadata + dump())
- `command_stream.lua` (semantic commands) + schema validator
- `rng.lua` (deterministic RNG module) + named stream policy + math.random guard
- fixed-step sim runner:
  - `assets/scripts/core/sim_clock.lua` with accumulator and `sim_dt`
  - add spiral-of-death clamp configuration + instrumentation counters for dropped time
  - `main.lua` uses `SimClock.step(render_dt)` to run N sim frames
- dev-only assertions:
  - `SkillSystem.end_frame()` called exactly once per sim frame
  - no raw `signal.connect()` usage in content directories (best-effort runtime checks)
  - no `math.random` calls in gameplay code

**Acceptance gate (Phase 0.3):**
- Headless run of 300 sim frames:
  - registry compiles (with migrations applied)
  - EventBus seq increments deterministically
  - Lifecycle cleanup runs on despawn without leaking handlers
  - CommandStream records and replays commands
  - RNG streams produce identical sequences for same seed

---

## Phase 1 — Combat Core (foundation)

### 1.0 DamageSystem (NEW foundation, pipeline architecture)
Add `assets/scripts/combat/damage_system.lua`:
- `DamageSystem.apply(source_eid, target_eid, damageSpec, rng)`:
  - builds an immutable `DamageContext` for deterministic modifiers
  - runs modifier pipeline (initially passthrough; resist/crit are future fields):
    - `build_context()` — construct immutable context
    - `run_modifiers()` — stats, crit, resist, tags (modifier registry with priority ordering)
    - `apply_hp()` — apply final HP changes
    - `emit_events()` — emit canonical events
  - assigns `damage_id`
  - emits canonical events:
    - `damage_dealt`
    - `damage_taken` (NEW) `{ source_eid, target_eid, damage = { ... } }`
    - `player_damaged` if target is player
    - `enemy_killed` if target dies
- enforces stable ordering for AoE/multi-hit: sort target eids before applying.

**Damage modifier hooks (deterministic):**
- `DamageSystem.register_modifier(id, fn, opts)` — ordered by `(opts.priority, id)`
- used by equipment/artifacts/forms; always registered via Lifecycle

**Acceptance gate (Phase 1.0):**
- All combat damage routes through DamageSystem; event emission consistent across melee/aura/projectile.

### 1.1 Melee Arc System + ACTION_MELEE_SWING
Add `assets/scripts/combat/melee_arc.lua` with `MeleeArc.execute(caster, config, rng)`:
- 8-step `physics.segment_query` arc sweep
- de-dupe hits per swing (key by `eid`)
- filters: ignore caster, ignore allies, only enemies/destructibles
- stable ordering: after collecting hit set, sort by `eid` before applying damage

Route `ACTION_MELEE_SWING` in `assets/scripts/wand/wand_actions.lua`:
- for each target hit:
  - `EventBus.emit("player_hit_enemy", ...)`
  - `DamageSystem.apply(...)` with `physical` and tags `{"melee","wand"}` (or `{"melee","skill"}` if used elsewhere)

**Acceptance gate (Phase 1.1):**
- Channeler can hit 1–N enemies in a 90° arc; each enemy max once per swing; no crashes with empty arc.

### 1.2 Status Stack Decay (centralized in StatusEngine)
Implement decay for `scorch`, `freeze`, `doom`, `charge`, `inflame`:
- accumulator (`decayTimer += dt`) with bounded tick loops for large `dt`
- emit `status_stack_changed` on decay
- emit `status_removed` when status reaches 0 stacks (with `reason = "decay"`)
- remove status at 0 stacks; removal triggers cleanup
- add per-status/per-entity opt-out flag (forms/skills use this)

**Acceptance gate (Phase 1.2):**
- decay timing matches config; stacks never negative; removal triggers cleanup; `status_removed` emitted.

### 1.3 Starter Wands
Create `assets/scripts/data/starter_wands.lua` with:
- `VOID_EDGE` (0.3s trigger, 40 mana, 4 slots, includes `ACTION_MELEE_SWING`)
- `SIGHT_BEAM` (1.0s trigger, 80 mana, 6 slots, includes a ranged starter action)

Register into wand template registry + `assets/scripts/core/card_eval_order_test.lua`.

**Acceptance gate (Phase 1.3):**
- Both starter wands instantiate with correct starting cards and stats; class restriction enforced at grant time.

---

## Phase 2 — Identity (Gods, Classes, Run Start)

### 2.1 Avatars: Gods + Classes
Implement in `assets/scripts/data/avatars.lua`:
- `Avatars.gods[id] = { element, blessing{cooldown, execute}, passive{trigger, effect}, starter_equipment, starter_artifact }`
- `Avatars.classes[id] = { starter_wand, passive, triggered }`

Accessors:
- `Avatars.get_god(id)` (supports `"nil"` alias mapping to `"nihil"`)
- `Avatars.get_class(id)`

### 2.2 Starter Loadout Grant
Implement single idempotent grant function:
- grants exactly:
  - 1 starter wand
  - 1 starter equipment
  - 1 starter artifact
- applies god/class runtime state and registers passives/triggers via Lifecycle

### 2.3 God/Class Selection UI
Add `assets/scripts/ui/god_select_panel.lua`:
- 2×2 god grid + class selector + preview panel (blessing/passive + starter gear + starter wand)
- confirm disabled until both selected
- on confirm:
  - emits `select_god_class` command via CommandStream
  - stores chosen IDs as strings
  - grants loadout
  - transitions into gameplay

**Acceptance gate (Phase 2):**
- From fresh boot: player selects god+class, sees correct preview, starts run with correct loadout and passive behavior.
- Run seed is visible in UI (and stored for replay); copy button works (dev-only OK).

---

## Phase 3 — Skill System Mechanics

### 3.1 Element Lock Enforcement
In `assets/scripts/core/skill_system.lua`:
- `SkillSystem.can_learn(player, skillId)` checks:
  - skill points
  - prerequisites
  - element lock rule
- track `player.elements_invested`
- after 3 distinct elements invested: lock set

`assets/scripts/ui/skills_panel.lua` shows:
- invested elements and lock state
- clear failure messaging on blocked learn
- **"why blocked" help text** that names the locked element set and the attempted element

### 3.2 Multi-Trigger Resolution (same sim frame)
Per-sim-frame event buffer:
- SkillSystem listens to EventBus during steps 3–4 (combat + status/aura)
- `SkillSystem.on_event(event)` stores event records by type
- `SkillSystem.end_frame()`:
  1. build frame snapshot (counts + first/last per type + per-element tallies)
  2. compute which skills fire from snapshot (no execution yet)
  3. execute fired skills in deterministic order:
     - by `priority` then `skillId`
  4. events emitted during skill execution are tagged with `origin="skill"`
     - snapshot that triggered evaluation excludes `origin="skill"` events (prevents feedback loops)
     - optional: keep `defer_skill_events=true` toggle for ultra-safe mode

**Performance + robustness additions:**
- Trigger DSL is compiled at content compile time into predicate functions.
- Optional per-skill fields:
  - `cooldown_s` (default 0)
  - `max_procs_per_frame` (default 1)
- Dev-only debugging:
  - `SkillSystem.explain_last_eval(skill_id)` returns which trigger clause passed/failed for last frame

**Trigger DSL (explicit semantics):**
```lua
triggers = {
    all = { "damage_dealt", "status_applied" },  -- AND: all must occur
    any = { "enemy_killed", "player_damaged" },  -- OR: at least one
    count = { event = "damage_dealt", n = 3, filter = { element = "fire" } }  -- threshold
}
filter = { element, status_id, source_kind, is_dot, tags[] }
```

**Optional trigger window for better feel (default is 1 frame):**
```lua
trigger_window = { within_frames = 1 } -- or 3..10 for ~50–150ms windows
```

**Acceptance gate (Phase 3):**
- Single-trigger skills behave as before
- multi-trigger skills only fire when all triggers occurred in the same sim frame
- UI blocks locked elements correctly with clear "why blocked" messaging

---

### Phase 3.3 — Codex (small UI, big clarity)

Add `assets/scripts/ui/codex_panel.lua`:
- reads directly from ContentRegistry lists (skills/cards/items/statuses/forms)
- searchable + shows trigger text and tags
- driven by content metadata (no hardcoded descriptions)

**Acceptance gate (Phase 3.3):**
- Codex shows all registered content
- Search works
- Players can understand skill triggers and item effects

---

## Phase 4 — Skills Content (32 skills)

### 4.1 Skills Data Modules
Implement 32 skills as data-driven entries (8 per element) in split modules:
- `assets/scripts/data/skills/fire.lua`
- `assets/scripts/data/skills/ice.lua`
- `assets/scripts/data/skills/lightning.lua`
- `assets/scripts/data/skills/void.lua`

Each skill defines:
- `id`, `element`, `cost`, `display_name`, `description`
- `triggers` DSL (as defined in 3.2)
- `execute(player, frameSnapshot, rng)` — receives explicit RNG
- optional `on_learn(player)` for passives
- optional `cooldown_s`, `max_procs_per_frame`, `priority`

### 4.2 Event Coverage for Skills
Ensure runtime emits enough events:
- elemental damage events (`damage_dealt.damage.element`)
- kill events (`enemy_killed`)
- wave start (`wave_start`)
- player damaged (`player_damaged`)
- status applied/changed (`status_applied`, `status_stack_changed`)
- status removed (`status_removed`)

**Acceptance gate (Phase 4):**
- Exactly 32 skills load (unique IDs)
- learn successfully
- each can be triggered in a controlled smoke run without runtime errors

---

## Phase 5 — Forms + Aura System + Reactions

### 5.1 Form Status Definitions
In `assets/scripts/data/status_effects.lua`, define:
- `fireform`, `iceform`, `stormform`, `voidform`
- each has:
  - `type="buff"`
  - `duration` (30–60s)
  - `stat_mods`
  - `aura{radius, tick_interval, effects[]}`
  - `visuals`
  - `immunities{ status_tags[] }`
- `on_apply` emits `form_activated`
- `on_expire/on_remove` emits `form_expired`

### 5.2 AuraSystem Runtime
Add `assets/scripts/combat/aura_system.lua`:
- `register(entity, auraId, config)`, `unregister(entity, auraId)`, `update(sim_dt)`
- tick applies damage + status stacks to enemies in radius
- cleans up dead entities automatically

**Perf + fairness constraints:**
- tick staggering: each aura has `phase` so not all auras tick the same sim frame
- cap targets per tick (configurable) + stable ordering by `eid`
- if physics returns unordered results, AuraSystem sorts before applying effects
- damage routed through `DamageSystem.apply(...)` (canonical events)
- **deterministic perf budget:**
  - `max_targets_processed_per_frame` (global) to avoid GC spikes
  - if over budget: continue next frame in stable round-robin order
- **optional optimization hook (if needed after profiling):**
  - cache overlaps from physics step (enter/exit) to avoid repeated radius queries

**CRITICAL:** `AuraSystem.update()` must be called BEFORE `SkillSystem.end_frame()`.

### 5.3 Form Threshold Tracking
Threshold tracking driven by `damage_dealt` events:
- per-element counters on player (e.g., `fire_damage_accum`)
- form skill enables threshold behavior; when reached:
  - applies form status
  - resets counter

### 5.4 ReactionSystem (small scope, big payoff)
Add `assets/scripts/combat/reaction_system.lua`:
- listens to `status_applied`, `status_stack_changed`, `damage_dealt`
- applies 2–3 data-driven reactions:
  - **Shatter:** freeze + heavy physical hit → bonus damage
  - **Overload:** charge + lightning damage → extra damage tick
  - **Detonate:** doom at max stacks → area damage
- routes reaction damage through DamageSystem
- emits dev-only `reaction_triggered`

**Proc guards (deterministic safety):**
- `max_reactions_per_target_per_frame` (default 1–2)
- per-reaction `cooldown_frames` (default 1–10)
- stable reaction evaluation order: by `reaction_id`, then `target_eid`

**Acceptance gate (Phase 5):**
- at least one form triggers naturally via thresholds
- aura ticks for full duration
- cleanup occurs on expiry and player death
- at least one reaction triggers in a controlled test
- reaction proc guards prevent infinite loops

---

## Phase 6 — Cards & Wands (full pool + triggers)

### 6.1 Modifier Cards (12)
Implement in `assets/scripts/data/cards/modifiers.lua`:
- Chain 2, Pierce, Fork, Homing, Larger AoE, Concentrated, Delayed, Rapid, Empowered, Efficient, Lingering, Brittle

Validate stacking via `assets/scripts/core/card_eval_order_test.lua`.

### 6.2 Action Cards (16 elemental)
Implement 4 per element across:
- `assets/scripts/data/cards/actions_fire.lua`
- `assets/scripts/data/cards/actions_ice.lua`
- `assets/scripts/data/cards/actions_lightning.lua`
- `assets/scripts/data/cards/actions_void.lua`

Ensure each action:
- emits `damage_dealt` via DamageSystem
- applies statuses via StatusEngine in a canonical way (so status events are consistent)
- takes explicit `rng` for any randomness

### 6.3 Findable (Shop) Wands (6) + Trigger Types
Define 6 templates in wand registry with trigger metadata + shop pricing/stages:
- `on_bump_enemy`
- `on_distance_traveled(distance)`
- `on_stand_still(duration)`
- `on_enemy_killed`
- `on_player_hit`
- `every_N_seconds(interval)`

Implement/extend trigger registration using Lifecycle handles (no raw connects/timers).

Wand runtime uses compiled plans:
- on equip / deck change: `CardPipeline.compile(wand)` → `wand.exec_plan`
- on trigger: execute `wand.exec_plan(rng)` where rng is derived from `(run_seed, frame, wand_id, trigger_seq)`

**CardPipeline determinism requirements:**
- compilation cached by `deck_hash`:
  - ordered card IDs
  - wand template ID + relevant base stats
  - `content_build.build_hash`
  - `card_pipeline_version` (bump when modifier phase logic changes)
- modifiers have explicit ordering:
  - by `phase` (e.g., `target_select`, `shape`, `timing`, `damage_scale`), then by `card_id`
  - never rely on Lua table iteration order
- pipeline emits IR snapshot (dev-only) for diff tests
- card actions/modifiers must take an explicit `rng` object for any randomness

**Acceptance gate (Phase 6):**
- modifiers affect action execution deterministically
- 6 shop wands fire under triggers and do not leak timers/handlers when swapped
- compile caching prevents unnecessary rebuilds on no-op changes
- identical deck_hash produces identical exec_plan

---

## Phase 7 — Artifacts & Equipment

### 7.1 Artifacts (15 across 3 tiers)
In `assets/scripts/data/artifacts.lua` define:
- 5 common + 5 uncommon + 5 rare

Rules:
- every artifact effect must be:
  - stat-mod based OR event-hook based registered through Lifecycle (auto-cleaned)
- prefer canonical events over bespoke timers where possible

### 7.2 Equipment (12 across 3 slots)
In `assets/scripts/data/equipment.lua` define:
- 4 chest, 4 gloves, 4 boots

Ensure equipment system:
- applies stat mods
- registers hooks through Lifecycle (auto-cleaned)

**Acceptance gate (Phase 7):**
- all items load
- equipping/unequipping never stacks permanently
- starter equipment references are valid

---

## Phase 8 — Economy & Progression

### 8.1 Skill Points by Level
Integrate into existing level-up flow:
- Level 1: 0 points
- Levels 2–6: +2 points each (10 total by level 6)

UI shows current available points immediately on grant.

### 8.2 Shop Stage Timeline (SHOP ONLY; loot handled separately)
Stage-based shop inventory generation:
- Stage 1: equipment only
- Stage 2: equipment + 1–2 wands
- Stage 3: equipment + 1–2 wands
- Stage 4: equipment + 1–2 wands + 1 artifact (guaranteed)
- Stage 5: boss (no shop)

Loot table (separate from shop):
- elite enemies can drop an artifact at Stage 3+ (chance-based)

**Deterministic generation:**
- use hashed seed mixing (supports independent RNG streams):
  - `shop_seed = Hash.combine(run_seed, stageIndex, shopVisitIndex)`
- use `rng_shop` stream, never `math.random`
- avoid simple addition to reduce collisions and improve future extensibility

**Player agency:**
- add 1 reroll option per shop (cost scales, e.g., 10g then 20g)
- add "lock 1 item" before reroll (keep one offer, reroll the rest)
- **add minimal gold sink (choose one implementation):**
  - **Card Removal Service:** remove 1 card from a chosen wand deck (cost scales, e.g., 15g → 25g → 40g)
  - **Wand Polish:** small permanent stat bump on a chosen wand (tiered, capped at 3 upgrades per wand)
  - *(prevents "reroll until perfect" degenerate strategy)*

Enforce:
- starter wands never appear for sale
- shop wands priced 25–50g

**Acceptance gate (Phase 8):**
- shop contents follow stage table
- purchasing deducts gold correctly
- no empty-inventory softlocks (fallbacks applied)
- reroll + lock works and is deterministic for same seed
- gold sink works, is deterministic, and cannot softlock the shop UI

---

## 5) Validation, QA, and Definition of Done

### 5.1 Automated Validation (dev-only script)
Add a lightweight validator asserting:
- unique IDs across skills/cards/wands/items/statuses
- all references exist (starter cards, starter gear, form status IDs, shop wand IDs)
- no missing required fields
- registry compilation succeeds (no dangling references, no duplicate IDs, no invalid trigger names)
- migrations applied correctly (deprecated IDs resolve)

**Determinism smoke (dev-only):**
- fixed seed → run N sim frames headless → checksum key counters (kills, damage totals, gold)

**Replay smoke (dev-only, HIGH VALUE):**
- record a 600-frame replay (CommandStream + run_seed + content_build hash + sim_dt + replay_version)
- re-run the replay headless:
  - assert identical checksums
  - assert identical event trace hash (required, dev-only)

**Event trace hash spec:**
- hash a canonical string per event:
  - `(frame, seq, type, source_eid, target_eid, damage_id, status.id, damage.amount, damage.element, kill.overkill, ...)`
- exclude non-deterministic/visual fields (positions if float noise is expected)

**Trace diff tool:**
- `assets/scripts/dev/trace_diff.lua` loads two traces and prints the first mismatch with N events of context

**Replay format versioning:**
- `replay_version = 2` (bumped from v1 to reflect CommandStream change)
- replay invalid if `content_build.build_hash` mismatches (fail fast with message)
- replay invalid if `sim_dt` or `max_sim_steps_per_render` mismatch (fail fast with message)

**Hook leak checks (dev-only):**
- equip/unequip wands repeatedly → assert no growth in active subscriptions/timers
- equip/unequip artifacts/equipment repeatedly → same assertion
- `Lifecycle.dump()` used to identify source of any leaks

### 5.2 Manual Smoke Checklist (must pass)
- Start run for all 8 god/class combinations (4×2) and confirm correct loadout
- Verify status decay visually and numerically (scorch/freeze/charge/doom/inflame)
- Learn skills across up to 3 elements; confirm 4th element is blocked with message
- Trigger at least one multi-trigger skill successfully
- Trigger at least one form and observe aura ticks + expiry cleanup
- Enable event trace logging for one run; confirm trace is stable for same seed + same CommandStream
- Buy and use at least 2 shop wands; confirm triggers work and stop after unequip
- Equip 3 equipment slots + 2 artifacts; confirm stats/effects apply and remove cleanly
- Run UBS before merging final workstreams
- Run golden replay check (at least 1 short replay passes determinism)

---

## Appendix A: Summary of v3 Changes

| Change | Impact |
|--------|--------|
| CommandStream (semantic commands) | Replays survive UI changes; input is UI-agnostic intent |
| Explicit Determinism Tier (A/B) | Sets expectations; avoids false promises |
| SimClock spiral-of-death protection | Prevents runaway catch-up on stalls |
| Entity ID Contract (monotonic, never reused) | Clear identity semantics for debugging |
| EventBus deferred dispatch | Prevents re-entrancy surprises; simpler reasoning |
| RNG Streams formalized | Prevents cross-system randomness coupling |
| DamageSystem pipeline architecture | Ready for equipment/artifact modifiers |
| `damage_taken` event | Enables "when you take damage" passives |
| `status_removed` event + `reason` field | Cleaner status event contract |
| Skill immediate execution with origin tagging | Responsive skills without feedback loops |
| CardPipeline versioning | Prevents stale compiled plans |
| Lifecycle name/domain metadata + dump() | Leak hunting is actually doable |
| Trace hash spec + trace_diff.lua | Determinism is a hard guarantee |
| ReactionSystem proc guards | Prevents infinite loops |
| ContentRegistry migrations + warnings | Smoother content iteration |
| Codex UI | Players understand content |
| Surfaced run_seed | Sharing/testing runs |
| Agent F (Tools + QA) | Dedicated owner for determinism tooling |
| Gold sink option | Prevents "reroll until perfect" degenerate play |

---

## Appendix B: Deferred Items (Not in v3 Scope)

Explicitly deferred:
- Daily Seed / Shareable Run Code (run_seed is visible but not daily-seeded)
- Tier B Determinism (cross-engine-build determinism)
- Overlap caching in AuraSystem (implement if profiling shows need)

Candidate post-v3 follow-ups (if time):
- More reaction types and cross-element synergies (balance pass)
- Save/load of mid-run state (requires broader serialization contracts)
- Daily challenge mode with leaderboards

---

## Appendix C: Interface Contracts (Stable vs Internal)

**Stable APIs (other modules may depend on):**
- `EventBus.emit()`, `EventBus.connect()`
- `DamageSystem.apply()`, `DamageSystem.register_modifier()`
- `Lifecycle.bind()`, `Lifecycle.on_event()`, `Lifecycle.cleanup_owner()`
- `CommandStream.push()`, `CommandStream.get_frame_commands()`
- `Rng.derive()`, `rng:random()`, `rng:random_int()`
- `ContentRegistry.get()`, `ContentRegistry.get_by_id()`
- `SkillSystem.can_learn()`, `SkillSystem.end_frame()`

**Internal (subject to change):**
- EventBus internal dispatch queue
- DamageContext internal structure
- CardPipeline IR format
- Trace hash implementation details
