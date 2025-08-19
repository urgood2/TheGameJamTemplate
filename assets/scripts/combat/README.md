# Combat & Effects System

This module implements a composable skill / trigger / effect framework in Lua, with support for stats, items, mutators, resistances, statuses, DoTs, and more.

It is intended as a flexible backbone for ARPG-style games, roguelikes, autobattlers, etc.

---

## Core Concepts

* **Events (Triggers):** Messages emitted by the `EventBus` (e.g. `OnCast`, `OnHitResolved`, `OnLevelUp`).
* **Effects:** Functions `(ctx, src, tgt) -> ()` that alter game state (deal damage, apply buffs, etc.).
* **Combinators:** Higher-order effects that combine or wrap others (`seq`, `chance`, `scale_by_stat`).
* **Targeters:** Functions `(ctx) -> {entities}` that determine which entities are affected.
* **Conditions:** Predicates `entity -> bool` used to filter targets.
* **Statuses:** Timed buffs/debuffs applied to entities.
* **Items:** Equipable definitions that add stat mods, conversions, procs, spell mutators, or grant spells.
* **Leveling:** XP curves, level ups, stat gains, and event hooks.

---

## Events (Triggers)

Built-in events you can listen to:

* `OnCast`
* `OnHitResolved`, `OnMiss`, `OnDodge`
* `OnHealed`, `OnRRApplied`
* `OnDotApplied`, `OnDotExpired`
* `OnStatusExpired`
* `OnDeath`
* `OnExperienceGained`, `OnLevelUp`
* `OnCounterAttack`, `OnProvoke` (demo/custom)
* `OnTick` (emitted every `World.update`)

```lua
Core.on(ctx, 'OnHitResolved', function(ev)
  print(ev.source.name .. " hit " .. ev.target.name .. " for " .. ev.damage)
end)
```

---

## Targeters

Functions that pick who receives an effect:

* `Targeters.self(ctx)`
* `Targeters.target_enemy(ctx)`
* `Targeters.all_enemies(ctx)` / `Targeters.all_allies(ctx)`
* `Targeters.random_enemy(ctx)`
* `Targeters.enemies_with(predicate)`

Example: enemies below 200 HP:

```lua
Targeters.enemies_with(Core.Cond.stat_below('health', 200))
```

---

## Conditions

Reusable filters:

* `Cond.always()`
* `Cond.has_tag("undead")`
* `Cond.stat_below("health", 200)`

---

## Effect Primitives

* `Effects.deal_damage{ weapon=true, scale_pct=100 }`
* `Effects.deal_damage{ components={{type='fire', amount=120}} }`
* `Effects.apply_rr{ kind='rr1', damage='fire', amount=20, duration=4 }`
* `Effects.apply_dot{ type='poison', dps=20, duration=5, tick=1 }`
* `Effects.modify_stat{ name='offensive_ability', base_add=25, duration=6 }`
* `Effects.heal{ flat=30 }`
* `Effects.grant_barrier{ amount=50, duration=4 }`

### Combinators

* `Effects.seq{ e1, e2, e3 }`
* `Effects.chance(30, eff)`
* `Effects.scale_by_stat("physique", 2.0, function(v) return Effects.deal_damage{components={{type='physical', amount=v}}} end)`

---

## Status System

Statuses are tracked per entity and removed when expired.
Modes:

* `replace` (default) – overwrite existing
* `time_extend` – extend duration if recast
* `count` – stacking up to `st.max`

Example:

```lua
Effects.modify_stat{
  id='oa_boost', name='offensive_ability',
  base_add=25, duration=6,
  stack={ mode='time_extend' }
}
```

---

## Items

Fields an item can define:

* `mods = { {stat='weapon_min', base=6}, ... }`
* `conversions = { {from='physical', to='fire', pct=25} }`
* `procs = { { trigger='OnBasicAttack', chance=70, effects=Effects.deal_damage{components={{type='fire', amount=40}}} } }`
* `spell_mutators = { Fireball = { {pr=0, wrap=function(orig) return function(ctx,src,tgt) if orig then orig(ctx,src,tgt) end ... end end} } }`
* `granted_spells = { "Fireball" }`

