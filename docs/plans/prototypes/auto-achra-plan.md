# Auto-Achra Colony Sim

**Date:** 2026-02-04
**Concept:** An automated roguelike colony sim where units explore dungeons autonomously. Player can optionally select upgrades or let AI decide. Ambient idle-game aesthetic.
**Inspirations:** Path of Achra (character builds, strategic depth), Dwarf Fortress (ASCII aesthetic, emergent behavior), Loop Hero (idle progression)

---

## Design Philosophy

From a327ex's Anchor principles:
- **Locality:** Unit behavior self-contained, not scattered across systems
- **No Bureaucracy:** Direct state mutation, minimal event wiring
- **Intuition-First:** If watching is boring, add visual feedback until it's interesting

---

## Core Loop

1. **Colony Phase** (base)
   - Units rest, heal, train
   - Resources gathered from expeditions
   - Player can assign upgrades OR enable auto-assign

2. **Expedition Phase** (dungeon)
   - Party auto-explores procedural dungeon
   - Combat handled by AI based on unit roles
   - Loot collected, experience gained

3. **Upgrade Phase** (between expeditions)
   - 3 upgrade choices offered
   - Manual: Player selects
   - Auto: AI picks based on party composition

4. **Progression**
   - Unlock new unit types
   - Deeper dungeon levels
   - Boss encounters

---

## Entities

### Heroes

| Entity | Sprite | Stats | Behavior |
|--------|--------|-------|----------|
| Knight | dm_144_hero_knight | HP: 100, ATK: 10, DEF: 8 | Tank, protects backline |
| Mage | dm_145_hero_mage | HP: 50, ATK: 15, DEF: 2 | AoE damage, stays back |
| Rogue | dm_146_hero_rogue | HP: 60, ATK: 12, DEF: 4 | Fast scout, finds secrets |
| Archer | dm_147_hero_archer | HP: 55, ATK: 13, DEF: 3 | Ranged single-target |

### Enemies

| Entity | Sprite | Tier | Behavior |
|--------|--------|------|----------|
| Skeleton | dm_148_skeleton | 1 | Basic melee |
| Zombie | dm_149_zombie | 1 | Slow, tanky |
| Ghost | dm_150_ghost | 2 | Phases through walls |
| Slime | dm_151_slime | 1 | Splits on death |
| Rat | dm_152_rat | 0 | Weak, swarms |
| Bat | dm_153_bat | 0 | Flying, fast |
| Spider | dm_154_spider | 1 | Poison DoT |
| Snake | dm_155_snake | 1 | High crit chance |
| Goblin | dm_156_goblin | 2 | Steals items |
| Orc | dm_157_orc | 2 | Berserker rage |
| Troll | dm_158_troll | 3 | Regenerates HP |
| Dragon | dm_159_dragon | Boss | Multi-phase |

### Environment

| Entity | Sprite | Role |
|--------|--------|------|
| Stone Floor | dm_192_floor_stone | Walkable |
| Cave Wall | dm_197_wall_cave | Blocking |
| Water | dm_200_water | Slows movement |
| Lava | dm_202_lava | Damage over time |
| Torch | dm_208_torch_wall | Light source |
| Chest | dm_213_crate | Loot container |
| Grave | dm_220_grave | Spawns undead |

### Items

| Entity | Sprite | Effect |
|--------|--------|--------|
| Red Potion | dm_176_potion_red | Heal 50 HP |
| Blue Potion | dm_177_potion_blue | Restore mana |
| Gold Coin | dm_190_coin_gold | Currency |
| Red Gem | dm_185_gem_red | Upgrade material |

---

## Systems

### 1. Auto-Behavior System

