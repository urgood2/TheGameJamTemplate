# Master Implementation Plan — Demo Content Spec v3

## 1) Goals & Deliverables
Ship the complete Demo Content Spec v3 as a cohesive, data-driven feature set:
- **Identity:** 4 gods + 2 classes selectable at run start
- **Combat:** melee arc support + status stack decay
- **Skills:** 32 skills (8 per element) with element-lock + multi-trigger support
- **Forms:** 4 timed transformation forms with aura ticking
- **Cards/Wands:** starter wands + 6 shop wands; ~40 cards (at minimum: 12 modifiers + 16 elemental actions + required starter actions)
- **Items:** 15 artifacts + 12 equipment pieces
- **Economy/Progression:** skill points by level + stage-based shop inventory (equipment → wands → artifacts)

---

## 2) Canonical Contracts (Naming, IDs, Events, Update Order)

### 2.1 Canonical IDs & Naming
- **Elements:** `fire`, `ice`, `lightning`, `void`, `physical`
- **God IDs:** `pyr`, `glah`, `vix`, `nil` (store as string keys; never rely on dot access for `"nil"`)
- **Class IDs:** `channeler`, `seer`
- **Statuses (stacks with decay):** `scorch`, `freeze`, `charge`, `doom`, `inflame`
- **Forms (timed):** `fireform`, `iceform`, `stormform`, `voidform`
- **Cards:**
  - Modifiers: `MOD_*`
  - Actions: `ACTION_*`
- **Wands:** `WandTemplates.*` keys are **UPPER_SNAKE_CASE**
  - Starters: `VOID_EDGE`, `SIGHT_BEAM`
  - Shop wands: `RAGE_FIST`, `STORM_WALKER`, `FROST_ANCHOR`, `SOUL_SIPHON`, `PAIN_ECHO`, `EMBER_PULSE`

### 2.2 Event Contract (SkillSystem + items depend on this)
Define and emit a stable set of gameplay events (via existing `signal` system or a thin adapter layer). Payloads are consistent across codebase:
- `player_hit_enemy(player, enemy, damageInfo)`
- `damage_dealt(source, target, amount, element, damageInfo)`
- `enemy_killed(enemy, killer, killInfo)`
- `player_damaged(player, amount, source, damageInfo)`
- `status_applied(target, statusId, newStacks, source)`
- `status_stack_changed(target, statusId, newStacks, oldStacks, source)`
- `wave_start(waveIndex)`
- `frame_end(frameNumber)`
- `form_activated(entity, formId)`
- `form_expired(entity, formId)`

### 2.3 Update Order (single source of truth in main loop)
Wire the runtime to guarantee deterministic behavior:
1. Combat resolution (including status ticking/decay)
2. Emit combat events (`*_hit_*`, `damage_dealt`, `enemy_killed`, etc.)
3. Skill event capture (SkillSystem listeners append to per-frame buffer)
4. **Exactly once per frame:** `SkillSystem.end_frame()`
5. `AuraSystem.update(dt)`
6. UI

---

## 3) Multi-Agent Execution Plan (3–5 agents)

### 3.1 Workstreams (recommended 5 agents; collapsible to 3)
- **Agent A — Combat Runtime**
  - `assets/scripts/combat/*`
  - `assets/scripts/wand/wand_actions.lua` (only combat action routing)
- **Agent B — Identity + Run Start UI**
  - `assets/scripts/data/avatars.lua`
  - `assets/scripts/ui/god_select_panel.lua`
  - Minimal wiring in `assets/scripts/core/main.lua`
- **Agent C — SkillSystem Core**
  - `assets/scripts/core/skill_system.lua`
  - `assets/scripts/ui/skills_panel.lua` (lock messaging + point display)
- **Agent D — Cards + Wands Content**
  - `assets/scripts/data/cards.lua` (or split modules)
  - `assets/scripts/data/starter_wands.lua`
  - `assets/scripts/core/card_eval_order_test.lua`
