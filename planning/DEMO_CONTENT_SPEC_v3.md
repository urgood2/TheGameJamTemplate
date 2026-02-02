# Demo Content Specification — v3 (Feedback Incorporated)

## Summary

| System | Count | Notes |
|--------|-------|-------|
| **Gods** | 4 | Pyr (Fire), Glah (Ice), Vix (Lightning), Nil (Void) |
| **Classes** | 2 | Channeler (melee), Seer (ranged) |
| **Skills** | 32 | 8 per element × 4 elements |
| **Wands** | 8 | 2 starter + 6 findable (with full stats) |
| **Cards** | ~40 | Modifiers + Actions (NOT trigger cards) |
| **Artifacts** | 15 | 5 common, 5 uncommon, 5 rare |
| **Equipment** | 12 | 4 per slot × 3 slots |
| **Combinations** | 8 | 4 Gods × 2 Classes |
| **Skill Points/Run** | ~10 | Capstones cost 5, entry costs 1-2 |
| **Element Lock** | 3 max | Players pick from 4, locked to first 3 invested |

---

## Part 1: Gods

Gods provide elemental blessings and passives. **No elemental assignment to gods themselves** — they are patrons that grant elemental powers.

### Pyr — God of Flames

| Feature | Value |
|---------|-------|
| **Blessing (E)** | Deal Fire damage = 5 × total Scorch stacks on all enemies |
| **Passive** | On hit: Apply 1 Scorch |
| **Starter Gear** | *Burning Gloves* (equipment) + *Flame Starter* (artifact: +10% Fire damage) |

---

### Glah — God of Frost

| Feature | Value |
|---------|-------|
| **Blessing (E)** | *Shatter* — Deal Ice damage = 10 × Freeze stacks on all enemies, then clear Freeze |
| **Passive** | On hit: Apply 1 Freeze. Frozen enemies have -20% Move Speed, -20% Dodge |
| **Starter Gear** | *Frozen Heart* (artifact: +20% Freeze duration) + *Glacier Grips* (equipment) |

---

### Vix — God of Storms

| Feature | Value |
|---------|-------|
| **Blessing (E)** | For 3 seconds, deal Lightning damage = Move Speed × 2 on every step |
| **Passive** | +5% Move Speed per enemy killed this wave. On kill: Chain Lightning to 2 enemies |
| **Starter Gear** | *Rubber Boots* (equipment: +5 Move Speed) + *Spark Catalyst* (artifact: +chain lightning range) |

---

### Nil — God of the Void

| Feature | Value |
|---------|-------|
| **Blessing (E)** | All enemies with Doom take Doom × 10 damage immediately |
| **Passive** | On enemy death: Apply 2 Doom to all nearby enemies |
| **Starter Gear** | *Reaper's Touch* (equipment) + *Doom Shard* (artifact: Doom threshold -2) |

**Design Note:** Gods no longer provide starter action cards. Instead, they grant 1 equipment piece + 1 artifact that synergizes with their element. This makes god choice feel distinct from class choice (which determines starter wand).

---

## Part 2: Classes

### Class Names: Channeler + Seer ✓

---

### Wand System Deep Dive

**Wands define WHEN attacks fire** and carry base stats:

```lua
wandDef = {
    id = "void_edge",
    mana_max = 50,          -- Total flux capacity
    mana_recharge_rate = 10, -- Flux per second
    cast_block_size = 2,    -- Cards evaluated per cast
    cast_delay = 100,       -- ms between shots in a cast
    recharge_time = 300,    -- ms cooldown after wand empties
    spread_angle = 5,       -- Projectile spread
    total_card_slots = 4,   -- Capacity for cards
}
```

**Card Slot Structure:**
```
[Wand Trigger] → [Modifier 1] → [Modifier 2] → [Action Card]
```

---

### Starter Wands (with Full Stats)

#### Channeler: Void Edge

| Stat | Value | Notes |
|------|-------|-------|
| **Trigger** | every_N_seconds (0.3s) | Fast auto-fire |
| **Mana Max** | 40 | Lower capacity = more aggressive |
| **Mana Regen** | 12/sec | Fast recharge |
| **Cast Block Size** | 2 | Mod + Action |
| **Cast Delay** | 100ms | Quick between-shot delay |
| **Recharge Time** | 300ms | Short cooldown |
| **Card Capacity** | 4 slots | Small deck |
| **Starting Cards** | Pierce (mod) + Melee Swing (action) | — |

