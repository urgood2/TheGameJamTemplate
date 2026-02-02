# Executive Summary (TL;DR)

Implement Demo Content Specification v3 end-to-end (no scope cuts) by adding a small set of core runtime systems (MeleeArc, StatusEngine decay, SkillSystem element-lock + multi-trigger, AuraSystem for forms), then layering data-driven content (gods/classes/skills/cards/wands/items) and integrating acquisition + UI (god select, skills panel, shop timeline). Work is organized into parallel agent-friendly workstreams with explicit integration contracts (IDs, event pipeline, and system entrypoints) and per-task acceptance criteria.

---

# Architecture Overview

## Runtime module layout (Lua)

- **Combat**
  - `assets/scripts/combat/combat_system.lua`  
    Owns `CombatSystem.update(dt)` orchestration and the centralized `StatusEngine` (apply/remove/update hooks).
  - `assets/scripts/combat/melee_arc.lua` (NEW)  
    Owns melee sweep execution: `MeleeArc.execute(caster, config)` (8-step segment sweep + per-swing de-dupe).
  - `assets/scripts/combat/aura_system.lua` (NEW)  
    Owns aura ticking for form buffs: `AuraSystem.register(entityId, auraConfig)`, `AuraSystem.unregister(entityId, auraId)`, `AuraSystem.update(dt)`.

- **Core**
  - `assets/scripts/core/main.lua`  
    Wires update order and UI flow: god/class selection before run start; calls `SkillSystem.end_frame()` exactly once per frame; calls `AuraSystem.update(dt)`.
  - `assets/scripts/core/skill_system.lua`  
    Owns skill learn logic, element investment tracking/locking, event capture, and multi-trigger evaluation.
  - `assets/scripts/core/card_eval_order_test.lua`  
    Treated as the canonical wand template evaluation harness; used to validate modifier/action ordering (and expanded to include new wands).

- **UI**
  - `assets/scripts/ui/god_select_panel.lua` (NEW)  
    One-shot pre-run screen that previews starter gear + artifact for selected god and starter wand(s) per class.
  - `assets/scripts/ui/skills_panel.lua`  
    Shows element lock state, prevents learning locked elements with a clear message, and displays per-element investment counts.

- **Data (data-driven content)**
  - `assets/scripts/data/avatars.lua` (gods + classes)
  - `assets/scripts/data/skills.lua` (32 skills, 8 per element)
  - `assets/scripts/data/cards.lua` (~40 cards: 12 modifiers + 16 actions + any additional spec-defined)
  - `assets/scripts/data/status_effects.lua` (Scorch/Freeze/Doom/Charge/Inflame + 4 forms; confirm list since spec table says “8” but enumerates 9)
  - `assets/scripts/data/artifacts.lua` (15)
  - `assets/scripts/data/equipment.lua` (12)
  - `assets/scripts/data/starter_wands.lua` (NEW; stable definitions for VOID_EDGE + SIGHT_BEAM)
  - `assets/scripts/wand/wand_actions.lua` (links ACTION_* to executors, including melee swing)

## Key data structures (contracts)

- **Status instance (per entity)**
  - `statuses[statusId] = { stacks:int, durationRemaining?:number, decayTimer?:number, sourceId?:string, ... }`
- **SkillSystem player state**
  - `player.skill_points_spent:int`
  - `player.elements_invested = { [elementId]=true }`
  - `player.element_lock = { locked:boolean, allowed = { [elementId]=true } }`
- **Frame event buffer (SkillSystem)**
  - `SkillSystem.frame_events = { {type=string, data=table}... }`
  - `SkillSystem.frame_event_index = { [eventType] = {event1,event2,...} }` (rebuilt each frame for O(1) presence checks)
- **Card definition**
  - `Cards[cardId] = { id, type=("modifier"|"action"), mana_cost, tags, eval=(fn or descriptor), ... }`
- **Wand template**
  - `WandTemplates[wandId] = { id, trigger_type, trigger_interval?, mana_max, mana_recharge_rate, cast_block_size, cast_delay, recharge_time, total_card_slots, starting_cards={...}, price?, shop_only? }`

## Update order (frame contract)