- **Agent E — Items + Economy**
  - `assets/scripts/data/artifacts.lua`, `assets/scripts/data/equipment.lua`
  - `assets/scripts/ui/shop_panel.lua` (or shop core)
  - `assets/scripts/core/progression.lua` (or existing level system integration)

### 3.2 File Ownership to Avoid Conflicts
- Split heavy data edits into submodules and keep the original entry file as an aggregator:
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
    - `assets/scripts/data/cards/actions_physical.lua` (for `ACTION_MELEE_SWING` if kept here)
- Only **one** agent touches `assets/scripts/core/main.lua` at a time (Agent B owns wiring; others request small hook points via Agent Mail).

### 3.3 Integration Gates
- No merges until each workstream passes its local smoke checklist.
- Run **UBS** as the final pre-merge gate (repo policy).

---

## 4) Phases, Tasks, Dependencies, Acceptance Gates

## Phase 0 — Audit & Alignment (must complete first)
**0.1 Combat/Status/Wand/UI Audit**
- Identify:
  - Existing `StatusEngine` API and status storage shape
  - Wand action dispatch + card evaluation context shape
  - Current signal/event names already emitted
  - Shop/progression entrypoints and stage concepts
- Output: a short “Integration Notes” doc + confirmed event adapter plan.

**0.2 Lock Spec Interpretation (final rule)**
- Element lock rule (authoritative for implementation):
  - Player may invest in **up to 3 distinct elements**
  - The **first skill learned** in an element marks that element as invested
  - After the **third distinct element** is invested, the element set is locked; learning skills from any other element fails with a clear reason

---

## Phase 1 — Combat Core (foundation)
**1.1 Melee Arc System + ACTION_MELEE_SWING**
- Add `assets/scripts/combat/melee_arc.lua` with `MeleeArc.execute(caster, config)`:
  - 8-step `physics.segment_query` arc sweep
  - de-dupe hits per swing (entity id key)
  - filters: ignore caster, ignore allies, only enemies/destructibles
- Route `ACTION_MELEE_SWING` in `assets/scripts/wand/wand_actions.lua`
- Ensure hit emits `player_hit_enemy` and `damage_dealt` with `physical`

**Acceptance gate (Phase 1.1):**
- Channeler can hit 1–N enemies in a 90° arc; each enemy max once per swing; no crashes with empty arc.

**1.2 Status Stack Decay (centralized in StatusEngine)**
- Implement decay for `scorch`, `freeze`, `doom`, `charge`, `inflame`
- Use accumulator (`decayTimer += dt`) with bounded tick loops for large `dt`
- Emit `status_stack_changed` on decay, remove status at 0 stacks
- Add per-status/per-entity opt-out flag (used by forms and specific skills)

**Acceptance gate (Phase 1.2):**
- Decay timing matches config; stacks never negative; removal triggers cleanup.

**1.3 Starter Wands**
- Create `assets/scripts/data/starter_wands.lua` with:
  - `VOID_EDGE` (0.3s trigger, 40 mana, 4 slots, includes `ACTION_MELEE_SWING`)
  - `SIGHT_BEAM` (1.0s trigger, 80 mana, 6 slots, includes a ranged starter action)
- Register into `assets/scripts/core/card_eval_order_test.lua` (and wand template registry)

**Acceptance gate (Phase 1.3):**
- Both starter wands instantiate with correct starting cards and stats; class restriction enforced at grant time.

---

## Phase 2 — Identity (Gods, Classes, Run Start)
**2.1 Avatars: Gods + Classes**
- Implement in `assets/scripts/data/avatars.lua`:
  - `Avatars.gods[id] = { element, blessing{cooldown, execute}, passive{trigger, effect}, starter_equipment, starter_artifact }`
  - `Avatars.classes[id] = { starter_wand, passive, triggered }`
- Provide accessors:
  - `Avatars.get_god(id)` (handles `"nil"` safely)
  - `Avatars.get_class(id)`

