# Proposed Revisions to “Master Implementation Plan — Demo Content Spec v3 (v2 Revision)”

This is a blunt review focused on making the project **more deterministic, more replayable, easier to debug, harder to break**, and **more scalable** when you inevitably add more content after v3.

The original plan is already strong. The biggest remaining risk areas are:

- **Replay fragility:** “raw input capture” often breaks the moment UI/layout timing changes. You want **semantic commands**, not keystates.
- **Event re-entrancy hazards:** immediate `emit()` while dispatching can create subtle ordering surprises even if “deterministic”.
- **One-frame latency in skills:** “skill execution events go to next frame” keeps you safe, but can make combat feel mushy and creates design constraints.
- **RNG discipline:** you’ll end up with accidental “global RNG state” coupling between systems unless you formalize streams/context now.
- **Physics determinism assumptions:** sorting results helps, but you still need **budgeting**, **clamps**, and an explicit “determinism tier” contract.

Below are proposed changes. Each change includes:
- what to change,
- why it improves the project,
- what it costs / risks,
- and a unified **git-diff style patch** against the plan document.

---

## Change 01 — Add a CommandStream (semantic commands) and make Replay resistant to UI changes

### Why this makes the project better
Your replay plan currently reads as “record input stream”. That’s usually a trap:
- **Raw inputs** (keys/mouse) are low-level and tied to UI layout, frame timing, and platform quirks.
- The moment you reorder UI focus or add a new button, old replays can desync.
- Determinism tests become flaky because the same physical input can map to different actions if UI changes.

A **CommandStream** solves this by recording **intent**:
- `move_axis`, `aim_vector`, `cast_wand`, `buy_shop_offer(slot)`, `learn_skill(skill_id)`, `reroll_shop(lock_idx)` …
- UI changes can be refactored without invalidating replays as long as they emit the same commands.

This also improves architecture:
- Input mapping becomes a thin adapter that produces commands.
- Simulation consumes commands deterministically (with sequence numbers).
- Replays become a first-class regression tool.

### Risks / costs
- Requires designing a small command schema.
- You must route “menu interactions” (shop purchases, selection confirmation) through commands too.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ## 1) Goals & Deliverables
@@
 - **Engineering:** compiled content registry + deterministic simulation + replay/debug tooling
   - seeded RNG streams
   - fixed-step sim
-  - input capture + replay runner (dev-only OK)
+  - semantic command capture + replay runner (dev-only OK)
   - deterministic ordering rules enforced (Lua-safe)
+
+### 1.1 Determinism Tier (explicit)
+Define determinism tier up front to avoid false expectations:
+- **Tier A (required for v3):** deterministic within the same engine build + same content_build + same replay_version
+- **Tier B (nice-to-have later):** deterministic across engine builds (requires stricter floating/physics constraints)
@@
 ## 2) Canonical Contracts (Naming, IDs, Events, Update Order)
+
+### 2.5 Command Contract (NEW, replay-critical)
+Introduce a semantic command stream consumed by simulation:
+- `assets/scripts/core/command_stream.lua`
+  - `CommandStream.begin_frame(frame)`
+  - `CommandStream.push(cmd)` assigns `(frame, seq)` and stores in per-frame buffer
+  - `CommandStream.get_frame_commands()` returns stable-ordered list (by seq)
+
+Commands are plain tables with a strict schema (validated dev-only):
+```lua
+cmd = { type="move", x=number, y=number }
+cmd = { type="aim", x=number, y=number }
+cmd = { type="trigger_wand", slot=number }
+cmd = { type="learn_skill", skill_id=string }
+cmd = { type="shop_buy", offer_index=number }
+cmd = { type="shop_reroll", lock_offer_index=number|nil }
+cmd = { type="select_god_class", god_id=string, class_id=string }
+```
+
+**Replay rule:** record CommandStream (plus run_seed + content_build + sim_dt), not raw input device states.
@@
 ### 2.3 Update Order (single source of truth in main loop) — CRITICAL
@@
 0. Begin-frame: increment `frame`, EventBus.begin_frame(frame, t), reset per-frame buffers