1. Input + movement
2. Combat resolution (including `StatusEngine.update_entity(dt, ...)`)
3. Skill event emission (`SkillSystem.on_event(...)` called by combat hooks)
4. **End-of-frame gate:** `SkillSystem.end_frame()` (evaluates multi-trigger skills with “ALL triggers in same frame”)
5. Aura ticking: `AuraSystem.update(dt)` (or earlier if it must apply before end-frame; decide once and keep consistent)
6. UI

---

# Phase Breakdown (Numbered Tasks)

## Phase 0 — Alignment & Interfaces (parallel kickoff)

### 0.1 Define canonical IDs + naming rules (S)
**Files:** `planning/DEMO_CONTENT_SPEC_v3.md`, `planning/INTERVIEW_TRANSCRIPT.md` (read-only references), plus a shared note in Agent Mail thread.  
**Work:** Lock conventions (e.g., elements: `"fire"|"ice"|"lightning"|"void"`, statuses lowercase, cards `MOD_*`/`ACTION_*`, wands uppercase).  
**Acceptance criteria:**
- Every system uses the same `elementId` strings and canonical IDs.
- A published “ID Map” message exists in Agent Mail for all agents to follow.

### 0.2 Establish multi-agent coordination protocol (S)
**Work:** Use Agent Mail to assign workstreams and reserve files (avoid conflicts on `assets/scripts/data/*.lua`).  
**Acceptance criteria:**
- One Agent Mail thread per workstream with clear ownership.
- File reservation plan documented (who touches which paths).

---

## Phase 1 — Core Combat Systems

### 1.1 Implement Melee Arc (8-step line sweep) for Channeler (M)
**Owner suggestion:** Combat workstream  
**Files:**  
- `assets/scripts/combat/melee_arc.lua` (NEW)  
- `assets/scripts/wand/wand_actions.lua` (MODIFY)  
- `assets/scripts/data/cards.lua` (ADD `ACTION_MELEE_SWING`)  
**Implementation details:**
- Add `MeleeArc.execute(caster, config)`:
  - `steps = 8`, compute `startAngle`, `stepAngle`, perform `physics.segment_query(...)`.
  - De-dupe per swing using `hitEntities[entityId]=true` (entityId, not pointer).
  - Enforce hit filtering: enemies only, ignore caster, ignore dead/invulnerable flags.
- In `wand_actions.lua`, route card `ACTION_MELEE_SWING` to `MeleeArc.execute(...)`.
**Edge cases / failure modes:**
- Segment query returns multiple shapes per entity → must de-dupe.
- Large `dt` or slow frame → swing should still be one logical action (not multiple executions).
- Facing direction unavailable → fall back to last-known facing vector.
**Acceptance criteria:**
- One swing can hit multiple enemies but each enemy max once per swing.
- Arc respects `arc_angle`, `range`, `duration`; matches spec feel.
- No crashes when no enemies/shapes are returned.

### 1.2 Centralized Status Decay in StatusEngine (M)
**Owner suggestion:** Combat workstream  
**Files:**  
- `assets/scripts/combat/combat_system.lua` (MODIFY)  
- `assets/scripts/data/status_effects.lua` (MODIFY)  
**Implementation details:**
- Add `STATUS_DECAY_RATES` table in `combat_system.lua` and update loop:
  - Use `data.decayTimer += dt`; apply decay in a `while data.decayTimer >= interval do ... end` loop (cap max ticks per update to avoid spiral-of-death on huge dt).
  - When `stacks` reaches 0 → `StatusEngine.remove(entityId, statusId)` and trigger `on_remove` if defined.
- Ensure safe iteration (don’t mutate the `statuses` table while iterating without collecting removals).
**Edge cases / failure modes:**
- `dt` spikes can decay multiple stacks at once; cap to preserve game feel.
- Statuses with both `duration` and `stacks` must behave deterministically (define precedence: duration expiry removes regardless of stacks, or vice versa).
**Acceptance criteria:**
- Scorch/Freeze/Doom/Charge/Inflame stacks decay at specified intervals.
- Removing the last stack always cleans up status visuals/effects.
- No status “sticks” forever due to timer drift.

### 1.3 Starter Wands as stable data (S)
**Owner suggestion:** Data workstream (wands)  
**Files:**  
- `assets/scripts/data/starter_wands.lua` (NEW)  
- `assets/scripts/core/card_eval_order_test.lua` (MODIFY)  
**Implementation details:**
- Define `WandTemplates.VOID_EDGE` and `WandTemplates.SIGHT_BEAM` per spec.
- Ensure templates are imported/registered in the same way as existing wands.
- Extend `card_eval_order_test.lua` to include these templates as golden references for ordering.
**Acceptance criteria:**
- Both starter wands can be instantiated without missing card IDs.
- Eval order test includes both and passes locally once run.

