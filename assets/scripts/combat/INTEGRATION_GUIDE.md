# Combat Loop Framework - Quick Integration Guide

## Quick Start (5 Minutes)

### Step 1: Basic Setup

```lua
-- In your main game file (e.g., gameplay.lua)
local CombatLoopIntegration = require("combat.combat_loop_integration")

-- Store combat loop instance
local combat_loop = nil
```

### Step 2: Define Your Waves

```lua
local my_waves = {
    -- Wave 1: Simple instant spawn
    {
        wave_number = 1,
        type = "instant",
        enemies = {
            { type = "goblin", count = 5 }
        },
        spawn_config = {
            type = "random_area",
            area = { x = 200, y = 200, w = 1200, h = 800 }
        },
        difficulty_scale = 1.0,
        rewards = {
            base_xp = 50,
            base_gold = 20
        }
    },

    -- Wave 2: Timed spawn for variety
    {
        wave_number = 2,
        type = "timed",
        spawn_schedule = {
            { delay = 0, enemy = "goblin", count = 3 },
            { delay = 5, enemy = "orc", count = 2 },
            { delay = 10, enemy = "goblin", count = 3 }
        },
        spawn_config = {
            type = "off_screen",
            margin = 50
        },
        difficulty_scale = 1.3,
        rewards = {
            base_xp = 100,
            base_gold = 50,
            interest_per_second = 2
        }
    }
}
```

### Step 3: Initialize Combat Loop

```lua
function initialize_combat()
    combat_loop = CombatLoopIntegration.new({
        waves = my_waves,
        player_entity = survivorEntity,  -- Your player entity
        entity_factory_fn = create_ai_entity,  -- Your entity factory
        loot_collection_mode = "auto_collect",  -- or "click" or "magnet"

        -- Optional callbacks
        on_wave_complete = function(wave_num, stats)
            log_debug("Wave", wave_num, "complete! XP:", stats.total_xp)
        end,

        on_combat_end = function(victory, stats)
            if victory then
                show_victory_screen()
            else
                show_defeat_screen()
            end
        end
    })

    log_debug("Combat loop initialized with", #my_waves, "waves")
end
```

### Step 4: Start Combat

```lua
function start_combat()
    if combat_loop then
        combat_loop:start()
        log_debug("Combat started!")
    end
end
```

### Step 5: Update Loop

```lua
function update(dt)
    -- Update combat loop every frame
    if combat_loop then
        combat_loop:update(dt)
    end
end
```

## That's It!

Your combat loop is now fully functional. Enemies will spawn, battles will occur, loot will drop, and waves will progress automatically.

---

## Advanced Configuration

### Custom Loot Tables

```lua
local my_loot_tables = {
    goblin = {
        gold = { min = 1, max = 3, chance = 100 },
        xp = { base = 10, variance = 2, chance = 100 },
        items = {
            { type = "health_potion", chance = 10 }
        }
    },
    orc = {
        gold = { min = 5, max = 10, chance = 100 },
        xp = { base = 25, variance = 5, chance = 100 },
        items = {
            { type = "health_potion", chance = 15 },
            { type = "card_common", chance = 5 }
        }
    },
    boss = {
        gold = { min = 50, max = 100, chance = 100 },
        xp = { base = 200, variance = 20, chance = 100 },
        items = {
            { type = "card_rare", chance = 50 },
            { type = "legendary_weapon", chance = 10 }
        }
    }
}

-- Pass to combat loop
combat_loop = CombatLoopIntegration.new({
    loot_tables = my_loot_tables,
    ...
})
```

### Different Spawn Patterns

#### Budget-Based Wave
```lua
{
    wave_number = 3,
    type = "budget",
    budget = 30,  -- Total points
    enemies = {
        { type = "goblin", cost = 1, weight = 10 },
        { type = "orc", cost = 3, weight = 5 },
        { type = "troll", cost = 10, weight = 1 }
    },
    spawn_config = {
        type = "random_area",
        area = { x = 100, y = 100, w = 1400, h = 1000 }
    }
}
```

#### Survival Wave
```lua
{
    wave_number = 4,
    type = "survival",
    survival_duration = 60,  -- 60 seconds
    spawn_interval = 3,      -- Spawn every 3 seconds
    enemies = {
        { type = "goblin", count = 2 },
        { type = "orc", count = 1 }
    },
    spawn_config = {
        type = "around_player",
        radius = 400,
        min_radius = 300
    }
}
```

### Different Spawn Locations

