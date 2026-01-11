# SNKRX Arenas - Level Design & Progression

> **Source**: [a327ex/SNKRX](https://github.com/a327ex/SNKRX/blob/master/arena.lua)
> **Arena Count**: 1 (single rectangular arena)
> **Levels Per Run**: 25
> **NG+ Levels**: 0-5

---

## Arena Layout

### Physical Dimensions
```lua
-- Arena is 80% of game window
self.x1, self.y1 = gw/2 - 0.8*gw/2, gh/2 - 0.8*gh/2
self.x2, self.y2 = gw/2 + 0.8*gw/2, gh/2 + 0.8*gh/2
self.w, self.h = self.x2 - self.x1, self.y2 - self.y1
```

| Property | Value |
|----------|-------|
| Shape | Fixed rectangle |
| Size | 80% of window width × 80% of window height |
| Boundaries | Solid walls on all four sides |
| Obstacles | None |
| Variations | None |

### Spawn Points
```lua
spawn_points = {
    { x = x1 + 32, y = y1 + 32, r = math.pi/4 },      -- Top-left
    { x = x1 + 32, y = y2 - 32, r = -math.pi/4 },     -- Bottom-left
    { x = x2 - 32, y = y1 + 32, r = 3*math.pi/4 },    -- Top-right
    { x = x2 - 32, y = y2 - 32, r = -3*math.pi/4 },   -- Bottom-right
    { x = gw/2, y = gh/2, r = random }                 -- Center
}
```

### Spawn Types
| Type | Description |
|------|-------------|
| `'left'` | Enemies spawn from left side |
| `'middle'` | Enemies spawn from center |
| `'right'` | Enemies spawn from right side |
| Corners | 4 corner spawn points (32 pixels from edges) |

---

## Level Types

### Wave Levels (Standard)
Most levels are wave-based combat encounters.

#### Waves Per Level
```lua
level_to_max_waves = {
    2, 3, 4,              -- Levels 1-3
    3, 4, 4, 5,           -- Levels 4-7
    5, 5, 5, 5, 7,        -- Levels 8-12
    6, 6, 7, 7, 8, 10,    -- Levels 13-18
    8, 8, 10, 12, 14, 16, 25, -- Levels 19-25
}
```

| Level Range | Waves | Difficulty |
|-------------|-------|------------|
| 1-3 | 2-4 | Tutorial |
| 4-7 | 3-5 | Early |
| 8-12 | 5-7 | Mid |
| 13-18 | 6-10 | Late |
| 19-25 | 8-25 | Endgame |

### Boss Levels
Boss encounters occur at specific levels.

#### Boss Trigger Formula
```lua
-- Boss spawns when:
(level - 25 * loop) % 6 == 0  -- Every 6th level
OR
level % 25 == 0               -- Level 25 (final boss)
```

| Level | Boss Type |
|-------|-----------|
| 6 | Speed Booster |
| 12 | Exploder |
| 18 | Swarmer |
| 24 | Forcer |
| 25 | Randomizer (Final) |

---

## Spawn Patterns

### Clustered Spawns
- All enemies spawn from one direction
- Easier to manage
- Dominant in early levels

### Distributed Spawns
- Enemies spawn from multiple corners over time
- More chaotic and challenging
- Increases with level progression

#### Distributed Spawn Chance
```lua
-- Chance increases linearly
distributed_chance = 0% (level 1) → 50% (level 25)
```

| Level | Distributed Chance |
|-------|-------------------|
| 1 | 0% |
| 5 | 10% |
| 10 | 20% |
| 15 | 30% |
| 20 | 40% |
| 25 | 50% |

---

## Progression System

### Run Structure
```
Level 1 → Shop → Level 2 → Shop → ... → Level 25 → Boss → Victory/Loop
```

### Shop Schedule
| Event | Levels |
|-------|--------|
| Unit Shop | After every level |
| Item Shop | After levels 3, 6, 9, 12, 15, 18, 21, 24 |
| Boss Fight | Levels 6, 12, 18, 24, 25 |

### Level Progression
| Phase | Levels | Focus |
|-------|--------|-------|
| Early | 1-7 | Build economy, basic synergies |
| Mid | 8-18 | Complete synergies, first bosses |
| Late | 19-25 | Maximize power, final boss prep |

---

## New Game Plus (NG+)

### Unlock Condition
Complete level 25 to unlock NG+1. Each subsequent completion unlocks the next NG+ level.

### Max Snake Size Progression
```lua
max_units = math.clamp(7 + current_new_game_plus + loop, 7, 12)
```

| NG+ | Starting Max | After Loop +1 | Cap |
|-----|--------------|---------------|-----|
| 0 | 7 | 8 | 12 |
| 1 | 8 | 9 | 12 |
| 2 | 9 | 10 | 12 |
| 3 | 10 | 11 | 12 |
| 4 | 11 | 12 | 12 |
| 5 | 12 | 12 | 12 (capped) |

### Enemy Stat Scaling

#### Normal Enemies
| NG+ | HP Multiplier | DMG Multiplier |
|-----|---------------|----------------|
| 0 | 1.0× | 1.0× |
| 1 | ~1.15× | ~1.25× |
| 2 | ~1.30× | ~1.50× |
| 3 | ~1.45× | ~1.75× |
| 4 | ~1.60× | ~2.00× |
| 5 | ~1.75× | ~2.25× |

#### Bosses
| NG+ | HP Multiplier | DMG Multiplier |
|-----|---------------|----------------|
| 0 | 1.0× | 1.0× |
| 1 | ~1.1× | ~1.2× |
| 2 | ~1.2× | ~1.4× |
| 3 | ~1.3× | ~1.6× |
| 4 | ~1.4× | ~1.8× |
| 5 | ~1.5× | ~2.0× |

### Boss Ability Changes

#### Exploder Boss
```lua
-- Projectile count increases with NG+
projectile_count = 8 + (current_new_game_plus × 2)
-- NG+0: 8 projectiles
-- NG+5: 18 projectiles
```

#### Speed Boost Duration
```lua
-- Duration increases with NG+
duration = 3 + (level × 0.015) + (current_new_game_plus × 0.1)
-- NG+0: 3.0s base
-- NG+5: 3.5s base
```

#### Mine Blink Speed
```lua
-- Blink interval decreases with NG+
blink_interval = 0.8 - (current_new_game_plus × 0.1)
-- NG+0: 0.8s between blinks (2.4s total)
-- NG+5: 0.3s between blinks (0.9s total) - 62% faster!
```

#### Randomizer Boss (Level 25)
```lua
-- Extra damage at NG+5
damage = (12 + NG×2) + (1.75 + 0.5×NG) × y[level]
-- 50% more damage scaling at NG+5
```

---

## Loop System

### How Loops Work
After completing level 25, you can choose to continue (loop) or end the run.

### Loop Scaling
```lua
-- Enemies per wave increases with loops
enemies_per_wave = base_enemies + (12 × loop_count)
-- Capped at +200 enemies per wave
```

| Loop | Extra Enemies | Total (base 10) |
|------|---------------|-----------------|
| 0 | +0 | 10 |
| 1 | +12 | 22 |
| 2 | +24 | 34 |
| 3 | +36 | 46 |
| ... | ... | ... |
| 16+ | +200 (cap) | 210 |

### Loop + NG+ Interaction
- Loop count adds to max snake size
- NG+ and loop bonuses stack
- Maximum snake size is always capped at 12

---

## Strategic Implications

### Early Game Strategy (Levels 1-7)
| Priority | Action |
|----------|--------|
| 1 | Learn snake movement |
| 2 | Build economy (save gold for interest) |
| 3 | Start synergy foundation |
| 4 | Avoid walls |

### Mid Game Strategy (Levels 8-18)
| Priority | Action |
|----------|--------|
| 1 | Complete 2-3 synergies |
| 2 | Prepare for bosses |
| 3 | Get key items |
| 4 | Upgrade core units to Level 2-3 |

### Late Game Strategy (Levels 19-25)
| Priority | Action |
|----------|--------|
| 1 | Maximize DPS |
| 2 | Ensure survivability |
| 3 | Perfect positioning |
| 4 | Prepare for Randomizer boss |

### NG+ Strategy
| NG+ | Focus |
|-----|-------|
| 0-2 | Damage scaling, learn mechanics |
| 3-4 | Add defensive items, optimize builds |
| 5 | Perfect synergies, 12-unit snake required |

---

## Arena Design Philosophy

### Why Single Arena?
SNKRX uses a single arena design for several reasons:

1. **Focus on Core Mechanics**: Snake movement + auto-combat
2. **Simplicity**: No environmental hazards to learn
3. **Consistency**: Same arena = predictable spawns
4. **Depth from Systems**: Complexity comes from units/items, not levels

### What Creates Variety?
| Element | Variation |
|---------|-----------|
| Spawn Patterns | Clustered vs Distributed |
| Wave Count | 2-25 waves per level |
| Enemy Density | Increases with level/loop |
| Boss Abilities | 5 unique boss types |
| NG+ Scaling | 6 difficulty levels |

---

## Implementation Notes

### Arena Initialization
```lua
function Arena:init()
    -- Calculate arena bounds
    self.x1 = gw/2 - 0.8*gw/2
    self.y1 = gh/2 - 0.8*gh/2
    self.x2 = gw/2 + 0.8*gw/2
    self.y2 = gh/2 + 0.8*gh/2
    self.w = self.x2 - self.x1
    self.h = self.y2 - self.y1
    
    -- Create walls
    self:create_walls()
    
    -- Initialize spawn points
    self:init_spawn_points()
end
```

### Wave Spawning
```lua
function Arena:spawn_wave(wave_num)
    local spawn_type = self:get_spawn_type()
    local enemy_count = self:calculate_enemy_count(wave_num)
    
    if spawn_type == 'clustered' then
        self:spawn_clustered(enemy_count)
    else
        self:spawn_distributed(enemy_count)
    end
end
```

### Boss Trigger
```lua
function Arena:should_spawn_boss(level)
    local adjusted_level = level - 25 * self.loop
    return adjusted_level % 6 == 0 or level % 25 == 0
end
```

---

## Summary Table

| Aspect | Details |
|--------|---------|
| **Arena Size** | 80% of window (fixed rectangular) |
| **Arena Count** | 1 (no variations) |
| **Hazards** | None (enemy-based only) |
| **Level Types** | Wave (normal) + Boss (every 6th + 25) |
| **Unlock System** | None (all levels use same arena) |
| **NG+ Changes** | +HP/DMG scaling, +max snake size, faster boss abilities |
| **Max NG+** | NG+5 (12-unit cap, hardest difficulty) |
| **Strategic Depth** | Spawn pattern variation, boss mechanics, NG+ scaling |

---

## References

- [SNKRX Source Code - arena.lua](https://github.com/a327ex/SNKRX/blob/master/arena.lua)
- [SNKRX Source Code - enemies.lua](https://github.com/a327ex/SNKRX/blob/master/enemies.lua)
- [SNKRX Source Code - objects.lua](https://github.com/a327ex/SNKRX/blob/master/objects.lua)
