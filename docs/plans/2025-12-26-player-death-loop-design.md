# Player Death Loop Design

**Date:** 2025-12-26
**Status:** Ready for Implementation

## Overview

Implement player death animation, death screen UI, and full game reset to planning phase with starting resources.

## Flow

```
Player HP reaches 0
       ↓
is_player_alive() returns false
       ↓
COMBAT → DEFEAT state (existing)
       ↓
Blood particles + Player dissolve animation (~1.5s)
       ↓
DEFEAT → GAME_OVER state (existing)
       ↓
Death screen overlay appears ("YOU DIED" + "Try Again")
       ↓
Player clicks "Try Again"
       ↓
Fade to black (~0.5s)
       ↓
Reset all game state to starting values
       ↓
Fade in to Planning Phase
```

## Components

### 1. Death Animation

- **Blood particles** using ParticleBuilder at player position
- **Dissolve shader** on player sprite (0 → 1 over 1.5s)
- Triggered via `signal.emit("player_died", playerEntity)`

### 2. Death Screen UI

- Uses Text Builder (not DSL)
- "YOU DIED" in red, large font (64px)
- "Try Again" clickable text below (32px)
- Dark overlay background
- Clicking "Try Again" emits `signal.emit("restart_game")`

### 3. Game State Reset

Full roguelike reset - everything returns to starting state:

| What | Reset To |
|------|----------|
| Player health | Full |
| Currency | 30 |
| Player level | 1 |
| Cards on boards | Cleared |
| Deck/inventory | Starting cards only |
| Jokers | Removed |
| Artifacts/relics | Starting relic only (`proto_umbrella`) |
| Wave progress | Wave 1 |
| Enemies/projectiles | Destroyed |

### 4. Signal Flow

```lua
-- combat_state_machine.lua enter_defeat()
signal.emit("player_died", playerEntity)

-- combat_state_machine.lua enter_game_over()
signal.emit("show_death_screen")

-- death_screen.lua "Try Again" click
signal.emit("restart_game")
```

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `assets/scripts/ui/death_screen.lua` | Create | Text Builder death UI |
| `assets/scripts/core/gameplay.lua` | Modify | Reset function, death animation, signal handlers, blood particles |
| `assets/scripts/combat/combat_state_machine.lua` | Modify | Emit signals in defeat/game_over states |
| `assets/scripts/combat/combat_loop_integration.lua` | Modify | Implement `handle_game_over()` |

## Implementation Notes

### Death Animation Function

```lua
function playPlayerDeathAnimation(playerEntity, onComplete)
    local ShaderBuilder = require("core.shader_builder")

    ShaderBuilder.for_entity(playerEntity)
        :add("dissolve", { dissolve = 0.0 })
        :apply()

    local timer = require("core.timer")
    local duration = 1.5
    local elapsed = 0

    timer.every_opts({
        delay = 0.016,
        action = function()
            elapsed = elapsed + 0.016
            local progress = math.min(elapsed / duration, 1.0)
            setShaderUniform(playerEntity, "dissolve", "dissolve", progress)

            if progress >= 1.0 then
                if onComplete then onComplete() end
                return false
            end
        end,
        tag = "player_death_dissolve"
    })
end
```

### Reset Function

```lua
function resetGameToStart()
    -- 1. Stop active timers
    timer.kill_group("combat")
    timer.kill_group("player_death_dissolve")

    -- 2. Clear all cards from boards
    clearAllBoards()

    -- 3. Reset globals
    globals.currency = 30
    globals.shopState.playerLevel = 1
    globals.shopState.ownedRelics = { "proto_umbrella" }

    -- 4. Clear jokers
    if JokerSystem then JokerSystem.clear_all() end

    -- 5. Reset player combat stats
    if playerScript and playerScript.combatTable then
        local hero = playerScript.combatTable
        hero.hp = hero.max_health
    end

    -- 6. Reset wave progress
    globals.currentWave = 1

    -- 7. Clean up combat entities
    cleanupCombatEntities()

    -- 8. Reinitialize planning phase
    startPlanningPhase()

    -- 9. Spawn starting deck
    spawnStartingDeck()
end
```

## Testing

1. Reduce player HP to 0 manually or let enemy kill player
2. Verify dissolve animation plays with blood particles
3. Verify death screen appears after animation
4. Click "Try Again" and verify:
   - Fade to black occurs
   - Planning phase loads
   - Currency is 30
   - No cards on boards
   - Starting deck spawned
   - Wave counter shows 1