#### Circle Formation
```lua
spawn_config = {
    type = "circle",
    center = { x = 800, y = 600 },
    radius = 300,
    total_enemies = 8  -- Evenly distributed
}
```

#### Fixed Points
```lua
spawn_config = {
    type = "fixed_points",
    points = {
        { x = 200, y = 200 },
        { x = 1400, y = 200 },
        { x = 800, y = 600 },
        { x = 200, y = 1000 },
        { x = 1400, y = 1000 }
    }
}
```

#### Around Player
```lua
spawn_config = {
    type = "around_player",
    player = survivorEntity,
    radius = 400,
    min_radius = 300
}
```

### Callbacks for Custom Logic

```lua
combat_loop = CombatLoopIntegration.new({
    -- Wave lifecycle
    on_wave_start = function(wave_number)
        -- Show wave banner
        show_wave_banner(wave_number)
        play_sound("wave_start")
    end,

    on_wave_complete = function(wave_number, stats)
        -- Show stats popup
        show_wave_stats_popup(stats)

        -- Grant player rewards
        grant_player_xp(stats.total_xp)
        grant_player_gold(stats.total_gold)

        -- Achievement check
        if stats.perfect_clear then
            unlock_achievement("perfect_wave_" .. wave_number)
        end
    end,

    -- Combat outcome
    on_combat_end = function(victory, stats)
        if victory then
            -- Victory sequence
            play_victory_fanfare()
            show_victory_screen(stats)
            unlock_next_level()
        else
            -- Defeat sequence
            play_defeat_sound()
            show_defeat_screen()
            offer_retry()
        end
    end,

    -- All waves complete
    on_all_waves_complete = function(total_stats)
        -- End game celebration
        show_credits()
        save_high_score(total_stats)
    end
})
```

## Control Functions

```lua
-- Pause/Resume
combat_loop:pause()
combat_loop:resume()

-- Manual wave progression (from intermission)
combat_loop:progress_to_next_wave()

-- Stop combat
combat_loop:stop()

-- Reset to beginning
combat_loop:reset()

-- Query state
local state = combat_loop:get_current_state()
-- Returns: "WAVE_START", "SPAWNING", "COMBAT", "VICTORY", etc.

-- Get statistics
local wave_stats = combat_loop:get_wave_stats()
local total_stats = combat_loop:get_total_stats()
```

## Enemy Entity Requirements

Your enemy entities must:

1. **Have a health value** (via blackboard or script component)
   ```lua
   setBlackboardFloat(enemy, "health", 100)
   setBlackboardFloat(enemy, "max_health", 100)
   ```

2. **Emit death event when HP reaches 0**
   ```lua
   if hp <= 0 then
       publishLuaEvent("OnEntityDeath", {
           entity = enemy,
           killer = attacker
       })
   end
   ```

3. **Be created by your entity factory function**
   ```lua
   function create_ai_entity(enemy_type)
       if enemy_type == "goblin" then
           return create_goblin()
       elseif enemy_type == "orc" then
           return create_orc()
       end
   end
   ```

## Player Entity Requirements

Your player entity must:

1. **Have a valid entity ID**
   ```lua
   local player = survivorEntity  -- Or however you track player
   ```

2. **Have a health value** (for alive check)
   ```lua
   setBlackboardFloat(player, "health", 100)
   ```

3. **Stay alive** (combat loop checks every frame)
   ```lua
   -- The combat loop automatically checks:
   is_player_alive = function()
       local hp = getBlackboardFloat(player, "health")
       return hp and hp > 0
   end
   ```

## Event Integration

The combat loop emits these events:

```lua
-- Listen for events in your code
combat_context.bus:on("OnWaveStart", function(event)
    log_debug("Wave", event.wave_number, "started!")
end)

combat_context.bus:on("OnEnemySpawned", function(event)
    log_debug("Enemy spawned:", event.enemy_type)
end)

combat_context.bus:on("OnEnemyDeath", function(event)
    log_debug("Enemy died:", event.entity)
end)

combat_context.bus:on("OnLootDropped", function(event)
    log_debug("Loot dropped:", event.loot_type)
end)

combat_context.bus:on("OnLootCollected", function(event)
    log_debug("Collected:", event.loot_type, "x", event.amount)
end)
```

## Projectile System Integration

Enemies can use the projectile system (from Task 1):