```lua
-- Behavior priority for each unit type
UnitBehaviors = {
    knight = {"protect_ally", "attack_nearest", "advance"},
    mage = {"cast_aoe", "attack_lowest_hp", "retreat"},
    rogue = {"find_treasure", "backstab", "scout"},
    archer = {"attack_furthest", "attack_lowest_hp", "hold_position"},
}

-- Behavior tree evaluation
function update_unit(unit, dt)
    for _, behavior in ipairs(UnitBehaviors[unit.class]) do
        if Behaviors[behavior](unit) then
            break  -- First successful behavior wins
        end
    end
end
```

### 2. Dungeon Generation

```lua
-- Simple BSP dungeon
DungeonGen = {
    width = 50,
    height = 40,
    min_room_size = 5,
    max_room_size = 12,

    generate = function()
        local rooms = bsp_partition(width, height, min_room_size)
        local corridors = connect_rooms(rooms)
        local tiles = place_tiles(rooms, corridors)
        local enemies = spawn_enemies(rooms)
        local loot = spawn_loot(rooms)
        return {tiles = tiles, enemies = enemies, loot = loot}
    end
}
```

### 3. Combat System

```lua
-- Turn-based with real-time visualization
Combat = {
    tick_rate = 0.5,  -- seconds between actions

    resolve_turn = function(units, enemies)
        -- Sort by speed
        local actors = sort_by_speed(concat(units, enemies))

        for _, actor in ipairs(actors) do
            if actor.alive then
                local action = select_action(actor)
                execute_action(actor, action)
            end
        end
    end
}
```

### 4. Upgrade System

```lua
UpgradePool = {
    -- Stat upgrades
    {id = "hp_up", name = "+10 Max HP", effect = {max_hp = 10}},
    {id = "atk_up", name = "+2 Attack", effect = {atk = 2}},
    {id = "def_up", name = "+2 Defense", effect = {def = 2}},

    -- Skill upgrades
    {id = "cleave", name = "Cleave", class = "knight", desc = "Hit 3 enemies"},
    {id = "fireball", name = "Fireball", class = "mage", desc = "AoE fire damage"},
    {id = "backstab", name = "Backstab+", class = "rogue", desc = "+50% crit damage"},
    {id = "multishot", name = "Multishot", class = "archer", desc = "Hit 2 targets"},
}

-- AI upgrade selection
function ai_select_upgrade(party, choices)
    -- Prioritize based on party needs
    local scores = {}
    for _, choice in ipairs(choices) do
        scores[choice] = evaluate_upgrade(party, choice)
    end
    return max_by_value(scores)
end
```

### 5. Animation (DF-Style)

```lua
-- Animation presets for minimal sprites
Animations = {
    idle = function(e)
        -- Slow breathing bob
        e.offset_y = math.sin(game.time * 2) * 2
    end,

    walk = function(e, target_x, target_y)
        -- Lerp position + slight hop
        e.offset_y = math.abs(math.sin(game.time * 8)) * 4
    end,

    attack = function(e, target)
        -- Lunge toward target + white flash
        local dx = (target.x - e.x) * 0.3
        local dy = (target.y - e.y) * 0.3
        e.tint = WHITE
        timer.tween(0.1, e, {offset_x = dx, offset_y = dy}, 'out-quad', function()
            e.tint = nil
            timer.tween(0.1, e, {offset_x = 0, offset_y = 0}, 'in-quad')
        end)
    end,

    damage = function(e, amount)
        -- Red tint + shake
        e.tint = RED
        local orig_x, orig_y = e.x, e.y
        timer.during(0.2, function()
            e.x = orig_x + math.random(-2, 2)
            e.y = orig_y + math.random(-2, 2)
        end, function()
            e.x, e.y = orig_x, orig_y
            e.tint = nil
        end)
        -- Damage number popup
        spawn_popup(e.x, e.y - 16, "-" .. amount, RED)
    end,

    death = function(e)
        -- Spin + shrink + fade
        timer.tween(0.5, e, {
            rotation = math.pi * 2,
            scale_x = 0,
            scale_y = 0,
            alpha = 0
        }, 'in-quad', function()
            destroy_entity(e)
        end)
    end,

    level_up = function(e)
        -- Yellow flash + expand + sparkles
        e.tint = YELLOW
        timer.tween(0.1, e, {scale_x = 1.3, scale_y = 1.3}, 'out-quad', function()
            timer.tween(0.2, e, {scale_x = 1, scale_y = 1}, 'in-quad')
            e.tint = nil
        end)
        for i = 1, 8 do
            spawn_particle(e.x, e.y, "dm_226_magic_sparkle")
        end
    end,
}
```