**Pierce Modifier:**
```lua
{
    id = "MOD_PIERCE",
    type = "modifier",
    mana_cost = 5,
    pierce_count = 2,  -- Pass through 2 enemies
}
```

**Melee Swing Action:**
```lua
{
    id = "ACTION_MELEE_SWING",
    type = "action",
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    arc_angle = 90,       -- degrees
    range = 60,           -- pixels from player center
    duration = 0.15,      -- seconds
}
```

**Implementation: Melee Arc Collision**

```lua
-- Create arc hitbox using sector shape
-- Option A: Chipmunk physics circle-sector (not native, needs poly approx)
-- Option B: Multiple rectangle segments forming arc
-- Option C: Runtime line sweep + point queries

-- Recommended: Option C (Line Sweep)
function createMeleeArc(origin, facing, arcAngle, range, duration)
    local steps = 8  -- Subdivisions of arc
    local stepAngle = arcAngle / steps
    local startAngle = facing - arcAngle / 2

    for i = 0, steps do
        local angle = startAngle + stepAngle * i
        local endX = origin.x + math.cos(angle) * range
        local endY = origin.y + math.sin(angle) * range

        -- Query entities along this line
        physics.segment_query(world, origin, {x=endX, y=endY}, function(shape, point)
            local entity = physics.entity_from_ptr(shape)
            if isEnemy(entity) then
                dealDamage(entity, damage)
            end
        end)
    end
end

-- Visual: Use command_buffer.queueDrawArc or sprite animation
```

---

#### Seer: Sight Beam

| Stat | Value | Notes |
|------|-------|-------|
| **Trigger** | every_N_seconds (1.0s) | Slow auto-fire |
| **Mana Max** | 80 | Higher capacity |
| **Mana Regen** | 6/sec | Slower recharge |
| **Cast Block Size** | 3 | 2 Mods + Action |
| **Cast Delay** | 50ms | Very quick |
| **Recharge Time** | 800ms | Longer cooldown |
| **Card Capacity** | 6 slots | Larger deck |
| **Starting Cards** | Pierce (mod) + Homing (mod) + Projectile Bolt (action) |

**Projectile Bolt Action:**
```lua
{
    id = "ACTION_PROJECTILE_BOLT",
    type = "action",
    mana_cost = 10,
    damage = 20,
    damage_type = "arcane",
    projectile_speed = 600,
    lifetime = 2000,  -- ms
}
```

---

### Findable Wands (6)

| Wand Name | Trigger | Stats | Starting Cards | Best Class |
|-----------|---------|-------|----------------|------------|
| **Rage Fist** | on_bump_enemy | mana:30, regen:15, block:1, delay:50, recharge:200, cap:3 | Empowered (mod) + Melee Swing | Channeler |
| **Storm Walker** | on_distance_traveled (50u) | mana:60, regen:8, block:2, delay:100, recharge:500, cap:5 | Chain 2 (mod) + Projectile Bolt | Either |
| **Frost Anchor** | on_stand_still (1.5s) | mana:100, regen:4, block:4, delay:0, recharge:1500, cap:8 | Fork (mod) + Larger AoE (mod) + AoE Blast | Seer |
| **Soul Siphon** | enemy_killed | mana:50, regen:10, block:2, delay:150, recharge:100, cap:4 | Homing (mod) + Projectile Bolt | Either |
| **Pain Echo** | on_player_hit | mana:30, regen:20, block:2, delay:0, recharge:200, cap:4 | Empowered (mod) + AoE Burst | Channeler |
| **Ember Pulse** | every_N_seconds (0.5s) | mana:50, regen:10, block:2, delay:100, recharge:400, cap:5 | Lingering (mod) + Fireball | Either |

**Wand Progression:** Players start with class wand, can find 1-2 new wands per run.

---

### Channeler

| Feature | Value |
|---------|-------|
| **Starter Wand** | *Void Edge* (0.3s timer) |
| **Passive** | +5% spell damage per enemy within close range (max +25%) |
| **Triggered** | On hit: Gain 1 Arcane Charge (max 10). At 10: Next spell +100% damage, reset |

**Playstyle:** Rush into crowds, build Arcane Charges, unleash empowered spells.

---

### Seer