---

## Phase 2 — Gods & Classes (Identity at run start)

### 2.1 God + Class definitions in Avatars (M)
**Owner suggestion:** Data workstream (avatars)  
**Files:** `assets/scripts/data/avatars.lua` (MODIFY)  
**Implementation details:**
- Add 4 gods (`pyr`, `glah`, `vix`, `nil`) with:
  - `blessing = { id, cooldown, effect(player) }`
  - `passive = { trigger, effect(...) }`
  - `starter_equipment`, `starter_artifact`
- Add 2 classes (`channeler`, `seer`) with:
  - `starter_wand` id
  - `passive` and any triggered mechanics described in spec.
**Edge cases:**
- Blessing targets/queries must handle “no enemies” gracefully.
- Passive triggers must not spam apply on multi-hit in same frame unless intended.
**Acceptance criteria:**
- Selecting a god/class results in the correct starter wand, equipment, artifact, and passive/blessing availability.
- No nil accesses when blessing is used in empty room.

### 2.2 Apply starter gear reliably (M)
**Owner suggestion:** Economy/core workstream  
**Files:** `assets/scripts/core/main.lua` (MODIFY) and/or existing inventory/equipment modules (wire-in point discovered during implementation).  
**Implementation details:**
- Add a single “grant starter loadout” function:
  - `GrantStarterLoadout.apply(player, godId, classId)` (can be implemented in `main.lua` if no core helper exists, or a new helper module if needed).
- Ensure idempotency: calling twice does not duplicate items.
**Acceptance criteria:**
- Start run always yields exactly: 1 starter wand, 1 starter equipment piece, 1 starter artifact.
- UI preview matches granted items.

### 2.3 God selection UI with starter previews (L)
**Owner suggestion:** UI workstream  
**Files:**  
- `assets/scripts/ui/god_select_panel.lua` (NEW)  
- `assets/scripts/core/main.lua` (MODIFY)  
**Implementation details:**
- UI shows:
  - 4 god cards (name, blessing, passive)
  - Separate class selector (Channeler/Seer)
  - Starter equipment + artifact preview (from selected god)
  - Starter wand preview (from selected class)
- Confirm button:
  - Persists selection to player/run state
  - Grants starter loadout
  - Transitions into gameplay
**Edge cases:**
- Prevent confirm until both god and class selected.
- Handle missing icon/asset references without crashing (fallback text).
**Acceptance criteria:**
- Player cannot start a run without a valid god+class.
- Preview content matches data definitions exactly.

---

## Phase 3 — Skills System (32 skills + element lock + multi-trigger)

### 3.1 Element lock mechanic (“3rd skill point triggers lock”) (M)
**Owner suggestion:** Core/skills workstream  
**Files:**  
- `assets/scripts/core/skill_system.lua` (MODIFY)  
- `assets/scripts/ui/skills_panel.lua` (MODIFY)  
**Implementation details (make rule explicit):**
- Track total spent points and invested elements:
  - Increment `player.skill_points_spent` on successful learn.
  - Maintain `player.elements_invested[element]=true` when learning first skill in an element.
- Lock behavior (recommended interpretation consistent with “3 elements max”):
  - When player invests in a **third distinct element**, set `player.element_lock.locked=true` and freeze `allowed` to the 3 invested elements.
  - After lock, learning skills from a non-allowed element fails with `"Element locked"`.
- UI must clearly show locked elements and allowed set.
**Edge cases:**
- If first 3 skills are all same element, lock should **not** restrict to 1 element; ensure lock is based on **distinct elements**, not total points.
- Respec not supported: block any feature that would “unlearn” without defined behavior.
**Acceptance criteria:**
- Player can invest in up to 3 elements; cannot learn a 4th element skill after lock.
- Lock triggers exactly when the third distinct element is first invested (and never earlier).

