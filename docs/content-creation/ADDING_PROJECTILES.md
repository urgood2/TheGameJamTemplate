# Adding Projectiles

Projectile presets define reusable projectile configurations. Instead of specifying speed, movement, and collision behavior inline every time, you define a preset once and reference it from cards.

## Quick Start

Add to `assets/scripts/data/projectiles.lua`:

```lua
my_fireball = {
    id = "my_fireball",
    speed = 400,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    lifetime = 2000,
    tags = { "Fire", "Projectile", "AoE" },
}
```

## Field Reference

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (must match table key) |
| `speed` | number | Base velocity (pixels/second) |
| `movement` | string | Movement pattern (see below) |
| `collision` | string | What happens on hit (see below) |

### Common Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `damage_type` | string | "physical" | Damage element type |
| `lifetime` | number | 2000 | Duration before despawn (ms) |
| `tags` | table | {} | Tags for joker synergies |
| `sprite` | string | nil | Visual sprite/animation ID |
| `scale` | number | 1.0 | Size multiplier |
| `trail` | bool | false | Leaves particle trail |

### Movement Types

| Value | Description | Extra Fields |
|-------|-------------|--------------|
| `"straight"` | Constant velocity in aim direction | - |
| `"homing"` | Tracks nearest enemy | `homing_strength` (1-15) |
| `"arc"` | Gravity-affected parabola | `gravity` (pixels/s²) |
| `"orbital"` | Circles around spawn point | `orbital_radius`, `orbital_speed` |
| `"custom"` | User-defined update function | `update_func` |

### Collision Types

| Value | Description | Extra Fields |
|-------|-------------|--------------|
| `"destroy"` | Despawn on hit | - |
| `"pierce"` | Pass through N enemies | `pierce_count` |
| `"bounce"` | Ricochet off surfaces/enemies | `bounce_count`, `bounce_dampening` |
| `"explode"` | AoE damage on impact | `explosion_radius` |
| `"pass_through"` | Ignore collision, still deal damage | - |
| `"chain"` | Jump to nearby enemies | `chain_count`, `chain_range` |

### Movement-Specific Fields

#### Homing
```lua
movement = "homing",
homing_strength = 8,      -- Turn rate (1 = weak, 15 = snappy)
homing_delay = 200,       -- ms before tracking starts
homing_range = 300,       -- Max detection range
```

#### Arc
```lua
movement = "arc",
gravity = 400,            -- Downward acceleration
```

#### Orbital
```lua
movement = "orbital",
orbital_radius = 80,      -- Distance from center
orbital_speed = 3,        -- Rotations per second
```

### Collision-Specific Fields

#### Pierce
```lua
collision = "pierce",
pierce_count = 3,         -- Enemies before despawn
```

#### Bounce
```lua
collision = "bounce",
bounce_count = 5,         -- Bounces before despawn
bounce_dampening = 0.8,   -- Speed multiplier per bounce
```

#### Explode
```lua
collision = "explode",
explosion_radius = 60,    -- AoE radius
explosion_damage_falloff = true,  -- Less damage at edges
```

#### Chain
```lua
collision = "chain",
chain_count = 3,          -- Jumps after initial hit
chain_range = 100,        -- Max jump distance
chain_damage_decay = 0.8, -- Damage multiplier per jump
```

### Special Fields

| Field | Type | Description |
|-------|------|-------------|
| `suction_strength` | number | Pulls enemies toward projectile |
| `suction_radius` | number | Pull effect range |
| `leaves_hazard` | bool | Creates hazard zone at impact |
| `hazard_duration` | number | Hazard lifetime (ms) |
| `on_hit_effect` | string | Status effect applied ("burn", "freeze", "poison") |
| `on_hit_duration` | number | Status effect duration (ms) |

## Templates

### Basic Bolt
```lua
basic_bolt = {
    id = "basic_bolt",
    speed = 500,
    damage_type = "physical",
    movement = "straight",
    collision = "destroy",
    lifetime = 2000,
    tags = { "Projectile" },
}
```

### Explosive Fireball
```lua
fireball = {
    id = "fireball",
    speed = 400,
    damage_type = "fire",
    movement = "straight",
    collision = "explode",
    explosion_radius = 60,
    lifetime = 2000,
    on_hit_effect = "burn",
    on_hit_duration = 3000,
    tags = { "Fire", "Projectile", "AoE" },
}
```

### Piercing Ice Shard
```lua
ice_shard = {
    id = "ice_shard",
    speed = 600,
    damage_type = "ice",
    movement = "straight",
    collision = "pierce",
    pierce_count = 2,
    lifetime = 1800,
    on_hit_effect = "freeze",
    on_hit_duration = 1000,
    tags = { "Ice", "Projectile" },
}
```