| Feature | Value |
|---------|-------|
| **Starter Wand** | *Sight Beam* (1.0s timer) |
| **Passive** | +10% damage to enemies at far range. **-10% damage at close range** |
| **Triggered** | On stand still 1 sec: "Focused" — next 3 spells +30% damage, then reset |

**Playstyle:** Keep distance, let auto-fire pierce crowds, stand still for damage boost.

---

## Part 3: Status Effects & Buffs

### Debuffs on Enemies (ALL DECAY OVER TIME)

| Effect | Element | Behavior | Decay Rate | Visual Display |
|--------|---------|----------|------------|----------------|
| **Scorch** | Fire | Fire DoT per stack | -1 stack/2s | Fire icon + stack count bar |
| **Freeze** | Ice | -20% Move/Dodge per stack | -1 stack/3s | Ice icon + stack count bar |
| **Doom** | Void | At 10: Deal 50% max HP | -1 stack/4s | Purple skull + stack count |

**Stack Decay Implementation:**
```lua
-- In status_effects.lua
local STATUS_DECAY_RATES = {
    scorch = { interval = 2.0, amount = 1 },
    freeze = { interval = 3.0, amount = 1 },
    doom   = { interval = 4.0, amount = 1 },
    charge = { interval = 2.0, amount = 1 },
    inflame = { interval = 3.0, amount = 1 },
}

function StatusSystem.update(dt)
    for entityId, statuses in pairs(activeStatuses) do
        for statusName, data in pairs(statuses) do
            local decay = STATUS_DECAY_RATES[statusName]
            if decay then
                data.decayTimer = (data.decayTimer or 0) + dt
                if data.decayTimer >= decay.interval then
                    data.stacks = math.max(0, data.stacks - decay.amount)
                    data.decayTimer = 0
                    if data.stacks == 0 then
                        removeStatus(entityId, statusName)
                    end
                end
            end
        end
    end
end

-- Visual: Draw stack bar above enemy
function drawStackBar(entity, statusName, stacks, maxStacks)
    local cx, cy = Q.visualCenter(entity)
    local barWidth = 30
    local fillPct = stacks / maxStacks
    local color = STATUS_COLORS[statusName]

    command_buffer.queueDrawRectangle(layers.ui, function(c)
        c.x, c.y, c.w, c.h = cx - barWidth/2, cy - 20, barWidth * fillPct, 4
        c.color = color
    end, z_orders.status_bars, layer.DrawCommandSpace.World)
end
```

### Player Buffs

| Effect | Source | Behavior | Decay |
|--------|--------|----------|-------|
| **Charge** | Lightning | +5% Move Speed per stack | -1/2s |
| **Inflame** | Fire (Roil) | +10% Fire damage per stack | -1/3s |
| **Arcane Charge** | Channeler | At 10: +100% damage, reset | No decay (consumed) |
| **Focused** | Seer | +30% damage × 3 spells | No decay (consumed) |

### Transformation Buffs

| Form | Trigger | Effects | Implementation |
|------|---------|---------|----------------|
| **Fireform** | Deal 100+ Fire damage | +30% Fire, flame aura | See Aura Implementation |
| **Iceform** | Apply 50+ Freeze | +30% Ice, +50 Armor, chill aura | See Aura Implementation |
| **Stormform** | Reach 20+ Move Speed | +30% Lightning, spark aura | See Aura Implementation |
| **Voidform** | Deal 100+ Death | +30% Death, enemies gain Doom | See Aura Implementation |

**Aura Implementation:**
```lua
-- Aura = periodic AoE effect centered on player
function createAura(player, auraType, config)
    local auraEntity = registry:create()

    -- Attach to player
    ChildBuilder.for_entity(auraEntity)
        :attachTo(player)
        :offset(0, 0)
        :apply()

    -- Visual: Animated sprite/shader
    local auraSprite = AnimationLoader.load(config.sprite)
    component_cache.add(auraEntity, SpriteComponent, auraSprite)

    -- Damage tick
    timer.every(config.tickInterval, function()
        local px, py = Q.center(player)
        local enemies = physics.GetObjectsInArea(world,
            px - config.radius, py - config.radius,
            config.radius * 2, config.radius * 2)

        for _, enemy in ipairs(enemies) do
            if isEnemyEntity(enemy) then
                dealDamage(enemy, config.damage, config.damageType)
                if config.applyStatus then
                    applyStatus(enemy, config.applyStatus, config.statusStacks)
                end
            end
        end
    end, -1, false, nil, "aura_" .. player .. "_" .. auraType)
end

-- Example: Flame aura
createAura(player, "flame", {
    sprite = "flame_aura.png",
    radius = 80,
    tickInterval = 0.5,
    damage = 10,
    damageType = "fire",
    applyStatus = "scorch",
    statusStacks = 1,
})
```

