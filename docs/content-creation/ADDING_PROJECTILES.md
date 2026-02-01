# Adding Projectiles

Projectile presets define reusable projectile configurations. Instead of specifying speed, movement, and collision behavior inline every time, you define a preset once and reference it from cards.

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| Preset definitions | ✅ Implemented | `data/projectiles.lua` |
| Movement types | ✅ Implemented | straight, homing, arc, orbital |
| Collision types | ✅ Implemented | destroy, pierce, bounce, explode, pass_through, chain |
| **Custom movement** | ✅ Extensible | Via `movement = "custom"` + `update_func` |
| **Custom fields** | ✅ Extensible | Any field name works |

The projectile system is **fully extensible**. You can add custom fields and even define custom movement/collision functions.

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

| Field | Type | Status | Description |
|-------|------|--------|-------------|
| `suction_strength` | number | ⚠️ NOT IMPL | Pulls enemies toward projectile |
| `suction_radius` | number | ⚠️ NOT IMPL | Pull effect range |
| `leaves_hazard` | bool | ⚠️ NOT IMPL | Creates hazard zone at impact |
| `hazard_duration` | number | ⚠️ NOT IMPL | Hazard lifetime (ms) |
| `on_hit_effect` | string | ⚠️ NOT IMPL | Status effect ("burn", "freeze", "poison") |
| `on_hit_duration` | number | ⚠️ NOT IMPL | Status effect duration (ms) |

> **Note**: These special fields are defined in data but require implementation in `projectile_system.lua`. See [Extending the System](#extending-the-system) for how to add them.

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

## Extending the System

### Adding Custom Fields

You can add any field to a projectile preset. The spawner passes the full definition:

```lua
my_custom_proj = {
    id = "my_custom_proj",
    speed = 400,
    movement = "straight",
    collision = "destroy",
    lifetime = 2000,

    -- Custom fields
    my_special_flag = true,
    custom_data = { intensity = 5 },
    tags = { "Projectile" },
}
```

Access in your collision/update code:
```lua
if projectile.my_special_flag then
    -- Do something special
end
```

### Custom Movement Functions

For movement patterns not covered by built-in types, use `movement = "custom"`:

```lua
spiral_projectile = {
    id = "spiral_projectile",
    speed = 300,
    movement = "custom",
    collision = "destroy",
    lifetime = 3000,

    -- Custom update function
    update_func = function(self, dt)
        -- self.age = time since spawn
        -- self.x, self.y = current position
        -- self.vx, self.vy = current velocity

        local radius = 20 + self.age * 0.1
        local angle = self.age * 5
        self.x = self.x + math.cos(angle) * radius * dt
        self.y = self.y + math.sin(angle) * radius * dt
    end,

    tags = { "Arcane", "Projectile" },
}
```

### Adding New Movement Types

To add a new built-in movement type:

1. Add the handler in `combat/projectile_system.lua`:
   ```lua
   local movement_handlers = {
       straight = function(proj, dt) ... end,
       homing = function(proj, dt) ... end,
       -- Add yours:
       zigzag = function(proj, dt)
           proj.zigzag_timer = (proj.zigzag_timer or 0) + dt
           if proj.zigzag_timer > 0.2 then
               proj.vy = -proj.vy
               proj.zigzag_timer = 0
           end
       end,
   }
   ```

2. Use it in presets:
   ```lua
   movement = "zigzag",
   ```

### Adding New Collision Types

To add a new collision type:

1. Add the handler in `combat/projectile_system.lua`:
   ```lua
   local collision_handlers = {
       destroy = function(proj, target) ... end,
       pierce = function(proj, target) ... end,
       -- Add yours:
       split = function(proj, target)
           -- Spawn 3 smaller projectiles
           for i = 1, 3 do
               spawn_child_projectile(proj, i)
           end
           destroy_projectile(proj)
       end,
   }
   ```

2. Use it in presets:
   ```lua
   collision = "split",
   split_count = 3,  -- Custom field for your handler
   ```

### Adding New Damage Types

Damage types are strings. Add new ones freely:

```lua
damage_type = "chaos",
```

Then handle in your damage calculation:
```lua
if damage_type == "chaos" then
    -- Random element, ignores resistances, etc.
end
```

Standard types: `physical`, `fire`, `ice`, `lightning`, `poison`, `arcane`, `holy`, `void`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