### 3.2 Multi-trigger skills (“ALL triggers required, same frame”) (M)
**Owner suggestion:** Core/skills workstream  
**Files:** `assets/scripts/core/skill_system.lua` (MODIFY)  
**Implementation details:**
- Add:
  - `SkillSystem.on_event(eventType, eventData)` to append to `frame_events`.
  - `SkillSystem.end_frame()` to:
    - Build `frame_event_index` (eventType → list of events).
    - For each active skill with `skill.triggers = { ... }` where `#triggers > 1`, require `frame_event_index[trigger]` exists for **all** triggers.
    - Call `executeSkillEffect(skill, frame_event_index)` once per frame when satisfied.
- Ensure `SkillSystem.end_frame()` is called from `assets/scripts/core/main.lua` exactly once per frame after all relevant systems emit events.
**Edge cases:**
- Multiple occurrences of same trigger in frame: provide the full list to the effect so it can choose.
- Avoid double-firing if end_frame called twice (guard with `frame_id` or clear-once semantics).
**Acceptance criteria:**
- Skills with triggers `{"on_hit","on_fire_damage"}` only fire on frames where both events occurred.
- Single-trigger skills continue to function as before.

### 3.3 Implement 32 skills (8 per element) in data (L)
**Owner suggestion:** Data/skills workstream  
**Files:** `assets/scripts/data/skills.lua` (MODIFY)  
**Implementation details:**
- Define each skill with:
  - `id`, `name`, `element`, `cost`, `description`
  - `triggers` (single string or list), plus effect function or effect descriptor
  - Any threshold trackers for form unlock skills (e.g., `on_threshold(100 fire)`; implement as explicit trigger type + counter key)
- Ensure each skill’s effect interacts with:
  - `StatusEngine.apply/remove`
  - Damage helpers (`dealDamage`, `dealAoEDamage`)
  - Summon helpers if applicable (e.g., Familiar)
**Edge cases:**
- Skills referencing statuses must use canonical status IDs.
- Summons must be cleaned up on room transition or timeouts if not permanent.
**Acceptance criteria:**
- Exactly 32 skills load with unique IDs and correct element assignment.
- All skills can be learned and invoked without runtime errors (smoke test run).
- Multi-trigger skills use the multi-trigger pipeline, not ad-hoc checks.

---

## Phase 4 — Transformation Forms (timed 30–60s) + Auras

### 4.1 Define 4 timed form statuses (M)
**Owner suggestion:** Data/status workstream  
**Files:** `assets/scripts/data/status_effects.lua` (MODIFY)  
**Implementation details:**
- Add `fireform`, `iceform`, `lightningform`, `voidform`:
  - `duration = 30..60` seconds (pick exact value per spec; store per status)
  - `stat_mods` (e.g., `mult` bonuses)
  - `aura` config (radius, tick_interval, damage/status application)
  - `on_apply(entityId)` emits `signal.emit("form_activated", ...)` and registers aura
  - `on_remove(entityId)` emits `signal.emit("form_expired", ...)` and unregisters aura and resets threshold counters
**Edge cases:**
- Re-applying a form while active: decide policy (refresh duration vs ignore); implement explicitly and consistently.
**Acceptance criteria:**
- Forms expire automatically; effects stop immediately on expiry.
- Visual hooks (shader/particles) fail gracefully if assets missing.

### 4.2 Implement AuraSystem tick loop (M)
**Owner suggestion:** Combat workstream  
**Files:** `assets/scripts/combat/aura_system.lua` (NEW), `assets/scripts/core/main.lua` (MODIFY), `assets/scripts/combat/combat_system.lua` (optional integration)  
**Implementation details:**
- `AuraSystem.register(entityId, auraId, config)` stores `active_auras[entityId][auraId] = {config, tickTimer=0}`
- `AuraSystem.update(dt)` increments timers and ticks using a bounded `while` loop for large dt (cap ticks/update).
- `AuraSystem.tick(entityId, config)`:
  - Area query; filter enemies; apply damage + status stacks.
**Edge cases:**
- Entity removed/dead: AuraSystem must auto-clean entries to avoid leaking tables.
- World query returns non-entities: ignore safely.
**Acceptance criteria:**
- Aura damage/status applies at the configured cadence, not frame-rate dependent.
- No crashes when caster dies mid-form.