### Chain Lightning
```lua
lightning_bolt = {
    id = "lightning_bolt",
    speed = 900,
    damage_type = "lightning",
    movement = "straight",
    collision = "chain",
    chain_count = 3,
    chain_range = 100,
    chain_damage_decay = 0.7,
    lifetime = 1000,
    tags = { "Lightning", "Projectile" },
}
```

### Homing Missile
```lua
homing_missile = {
    id = "homing_missile",
    speed = 350,
    damage_type = "arcane",
    movement = "homing",
    homing_strength = 8,
    homing_delay = 100,
    collision = "destroy",
    lifetime = 3000,
    trail = true,
    tags = { "Arcane", "Projectile" },
}
```

### Bouncing Ball
```lua
bouncing_ball = {
    id = "bouncing_ball",
    speed = 450,
    damage_type = "physical",
    movement = "straight",
    collision = "bounce",
    bounce_count = 3,
    bounce_dampening = 0.9,
    lifetime = 2500,
    tags = { "Projectile" },
}
```

### Gravity Bomb
```lua
gravity_bomb = {
    id = "gravity_bomb",
    speed = 300,
    damage_type = "physical",
    movement = "arc",
    gravity = 400,
    collision = "explode",
    explosion_radius = 80,
    lifetime = 3000,
    tags = { "Projectile", "AoE" },
}
```

### Orbital Orb
```lua
orbital_orb = {
    id = "orbital_orb",
    speed = 200,
    damage_type = "arcane",
    movement = "orbital",
    orbital_radius = 80,
    orbital_speed = 3,
    collision = "pass_through",
    lifetime = 5000,
    tags = { "Arcane", "Projectile" },
}
```

### Poison Cloud
```lua
poison_cloud = {
    id = "poison_cloud",
    speed = 150,
    damage_type = "poison",
    movement = "straight",
    collision = "pass_through",
    leaves_hazard = true,
    hazard_duration = 3000,
    lifetime = 2000,
    on_hit_effect = "poison",
    on_hit_duration = 5000,
    tags = { "Poison", "Hazard" },
}
```

### Void Rift (Suction)
```lua
void_rift = {
    id = "void_rift",
    speed = 250,
    damage_type = "void",
    movement = "straight",
    collision = "destroy",
    suction_strength = 10,
    suction_radius = 100,
    lifetime = 2500,
    tags = { "Void", "Projectile" },
}
```

## Using Presets in Cards

Reference a projectile preset from a card:

```lua
-- In data/cards.lua
Cards.FIRE_BLAST = {
    id = "FIRE_BLAST",
    type = "action",
    mana_cost = 12,
    damage = 25,
    projectile_preset = "fireball",  -- References projectiles.lua
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "FIRE\nblast",
}
```

The projectile system will merge card damage with preset behavior.

## Testing

1. **Validate syntax:**
   ```lua
   dofile("assets/scripts/tools/content_validator.lua")
   ```

2. **Spawn in game:**
   - Open Content Debug Panel → Projectile Spawner tab
   - Select your preset from dropdown
   - Adjust parameters with sliders
   - Click [Spawn at Cursor] or [Spawn at Player]

3. **Test movement:**
   - Spawn homing projectile near enemies
   - Spawn arc projectile to see gravity
   - Spawn orbital to see rotation

4. **Test collision:**
   - Spawn pierce projectile into enemy group
   - Spawn bounce projectile at wall
   - Spawn explode projectile to see AoE radius

## Common Mistakes

1. **Invalid movement type** - Must be exact string
   ```lua
   -- WRONG
   movement = "Homing",  -- capital H
   movement = "seek",    -- not a valid type

   -- RIGHT
   movement = "homing",
   ```

2. **Invalid collision type** - Must be exact string
   ```lua
   -- WRONG
   collision = "Explode",  -- capital E
   collision = "aoe",      -- not a valid type

   -- RIGHT
   collision = "explode",
   ```

3. **Missing required fields for behavior**
   ```lua
   -- WRONG (homing without strength)
   movement = "homing",
   -- missing homing_strength!

   -- RIGHT
   movement = "homing",
   homing_strength = 8,
   ```

4. **ID mismatch** - Table key must match `id` field
   ```lua
   -- WRONG
   my_projectile = { id = "myprojectile", ... }

   -- RIGHT
   my_projectile = { id = "my_projectile", ... }
   ```

5. **Forgetting lifetime** - Projectile may never despawn
   ```lua
   -- WRONG (lives forever if it misses)
   collision = "destroy",
   -- missing lifetime!

   -- RIGHT
   collision = "destroy",
   lifetime = 2000,
   ```