**2.2 Starter Loadout Grant**
- Implement a single idempotent grant function (new helper module or in existing inventory layer):
  - grants exactly: 1 starter wand + 1 starter equipment + 1 starter artifact
  - applies god/class runtime state and registers passives/triggers

**2.3 God/Class Selection UI**
- Add `assets/scripts/ui/god_select_panel.lua`:
  - 2×2 god grid + class selector + preview panel (blessing/passive + starter gear + starter wand)
  - confirm disabled until both selected
  - on confirm: applies identity + grants loadout + transitions into gameplay

**Acceptance gate (Phase 2):**
- From fresh boot: player selects god+class, sees correct preview, starts run with correct loadout and passive behavior.

---

## Phase 3 — Skill System Mechanics
**3.1 Element Lock Enforcement**
- `assets/scripts/core/skill_system.lua`:
  - `SkillSystem.can_learn(player, skillId)` checks skill points, prerequisites, and element lock
  - Track `player.elements_invested` and lock after 3 distinct elements
- `assets/scripts/ui/skills_panel.lua` shows:
  - invested elements and lock state
  - clear failure messaging on blocked learn

**3.2 Multi-Trigger Resolution (same frame)**
- Add per-frame event buffer:
  - `SkillSystem.on_event(eventType, eventData)` stores events
  - `SkillSystem.end_frame()` builds index and resolves multi-trigger skills once per frame
- Ensure `end_frame()` is called exactly once from main loop (Phase 2/0 wiring)

**Acceptance gate (Phase 3):**
- Single-trigger skills behave as before; multi-trigger skills only fire when all triggers occurred in the same frame; UI blocks locked elements correctly.

---

## Phase 4 — Skills Content (32 skills)
**4.1 Skills Data Modules**
- Implement 32 skills as data-driven entries (8 per element) in split modules:
  - `assets/scripts/data/skills/fire.lua`
  - `assets/scripts/data/skills/ice.lua`
  - `assets/scripts/data/skills/lightning.lua`
  - `assets/scripts/data/skills/void.lua`
- Each skill defines:
  - `id`, `element`, `cost`, `display_name`, `description`
  - `triggers` (string or array) and `execute(player, eventData)`
  - optional `on_learn(player)` for passives
  - optional cooldown/threshold metadata (handled by SkillSystem if supported)

**4.2 Event Coverage for Skills**
Ensure the runtime emits enough events for all skills to function:
- elemental damage events (`damage_dealt` with element)
- kill events (`enemy_killed`)
- wave start (`wave_start`)
- player damaged (`player_damaged`)
- status applied/changed (`status_applied`, `status_stack_changed`)

**Acceptance gate (Phase 4):**
- Exactly 32 skills load (unique IDs), learn successfully, and each can be triggered in a controlled smoke run without runtime errors.

---

## Phase 5 — Forms + Aura System
**5.1 Form Status Definitions**
- In `assets/scripts/data/status_effects.lua`, define:
  - `fireform`, `iceform`, `stormform`, `voidform`
  - each has: `duration` (30–60s), `stat_mods`, `aura{radius, tick_interval, effects[]}`, `visuals`, `decay_immune=true`
  - `on_apply` emits `form_activated`; `on_expire/on_remove` emits `form_expired`

**5.2 AuraSystem Runtime**
- Add `assets/scripts/combat/aura_system.lua`:
  - `register(entity, auraId, config)`, `unregister(entity, auraId)`, `update(dt)`
  - tick applies damage + status stacks to enemies in radius
  - cleans up dead entities automatically

**5.3 Form Threshold Tracking**
- Implement threshold tracking driven by `damage_dealt` events:
  - counters per element on player (e.g., `fire_damage_accum`)
  - form skill enables threshold behavior; when reached, applies form status and resets counter

**Acceptance gate (Phase 5):**
- At least one form can be triggered naturally via skill thresholds; aura ticks for full duration; cleanup occurs on expiry and player death.

---

