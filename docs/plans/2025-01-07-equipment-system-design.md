# Equipment System Design

## Overview

Equipment items provide passive stats, triggered effects, and direct actions. They combine the declarative approach of Avatars with the reactive flexibility of Jokers, plus an injected API for discrete side effects.

## Architecture: Hybrid with API

Equipment `calculate()` functions receive three things:
- `self` - The equipment definition
- `context` - Event data (same as jokers)
- `api` - Injected object for discrete actions

```lua
calculate = function(self, context, api)
    -- Aggregatable effects: RETURN these
    local effects = { damage_mod = 15 }

    -- Discrete actions: CALL api directly
    if context.event == "on_kill" then
        api.spawnProjectile("chain_lightning", context.position.x, context.position.y, 0)
        api.applyStatus(context.killer, "energized", 3)
    end

    return effects
end
```

**Why this approach:**
- Return values aggregate across multiple equipment (damage bonuses stack)
- API calls execute immediately for discrete effects (spawns, heals)
- API provides safety layer (validates targets, can be mocked for tests)
- Clear separation of concerns

## Equipment Data Structure

```lua
-- assets/scripts/data/equipment.lua

local Equipment = {
    storm_ring = {
        id = "storm_ring",
        name = "Ring of the Storm",
        description = "Lightning spells chain further. Kills restore mana.",
        slot = "ring",           -- ring, amulet, weapon, armor, etc.
        rarity = "Rare",
        sprite = "equip-storm-ring.png",

        -- PASSIVE STATS (always active, declarative)
        stats = {
            lightning_modifier_pct = 15,
            chain_count_bonus = 1,
        },

        -- TRIGGERED EFFECTS (reactive, hybrid)
        calculate = function(self, context, api)
            -- Aggregatable: return these
            if context.event == "on_spell_cast" and context.tags.Lightning then
                return { extra_chain = 1, message = "Storm Ring!" }
            end

            -- Discrete: call api directly
            if context.event == "on_kill" and context.damage_type == "lightning" then
                api.heal(api.getPlayer(), 5)
                api.spawnParticles("lightning_burst", context.position.x, context.position.y)
            end
        end,
    },
}
```

**Three layers:**
1. `stats` - Permanent stat buffs (applied on equip)
2. `calculate()` return values - Aggregatable effects (damage_mod, extra_chain, etc.)
3. `calculate()` api calls - Discrete actions (spawns, heals, status application)

## Equipment API Surface

```lua
-- SPAWNING
api.spawnProjectile(id, x, y, angle, overrides)  -- Returns projectile entity
api.spawnParticles(preset, x, y, config)
api.spawnSummon(id, x, y, owner)

-- STATUS & MARKS
api.applyStatus(target, statusId, stacks, duration)
api.removeStatus(target, statusId)
api.applyMark(target, markId, stacks)
api.detonateMark(target, markId)

-- DAMAGE & HEALING
api.dealDamage(target, amount, damageType, source)
api.heal(target, amount)
api.addBarrier(target, amount)

-- QUERIES (read-only)
api.getNearbyEnemies(x, y, radius)  -- Returns entity list
api.getNearbyAllies(x, y, radius)
api.getPlayer()
api.getTarget()  -- Current target if applicable

-- TIMERS & EVENTS
api.after(delay, callback, tag)
api.emit(signalName, data)

-- STATE (per-equipment counters)
api.getStacks(equipmentId)
api.setStacks(equipmentId, value)
api.modStacks(equipmentId, delta)
```

**Constraints:** API is scoped to safe operations. No direct registry access, no destroying arbitrary entities. All target-taking functions validate entity exists before acting.

## Equipment System Module

```lua
-- assets/scripts/wand/equipment_system.lua

local EquipmentSystem = {}

-- Player's equipped items: { ring = equipmentInstance, amulet = ... }
EquipmentSystem.equipped = {}

-- Internal state per equipment (stacks, counters)
EquipmentSystem._state = {}

--- Equip an item (applies stats, registers for events)
function EquipmentSystem.equip(player, slot, equipmentId)
    local def = EquipmentDefs[equipmentId]
    if not def then return false end

    -- Unequip existing
    if EquipmentSystem.equipped[slot] then
        EquipmentSystem.unequip(player, slot)
    end

    -- Apply passive stats
    if def.stats and player.combatTable then
        for stat, value in pairs(def.stats) do
            player.combatTable.stats:add_flat(stat, value)
        end
        player.combatTable.stats:recompute()
    end

    -- Store instance
    EquipmentSystem.equipped[slot] = { id = equipmentId, def = def }
    EquipmentSystem._state[equipmentId] = { stacks = 0 }

    return true
end

--- Trigger event across all equipment
function EquipmentSystem.trigger_event(event_name, context)
    local aggregate = { messages = {} }
    local api = EquipmentSystem._createApi(context)

    for slot, instance in pairs(EquipmentSystem.equipped) do
        if instance.def.calculate then
            context.event = event_name
            local result = instance.def:calculate(context, api)

            if result then
                EquipmentSystem._aggregateResult(aggregate, result, instance)
            end
        end
    end

    return aggregate
end
```

## API Implementation