---

## UI Layout

```
+--------------------------------------------------+
|  Colony: Dungeon Delvers    Gold: 1234    Lvl: 5 |
+--------------------------------------------------+
|                                                  |
|                 [DUNGEON MAP]                    |
|                                                  |
|              @ . . # . . @ . .                   |
|              . . G . . . . . .                   |
|              . . . . . . . . .                   |
|              . . . . R . . . .                   |
|              . . . . . . . S .                   |
|                                                  |
+--------------------------------------------------+
| Party:                                           |
| [Knight HP:85/100] [Mage HP:45/50]              |
| [Rogue HP:60/60]   [Archer HP:50/55]            |
+--------------------------------------------------+
| [Auto: ON]  [Speed: 2x]  [Pause]                |
+--------------------------------------------------+
```

**Legend:**
- `@` = Hero
- `G` = Goblin
- `R` = Rat
- `S` = Skeleton
- `#` = Wall
- `.` = Floor

---

## Window Configuration

```lua
-- Borderless desktop widget
WindowConfig = {
    title = "Auto-Achra",
    width = 800,
    height = 600,
    borderless = true,
    resizable = true,
    always_on_top = false,  -- Set true for widget mode

    -- Pixel-perfect rendering
    render_scale = 4,       -- 16px tiles -> 64px display
    target_width = 200,     -- Internal resolution
    target_height = 150,
}
```

---

## Milestones

### Phase 1: Foundation
- [ ] Basic tile rendering with dungeon_mode sprites
- [ ] Single room dungeon
- [ ] One unit moving via pathfinding
- [ ] Camera following party

### Phase 2: Core Combat
- [ ] Enemy spawning
- [ ] Turn-based combat resolution
- [ ] HP display and damage numbers
- [ ] Death animations

### Phase 3: Dungeon Loop
- [ ] BSP dungeon generation
- [ ] Multiple rooms with corridors
- [ ] Exploration fog of war
- [ ] Chest/loot spawning

### Phase 4: Party System
- [ ] 4 unit types with different behaviors
- [ ] Formation system
- [ ] Class-specific abilities
- [ ] Party HP display

### Phase 5: Upgrade System
- [ ] Upgrade pool definition
- [ ] Manual upgrade selection UI
- [ ] Auto-upgrade AI
- [ ] Upgrade preview tooltips

### Phase 6: Meta Progression
- [ ] Colony base view
- [ ] Resource accumulation
- [ ] Unit unlocking
- [ ] Difficulty scaling

### Phase 7: Polish
- [ ] All DF-style animations
- [ ] Sound effects (optional)
- [ ] Save/load
- [ ] Borderless window mode

---

## Questions / Decisions Needed

- [ ] How deep should dungeon floors go? (10? 20? Infinite?)
- [ ] Should units permadeath or respawn at base?
- [ ] How many units in a party max? (4? 6?)
- [ ] Add mini-boss rooms between floors?
- [ ] Save between expeditions or only at base?

---

## Asset Checklist

All sprites from `dungeon_mode` folder:

- [x] Heroes: dm_144-147
- [x] Basic enemies: dm_148-155
- [x] Advanced enemies: dm_156-159
- [x] Terrain: dm_192-203
- [x] Props: dm_208-223
- [x] UI elements: dm_236-250
- [ ] Custom animation frames: N/A (using DF-style)

---

*Plan created: 2026-02-04*