### 4.3 Threshold tracking to trigger forms (M)
**Owner suggestion:** Core/skills workstream  
**Files:** `assets/scripts/core/skill_system.lua` (MODIFY) and/or `assets/scripts/combat/combat_system.lua` (hook points)  
**Implementation details:**
- Add per-player counters (e.g., `player.fire_damage_accum`, etc.).
- When damage of an element is dealt, emit event with amount; update counters.
- When threshold reached and “Form skill” learned, apply corresponding form status and reset counter.
**Acceptance criteria:**
- Forms trigger only when the player has learned the relevant form skill.
- Threshold logic is deterministic across frame spikes (no double-trigger).

---

## Phase 5 — Cards & Wands

### 5.1 Add 12 modifier cards (M)
**Owner suggestion:** Data/cards workstream  
**Files:** `assets/scripts/data/cards.lua` (MODIFY)  
**Implementation details:**
- Each modifier defines:
  - Mana cost adjustment
  - A deterministic mutation of an “action context” (e.g., `ctx.damage_mult`, `ctx.chain_count`, `ctx.pierce`, `ctx.aoe_radius_mult`)
- Ensure modifier stacking order is explicit and validated via `card_eval_order_test.lua`.
**Edge cases:**
- Mutually exclusive modifiers (e.g., Larger AoE vs Concentrated): define stacking rule (multiply in sequence or last-wins) and stick to it.
**Acceptance criteria:**
- All 12 modifiers load and apply without nil field errors.
- Existing card evaluation still works; new ones have predictable stacking.

### 5.2 Add 16 action cards (M)
**Owner suggestion:** Data/cards workstream + Combat workstream as needed  
**Files:** `assets/scripts/data/cards.lua` (MODIFY), `assets/scripts/wand/wand_actions.lua` (MODIFY if new executors needed)  
**Implementation details:**
- Define 4 actions per element (projectiles/AoE/utility) per spec.
- Actions must consume the same “action context” modifiers produced in 5.1.
**Acceptance criteria:**
- All 16 actions execute under the wand system with modifiers applied.
- Actions emit appropriate skill events (hit, elemental damage, kill, etc.) for SkillSystem triggers.

### 5.3 Implement 6 shop-only wands (M)
**Owner suggestion:** Data/wands workstream + Economy workstream  
**Files:** `assets/scripts/core/card_eval_order_test.lua` (MODIFY), plus the shop inventory module/logic used by the project (or introduce `assets/scripts/core/shop_inventory.lua` if none exists)  
**Implementation details:**
- Define the 6 templates with correct triggers and `price` in [25..50].
- Enforce acquisition rule: `shop_only=true` and ensure drop tables never spawn these wands.
**Edge cases:**
- If the game already has random wand drops, ensure a single authoritative filter prevents spawning shop-only wands outside shops.
**Acceptance criteria:**
- Wands appear only in shops at the correct stages and prices.
- Buying a wand grants exactly one instance and removes it from stock.

---

## Phase 6 — Artifacts & Equipment (15 + 12)

### 6.1 Add 15 artifacts (L)
**Owner suggestion:** Data/items workstream  
**Files:** `assets/scripts/data/artifacts.lua` (MODIFY)  
**Implementation details:**
- Add tiered artifacts (common/uncommon/rare) with deterministic effects:
  - Passive stat mods (e.g., damage multipliers, status interactions)
  - Triggered effects (hook into SkillSystem events or CombatSystem hooks)
- Ensure effects are centralized (avoid per-artifact ad-hoc timers; prefer using SkillSystem events or StatusEngine hooks).
**Acceptance criteria:**
- All 15 artifacts load with unique IDs and tiers.
- Each artifact effect can be activated/observed in a debug run without errors.

### 6.2 Add 12 equipment pieces (M)
**Owner suggestion:** Data/items workstream  
**Files:** `assets/scripts/data/equipment.lua` (MODIFY)  
**Implementation details:**
- Define 4 chest, 4 gloves, 4 boots with stats and any on-equip effects.
- Ensure equip rules are enforced: one per slot; swapping removes old stats cleanly.
**Acceptance criteria:**
- Equipping/unequipping updates stats correctly (no stacking leaks).
- Starter equipment from gods matches one of these definitions.