+0.5 CommandStream.begin_frame(frame); map raw input/UI → semantic commands; store in command buffer
 1. Movement/physics integration (produces collisions/overlaps but does not apply damage yet)
@@
 7. Cleanup (despawn, unregister hooks tied to dead entities, end-of-frame assertions)
@@
 ## Phase 0 — Audit & Alignment (must complete first)
@@
 ### 0.3 Core Infrastructure (MUST land before Phase 1+)
 Implement and wire:
@@
 - fixed-step sim runner:
@@
 - dev-only assertions:
@@
+ - CommandStream (semantic commands) + validator
@@
 ### 5.1 Automated Validation (dev-only script)
@@
 **Replay smoke (dev-only, HIGH VALUE):**
-- record a 600-frame replay (input stream + run_seed + content_build hash)
+- record a 600-frame replay (CommandStream + run_seed + content_build hash + sim_dt)
 - re-run the replay headless:
   - assert identical checksums
   - assert identical event trace hash (optional, dev-only)
```

---

## Change 02 — Harden SimClock against “spiral of death” + store sim config in replay/build

### Why this makes the project better
Fixed-step is good; fixed-step **without clamps** is how you end up with:
- runaway catch-up when the game stalls (GC spikes, debugger, OS hitch),
- non-obvious desync because you run “too many” sim steps in one render frame,
- inconsistent behavior when pausing/unpausing.

Also, determinism is not just “seed + input”; it’s also **sim_dt, max_steps, and timebase**. If those change, replays should fail fast.

### Risks / costs
- Very low. This is mostly guardrails.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 2.3.1 Determinism requirement: fixed-step simulation
@@
 - Render dt is accumulated and drives `N` sim steps per render frame.
+ - Render dt is accumulated and drives `N` sim steps per render frame.
+ - Clamp catch-up to avoid spiral-of-death:
+   - `max_sim_steps_per_render = 4` (tunable)
+   - `max_accumulator = sim_dt * max_sim_steps_per_render`
+   - if exceeded: drop excess with a dev warning counter (and optionally pause replay determinism checks)
 - `Event.frame` refers to **sim frame**, not render frame.
+
+**Replay/build invariants:**
+- replay stores `{ sim_dt, max_sim_steps_per_render }`
+- replay invalid if these mismatch current build config
@@
 ### 0.3 Core Infrastructure (MUST land before Phase 1+)
@@
 - fixed-step sim runner:
   - `assets/scripts/core/sim_clock.lua` with accumulator and `sim_dt`
   - `main.lua` uses `SimClock.step(render_dt)` to run N sim frames
+  - add clamp configuration + instrumentation counters for dropped time
```

---

## Change 03 — Make entity identity explicit: eid allocation, non-reuse, and “entity_kind”

### Why this makes the project better
A lot of “determinism” and “debuggability” quietly depends on entity identity rules. Right now, you say “stable entity IDs”, but not:
- how they’re assigned,
- whether they can be reused,
- whether replay expects the same spawn order,
- what an eid refers to after despawn.

Define it now, or you’ll invent three different eid schemes later.

### Recommended contract
- `eid` is **monotonic** within a run (never reused).
- `eid` includes `spawn_seq` (or is the spawn_seq).
- Entities have `entity_kind` string (`"player"`, `"enemy"`, `"projectile"`, `"pickup"`, …) for trace readability.
- All event payloads that reference entities include `source_eid` / `target_eid` plus optional `source_kind` / `target_kind`.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 #### 2.2.2 Event Envelope (all events use this structure)
@@
 Event = {
     type = "event_name",
     frame = number,      -- sim frame number
     seq = number,        -- per-frame sequence for deterministic ordering
     t = number,          -- sim time (accumulated fixed-step time)
     payload = { ... }    -- event-specific data
 }