```lua
function EquipmentSystem._createApi(context)
    local api = {}
    local player = context.player or globals.playerScript

    -- SPAWNING
    function api.spawnProjectile(id, x, y, angle, overrides)
        local ProjectileSpawner = require("combat.projectile_spawner")
        return ProjectileSpawner.spawn(id, x, y, angle, overrides)
    end

    function api.spawnParticles(preset, x, y, config)
        local Particles = require("core.particles")
        Particles.emit(preset, x, y, config)
    end

    -- STATUS & MARKS
    function api.applyStatus(target, statusId, stacks, duration)
        if not ensure_entity(target) then return end
        local StatusSystem = require("combat.status_system")
        StatusSystem.apply(target, statusId, stacks, duration)
    end

    -- DAMAGE & HEALING
    function api.heal(target, amount)
        if not ensure_entity(target) then return end
        local script = safe_script_get(target)
        if script and script.combatTable then
            script.combatTable:heal(amount)
        end
    end

    -- QUERIES
    function api.getNearbyEnemies(x, y, radius)
        local SpatialQuery = require("core.spatial_query")
        return SpatialQuery.findByTag("enemy", x, y, radius)
    end

    function api.getPlayer()
        return player and player:handle()
    end

    -- STATE (per-equipment counters)
    function api.getStacks(equipmentId)
        return (EquipmentSystem._state[equipmentId] or {}).stacks or 0
    end

    function api.setStacks(equipmentId, value)
        local state = EquipmentSystem._state[equipmentId]
        if state then state.stacks = value end
    end

    function api.modStacks(equipmentId, delta)
        local state = EquipmentSystem._state[equipmentId]
        if state then state.stacks = state.stacks + delta end
    end

    return api
end
```

## Integration Points

Equipment triggers separately from jokers, with separate aggregation:

```lua
-- In wand_executor.lua
local function executeCastBlock(...)
    local modifiers = WandModifiers.aggregate(modifierCards)

    -- Jokers first
    local jokerEffects = JokerSystem.trigger_event("on_spell_cast", context)
    WandModifiers.applyJokerEffects(modifiers, jokerEffects)

    -- Equipment second (separate aggregate, separate apply)
    local equipEffects = EquipmentSystem.trigger_event("on_spell_cast", context)
    WandModifiers.applyEquipmentEffects(modifiers, equipEffects)
end

-- In combat_system.lua (damage/kill events)
local function onEnemyKilled(enemy, killer, damageType)
    local context = {
        target = enemy,
        killer = killer,
        damage_type = damageType,
        position = { x = Q.center(enemy) }
    }

    JokerSystem.trigger_event("on_kill", context)
    EquipmentSystem.trigger_event("on_kill", context)
end

-- In player damage handler
local function onPlayerDamaged(amount, source, damageType)
    local context = { amount = amount, source = source, damage_type = damageType }

    JokerSystem.trigger_event("on_player_damaged", context)
    EquipmentSystem.trigger_event("on_player_damaged", context)
end
```

## Example Equipment

### Simple: Passive stats + triggered return value

```lua
blazing_amulet = {
    id = "blazing_amulet",
    name = "Blazing Amulet",
    slot = "amulet",
    rarity = "Common",

    stats = { fire_modifier_pct = 10 },

    calculate = function(self, context, api)
        if context.event == "on_spell_cast" and context.tags.Fire then
            return { damage_mod = 5, message = "Blazing!" }
        end
    end,
},
```

### Complex: API calls + state tracking

```lua
vampiric_blade = {
    id = "vampiric_blade",
    name = "Vampiric Blade",
    slot = "weapon",
    rarity = "Epic",

    stats = { lifesteal = 5 },

    calculate = function(self, context, api)
        if context.event == "on_kill" then
            api.modStacks(self.id, 1)

            if api.getStacks(self.id) >= 5 then
                api.setStacks(self.id, 0)
                api.heal(api.getPlayer(), 25)
                api.spawnProjectile("blood_nova", context.position.x, context.position.y, 0, {
                    damage = 50,
                    owner = api.getPlayer()
                })
                api.spawnParticles("blood_burst", context.position.x, context.position.y)
                return { message = "Blood Feast!" }
            end
        end
    end,
},
```

### Reactive: Query + conditional effects

```lua
storm_aegis = {
    id = "storm_aegis",
    name = "Storm Aegis",
    slot = "armor",
    rarity = "Legendary",

    stats = { lightning_resist_pct = 25, armor = 10 },

    calculate = function(self, context, api)
        if context.event == "on_player_damaged" then
            local px, py = Q.center(api.getPlayer())
            local nearby = api.getNearbyEnemies(px, py, 120)

            for _, enemy in ipairs(nearby) do
                api.applyStatus(enemy, "electrocute", 3, 4.0)
            end

            if #nearby > 0 then
                api.spawnParticles("lightning_burst", px, py)
                return { damage_reduction = 5, message = "Storm Aegis!" }
            end
        end
    end,
},
```

## Files to Create/Modify

**New files:**
- `assets/scripts/data/equipment.lua` - Equipment definitions
- `assets/scripts/wand/equipment_system.lua` - System module

**Modified files:**
- `assets/scripts/wand/wand_executor.lua` - Add equipment trigger call
- `assets/scripts/wand/wand_modifiers.lua` - Add `applyEquipmentEffects()`
- `assets/scripts/combat/combat_system.lua` - Add equipment triggers to kill/damage handlers