### 6.3 Integrate acquisition timeline (M)
**Owner suggestion:** Economy workstream  
**Files:** shop/drop integration module(s) (wire-in discovered), plus `assets/scripts/core/main.lua` if stage progression is owned there.  
**Implementation details:**
- Stage 1: equipment only
- Stage 2: equipment + 1–2 wands (shop-only rule still applies)
- Stage 3: equipment + artifact (elite drop)
- Stage 4: equipment + wand + artifact
- Stage 5: boss
**Acceptance criteria:**
- Shop inventory matches stage table; wand availability starts at stage 2.
- Artifact drops occur only from elite drop at stage 3 (and later rules as specified).

---

## Phase 7 — Economy & Progression

### 7.1 Skill point grants by level (M)
**Owner suggestion:** Economy/core workstream  
**Files:** progression/level-up handler module (wire-in discovered; if absent, introduce `assets/scripts/core/progression.lua` and call from `assets/scripts/core/main.lua`)  
**Implementation details:**
- Grant schedule:
  - Level 2..6: +2 points each (total 10 by level 6)
- Persist on player state: `player.skill_points_available`
**Edge cases:**
- Level skipping (big XP): apply multiple level grants in one update deterministically.
- New run resets points correctly.
**Acceptance criteria:**
- Reaching each level yields the exact number of points once (no duplication on reload/frame).
- UI updates immediately when points are granted.

### 7.2 Shop wand integration + price bounds (S)
**Owner suggestion:** Economy workstream  
**Files:** shop inventory module  
**Implementation details:**
- Wands priced 25–50g; starter wands never sold.
- Ensure coin spend checks and insufficient funds messaging.
**Acceptance criteria:**
- Attempting to buy without enough gold fails with clear feedback.
- Prices always fall within bounds.

---

# Critical Path & Dependencies

- **Must land first (foundation):**
  1. Phase 1.2 (StatusEngine decay) — required by many skills and form expirations.
  2. Phase 3.2 (SkillSystem multi-trigger pipeline) — required by multi-trigger skills and consistent behavior.
  3. Phase 2.3 (God selection UI wiring) — required to preview and grant starter loadout cleanly.

- **Depends on foundation:**
  - Phase 4 (Forms) depends on StatusEngine + SkillSystem event emission + AuraSystem wiring.
  - Phase 5 (Cards/Wands) depends on wand action routing and stable action context evaluation order.
  - Phase 6–7 (Items/Economy) depend on shop/stage progression entrypoints.

- **Parallel-safe workstreams (minimize file conflicts):**
  - Combat: `assets/scripts/combat/*`, `assets/scripts/wand/wand_actions.lua`
  - UI: `assets/scripts/ui/*`, minimal touches to `assets/scripts/core/main.lua` (coordinate via Agent Mail)
  - Data: split by file ownership:
    - Avatars: `assets/scripts/data/avatars.lua`
    - Skills: `assets/scripts/data/skills.lua`
    - Cards: `assets/scripts/data/cards.lua`
    - Statuses: `assets/scripts/data/status_effects.lua`
    - Items: `assets/scripts/data/artifacts.lua`, `assets/scripts/data/equipment.lua`
  - Economy: shop/progression modules + minimal main wiring

---

# Risk Mitigation

- **Spec ambiguity (element lock + status count):**
  - Resolve by writing an explicit rule for “3rd skill point triggers lock” (lock on 3rd *distinct element*) and confirming against `planning/DEMO_CONTENT_SPEC_v3.md` before coding; document final rule in Agent Mail.
  - Treat the enumerated status list as authoritative even if the count header is inconsistent.

- **Performance hotspots (melee sweep + aura ticks):**
  - Enforce de-dupe maps by entityId and cap tick loops on large `dt`.
  - Keep queries bounded (segment count fixed at 8; aura tick interval ≥ 0.25s).

- **Event ordering bugs (multi-trigger same frame):**
  - Centralize event emission points (combat hooks only) and call `SkillSystem.end_frame()` once per frame from `assets/scripts/core/main.lua`.
  - Add a debug-only counter/guard to prevent double end_frame calls.

- **Data integrity (IDs, missing references):**
  - Add a lightweight runtime validator (even if only in dev builds) that asserts uniqueness and existence of referenced IDs (skills↔statuses, cards↔actions, wands↔cards).

- **Multi-agent merge conflicts:**
  - Use Agent Mail to reserve `assets/scripts/data/*.lua` files per owner and avoid simultaneous edits; integrate via small, frequent merges.
  - Run UBS before commits (per repo policy) as the final gate before merging workstreams.