@@
-**Entity References:** Always use `source_eid` / `target_eid` (stable entity IDs), never live table references.
+**Entity References:** Always use `source_eid` / `target_eid` (stable entity IDs), never live table references.
+**Entity ID Contract (NEW):**
+- `eid` is a monotonic integer assigned at spawn; **never reused within a run**
+- despawned eids are never reassigned
+- payload may include `source_kind` / `target_kind` for trace readability
```

---

## Change 04 — Fix EventBus re-entrancy: defer nested emits until current dispatch completes + add “phase”

### Why this makes the project better
Your current EventBus rule:
> “emit() during dispatch is allowed; ordering is deterministic by (frame, seq).”

That’s deterministic, but it is still a **footgun**: nested `emit()` can interleave with remaining listeners of the current event, causing:
- subtle dependencies on listener registration order,
- “half-updated state” observers,
- hard-to-debug cascade behavior.

Safer semantics:
- If an event handler emits another event, that emitted event is queued and only dispatched **after** the current event finishes dispatching to all listeners.

Also, adding an event `phase` makes trace analysis much easier:
- `"movement"`, `"combat"`, `"status"`, `"skills"`, `"cleanup"` …

### Risks / costs
- Any current code relying on immediate nested dispatch will need small adjustments.
- This reduces accidental coupling and makes behavior more intuitive.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 #### 2.2.1 EventBus API (authoritative)
@@
 - `EventBus.emit(type, payload)`
   - increments `seq`
   - constructs `Event = { type, frame, seq, t, payload }`
-  - dispatches to listeners in deterministic order
+  - dispatches to listeners in deterministic order
   - returns the `Event`
+ - `EventBus.emit_deferred(type, payload)`
+   - same as emit, but guarantees dispatch occurs after the current dispatch completes
+   - EventBus may internally treat *all emits during dispatch* as deferred for safety
@@
 **Rules:**
@@
-- `emit()` during dispatch is allowed; ordering is deterministic by `(frame, seq)`.
+- `emit()` during dispatch is allowed but **dispatch is deferred** until current event completes.
+- Add `phase` metadata for debugging (dev-only optional):
+  - EventBus.set_phase("combat"|"status"|"skills"|...)
@@
 Event = {
     type = "event_name",
     frame = number,      -- sim frame number
     seq = number,        -- per-frame sequence for deterministic ordering
     t = number,          -- sim time (accumulated fixed-step time)
+    phase = string,      -- optional: system phase for trace/debug
     payload = { ... }    -- event-specific data
 }
```

---

## Change 05 — Status events need one more canonical event + tighter payload shapes

### Why this makes the project better
Right now you have `status_applied` and `status_stack_changed`, but no explicit “removed”.
You *can* infer removal from `new_stacks == 0`, but that breaks down when:
- non-stacking statuses exist,
- you “refresh duration” without stack changes,
- forms/immunities remove statuses without stack math.

A dedicated `status_removed` event reduces ambiguity and makes skills/items more expressive.

Also, your payload shapes inconsistently include `source_eid`. Make it present everywhere it matters.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 #### 2.2.3 Standard Payload Shapes
@@
 payload.status = {
     id = string,
     new_stacks = number,
     old_stacks = number,
-    source_eid = entity_id
+    source_eid = entity_id,   -- who caused the change (or nil if system/decay)
+    reason = string           -- "apply"|"refresh"|"decay"|"cleanse"|"expire"
 }
@@
 #### 2.2.4 Canonical Events (envelope-only)
@@
 - `status_applied` — `{ target_eid, status = { ... } }`
 - `status_stack_changed` — `{ target_eid, status = { ... } }`