---

## Part 4: Unified Trigger System

### All Triggers (Internal Names)

Skills and wands share this trigger pool. **Internal names match code:**

| Internal Name | Fires When | Wand Use | Skill Use |
|---------------|------------|----------|-----------|
| `every_N_seconds` | Timer interval | Void Edge, Sight Beam | — |
| `on_bump_enemy` | Melee contact | Rage Fist | — |
| `on_distance_traveled` | Move X pixels | Storm Walker | — |
| `on_stand_still` | Stationary N sec | Frost Anchor | Focused, Frost Turret, Anchor of Doom |
| `enemy_killed` | Enemy dies | Soul Siphon | Combustion, Chain Lightning, Plague Spread |
| `on_player_hit` | Player damaged | Pain Echo | Ice Armor, Amplify Pain |
| `on_hit` | Attack lands | — | Kindle, Pyrokinesis, Entropy |
| `on_crit` | Critical hit | — | Charge Master |
| `on_step` | Player moves | — | Surge, Electromancy |
| `on_wave_start` | Wave begins | — | Summon familiars |
| `on_threshold` | Status reaches N | — | Forms, Doom execute |
| `on_status_applied` | Status applied | — | See Status Triggers |

### Status-Based Triggers (NEW)

| Internal Name | Fires When | Example Skills |
|---------------|------------|----------------|
| `on_scorch_applied` | Scorch applied to enemy | Fire synergy cards |
| `on_freeze_applied` | Freeze applied to enemy | Shatter Synergy |
| `on_doom_applied` | Doom applied to enemy | Doom Mark synergy |
| `on_heal` | Player healed | Necrokinesis |
| `on_self_damage` | Player damages self | Amplify Pain, Grave Chant |
| `on_fire_damage` | Fire damage dealt | Fire Healing, Roil |

### Trigger Coverage by Class

**Channeler (melee, aggressive):**
| Trigger | Access | Sources |
|---------|--------|---------|
| Timer (fast) | ✓ Starter | Void Edge (0.3s) |
| On Bump Enemy | ✓ Findable | Rage Fist wand |
| On Kill | ✓ Findable | Soul Siphon wand |
| On Player Hit | ✓ Findable | Pain Echo wand |
| On Hit | ✓ Skills | Fire/Ice/Lightning/Void skills |
| On Step | ✓ Skills | Lightning skills |

**Seer (ranged, patient):**
| Trigger | Access | Sources |
|---------|--------|---------|
| Timer (slow) | ✓ Starter | Sight Beam (1.0s) |
| On Stand Still | ✓ Passive + Findable | Focused buff, Frost Anchor |
| On Distance | ✓ Findable | Storm Walker wand |
| On Kill | ✓ Findable | Soul Siphon wand |
| On Hit | ✓ Skills | All elements |

### Multi-Trigger Skills

| Skill | Triggers | Code Implementation |
|-------|----------|---------------------|
| **Roil** | `on_hit` + `on_fire_damage` | Both must fire in same frame |
| **Amplify Pain** | `on_player_hit` + `on_self_damage` | Self-damage counts as both |
| **Necrokinesis** | `on_hit` + `on_heal` | Either triggers effect |
| **Grave Chant** | `on_spell_cast` + `on_self_damage` | Casting causes self-damage |

```lua
-- Multi-trigger implementation: skill fires if ANY trigger matches
function checkSkillTriggers(skill, event)
    for _, trigger in ipairs(skill.triggers) do
        if event.type == trigger then
            executeSkillEffect(skill, event)
            return -- Only fire once per event
        end
    end
end
```

---

## Part 5: Skills (32 Total)

### Fire Skills (8)