Example: Fire sword that procs flames

```lua
local Flamebrand = {
  id='flamebrand', slot='sword1',
  mods = {
    { stat='weapon_min', base=6 },
    { stat='weapon_max', base=10 },
    { stat='fire_modifier_pct', add_pct=15 },
  },
  conversions = { { from='physical', to='fire', pct=25 } },
  procs = {
    { trigger='OnBasicAttack', chance=70,
      effects=Effects.deal_damage{ components={{type='fire', amount=40}} } },
  },
  granted_spells = { 'Fireball' },
}
```

Equip with:

```lua
ItemSystem.equip(ctx, hero, Flamebrand)
```

---

## Casting System

```lua
Cast.cast(ctx, caster, "Fireball", target)
```

* Handles cooldown, costs, CDR, cost reduction.
* Applies `ability_mods` from items.
* Wraps spell’s `effects` function with spell mutators.
* Uses targeter if no explicit `target` provided.

### Spell schema

```lua
Content.Spells.Fireball = {
  id="Fireball", trigger="OnCast",
  cooldown=3.0, cost=40,
  targeter=function(ctx) return { ctx.target } end,
  build=function(level, mods)
    return Effects.seq{
      Effects.deal_damage{ components={{type='fire', amount=120*(1+(mods.dmg_pct or 0)/100)}} },
      Effects.apply_rr{ kind='rr1', damage='fire', amount=20, duration=4 },
    }
  end
}
```

---

## Leveling

* Define curves with `Leveling.register_curve(id, fn)`.
* Gain XP: `Leveling.grant_exp(ctx, e, baseXP)`.
* On level up: event `OnLevelUp` fires (you can add stat points, grant spells, etc.).

Example:

```lua
bus:on('OnLevelUp', function(ev)
  local e = ev.entity
  e.stats:add_base('physique', 1)
  e.stats:recompute()
  if e.level == 3 then
    e.granted_spells = e.granted_spells or {}
    e.granted_spells['Fireball'] = true
  end
end)
```

---

## World Loop

Update simulation each frame:

```lua
World.update(ctx, dt)
```

* Advances time
* Ticks statuses & DoTs
* Applies regen (HP/energy)
* Emits `OnTick`

---

## Quick Recipe: New Spell

1. **Define** a spell in `Content.Spells` with `effects` or `build`.
2. **Targeter:** pick who it hits.
3. **Effects:** use `Effects.*` atoms, compose with `seq/chance`.
4. **Hook it up:** call `Cast.cast(ctx, caster, "SpellName", target)` or let triggers fire it.

Example: Frost Lance

```lua
Content.Spells.FrostLance = {
  id="FrostLance", trigger="OnCast",
  cooldown=2.5, cost=25,
  targeter=function(ctx) return { ctx.target } end,
  build=function(level, mods)
    local dmg = 80 + (level-1)*30
    dmg = dmg * (1+(mods.dmg_pct or 0)/100)
    return Effects.seq{
      Effects.deal_damage{ components={{type='cold', amount=dmg}} },
      Effects.apply_rr{ kind='rr2', damage='cold', amount=15, duration=3 },
    }
  end
}
```

---

## Quick Recipe: New Item

```lua
local ThunderSeal = {
  id='thunder_seal', slot='amulet',
  spell_mutators = {
    Fireball = {
      { pr=0, wrap=function(orig)
          return function(ctx,src,tgt)
            if orig then orig(ctx,src,tgt) end
            Effects.deal_damage{
              weapon=true, scale_pct=200,
              skill_conversions={ {from='physical', to='lightning', pct=100} }
            }(ctx,src,tgt)
          end
        end }
    }
  }
}
```

---

## Extending the System

* **New trigger:** emit an event (`ctx.bus:emit("OnX", { ... })`).
* **New targeter:** return a list of entities.
* **New effect:** write a function returning `(ctx,src,tgt)->()`.
* **New stat:** add in `StatDef.make()`.
* **New damage type:** add to `Core.DAMAGE_TYPES`.

---