+- `status_removed` — `{ target_eid, status = { id, old_stacks, source_eid, reason } }`
```

---

## Change 06 — Make DamageSystem a “pipeline” now (without forcing complexity)

### Why this makes the project better
You already centralized damage, which is the right move. The mistake would be treating `apply()` as a monolith that you’ll later have to rip apart.

A lightweight pipeline buys you long-term flexibility without forcing you to implement resistances today:
- `build_context()` (construct immutable context)
- `run_modifiers()` (stats, crit, resist, tags)
- `apply_hp()`
- `emit_events()`

It also allows deterministic “damage modifiers” from equipment/artifacts without ad-hoc patching.

### What to add
- A `DamageContext` table with stable fields.
- A “damage modifier registry” with deterministic ordering (priority + id).
- A `damage_taken` event (target-side view). This helps passives like “when you take damage”.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 1.0 DamageSystem (NEW foundation)
 Add `assets/scripts/combat/damage_system.lua`:
 - `DamageSystem.apply(source_eid, target_eid, damageSpec)`:
-  - computes final amount (initially simple passthrough; supports future resist/crit)
+  - computes final amount via pipeline (initially passthrough; resist/crit are future fields)
+  - builds an immutable `DamageContext` for deterministic modifiers
   - assigns `damage_id`
   - applies HP changes
   - emits canonical events:
     - `damage_dealt`
+    - `damage_taken` (NEW) `{ source_eid, target_eid, damage = { ... } }`
     - `player_damaged` if target is player
     - `enemy_killed` if target dies
 - enforces stable ordering for AoE/multi-hit: sort target eids before applying.
+
+**Damage modifier hooks (deterministic):**
+- `DamageSystem.register_modifier(id, fn, opts)` ordered by `(opts.priority, id)`
+- used by equipment/artifacts/forms; always registered via Lifecycle
```

---

## Change 07 — Formalize RNG Streams now (and pass RNG into Cards/Skills)

### Why this makes the project better
You mention seeded RNG streams, but the plan doesn’t define:
- what RNG algorithm you use,
- how you split streams,
- how you avoid “global RNG state” coupling.

If you don’t lock this down, random behavior will accidentally depend on unrelated systems (“shop reroll changes projectile spread”).

### Recommended approach
- Add `core/rng.lua` using a deterministic algorithm (e.g., PCG32 / xoroshiro) implemented in Lua or C.
- Create **named streams** derived from `run_seed` and context:
  - `rng_shop`, `rng_loot`, `rng_combat`, `rng_ai`, `rng_visual` (visual can be non-deterministic if desired)
- When executing a wand plan or skill, derive a local RNG:
  - `rng = Rng.derive("wand", frame, wand_id, trigger_seq)`
- Card actions and skills take `rng` explicitly. No hidden `math.random`.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ## 1) Goals & Deliverables
@@
 - seeded RNG streams
@@
 ## Phase 0 — Audit & Alignment (must complete first)
@@
 ### 0.3 Core Infrastructure (MUST land before Phase 1+)
 Implement and wire:
@@
+ - deterministic RNG module + stream policy:
+   - `assets/scripts/core/rng.lua`
+   - forbid `math.random` in gameplay code (dev-only runtime check)
@@
 ## Phase 6 — Cards & Wands (full pool + triggers)
@@
 Wand runtime uses compiled plans:
@@
 - on trigger: execute `wand.exec_plan` (no per-trigger rebuild)
+ - on trigger: execute `wand.exec_plan(rng)` where rng is derived from `(run_seed, frame, wand_id, trigger_seq)`
@@
 **CardPipeline determinism requirements:**
@@
 - pipeline emits IR snapshot (dev-only) for diff tests
+ - card actions/modifiers must take an explicit `rng` object for any randomness
```

---

## Change 08 — Remove the “skill feels delayed” problem without reintroducing feedback loops

### Why this makes the project better
Your current SkillSystem rule:
> “events emitted during skill execution are queued for NEXT frame by default”

This avoids feedback loops, but it also creates:
- one-frame “lag” in reactive skills,
- confusing frame semantics (“I killed an enemy; why didn’t my on-kill skill do anything until later?”),
- design limitations (skills that should modify *this* hit).

Better model:
- Skills still evaluate triggers from a snapshot of **pre-skill events**.
- Skill execution happens immediately in the same frame, but events emitted during skill execution are tagged with `origin="skill"` and excluded from the snapshot that caused them.

This gives you responsiveness *and* safety.

Also: allow optional multi-frame windows for triggers. Same-frame triggers are strict and can feel unintuitive at 60 FPS. Making it configurable (`within_frames`) lets you tune for fun.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 3.2 Multi-Trigger Resolution (same sim frame)
@@
 - `SkillSystem.end_frame()`:
+ - `SkillSystem.end_frame()`:
   1. build frame snapshot (counts + first/last per type + per-element tallies)
   2. compute which skills fire from snapshot (no execution yet)
   3. execute fired skills in deterministic order:
      - by `priority` then `skillId`
-  4. events emitted during skill execution are queued for NEXT frame by default (prevents feedback loops)
+  4. events emitted during skill execution are allowed immediately but are tagged `origin="skill"`
+     - snapshot that triggered evaluation excludes `origin="skill"` events (prevents feedback loops)
+     - optional: keep `defer_skill_events=true` toggle for ultra-safe mode
@@
 **Trigger DSL (explicit semantics):**
@@
 triggers = {
@@
 }
 filter = { element, status_id, source_kind, is_dot, tags[] }
+
+Optional trigger window for better feel (default is 1 frame):
+```lua
+trigger_window = { within_frames = 1 } -- or 3..10 for ~50–150ms windows
+```
```