## Phase 6 — Cards & Wands (full pool + triggers)
**6.1 Modifier Cards (12)**
- Implement in `assets/scripts/data/cards/modifiers.lua` with existing card schema:
  - Chain 2, Pierce, Fork, Homing, Larger AoE, Concentrated, Delayed, Rapid, Empowered, Efficient, Lingering, Brittle
- Validate stacking behavior via `assets/scripts/core/card_eval_order_test.lua`

**6.2 Action Cards (16 elemental)**
- Implement 4 per element across:
  - `assets/scripts/data/cards/actions_fire.lua`
  - `assets/scripts/data/cards/actions_ice.lua`
  - `assets/scripts/data/cards/actions_lightning.lua`
  - `assets/scripts/data/cards/actions_void.lua`
- Ensure each action emits correct elemental `damage_dealt` events and applies status stacks as specified.

**6.3 Findable (Shop) Wands (6) + Trigger Types**
- Define 6 templates in wand template registry with trigger metadata + shop pricing/stages:
  - `on_bump_enemy`
  - `on_distance_traveled(distance)`
  - `on_stand_still(duration)`
  - `on_enemy_killed`
  - `on_player_hit`
  - `every_N_seconds(interval)`
- Implement/extend trigger registration in the wand system (with proper unregister on unequip).

**Acceptance gate (Phase 6):**
- Modifiers affect action execution deterministically; 6 shop wands fire under their triggers and do not leak timers/handlers when swapped.

---

## Phase 7 — Artifacts & Equipment
**7.1 Artifacts (15 across 3 tiers)**
- In `assets/scripts/data/artifacts.lua` define:
  - 5 common + 5 uncommon + 5 rare
- Require every artifact effect to be:
  - stat-mod based OR event-hook based with explicit register/unregister
- Prefer using the canonical event contract over bespoke timers where possible.

**7.2 Equipment (12 across 3 slots)**
- In `assets/scripts/data/equipment.lua` define:
  - 4 chest, 4 gloves, 4 boots
- Ensure equipment system cleanly applies/removes stat mods and hooks.

**Acceptance gate (Phase 7):**
- All items load; equipping/unequipping never stacks permanently; starter equipment references are valid.

---

## Phase 8 — Economy & Progression
**8.1 Skill Points by Level**
- Integrate into existing level-up flow:
  - Level 1: 0 points
  - Levels 2–6: +2 points each (10 total by level 6)
- UI shows current available points immediately on grant.

**8.2 Shop Stage Timeline**
- Implement stage-based shop inventory generation:
  - Stage 1: equipment only
  - Stage 2: equipment + 1–2 wands
  - Stage 3: equipment + 1–2 wands + artifact (elite drop / chance)
  - Stage 4: equipment + 1–2 wands + artifact (guaranteed)
  - Stage 5: boss (no shop)
- Enforce: starter wands never appear for sale; shop wands priced 25–50g.

**Acceptance gate (Phase 8):**
- Shop contents follow stage table; purchasing deducts gold correctly; no empty-inventory softlocks (fallbacks applied).

---

## 5) Validation, QA, and Definition of Done

### 5.1 Automated Validation (dev-only script)
Add a lightweight validator that asserts:
- Unique IDs across skills/cards/wands/items/statuses
- All references exist (starter cards, starter gear, form status IDs, shop wand IDs)
- No missing required fields (e.g., `mana_cost`, `type`, `element` where applicable)

### 5.2 Manual Smoke Checklist (must pass)
- Start run for all 8 god/class combinations (4×2) and confirm correct loadout
- Verify status decay visually and numerically (scorch/freeze/charge/doom/inflame)
- Learn skills across up to 3 elements; confirm 4th element is blocked with message
- Trigger at least one multi-trigger skill successfully
- Trigger at least one form and observe aura ticks + expiry cleanup
- Buy and use at least 2 shop wands; confirm triggers work and stop after unequip
- Equip 3 equipment slots + 2 artifacts; confirm stats/effects apply and remove cleanly
- Run UBS before merging final workstreams