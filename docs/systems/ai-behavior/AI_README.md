# GOAP Goal Selector — How To Configure (Rundown)

> Minimal, type-aware goal selection that plays nice with your existing GPGOAP + Lua actions

---

## Files at a glance

* **`ai/ai.init.lua`** — builds the global `ai` table, loads actions, selectors, blackboard init, entity presets, updaters; defines **shared policy** (bands) and **shared goals** (e.g., `digforgold`, `wander`, optional `eat`).
* **`ai/selector.lua`** — generic selector: **desire + hysteresis** (persist) + **band arbitration**. Writes `current_goal` to blackboard and calls `on_apply` for the chosen goal.
* **`ai/goal_selectors/<type>.lua`** — per-entity-type hook. Usually just calls the generic selector, but you can tweak `def.policy` / `def.goals` here to customize behavior per type.
* **`ai/worldstate_updaters.lua`** — “sensors” that set worldstate atoms every tick (e.g., `candigforgold`, `hungry`, cooldowns).
* **`ai/actions/<action>.lua`** — your standard GOAP actions (`pre`, `post`, `start/update/finish`).
* **`ai/blackboard_init/<type>.lua`** — initial blackboard seeds for a type.
* **`ai/entity_types/<type>.lua`** — initial & default goal worldstate for a type (used only at init; later the selector sets goals per tick).

---

## Data model (simple)

Each **goal** is a Lua table:

```lua
<goal_id> = {
  band    = "SURVIVAL" | "WORK" | "IDLE" | "COMBAT",
  persist = 0.05..0.15,        -- hysteresis boost while active
  desire  = function(e, S) -> [0..1],  -- urgency (use worldstate / blackboard)
  veto    = function(e, S) -> bool,    -- cheap “skip” (optional)
  on_apply= function(e)                 -- translate to GOAP target
              ai.set_goal(e, { some_atom = <bool>, ... })
            end
}
```

* **desire**: reads **worldstate**/blackboard and returns a 0..1 urgency.
* **persist**: small stickiness to avoid flip-flop.
* **band**: coarse priority class; higher bands override.
* **on\_apply**: sets the **GOAP goal** (target atoms). C++ then calls `replan(entity)`.

---

## What happens per tick

1. C++ runs **actions** (coroutines).
2. C++ runs **worldstate updaters** → flips atoms like `candigforgold`, `hungry`.
3. C++ checks: if current worldstate deviates from cached, or plan ends/fails → **select\_goal(entity)** (Lua) → **replan** (C++).
4. Selector:

   * computes `pre = desire + persist_if_current`,
   * sorts candidates by `pre`,
   * band arbitration (SURVIVAL > WORK > IDLE),
   * if winner changed → writes `current_goal` + calls `on_apply`,
   * C++ replans immediately.

---

## Hungry mid-action — exact behavior

* Updater sets `hungry=true` when blackboard hunger drops.
* `update_goap` detects worldstate change → calls selector → replans.
* **If `EAT` goal exists (SURVIVAL band)** → interrupts current plan; new plan addresses hunger.
* **If not** → plan won’t change to handle hunger.

---

## Configure per-type strategy

### Option A: Per-type selector tweak

```lua
-- ai/goal_selectors/healer.lua
local selector = require("ai.selector")
return function(e)
  local def = ai.get_entity_ai_def(e)
  def.policy = { band_rank = { COMBAT=4, SURVIVAL=3, WORK=1, IDLE=0 } }
  def.goals.HEAL = {
    band="SURVIVAL", persist=0.10,
    desire=function(e) return ai.get_worldstate(e,"canhealother") and 1 or 0 end,
    on_apply=function(e) ai.set_goal(e,{ ally_stabilized=true }) end
  }
  selector.select_and_apply(e)
end
```

### Option B: Swap goal tables

```lua
-- ai/goal_selectors/gold_digger.lua
local selector = require("ai.selector")
return function(e)
  local def = ai.get_entity_ai_def(e)
  def.policy = ai.policy
  def.goals  = ai.goals_gold_digger
  selector.select_and_apply(e)
end
```

---

## Recommended goals

Add an `EAT` goal so hunger can preempt:

```lua
ai.goals.EAT = {
  band    = "SURVIVAL",
  persist = 0.10,
  desire  = function(e)
    local h = getBlackboardFloat(e, "hunger") or 0.0
    return h
  end,
  veto    = function(e)
    return not (ai.get_worldstate(e,"has_food") or ai.get_worldstate(e,"food_visible"))
  end,
  on_apply= function(e)
    ai.set_goal(e, { hungry = false })
  end
}
```

---

## Interrupt policy (optional)

* Current system drops actions without calling `finish()`.
* To improve: add `interruptible=true/false` on actions, or implement a lock timer.
* Optionally call `finish()` before clearing the queue in `fill_action_queue_based_on_plan`.

---

## Cooldowns

* Keep cooldown gating in **worldstate updaters**.
* E.g., `digforgold` action sets `last_dig_time` → updater toggles `candigforgold` based on cooldown.

---

## Bands & hysteresis

* `band_rank`: `COMBAT > SURVIVAL > WORK > IDLE` default.
* `persist`: `0.05–0.10` is usually enough.

---

## Debug tips

* In selector: log candidates `{id, band, pre}` and winner.
* In updaters: log diffs when atoms change.

---

## Checklist for hunger preemption

1. Add `EAT` goal (SURVIVAL).
2. Ensure updaters set `hungry=true`, and `has_food` / `food_visible`.
3. Add `Eat` GOAP action (pre `{ hungry=true }`, post `{ hungry=false }`).
4. Done — hunger interrupts long actions.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