---

## Change 09 — CardPipeline: include pipeline versioning + deck hash must include content_build

### Why this makes the project better
Your deck hash caching is good, but it will bite you unless you include:
- the pipeline algorithm version,
- the content build hash (card definitions changed but deck list didn’t),
- the wand base template version.

Otherwise you’ll reuse stale compiled plans.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 **CardPipeline determinism requirements:**
 - compilation cached by `deck_hash` (cards + order + wand base stats)
+ - `deck_hash` must include:
+   - ordered card IDs
+   - wand template ID + relevant base stats
+   - `content_build.build_hash`
+   - `card_pipeline_version` (bump when modifier phase logic changes)
```

---

## Change 10 — AuraSystem: add an explicit performance budget + optional overlap caching

### Why this makes the project better
Aura ticking can become your hidden performance killer:
- N auras × radius query × sorting × applying
- In Lua, allocations and table churn will spike and create GC hitches (which then stress determinism).

Add two things:
1. **Budgeting:** cap work per frame deterministically (targets processed), carry remainder to next tick.
2. **Optional overlap caching:** track aura → nearby enemies based on movement/overlap notifications, so aura tick iterates a cached list instead of querying physics every time.

### Risks / costs
- Overlap caching is optional; implement later if profiling shows need.
- Budgeting must be deterministic (same ordering of who gets processed when under cap).

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 5.2 AuraSystem Runtime
 Add `assets/scripts/combat/aura_system.lua`:
@@
 **Perf + fairness constraints:**
@@
 - cap targets per tick (configurable) + stable ordering by `eid`
+ - add deterministic perf budget:
+   - `max_targets_processed_per_frame` (global) to avoid GC spikes
+   - if over budget: continue next frame in stable round-robin order
+ - optional optimization hook (if needed after profiling):
+   - cache overlaps from physics step (enter/exit) to avoid repeated radius queries
```

---

## Change 11 — ReactionSystem: add proc guards to prevent infinite loops and “reaction storms”

### Why this makes the project better
Reactions are a “small scope, big payoff” feature, but they are also a classic infinite-loop vector:
- reaction causes damage → damage applies status → status triggers reaction → etc.

Even if you intend it, you need guardrails for performance and stability:
- per-reaction cooldown in frames,
- per-target “max reactions per frame” cap,
- stable ordering (reaction_id then target_eid).

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 5.4 ReactionSystem (small scope, big payoff)
 Add `assets/scripts/combat/reaction_system.lua`:
@@
 - routes reaction damage through DamageSystem
 - emits dev-only `reaction_triggered`
+ - proc guards (deterministic safety):
+   - `max_reactions_per_target_per_frame` (default 1–2)
+   - per-reaction `cooldown_frames` (default 1–10)
+   - stable reaction evaluation order: by `reaction_id`, then `target_eid`
```

---

## Change 12 — ContentRegistry: add explicit migrations + warnings (not just hard fails)

### Why this makes the project better
Hard-failing on invalid data is correct. But you also want:
- **warnings** for suspicious-but-valid content (missing description, no icon, unreachable skill, unused card),
- explicit **migrations** for renamed/removed IDs beyond just `"nil" → "nihil"`.

This makes content iteration faster and avoids “soft breaks” of replays/saves when you rename something.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 2.0 Content Registry + Schema Versioning
@@
 - emits `content_build = { schema_version, build_hash, id_maps }` for save/replay compatibility
+ - emits `content_build = { schema_version, build_hash, id_maps, sim_dt, engine_build }`
+ - supports migrations:
+   - `assets/scripts/core/content_migrations.lua`
+   - maps deprecated IDs → canonical IDs (skills/cards/items/statuses)
+   - supports “deleted” IDs with actionable errors ("replay references removed content: ...")
+ - emits warnings list (dev-only) for non-fatal authoring issues
```