| Skill | Cost | Trigger(s) | Effect |
|-------|------|------------|--------|
| **Kindle** | 1 | `on_hit` | +2 Scorch per hit |
| **Pyrokinesis** | 2 | `on_hit` | 30 Fire AoE |
| **Fire Healing** | 2 | `on_fire_damage` | Heal 3 |
| **Combustion** | 3 | `enemy_killed` | Explode for Scorch × 10 |
| **Flame Familiar** | 3 | `on_wave_start` | Summon Fire Sprite |
| **Roil** | 3 | `on_hit` + `on_fire_damage` | Heal 5, +2 Inflame, 15 Fire self-damage |
| **Scorch Master** | 4 | Passive | Immune to Scorch. Scorch never expires |
| **Fire Form** | 5 | `on_threshold` (100 Fire dmg) | Gain Fireform |

---

### Ice Skills (8)

| Skill | Cost | Trigger(s) | Effect |
|-------|------|------------|--------|
| **Frostbite** | 1 | `on_hit` | +2 Freeze per hit |
| **Cryokinesis** | 2 | `on_hit` | Ice to 2 adjacent + 3 Freeze |
| **Ice Armor** | 2 | `on_player_hit` | +50 Armor. Counter-Freeze attackers |
| **Shatter Synergy** | 3 | `on_freeze_applied` + `enemy_killed` | AoE = Freeze × 15 |
| **Frost Familiar** | 3 | `on_wave_start` | Summon Ice Elemental |
| **Frost Turret** | 3 | `on_stand_still` | Summon ice turret that fires |
| **Freeze Master** | 4 | Passive | Immune to Freeze. +2 Armor per enemy Freeze |
| **Ice Form** | 5 | `on_threshold` (50 Freeze) | Gain Iceform |

---

### Lightning Skills (8)

| Skill | Cost | Trigger(s) | Effect |
|-------|------|------------|--------|
| **Spark** | 1 | `on_hit` | +5% Move Speed |
| **Electrokinesis** | 2 | `on_hit` | Lightning line through target |
| **Chain Lightning** | 2 | `enemy_killed` | Lightning chains to 2 |
| **Surge** | 3 | `on_step` | Deal Move Speed damage |
| **Storm Familiar** | 3 | `on_wave_start` | Summon Ball Lightning |
| **Amplify Pain** | 3 | `on_player_hit` + `on_self_damage` | 5 self-damage → 20 Lightning AoE |
| **Charge Master** | 4 | `on_crit` | +1% crit per Charge. On crit: +3 Charge |
| **Storm Form** | 5 | `on_threshold` (20 Speed) | Gain Stormform |

---

### Void/Death Skills (8)

| Skill | Cost | Trigger(s) | Effect |
|-------|------|------------|--------|
| **Entropy** | 1 | `on_hit` | +1 Doom per hit |
| **Necrokinesis** | 2 | `on_hit` OR `on_heal` | 30 Death to closest. On heal: +50 Death |
| **Cursed Flesh** | 3 | `enemy_killed` | Heal 10, 50 Death to 2 adjacent |
| **Grave Summon** | 3 | `on_wave_start` + `enemy_killed` | Summon 2 Skeletons. 30% more on kill |
| **Doom Mark** | 3 | Passive | Enemies with Doom take +20% damage |
| **Anchor of Doom** | 3 | `on_stand_still` | All enemies in range gain 1 Doom/sec |
| **Doom Master** | 4 | Passive | Immune to Doom. Threshold → 5 |
| **Void Form** | 5 | `on_threshold` (100 Death) | Gain Voidform |

---

## Part 6: Card Pool (~28 Cards)

**Cards are Modifiers + Actions only.** Wands handle triggers.

### Modifier Cards (12)

| Card | Mana | Effect | Analog |
|------|------|--------|--------|
| **Chain 2** | 8 | Chain to 2 additional targets | Noita: Chain spell |
| **Pierce** | 5 | Pass through 2 enemies | VS: Runetracer piercing |
| **Fork** | 10 | Split into 3 at half damage | Noita: Divide spells |
| **Homing** | 6 | Seek nearest enemy | VS: Homing projectiles |
| **Larger AoE** | 8 | AoE radius +50% | POA: Increased area |
| **Concentrated** | 6 | AoE -50%, damage +50% | POA: Focused damage |
| **Delayed** | 5 | 1s delay, +30% power | Noita: Timer modifier |
| **Rapid** | 10 | Cooldowns -20% | VS: Cooldown reduction |
| **Empowered** | 12 | +25% damage, +25% mana | POA: Power at cost |
| **Efficient** | 5 | -25% mana, -15% damage | Tiny Rogues: Efficiency |
| **Lingering** | 8 | DoT lasts 50% longer | VS: Duration up |
| **Brittle** | 6 | Frozen enemies +25% damage | POA: Combo enabler |

