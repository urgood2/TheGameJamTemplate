# SNKRX Enemies - Complete Enemy & Boss Guide

> **Source**: [a327ex/SNKRX](https://github.com/a327ex/SNKRX/blob/master/enemies.lua)
> **Enemy Types**: Seekers (basic), Bosses (5 types)
> **Scaling**: Exponential with level and NG+

---

## Enemy System Overview

### Core Mechanics
- **Auto-spawn**: Enemies spawn from arena edges/corners
- **Wave-based**: Multiple waves per level
- **Scaling**: Stats increase exponentially with level
- **Cap**: 300 enemies max (despawn if too far)

### Spawn Locations
```lua
spawn_points = {
    { x = x1 + 32, y = y1 + 32 },  -- Top-left corner
    { x = x1 + 32, y = y2 - 32 },  -- Bottom-left corner
    { x = x2 - 32, y = y1 + 32 },  -- Top-right corner
    { x = x2 - 32, y = y2 - 32 },  -- Bottom-right corner
    { x = center_x, y = center_y } -- Center
}
```

---

## Basic Enemy: Seeker

### Description
The Seeker is the only basic enemy type in SNKRX. It's a simple chasing enemy that moves toward the player's snake.

### Base Stats

| Stat | Formula | Level 1 | Level 10 | Level 25 |
|------|---------|---------|----------|----------|
| HP | 25 + 16.5 × y[level] | ~42 | ~190 | ~438 |
| Damage | 4.5 + 2.5 × y[level] | ~7 | ~29 | ~67 |
| Speed | min(70 + 3 × y[level], 70 + 3 × y[150]) | ~73 | ~100 | ~145 |

**Note**: `y[level]` is a scaling factor that increases with level

### Behavior
1. Spawns at arena edge
2. Moves directly toward player's snake head
3. Deals contact damage on collision
4. Dies when HP reaches 0

### Visual Variants
Seekers have different colors based on special properties:
- **White**: Standard seeker
- **Green**: Speed-boosted (from Speed Booster boss)
- **Blue**: About to explode (from Exploder boss)
- **Purple**: About to spawn critters (from Swarmer boss)

---

## Boss Enemies

### Boss Schedule
| Level | Boss Type | Color |
|-------|-----------|-------|
| 6 | Speed Booster | Green |
| 12 | Exploder | Blue |
| 18 | Swarmer | Purple |
| 24 | Forcer | Yellow |
| 25 | Randomizer | Multi-color |

### Boss Mechanics
- **Spawn Delay**: 3-second countdown before boss appears
- **Continuous Waves**: Regular enemies spawn during boss fight
- **Push Resistance**: Bosses have 80% knockback resistance
- **Win Condition**: Kill boss + clear all remaining enemies

---

### Speed Booster Boss (Level 6)
**Color**: Green

#### Stats
| Stat | Value |
|------|-------|
| HP | 100 + 90 × y[level] |
| Damage | 12 + 2 × y[level] |
| Ability Cooldown | 8 seconds |

#### Ability: Speed Boost
1. Finds 4 nearest Seeker enemies within 128 radius
2. Grants them 3× movement speed for duration
3. Duration: 3 + 0.015 × level + 0.1 × NG+ seconds
4. Visual: Green lightning lines connecting boss to buffed enemies

#### Strategy
- Kill buffed enemies quickly (they're dangerous)
- Stay mobile to avoid speed-boosted seekers
- Focus boss when no buffed enemies nearby

---

### Exploder Boss (Level 12)
**Color**: Blue

#### Stats
| Stat | Value |
|------|-------|
| HP | 100 + 90 × y[level] |
| Damage | 12 + 2 × y[level] |
| Ability Cooldown | 4 seconds |

#### Ability: Convert to Mine
1. Selects random nearby Seeker
2. Kills the Seeker
3. Spawns an ExploderMine at that location
4. Mine blinks 3 times over 2.4 seconds (0.8s intervals)
5. Mine explodes into 8 + (2 × NG+) projectiles

#### Mine Stats
| Stat | Value |
|------|-------|
| Projectile Count | 8 + (2 × NG+) |
| Projectile Speed | 120 + min(5 × level, 300) |
| Projectile Damage | 1.3 × boss damage |

#### Strategy
- Watch for blue-tinted enemies (about to become mines)
- Move away from mines before they explode
- Clear mines quickly if possible

---

### Swarmer Boss (Level 18)
**Color**: Purple

#### Stats
| Stat | Value |
|------|-------|
| HP | 100 + 90 × y[level] |
| Damage | 12 + 2 × y[level] |
| Ability Cooldown | 4 seconds |

#### Ability: Convert to Critters
1. Selects random nearby Seeker
2. Kills the Seeker
3. Spawns 4-6 EnemyCritters at that location
4. Critters have 2× damage multiplier

#### Critter Stats
| Stat | Value |
|------|-------|
| HP | Scales with level |
| Speed | 8 + 0.1 × level |
| Damage | 2× parent damage |
| Size | 7×4 (smaller than Seekers) |

#### Strategy
- Kill purple-tinted enemies before conversion
- AoE attacks are effective against critter swarms
- Don't let critters accumulate

---

### Forcer Boss (Level 24)
**Color**: Yellow

#### Stats
| Stat | Value |
|------|-------|
| HP | 100 + 90 × y[level] |
| Damage | 12 + 2 × y[level] |
| Ability Cooldown | 6 seconds |

#### Ability: Pull and Push
1. Creates pull zone (160 radius) at boss location
2. Pulls all enemies toward center for 2 seconds
3. After 2 seconds, pushes all enemies toward player
4. Push force: 40-80 (varies)

#### Visual
- Yellow rotating circle during pull phase
- Expanding ring during push phase

#### Strategy
- Stay away from boss during pull phase
- Be ready to dodge pushed enemies
- Use the grouping to your advantage (AoE)

---

### Randomizer Boss (Level 25)
**Color**: Multi-color (changes per attack)

#### Stats
| Stat | Value |
|------|-------|
| HP | 100 + 90 × y[level] |
| Damage | (12 + NG×2) + (1.75 + 0.5×NG) × y[level] |
| Ability Cooldown | 6 seconds |
| Push Resistance | 30% (less than other bosses) |

#### Ability: Random Attack
Each cycle, randomly uses one of the 4 boss abilities:
1. **Speed Boost** (Green) - Buffs nearby enemies
2. **Explode** (Blue) - Creates mines
3. **Swarm** (Purple) - Spawns critters
4. **Force** (Yellow) - Pull and push

#### Special Properties
- Color changes to match current ability
- 50% more damage at NG+5
- Less push resistance (can be knocked around)

#### Strategy
- Watch color to predict next attack
- Adapt strategy based on current ability
- Most challenging boss - requires all strategies

---

## Enemy Scaling

### Base Game (NG+0)

#### Normal Enemies
```lua
base_hp = 25 + 16.5 × y[level]
base_dmg = 4.5 + 2.5 × y[level]
base_mvspd = min(70 + 3 × y[level], 70 + 3 × y[150])
```

#### Bosses
```lua
base_hp = 100 + 90 × y[level]
base_dmg = 12 + 2 × y[level]
```

### New Game Plus Scaling

#### Normal Enemies (NG+1 to NG+5)
```lua
base_hp = 22 + (NG × 3) + (15 + NG × 2.7) × y[level]
base_dmg = (4 + NG × 1.15) + (2 + NG × 0.83) × y[level]
```

#### Bosses (NG+1 to NG+5)
```lua
base_hp = 100 + (NG × 5) + (90 + NG × 10) × y[level]
base_dmg = (12 + NG × 2) + (2 + NG) × y[level]
```

### Scaling Table

| NG+ | Enemy HP Mult | Enemy DMG Mult | Boss HP Mult | Boss DMG Mult |
|-----|---------------|----------------|--------------|---------------|
| 0 | 1.0× | 1.0× | 1.0× | 1.0× |
| 1 | ~1.15× | ~1.25× | ~1.1× | ~1.2× |
| 2 | ~1.30× | ~1.50× | ~1.2× | ~1.4× |
| 3 | ~1.45× | ~1.75× | ~1.3× | ~1.6× |
| 4 | ~1.60× | ~2.00× | ~1.4× | ~1.8× |
| 5 | ~1.75× | ~2.25× | ~1.5× | ~2.0× |

---

## Wave System

### Waves Per Level
```lua
level_to_max_waves = {
    2, 3, 4,              -- Levels 1-3
    3, 4, 4, 5,           -- Levels 4-7
    5, 5, 5, 5, 7,        -- Levels 8-12
    6, 6, 7, 7, 8, 10,    -- Levels 13-18
    8, 8, 10, 12, 14, 16, 25, -- Levels 19-25
}
```

### Wave Progression
| Level Range | Waves | Notes |
|-------------|-------|-------|
| 1-3 | 2-4 | Tutorial difficulty |
| 4-7 | 3-5 | Early game |
| 8-12 | 5-7 | Mid game, first bosses |
| 13-18 | 6-10 | Late game |
| 19-25 | 8-25 | Endgame, final boss |

### Spawn Patterns

#### Clustered Spawns (Early Game)
- All enemies spawn from one direction
- Easier to manage
- Dominant in levels 1-12

#### Distributed Spawns (Late Game)
- Enemies spawn from multiple corners
- More chaotic
- Chance increases: 0% (level 1) → 50% (level 25)

### Loop Scaling
After completing level 25, the game loops with increased difficulty:
```lua
enemies_per_wave = base_enemies + (12 × loop_count)
-- Capped at +200 enemies per wave
```

---

## Enemy Projectiles

### Exploder Mine Projectiles
| Property | Value |
|----------|-------|
| Speed | 120 + min(5 × level, 300) |
| Damage | 1.3 × boss damage |
| Count | 8 + (2 × NG+) |
| Pattern | Radial (360° spread) |

### Shooter Enemy Projectiles (if implemented)
| Property | Value |
|----------|-------|
| Speed | 100-200 |
| Damage | Enemy base damage |
| Pattern | Aimed at player |

---

## Special Enemy Properties

### Speed Boost Effect
```lua
-- Duration formula
duration = 3 + (0.015 × level) + (0.1 × NG+)

-- Speed multiplier
speed_multiplier = 3.0
```

### Push Resistance
| Entity | Resistance |
|--------|------------|
| Normal Seeker | 0% |
| Boss (Level 6-24) | 80% |
| Randomizer Boss | 30% |

### Critter Properties
| Property | Value |
|----------|-------|
| Size | 7×4 pixels |
| HP | Scales with level |
| Speed | 8 + 0.1 × level |
| Damage | 2× parent |
| Behavior | Chase player |

---

## Strategic Considerations

### Early Game (Levels 1-7)
- Simple clustered spawns
- Low enemy count
- Focus on learning movement
- Build economy

### Mid Game (Levels 8-18)
- First boss encounters
- Mixed spawn patterns
- Build synergies
- Manage boss abilities

### Late Game (Levels 19-25)
- High wave counts
- Distributed spawns
- Maximum chaos
- Final boss preparation

### NG+ Strategy
| NG+ | Focus |
|-----|-------|
| 0-2 | Damage scaling |
| 3-4 | Add defensive items |
| 5 | Perfect synergies required |

---

## Implementation Notes

### Enemy AI
```lua
-- Basic Seeker behavior
function Seeker:update(dt)
    -- Calculate direction to player
    local dx = player.x - self.x
    local dy = player.y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Normalize and apply speed
    self.vx = (dx / dist) * self.speed
    self.vy = (dy / dist) * self.speed
    
    -- Move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
end
```

### Boss Ability Timing
```lua
-- Boss ability loop
function Boss:update(dt)
    self.ability_timer = self.ability_timer - dt
    if self.ability_timer <= 0 then
        self:use_ability()
        self.ability_timer = self.ability_cooldown
    end
end
```

### Spawn System
```lua
-- Wave spawning
function Arena:spawn_wave()
    local spawn_point = self:get_spawn_point()
    local enemy_count = self:calculate_enemy_count()
    
    for i = 1, enemy_count do
        local enemy = Seeker:new(spawn_point.x, spawn_point.y)
        self:add_enemy(enemy)
    end
end
```

---

## References

- [SNKRX Source Code - enemies.lua](https://github.com/a327ex/SNKRX/blob/master/enemies.lua)
- [SNKRX Source Code - arena.lua](https://github.com/a327ex/SNKRX/blob/master/arena.lua)
- [SNKRX Source Code - objects.lua](https://github.com/a327ex/SNKRX/blob/master/objects.lua)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