---

## Change 13 — Lifecycle: add scoping + debug names to make leak hunting actually doable

### Why this makes the project better
“Auto-cleaned via Lifecycle” is great, but leak hunting still sucks unless:
- every handle has a name (what registered it?),
- you can group handles by “domain” (wand, artifact, equipment, skill),
- you can dump active handles per owner.

Otherwise, your leak test will tell you “counts increased” and you’ll spend hours chasing it.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 2.4 Effect Lifecycle Contract (required for reliability)
@@
 - `Lifecycle.bind(owner_eid, handle)` tracks subscriptions/timers/resources
+ - `Lifecycle.bind(owner_eid, handle, opts)` where opts supports:
+   - `name` (string) for debugging
+   - `domain` ("wand"|"artifact"|"equipment"|"skill"|"form")
@@
   - provides helpers:
@@
     - `Lifecycle.assert_no_raw_connects()` (dev-only)
+    - `Lifecycle.dump(owner_eid)` (dev-only): list live handles grouped by domain/name
```

---

## Change 14 — Determinism tooling: standardize trace hashing + add a diff viewer script

### Why this makes the project better
You already plan a replay smoke and optional event trace hash. Make it concrete:
- Define exactly what goes into the hash (event type + key payload fields).
- Provide a “trace diff” tool that prints the first divergence with context.
- Store a small set of “golden replays” in the repo and run them in CI.

This turns determinism from a vibe into a hard guarantee.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ### 5.1 Automated Validation (dev-only script)
@@
 **Replay smoke (dev-only, HIGH VALUE):**
@@
 - re-run the replay headless:
-  - assert identical checksums
-  - assert identical event trace hash (optional, dev-only)
+ - re-run the replay headless:
+   - assert identical checksums
+   - assert identical event trace hash (required, dev-only)
+
+**Event trace hash spec (NEW):**
+- hash a canonical string per event:
+  - `(frame, seq, type, source_eid, target_eid, damage_id, status.id, damage.amount, damage.element, kill.overkill, ...)`
+- exclude non-deterministic/visual fields (positions if float noise is expected)
+
+**Trace diff tool (NEW):**
+- `assets/scripts/dev/trace_diff.lua` loads two traces and prints the first mismatch with N events of context
```

---

## Change 15 — Player-facing value: add a Codex + surface the run seed + simple “why can’t I learn this?” UX

### Why this makes the project better
If you want “compelling/useful”, the engineering-only wins aren’t enough. Two cheap additions pay off hard:
1. **Codex** (skills/cards/items/statuses/forms) driven by ContentRegistry. This makes content legible and reduces confusion.
2. **Seed surfaced** in UI with copy-to-clipboard (even if daily seeds are deferred). Players and testers can share runs.

Also, your element lock will frustrate players unless the UI is explicit about:
- which elements are invested,
- what counts toward lock,
- and why a learn is blocked.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ## 1) Goals & Deliverables
@@
 - **Engineering:** compiled content registry + deterministic simulation + replay/debug tooling
@@
+ - **UX:** Codex UI (skills/cards/items/statuses/forms) + surfaced run_seed for sharing/debug
@@
 ## Phase 2 — Identity (Gods, Classes, Run Start)
@@
 **Acceptance gate (Phase 2):**
 - From fresh boot: player selects god+class, sees correct preview, starts run with correct loadout and passive behavior.
+ - Run seed is visible in UI (and stored for replay); copy button works (dev-only OK).
@@
 ## Phase 3 — Skill System Mechanics
@@
 `assets/scripts/ui/skills_panel.lua` shows:
 - invested elements and lock state
 - clear failure messaging on blocked learn