### Action Cards (16)

**Fire Actions (4)**
| Card | Mana | Damage | Effect | Analog |
|------|------|--------|--------|--------|
| **Fireball** | 12 | 25 Fire | AoE, +3 Scorch | VS: Fire Wand |
| **Combustion** | 8 | 15 Fire | Consume Scorch × 5 damage | Noita: Explosion |
| **Flame Wave** | 18 | 40 Fire | Cone, +2 Scorch/enemy | Tiny Rogues: Flamethrower |
| **Inferno** | 25 | 60 Fire | Large AoE, +5 Scorch | VS: Hellfire |

**Ice Actions (4)**
| Card | Mana | Damage | Effect | Analog |
|------|------|--------|--------|--------|
| **Ice Shard** | 8 | 20 Ice | Single, +3 Freeze | Tiny Rogues: Ice Bolt |
| **Blizzard** | 15 | 10/sec Ice | AoE 3s, +1 Freeze/tick | VS: Freeze aura |
| **Glacial Spike** | 12 | 35 Ice | Pierce, share Freeze | Noita: Piercing ice |
| **Absolute Zero** | 30 | 0 | Freeze × 2 all in range | POA: Control ultimate |

**Lightning Actions (4)**
| Card | Mana | Damage | Effect | Analog |
|------|------|--------|--------|--------|
| **Shock** | 6 | 15 Lightning | Fast, +5% Speed | Tiny Rogues: Zap |
| **Arc Strike** | 10 | 20 Lightning | Chain 3 | VS: Lightning Ring |
| **Thunder Bolt** | 16 | 45 Lightning | High dmg, stun 0.5s | POA: Stun |
| **Storm Call** | 22 | 30 × 3 | Random bolts over 2s | VS: Thunder Loop |

**Void Actions (4)**
| Card | Mana | Damage | Effect | Analog |
|------|------|--------|--------|--------|
| **Soul Drain** | 10 | 20 Death | Damage = HP healed | VS: Bloody Tear |
| **Doom Bolt** | 8 | 15 Death | +3 Doom | POA: Curse |
| **Death Coil** | 14 | 35 Death | +50% if has Doom | POA: Execute combo |
| **Void Rift** | 28 | 0 | All gain Doom = 25% current | Unique |

---

## Part 7: Artifacts (15)

### Tier 1: Common (5)

| Artifact | Effect | Game Reference |
|----------|--------|----------------|
| **Burning Gloves** | +10 Fire damage per hit | VS: Spinach (flat damage boost) |
| **Frozen Heart** | +20% Freeze duration | POA: Control duration artifact |
| **Rubber Boots** | +5 Move Speed | VS: Wings (move speed) |
| **Lucky Coin** | +15% gold | VS: Stone Mask |
| **Healing Salve** | Heal 5 at wave start | Tiny Rogues: Regen items |

### Tier 2: Uncommon (5)

| Artifact | Effect | Game Reference |
|----------|--------|----------------|
| **Scorch Ring** | Scorched enemies +15% Fire damage | POA: Element synergy artifacts |
| **Glacial Shield** | Block 1 attack/wave if Freeze > 10 | POA: Threshold-based defense |
| **Storm Battery** | On kill: +3 Speed 3s, stacks 3× | VS: Kill-based stacking buffs |
| **Vampiric Pendant** | On kill: Heal 3% max HP | VS: Bloody Tear / Skull O'Maniac |
| **Doom Shard** | Doom threshold -2 | POA: Build-around modifiers |

### Tier 3: Rare (5)

| Artifact | Effect | Game Reference |
|----------|--------|----------------|
| **Phoenix Feather** | Revive once at 30% HP | VS: Tiragisu |
| **Elemental Convergence** | Non-primary elements -1 point | POA: Multiclass enabler |
| **Berserker's Rage** | +1% damage per 1% missing HP | VS: Bracer (glass cannon) |
| **Prismatic Core** | All elemental +15% | POA: General power boost |
| **Chrono Lens** | All enemies -15% Move Speed | VS: Slow aura effects |

---

## Part 8: Equipment (12 Pieces)

### Chest Armor (4)

