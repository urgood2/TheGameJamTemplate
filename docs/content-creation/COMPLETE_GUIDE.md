# Complete Content Creation Guide

This guide covers how to add jokers, cards, avatars, and improve wave visuals in your game.

## Table of Contents
1. [Adding Jokers](#1-adding-jokers)
2. [Adding Cards (Action/Modifier/Trigger)](#2-adding-cards)
3. [Adding Avatars with Unlock Conditions](#3-adding-avatars)
4. [Wave Visual Improvements](#4-wave-visual-improvements)

---

## 1. Adding Jokers

Jokers are passive artifacts that react to game events. They're defined in `assets/scripts/data/jokers.lua` and managed by `assets/scripts/wand/joker_system.lua`.

### Step 1: Define the Joker

Edit `assets/scripts/data/jokers.lua`:

```lua
-- Add your new joker to the Jokers table
glass_cannon = {
    id = "glass_cannon",           -- Unique identifier (must match table key)
    name = "Glass Cannon",         -- Display name
    description = "+50% Damage, but take +25% damage from projectiles.",
    rarity = "Rare",               -- Common, Uncommon, Rare, Epic, Legendary
    -- sprite = "joker_glass_cannon",  -- Optional: custom sprite (default: joker_sample.png)

    -- The calculate function is called for every game event
    calculate = function(self, context)
        -- React to spell casts (offensive buff)
        if context.event == "on_spell_cast" then
            return {
                damage_mult = 1.5,          -- Multiply damage by 1.5
                message = "Glass Cannon!"    -- Floating text shown
            }
        end

        -- React to taking damage (defensive penalty)
        if context.event == "on_player_damaged" and context.source == "enemy_projectile" then
            return {
                damage_increase = math.floor(context.damage * 0.25),
                message = "Fragile!"
            }
        end
    end
}
```

### Step 2: Understand Available Events

The `context.event` can be:

| Event | When Triggered | Context Fields |
|-------|---------------|----------------|
| `"on_spell_cast"` | Player casts a spell | `spell_type`, `tags`, `player`, `tag_analysis` |
| `"calculate_damage"` | Damage is being calculated | `player`, `player.tag_counts` |
| `"on_player_damaged"` | Player takes damage | `source`, `damage`, `damage_type` |
| `"on_kill"` | Player kills an enemy | `enemy_type`, `tags` |
| `"on_dodge"` | Player dodges | - |
| `"on_dash"` | Player dashes | `direction` |

### Step 3: Return Effects

Your `calculate` function can return any combination of:

```lua
return {
    -- Damage modification
    damage_mod = 10,              -- Add flat damage
    damage_mult = 1.3,            -- Multiply damage by 1.3 (30% increase)

    -- Cast effects
    repeat_cast = 1,              -- Cast the spell again

    -- Resource effects
    mana_restore = 10,            -- Restore mana

    -- Defensive effects
    damage_reduction = 5,         -- Reduce incoming damage
    reflect_damage = 10,          -- Reflect damage to attacker

    -- Buff effects
    buff = { stat = "damage_mult", value = 1.2, duration = 3.0 },

    -- UI feedback
    message = "Joker Triggered!"  -- Floating text
}
```

### Step 4: Add Joker to Player

In your game code, add jokers to the player:

```lua
local JokerSystem = require("wand.joker_system")

-- Add a joker by ID
JokerSystem.add_joker("glass_cannon")

-- Clear all jokers (for testing/new run)
JokerSystem.clear_jokers()

-- Trigger events manually (combat system does this automatically)
local effects = JokerSystem.trigger_event("on_spell_cast", {
    spell_type = "Mono-Element",
    tags = { Fire = true, Projectile = true },
    player = playerData
})

-- Use aggregated effects
print("Total damage mod:", effects.damage_mod)
print("Total damage mult:", effects.damage_mult)
for _, msg in ipairs(effects.messages) do
    print("Message:", msg.text)
end
```

### Step 5: Show Jokers in UI

The `avatar_joker_strip.lua` automatically displays active jokers. Sync it with your player:

```lua
local AvatarJokerStrip = require("ui.avatar_joker_strip")

-- Initialize the strip
AvatarJokerStrip.init()

-- Sync with player data (call when jokers change)
AvatarJokerStrip.syncFrom(player, JokerSystem.jokers)

-- In your update loop
AvatarJokerStrip.update()

-- In your draw loop
AvatarJokerStrip.draw()
```

---

## 2. Adding Cards

Cards are defined in `assets/scripts/data/cards.lua`. There are three types: **Action**, **Modifier**, and **Trigger**.

### Action Cards (Spells that do things)

```lua
Cards.MY_LIGHTNING_BOLT = {
    -- Required fields
    id = "MY_LIGHTNING_BOLT",        -- Must match table key
    type = "action",                  -- "action", "modifier", or "trigger"
    mana_cost = 15,
    tags = { "Lightning", "Projectile" },
    test_label = "MY\nlightning\nbolt",  -- Display label (\n for line breaks)
    -- sprite = "lightning_bolt_icon",   -- Optional custom sprite

    -- Action-specific combat fields
    damage = 35,
    damage_type = "lightning",        -- fire/ice/lightning/poison/arcane/holy/void/magic/physical
    projectile_speed = 700,
    lifetime = 1500,                  -- ms before projectile expires
    radius_of_effect = 0,             -- 0 = single target, >0 = AoE radius

    -- Optional behavior fields
    spread_angle = 2,                 -- Accuracy spread in degrees
    cast_delay = 100,                 -- ms delay before cast
    homing_strength = 5,              -- 0-15, higher = stronger homing
    ricochet_count = 2,               -- Number of bounces

    -- Special behaviors
    trigger_on_collision = true,      -- Cast wrapped spells on hit
    timer_ms = 1000,                  -- Timer for delayed effects
    teleport_on_hit = true,           -- Teleport player to impact point

    -- Limits
    max_uses = -1,                    -- -1 = unlimited, >0 = consumable
    weight = 3,                       -- For weighted random selection
}
```

### Modifier Cards (Modify next spell)

```lua
Cards.MOD_CHAIN_LIGHTNING = {
    id = "MOD_CHAIN_LIGHTNING",
    type = "modifier",
    mana_cost = 8,
    tags = { "Lightning", "Arcane" },
    test_label = "MOD\nchain\nlightning",

    -- Modifier effects (applied to next action)
    damage_modifier = 5,              -- Add flat damage
    speed_modifier = 2,               -- Speed boost (-3 to +3 typical)
    spread_modifier = -2,             -- Accuracy improvement
    lifetime_modifier = 1,            -- Duration boost
    critical_hit_chance_modifier = 10,-- Crit chance %

    -- Special modifiers
    homing_strength = 8,              -- Add homing
    seek_strength = 5,                -- Seeking behavior
    make_explosive = true,            -- Add explosion on hit
    radius_of_effect = 40,            -- AoE when explosive

    -- Multicast (affects multiple spells)
    multicast_count = 2,              -- Cast next N actions

    -- Meta effects
    trigger_on_collision = true,      -- Wrapped spell triggers on hit
    timer_ms = 500,                   -- Delay before wrapped spell

    -- Limits
    revisit_limit = 2,                -- How many times can be applied
    weight = 2,
}
```

### Trigger Cards (Automatic casting conditions)

```lua
TriggerCards.TRIGGER_ON_CRIT = {
    id = "on_crit",
    type = "trigger",
    mana_cost = 0,                    -- Triggers usually cost 0 mana
    weight = 0,
    tags = { "Arcane", "Brute" },
    description = "Casts spells when you land a critical hit",

    -- Trigger configuration
    trigger_type = "crit",            -- time, collision, dash, movement, crit, kill

    -- Type-specific config
    trigger_interval = 2000,          -- For "time": ms between triggers
    trigger_distance = 200,           -- For "movement": pixels traveled

    test_label = "TRIGGER\non\ncrit",
    -- sprite = "trigger-on-crit.png",
}
```

### Trigger Types

| Type | Description | Config Field |
|------|-------------|--------------|
| `"time"` | Auto-cast every N seconds | `trigger_interval` (ms) |
| `"collision"` | On bump with enemy | - |
| `"dash"` | When player dashes | - |
| `"movement"` | After traveling distance | `trigger_distance` (pixels) |

### Complete Example: Adding a Fire Burst Card

```lua
-- In assets/scripts/data/cards.lua

-- Action: Fire Burst
Cards.ACTION_FIRE_BURST = {
    id = "ACTION_FIRE_BURST",
    type = "action",
    mana_cost = 18,
    damage = 40,
    damage_type = "fire",
    radius_of_effect = 80,            -- Large AoE
    projectile_speed = 300,           -- Slow-moving
    lifetime = 1000,
    cast_delay = 200,
    spread_angle = 0,
    max_uses = -1,
    weight = 3,
    tags = { "Fire", "AoE", "Projectile" },
    test_label = "ACTION\nfire\nburst",
    sprite = "action-fire-burst.png",
}

-- Modifier: Pyroclasm (makes next spell leave fire hazards)
Cards.MOD_PYROCLASM = {
    id = "MOD_PYROCLASM",
    type = "modifier",
    mana_cost = 6,
    damage_modifier = 0,
    leave_hazard = true,              -- Custom field
    hazard_damage = 5,                -- Custom field
    hazard_duration = 3.0,            -- Custom field
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    tags = { "Fire", "Hazard" },
    test_label = "MOD\npyroclasm",
}

-- Trigger: Cast on taking fire damage
TriggerCards.TRIGGER_ON_FIRE_HIT = {
    id = "on_fire_hit",
    type = "trigger",
    mana_cost = 0,
    weight = 0,
    tags = { "Fire", "Defense" },
    description = "Casts spells when you take fire damage",
    trigger_type = "damage_taken",    -- Custom trigger type
    damage_type_filter = "fire",      -- Custom field
    test_label = "TRIGGER\non\nfire\nhit",
}
```

---

## 3. Adding Avatars

Avatars are "Ascensions" - powerful upgrades unlocked during a run. They're defined in `assets/scripts/data/avatars.lua` and managed by `assets/scripts/wand/avatar_system.lua`.

### Step 1: Define the Avatar

Edit `assets/scripts/data/avatars.lua`:

```lua
frostweaver = {
    name = "Avatar of Frost",
    description = "Your ice magic freezes the battlefield.",
    -- sprite = "avatar_frost",  -- Optional custom sprite

    -- Unlock conditions (session-based)
    -- PRIMARY conditions (all must be met) OR alternative conditions (any OR_ met)
    unlock = {
        -- Primary path: achieve both of these
        kills_with_ice = 75,          -- Kill 75 enemies with ice damage
        ice_tags = 5,                 -- Have 5+ Ice tags in your build

        -- OR alternative path: achieve any of these
        OR_ice_tags = 9,              -- Have 9+ Ice tags (instant unlock)
        OR_damage_blocked = 3000,     -- Block 3000 damage total
    },

    -- Effects when avatar is equipped
    effects = {
        -- Rule changes (modify core mechanics)
        {
            type = "rule_change",
            rule = "ice_chains",
            desc = "Ice projectiles chain to nearby enemies on hit."
        },

        -- Stat buffs
        {
            type = "stat_buff",
            stat = "ice_damage_pct",
            value = 25  -- +25% ice damage
        },

        -- Proc effects (triggered abilities)
        {
            type = "proc",
            trigger = "on_kill_ice",       -- Custom trigger
            effect = "freeze_aura",
            radius = 50,
            duration = 1.5
        },

        -- Another proc
        {
            type = "proc",
            trigger = "on_cast_5th",       -- Every 5th cast
            effect = "ice_nova",
            damage = 30,
            radius = 100
        }
    }
}
```

### Step 2: Track Player Progress

The AvatarSystem tracks metrics on the player object:

```lua
local AvatarSystem = require("wand.avatar_system")

-- Set up player data structure
local player = {
    -- Avatar state (managed by AvatarSystem)
    avatar_state = {
        unlocked = {},      -- { avatar_id = true }
        equipped = nil      -- Current equipped avatar ID
    },

    -- Progress metrics (you increment these)
    avatar_progress = {
        kills_with_fire = 0,
        kills_with_ice = 0,
        damage_blocked = 0,
        distance_moved = 0,
        crits_dealt = 0,
        mana_spent = 0,
        hp_lost = 0,
    },

    -- Tag counts (from cards in deck)
    tag_counts = {
        Fire = 3,
        Ice = 7,
        Lightning = 2,
        -- etc.
    }
}
```

### Step 3: Record Progress and Check Unlocks

```lua
local AvatarSystem = require("wand.avatar_system")
local signal = require("external.hump.signal")

-- When player kills an enemy with ice damage:
signal.register("enemy_killed", function(entity, ctx)
    if ctx.damage_type == "ice" then
        -- Record progress and check for unlocks
        local newlyUnlocked = AvatarSystem.record_progress(
            player,
            "kills_with_ice",
            1,  -- increment by 1
            { tag_counts = player.tag_counts }
        )

        -- Handle newly unlocked avatars
        for _, avatarId in ipairs(newlyUnlocked) do
            print("Unlocked avatar: " .. avatarId)
            -- Show unlock notification, etc.
        end
    end
end)

-- Check unlocks manually (e.g., when deck changes)
signal.register("deck_changed", function()
    -- Recount tags
    player.tag_counts = recountTagsFromDeck(player.deck)

    -- Check unlocks with updated tag counts
    local newlyUnlocked = AvatarSystem.check_unlocks(player, {
        tag_counts = player.tag_counts
    })
end)
```

### Step 4: Equip Avatar

```lua
-- When player selects an avatar
function equipAvatar(avatarId)
    local success, err = AvatarSystem.equip(player, avatarId)
    if success then
        print("Equipped: " .. avatarId)
        applyAvatarEffects(player, avatarId)
    else
        print("Cannot equip: " .. tostring(err))
    end
end

-- Get currently equipped avatar
local equipped = AvatarSystem.get_equipped(player)
```

### Step 5: Apply Avatar Effects

You need to implement the effect application based on your game systems:

```lua
local avatarDefs = require("data.avatars")

function applyAvatarEffects(player, avatarId)
    local def = avatarDefs[avatarId]
    if not def or not def.effects then return end

    for _, effect in ipairs(def.effects) do
        if effect.type == "stat_buff" then
            -- Apply stat modification
            player.stats[effect.stat] = (player.stats[effect.stat] or 0) + effect.value

        elseif effect.type == "rule_change" then
            -- Enable rule flag
            player.rules = player.rules or {}
            player.rules[effect.rule] = true

        elseif effect.type == "proc" then
            -- Register proc handler
            registerProcHandler(player, effect)
        end
    end
end
```

### Step 6: Listen for Unlock Events

The AvatarSystem emits signals when avatars are unlocked:

```lua
signal.register("avatar_unlocked", function(data)
    local avatarId = data.avatar_id
    local def = avatarDefs[avatarId]

    -- Show unlock notification
    showNotification("Avatar Unlocked!", def.name, def.description)

    -- Play unlock sound
    playSound("avatar_unlock")
end)
```

---

## 4. Wave Visual Improvements

Currently, `wave_visuals.lua` has placeholder implementations. Here's how to add proper spawn indicators and wave announcements.

### Current State

The telegraph system in `wave_visuals.lua` only prints to console:

```lua
-- Current placeholder (line 26)
print("[WaveVisuals] Telegraph at " .. math.floor(x) .. ", " .. math.floor(y))
```

### Improved wave_visuals.lua

Replace the contents of `assets/scripts/combat/wave_visuals.lua` with:

```lua
-- assets/scripts/combat/wave_visuals.lua
-- Visual feedback handlers for wave system (improved version)

local signal = require("external.hump.signal")
local timer = require("core.timer")
local z_orders = require("core.z_orders")

local WaveVisuals = {}

local active_telegraphs = {}
local current_announcement = nil

--============================================
-- TELEGRAPH MARKERS
--============================================

signal.register("spawn_telegraph", function(data)
    local x = data.x
    local y = data.y
    local duration = data.duration or 1.0
    local enemy_type = data.enemy_type

    local id = "tel_" .. tostring(x) .. "_" .. tostring(y) .. "_" .. tostring(os.clock())
    active_telegraphs[id] = {
        x = x,
        y = y,
        enemy_type = enemy_type,
        start_time = os.clock(),
        duration = duration,
    }

    timer.after(duration, function()
        active_telegraphs[id] = nil
    end, id)
end)

--============================================
-- FLOATING TEXT / ANNOUNCEMENTS
--============================================

signal.register("show_floating_text", function(data)
    local text = data.text
    local style = data.style or "default"

    local styles = {
        wave_announce = {
            fontSize = 48,
            color = Col(255, 255, 255, 255),
            bgColor = Col(20, 20, 40, 200),
            duration = 2.0,
            slideIn = true
        },
        elite_announce = {
            fontSize = 56,
            color = Col(255, 200, 50, 255),
            bgColor = Col(80, 20, 20, 220),
            duration = 2.5,
            shake = true
        },
        stage_complete = {
            fontSize = 52,
            color = Col(100, 255, 100, 255),
            bgColor = Col(20, 60, 20, 200),
            duration = 2.5,
            expand = true
        },
        default = {
            fontSize = 32,
            color = Col(255, 255, 255, 255),
            bgColor = Col(40, 40, 40, 180),
            duration = 1.5
        },
    }

    local cfg = styles[style] or styles.default
    local screenW = globals.screenWidth and globals.screenWidth() or 1920
    local screenH = globals.screenHeight and globals.screenHeight() or 1080

    current_announcement = {
        text = text,
        style = cfg,
        x = screenW / 2,
        y = screenH / 3,
        start_time = os.clock(),
    }

    timer.after(cfg.duration, function()
        current_announcement = nil
    end, "announce_" .. text)
end)

--============================================
-- PARTICLES (placeholder)
--============================================

signal.register("spawn_particles", function(data)
    local effect = data.effect
    local x = data.x
    local y = data.y
    -- Integrate with your particle system
    -- Example: particle_system.spawn(effect, x, y)
end)

--============================================
-- SCREEN SHAKE (placeholder)
--============================================

signal.register("screen_shake", function(data)
    local duration = data.duration or 0.3
    local intensity = data.intensity or 5
    -- Integrate with your camera system
    -- Example: camera.shake(duration, intensity)
end)

--============================================
-- DRAW FUNCTIONS (call these from your game loop)
--============================================

function WaveVisuals.draw()
    WaveVisuals.draw_telegraphs()
    WaveVisuals.draw_announcement()
end

function WaveVisuals.draw_telegraphs()
    if not command_buffer or not layers then return end

    local now = os.clock()
    local worldLayer = layers.world or layers.ui
    local space = layer.DrawCommandSpace.World
    local z = (z_orders and z_orders.effects) or 10

    for id, tel in pairs(active_telegraphs) do
        local elapsed = now - tel.start_time
        local progress = elapsed / tel.duration

        -- Pulsing effect
        local pulse = 1 + math.sin(elapsed * 10) * 0.2
        local radius = 24 * pulse

        -- Fade in urgency as spawn approaches
        local alpha = math.floor(100 + progress * 155)

        -- Color based on enemy type
        local color = Col(255, 100, 100, alpha)  -- Default red
        if tel.enemy_type == "elite" then
            color = Col(255, 200, 50, alpha)     -- Gold for elites
        elseif tel.enemy_type == "summoner" then
            color = Col(150, 100, 255, alpha)    -- Purple for summoners
        end

        -- Draw outer warning circle (pulsing, grows over time)
        command_buffer.queueDrawCircle(worldLayer, function(c)
            c.x = tel.x
            c.y = tel.y
            c.radius = radius * (1.5 + progress * 0.5)
            c.color = Col(color.r, color.g, color.b, math.floor(alpha * 0.3))
            c.filled = false
            c.lineWidth = 2
        end, z, space)

        -- Draw inner filled circle
        command_buffer.queueDrawCircle(worldLayer, function(c)
            c.x = tel.x
            c.y = tel.y
            c.radius = radius
            c.color = Col(color.r, color.g, color.b, math.floor(alpha * 0.5))
            c.filled = true
        end, z + 1, space)

        -- Draw X mark in center
        local half = radius * 0.5
        command_buffer.queueDrawLine(worldLayer, function(c)
            c.x1 = tel.x - half
            c.y1 = tel.y - half
            c.x2 = tel.x + half
            c.y2 = tel.y + half
            c.color = color
            c.lineWidth = 3
        end, z + 2, space)

        command_buffer.queueDrawLine(worldLayer, function(c)
            c.x1 = tel.x + half
            c.y1 = tel.y - half
            c.x2 = tel.x - half
            c.y2 = tel.y + half
            c.color = color
            c.lineWidth = 3
        end, z + 2, space)
    end
end

function WaveVisuals.draw_announcement()
    if not current_announcement then return end
    if not command_buffer or not layers then return end

    local ann = current_announcement
    local style = ann.style
    local elapsed = os.clock() - ann.start_time
    local progress = elapsed / style.duration

    -- Fade in/out
    local alpha = 1.0
    if progress < 0.1 then
        alpha = progress / 0.1  -- Fade in
    elseif progress > 0.8 then
        alpha = (1.0 - progress) / 0.2  -- Fade out
    end

    local space = layer.DrawCommandSpace.Screen
    local z = (z_orders and z_orders.ui_tooltips) or 100

    -- Calculate text dimensions (approximate)
    local textWidth = #ann.text * style.fontSize * 0.5
    local textHeight = style.fontSize
    local padding = 20

    -- Slide-in effect
    local xOffset = 0
    if style.slideIn and progress < 0.15 then
        xOffset = (1 - progress / 0.15) * -200
    end

    -- Shake effect
    local shakeX, shakeY = 0, 0
    if style.shake then
        local shakeIntensity = 5 * (1 - progress)
        shakeX = math.sin(elapsed * 50) * shakeIntensity
        shakeY = math.cos(elapsed * 60) * shakeIntensity
    end

    -- Scale effect
    local scale = 1.0
    if style.expand and progress < 0.2 then
        scale = 0.5 + (progress / 0.2) * 0.5
    end

    -- Background box
    local bgColor = Col(
        style.bgColor.r,
        style.bgColor.g,
        style.bgColor.b,
        math.floor(style.bgColor.a * alpha)
    )

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = ann.x + xOffset + shakeX
        c.y = ann.y + shakeY
        c.w = (textWidth + padding * 2) * scale
        c.h = (textHeight + padding * 2) * scale
        c.rx = 8
        c.ry = 8
        c.color = bgColor
    end, z - 1, space)

    -- Draw text
    local textColor = Col(
        style.color.r,
        style.color.g,
        style.color.b,
        math.floor(255 * alpha)
    )

    local font = localization and localization.getFont and localization.getFont()

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = ann.text
        c.font = font
        c.x = ann.x - (textWidth * scale) / 2 + xOffset + shakeX
        c.y = ann.y - (textHeight * scale) / 2 + shakeY
        c.color = textColor
        c.fontSize = math.floor(style.fontSize * scale)
    end, z, space)
end

--============================================
-- OFFSCREEN INDICATORS
--============================================

function WaveVisuals.draw_offscreen_indicators()
    if not command_buffer or not layers then return end

    local screenW = globals.screenWidth and globals.screenWidth() or 1920
    local screenH = globals.screenHeight and globals.screenHeight() or 1080
    local margin = 50
    local space = layer.DrawCommandSpace.Screen
    local z = (z_orders and z_orders.effects) or 10

    -- Get camera offset if you have a camera system
    local camX, camY = 0, 0
    if camera and camera.getPosition then
        camX, camY = camera.getPosition()
    end

    for id, tel in pairs(active_telegraphs) do
        -- Convert world position to screen
        local screenX = tel.x - camX
        local screenY = tel.y - camY

        -- Check if off-screen
        local isOffscreen = screenX < margin or screenX > screenW - margin or
                           screenY < margin or screenY > screenH - margin

        if isOffscreen then
            -- Clamp to screen edge
            local edgeX = math.max(margin, math.min(screenW - margin, screenX))
            local edgeY = math.max(margin, math.min(screenH - margin, screenY))

            -- Calculate direction
            local dx = screenX - edgeX
            local dy = screenY - edgeY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 0 then
                dx, dy = dx / dist, dy / dist
            end

            local elapsed = os.clock() - tel.start_time
            local pulse = 1 + math.sin(elapsed * 8) * 0.2
            local arrowSize = 20 * pulse

            local color = tel.enemy_type == "elite"
                and Col(255, 200, 50, 200)
                or Col(255, 100, 100, 200)

            -- Draw arrow pointing toward spawn
            local angle = math.atan2(dy, dx)
            local tipX = edgeX + dx * arrowSize
            local tipY = edgeY + dy * arrowSize
            local leftX = edgeX + math.cos(angle + 2.5) * arrowSize * 0.6
            local leftY = edgeY + math.sin(angle + 2.5) * arrowSize * 0.6
            local rightX = edgeX + math.cos(angle - 2.5) * arrowSize * 0.6
            local rightY = edgeY + math.sin(angle - 2.5) * arrowSize * 0.6

            -- Draw triangle
            command_buffer.queueDrawTriangle(layers.ui, function(c)
                c.x1 = tipX
                c.y1 = tipY
                c.x2 = leftX
                c.y2 = leftY
                c.x3 = rightX
                c.y3 = rightY
                c.color = color
                c.filled = true
            end, z + 5, space)
        end
    end
end

--============================================
-- INIT
--============================================

function WaveVisuals.init()
    print("WaveVisuals initialized with visual feedback")
end

return WaveVisuals
```

### Integration

Call the draw function from your game loop:

```lua
-- In your game's draw function (during ACTION_STATE)
local WaveVisuals = require("combat.wave_visuals")

function drawGameWorld()
    -- ... other draw code ...

    -- Draw wave visual effects
    WaveVisuals.draw()
    WaveVisuals.draw_offscreen_indicators()  -- Optional
end
```

---

## Quick Reference Summary

| System | Data File | Manager | UI Display |
|--------|-----------|---------|------------|
| **Jokers** | `data/jokers.lua` | `wand/joker_system.lua` | `ui/avatar_joker_strip.lua` |
| **Cards** | `data/cards.lua` | Combat system | Card UI |
| **Avatars** | `data/avatars.lua` | `wand/avatar_system.lua` | `ui/avatar_joker_strip.lua` |
| **Waves** | Stage configs | `combat/wave_director.lua` | `combat/wave_visuals.lua` |

### File Locations

```
assets/scripts/
├── data/
│   ├── jokers.lua          # Joker definitions
│   ├── cards.lua           # Card definitions (Action, Modifier, Trigger)
│   ├── avatars.lua         # Avatar definitions with unlock conditions
│   ├── enemies.lua         # Enemy definitions
│   └── elite_modifiers.lua # Elite modifier definitions
├── wand/
│   ├── joker_system.lua    # Joker management
│   └── avatar_system.lua   # Avatar unlock/equip management
├── combat/
│   ├── wave_system.lua     # Main wave system entry point
│   ├── wave_director.lua   # Wave orchestration
│   ├── wave_visuals.lua    # Visual feedback (telegraphs, announcements)
│   ├── wave_helpers.lua    # Helper functions for enemy AI
│   └── enemy_factory.lua   # Enemy creation
└── ui/
    └── avatar_joker_strip.lua  # Displays avatars and jokers
```