+ - “why blocked” help text that names the locked element set and the attempted element
+
+## NEW: Phase 3.3 — Codex (small UI, big clarity)
+- `assets/scripts/ui/codex_panel.lua`
+- reads directly from ContentRegistry lists (skills/cards/items/statuses/forms)
+- searchable + shows trigger text and tags
```

---

## Change 16 — Add a minimal gold sink (otherwise shop + reroll collapses into “always reroll”)

### Why this makes the project better
Your economy adds reroll + lock (good). But if players can stockpile gold with no long-term sink, optimal play becomes:
- buy only the best offer,
- reroll repeatedly,
- ignore “good enough” upgrades,
- pacing gets weird.

A minimal sink keeps tension without needing a whole upgrade system:
- **Card Removal Service** in shop: pay gold to remove 1 card from a wand’s deck (or from inventory).
- Or **Wand Polish**: +small stat bump on current wand (mana efficiency, cooldown, etc.) with escalating cost and capped tiers.

This improves:
- meaningful decisions,
- build shaping,
- and prevents gold from being “dead” late-run.

### Risks / costs
- Small UI + pricing.
- Must be deterministic: the action is just a command + state change.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ## Phase 8 — Economy & Progression
@@
 **Player agency:**
 - add 1 reroll option per shop (cost scales, e.g., 10g then 20g)
 - add "lock 1 item" before reroll (keep one offer, reroll the rest)
+ - add minimal gold sink (choose one):
+   - **Card Removal Service:** remove 1 card from a chosen wand deck (cost scales)
+   - **Wand Polish:** small permanent stat bump on a chosen wand (tiered, capped)
@@
 **Acceptance gate (Phase 8):**
@@
 - reroll + lock works and is deterministic for same seed
+ - gold sink works, is deterministic, and cannot softlock the shop UI
```

---

## Change 17 — Strengthen multi-agent integration: add a dedicated “Tools/QA” owner and make interfaces explicit

### Why this makes the project better
Your “6 agents” plan is good, but tooling tends to become “everyone’s job” → nobody’s job.
If determinism, replay, and validators are critical, you want one owner driving:
- trace hashing,
- replay format and migration,
- validation scripts,
- CI gates.

Also, define “interface contracts” early:
- which modules are stable APIs,
- which tables are internal.

### Git-diff patch
```diff
diff --git a/implementation_plan.md b/implementation_plan.md
--- a/implementation_plan.md
+++ b/implementation_plan.md
@@
 ## 3) Multi-Agent Execution Plan (4–6 agents)
@@
 Recommended 6 agents (collapsible to 4):
@@
 - **Agent E — Items + Economy**
   - `assets/scripts/data/artifacts.lua`, `assets/scripts/data/equipment.lua`
   - shop core + UI
   - `assets/scripts/core/progression.lua` or existing integration
+
+- **Agent F — Tools + QA (NEW, single throat to choke)**
+  - validator + determinism harness + replay runner polish
+  - trace hashing + trace diff tool
+  - CI gate scripts (headless run + golden replay checks)
@@
 ### 3.3 Integration Gates
@@
 - Run **UBS** as the final pre-merge gate (repo policy).
+ - Add “golden replay” gate (dev-only OK for v3): at least 1 short replay must pass determinism checks on CI.
```

---

# Closing Notes (what I would NOT change)

- The “stable idx assignment sorted by ID” is exactly the right move.
- Lifecycle being mandatory is also correct; keep it non-negotiable.
- Central DamageSystem is the right foundation for balancing and instrumentation.
- Aura staggering + target caps are solid “fairness + perf” guardrails.

# Summary of highest-impact wins

If you only implement a subset, prioritize these in order:

1. **CommandStream replay** (semantic commands) — makes determinism actually durable.
2. **RNG streams + explicit RNG passing** — prevents cross-system randomness coupling.
3. **EventBus deferred emits** — prevents re-entrancy surprises and simplifies reasoning.
4. **Skill immediate execution (origin-tagged)** — preserves responsiveness without feedback loops.
5. **Trace hashing + diff tool + golden replay gate** — converts determinism into a reliable regression system.