| Name | Effect | Game Reference |
|------|--------|----------------|
| **Flame Robes** | +15% Fire. On hit: 2 Scorch to attacker | VS: Reflect damage |
| **Frost Plate** | +30 Armor. On block: 3 Freeze | POA: Block synergy |
| **Storm Cloak** | +10 Speed. On dodge: Chain 2 | VS: Dodge synergy |
| **Void Vestments** | +10% Death. On hit: 1 Doom to attacker | POA: Attacker debuff |

### Gloves (4)

| Name | Effect | Game Reference |
|------|--------|----------------|
| **Ignition Gauntlets** | Projectiles: +3 Scorch | VS: On-hit effects |
| **Glacier Grips** | AoE casts: +2 Freeze to all | POA: AoE synergy |
| **Surge Bracers** | +15% attack speed. Crit: +5 Speed 2s | Tiny Rogues: Crit bonuses |
| **Reaper's Touch** | If target has Doom: +10% damage | POA: Condition damage |

### Boots (4)

| Name | Effect | Game Reference |
|------|--------|----------------|
| **Ember Greaves** | Fire trail (10/sec 1s) | VS: Fire trail weapons |
| **Frozen Treads** | -5 Speed. +25% Freeze dur. +30 Armor | POA: Trade-off items |
| **Lightning Striders** | +10 Speed. 20% dodge on step | VS: Dodge chance |
| **Death Walkers** | On kill: +2 Doom to 2 nearby | POA: Kill spread |

---

## Part 9: Economy

### Skill Points Per Run: ~10

| Level | Points | Cumulative |
|-------|--------|------------|
| Start | 0 | 0 |
| 2 | +2 | 2 |
| 3 | +2 | 4 |
| 4 | +2 | 6 |
| 5 | +2 | 8 |
| 6 | +2 | **10** |

### Acquisition Timeline

| Stage | Rewards |
|-------|---------|
| **Stage 1** | Shop: Equipment |
| **Stage 2** | Shop: Equipment + Wand |
| **Stage 3** | Elite: Artifact (1 of 3) |
| **Stage 4** | Elite: Artifact + Wand |
| **Stage 5** | Boss |

---

## Part 10: Synergy Matrix

### God + Class (8 Combos)

| Combo | Rating | Key Synergy |
|-------|--------|-------------|
| Pyr + Channeler | ⭐⭐⭐ | Fast hits = fast Scorch |
| Pyr + Seer | ⭐⭐ | Pierce spreads Scorch |
| Glah + Channeler | ⭐⭐⭐ | Freeze for melee safety |
| Glah + Seer | ⭐⭐⭐ | Stand still + Frost Turret |
| Vix + Channeler | ⭐⭐ | Speed glass cannon |
| Vix + Seer | ⭐⭐ | Storm Walker synergy |
| Nil + Channeler | ⭐⭐⭐ | Close range Doom |
| Nil + Seer | ⭐⭐⭐ | Anchor of Doom + stand-still |

### Wand + Class Synergies

| Wand | Best Class | Why |
|------|------------|-----|
| **Void Edge** | Channeler | Default melee |
| **Sight Beam** | Seer | Default ranged |
| **Rage Fist** | Channeler | Requires melee |
| **Storm Walker** | Either | Movement builds |
| **Frost Anchor** | Seer | Turret playstyle |
| **Soul Siphon** | Either | Snowball |
| **Pain Echo** | Channeler | Risk-reward |
| **Ember Pulse** | Either | Balanced |

---

## Resolved Questions

1. **Doom threshold:** 10 → 50% max HP (bosses 25%)
2. **Skeleton limit:** Max 5
3. **Stack decay:** All enemy debuffs decay over time
4. **God starter gear:** Equipment + Artifact (not action cards)
5. **Trigger Cards → removed:** Effects moved to Artifacts/Equipment
6. **Element on gods:** Removed — gods grant elemental powers
7. **Wand stats:** Full stats documented
8. **Implementation notes:** Added for auras, melee arc, stack decay
9. **Game references:** Added for artifacts

---

## Approval Checklist

- [ ] Gods (4) — with starter equipment + artifact
- [ ] Classes (2) — Channeler, Seer ✓
- [ ] Wand system (full stats, mod+action combos)
- [ ] Unified trigger system (internal names, coverage)
- [ ] Skills (32) with multi-trigger support
- [ ] Card pool (28) — Modifiers + Actions only
- [ ] Artifacts (15) with game references
- [ ] Equipment (12)
- [ ] Status effects with decay implementation
- [ ] Economy
- [ ] Element lock (3 of 4)