```lua
local ProjectileSystem = require("combat.projectile_system")

-- In your enemy AI behavior
function enemy_attack(enemy, target)
    local enemy_pos = get_entity_position(enemy)
    local target_pos = get_entity_position(target)

    local direction = normalize(target_pos - enemy_pos)

    -- Spawn projectile
    ProjectileSystem.spawn({
        position = enemy_pos,
        direction = direction,
        baseSpeed = 300,
        damage = 10,
        owner = enemy,
        faction = "enemy",
        movementType = ProjectileSystem.MovementType.STRAIGHT,
        collisionBehavior = ProjectileSystem.CollisionBehavior.DESTROY,
        sprite = "enemy_bullet.png"
    })
end
```

## Testing

Use the built-in test scenario:

```lua
local CombatLoopTest = require("combat.combat_loop_test")

-- Initialize test
function init()
    CombatLoopTest.initialize()
end

-- Update test
function update(dt)
    CombatLoopTest.update_test_combat(dt)
end

-- Start test (press T key)
-- Or manually:
CombatLoopTest.start_test_combat()
```

Test helpers:
```lua
-- Kill all enemies instantly (test victory)
CombatLoopTest.kill_all_enemies()

-- Damage player (test defeat)
CombatLoopTest.damage_player(50)

-- Skip to next wave
CombatLoopTest.trigger_next_wave()

-- Check state
local state = CombatLoopTest.get_current_state()
```

## Common Patterns

### Boss Wave
```lua
{
    wave_number = 5,
    type = "instant",
    enemies = {
        { type = "boss", count = 1 }
    },
    spawn_config = {
        type = "fixed_points",
        points = { { x = 800, y = 300 } }  -- Center top
    },
    difficulty_scale = 2.0,
    rewards = {
        base_xp = 500,
        base_gold = 200,
        perfect_bonus = 100
    }
}
```

### Progressive Difficulty
```lua
local waves = {}
for i = 1, 10 do
    table.insert(waves, {
        wave_number = i,
        type = "instant",
        enemies = {
            { type = "goblin", count = 3 + i * 2 }
        },
        difficulty_scale = 1.0 + (i - 1) * 0.15,  -- +15% per wave
        rewards = {
            base_xp = 50 * i,
            base_gold = 20 * i
        }
    })
end
```

### Horde Mode
```lua
{
    wave_number = 1,
    type = "survival",
    survival_duration = 300,  -- 5 minutes
    spawn_interval = 2,       -- Spawn every 2 seconds
    enemies = {
        { type = "goblin", count = 3 }
    },
    spawn_config = {
        type = "off_screen",
        margin = 50
    },
    difficulty_scale = 1.0,
    rewards = {
        interest_per_second = 5  -- High interest for survival
    }
}
```

## Troubleshooting

**Problem**: Enemies don't spawn
- Check `create_ai_entity` function exists
- Verify enemy type names match
- Check spawn area is within world bounds

**Problem**: Wave doesn't complete
- Ensure death events are emitted
- Check enemy tracking in wave manager
- Verify all enemies are destroyed

**Problem**: Loot doesn't appear
- Check loot tables are defined
- Verify enemy types in loot tables
- Check loot spawn position calculation

**Problem**: Memory leaks
- Ensure `OnEntityDeath` event is emitted
- Check entity cleanup is called
- Verify timers are cancelled

**Problem**: Player death not detected
- Check player health blackboard value
- Verify `is_player_alive` callback
- Ensure health updates on damage

## Performance Tips

1. **Limit max enemies on screen** (30-50 recommended)
2. **Use budget waves** for controlled spawning
3. **Batch spawn enemies** (5-10 per frame max)
4. **Enable loot despawn** (30s timeout)
5. **Use auto-collect loot** for better performance

## Next Steps

After integration:

1. **Design your waves** - Create interesting wave progressions
2. **Balance rewards** - Tune XP/gold amounts
3. **Add enemy variety** - Create different enemy types
4. **Polish effects** - Enhance death animations
5. **Add UI** - Show wave progress, stats, timers
6. **Test thoroughly** - Run through all waves

## Support

For detailed architecture and system documentation, see:
- `ARCHITECTURE.md` - Full system architecture
- `TASK_4_COMBAT_LOOP_REPORT.md` - Complete implementation report
- `combat_loop_test.lua` - Working example code

For questions or issues, check the implementation files:
- `combat_state_machine.lua` - State logic
- `wave_manager.lua` - Wave progression
- `enemy_spawner.lua` - Spawning logic
- `loot_system.lua` - Loot drops
- `entity_cleanup.lua` - Cleanup system
