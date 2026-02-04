-- Serpent Game Main Module
-- Handles the main game loop and state management for the Serpent minigame

-- Mock log functions for environments that don't have them
local log_debug = log_debug or function(msg) end
local log_error = log_error or function(msg) end
local log_warning = log_warning or function(msg) end

local serpent_main = serpent_main or {}
local snake_entity_adapter = require("serpent.snake_entity_adapter")
local contact_collector_adapter = require("serpent.contact_collector_adapter")
local C = require("core.constants")

-- MODE_STATE enum for the Serpent game state machine
MODE_STATE = {
    SHOP = 0,
    COMBAT = 1,
    VICTORY = 2,
    GAME_OVER = 3
}

-- Current game state
local currentMode = MODE_STATE.SHOP

-- Physics callback registration (global, once only)
local physics_callbacks_registered = false

-- Game initialization
function serpent_main.init()
    log_debug("[Serpent] Initializing serpent game...")

    -- Reset to initial state
    currentMode = MODE_STATE.SHOP

    -- Register physics callbacks once globally
    if not physics_callbacks_registered then
        register_physics_callbacks()
        physics_callbacks_registered = true
    end

    -- Initialize snake entity adapter
    snake_entity_adapter.init()

    -- Initialize contact collector adapter and set as global
    contact_collector_adapter.init()
    _G.serpent_contact_collector = contact_collector_adapter

    -- Spawn test segment entities to verify SERPENT_SEGMENT tagging
    spawn_test_segments()

    -- TODO: Initialize game systems
    -- - Shop UI
    -- - Player stats
    -- - Combat system
    -- - Game world

    log_debug("[Serpent] Serpent game initialized in SHOP mode")
end

-- Game update loop
function serpent_main.update(dt)
    -- Update based on current mode state
    if currentMode == MODE_STATE.SHOP then
        updateShopMode(dt)
    elseif currentMode == MODE_STATE.COMBAT then
        updateCombatMode(dt)
    elseif currentMode == MODE_STATE.VICTORY then
        updateVictoryMode(dt)
    elseif currentMode == MODE_STATE.GAME_OVER then
        updateGameOverMode(dt)
    end
end

-- Game cleanup
function serpent_main.cleanup()
    log_debug("[Serpent] Cleaning up serpent game...")

    -- Cleanup snake entity adapter (despawns all segment entities)
    snake_entity_adapter.cleanup()

    -- Cleanup contact collector adapter
    if _G.serpent_contact_collector then
        _G.serpent_contact_collector.cleanup()
        _G.serpent_contact_collector = nil
    end

    -- Cleanup all serpent timers
    local timer = timer or require("core.timer")
    if timer and timer.kill_group then
        timer.kill_group(C.TimerGroups.SERPENT)
    end

    -- TODO: Cleanup game systems
    -- - Destroy entities
    -- - Clear timers
    -- - Release resources
    -- - Reset state

    currentMode = MODE_STATE.SHOP

    log_debug("[Serpent] Serpent game cleanup complete")
end

-- State management function (prefer using transition functions)
function serpent_main.setMode(newMode)
    if newMode ~= currentMode then
        if serpent_main.isValidTransition(currentMode, newMode) then
            log_debug(string.format("[Serpent] Mode change: %d -> %d", currentMode, newMode))
            currentMode = newMode
        else
            log_debug(string.format("[Serpent] Invalid mode transition: %d -> %d", currentMode, newMode))
            return false
        end
    end
    return true
end

-- Check if transition is valid according to state machine rules
function serpent_main.isValidTransition(fromMode, toMode)
    -- Any state can transition to GAME_OVER
    if toMode == MODE_STATE.GAME_OVER then
        return true
    end

    -- SHOP can transition to COMBAT
    if fromMode == MODE_STATE.SHOP and toMode == MODE_STATE.COMBAT then
        return true
    end

    -- COMBAT can transition to VICTORY or SHOP
    if fromMode == MODE_STATE.COMBAT and (toMode == MODE_STATE.VICTORY or toMode == MODE_STATE.SHOP) then
        return true
    end

    -- VICTORY can transition to SHOP
    if fromMode == MODE_STATE.VICTORY and toMode == MODE_STATE.SHOP then
        return true
    end

    return false
end

function serpent_main.getMode()
    return currentMode
end

-- State machine transition functions
function serpent_main.transitionToCombat()
    if currentMode == MODE_STATE.SHOP then
        log_debug("[Serpent] Transitioning from SHOP to COMBAT")
        currentMode = MODE_STATE.COMBAT
        -- TODO: Initialize combat
        -- - Spawn enemies
        -- - Set up combat UI
        -- - Initialize player combat state
        return true
    else
        log_debug(string.format("[Serpent] Invalid transition to COMBAT from mode %d", currentMode))
        return false
    end
end

function serpent_main.transitionToShop()
    if currentMode == MODE_STATE.COMBAT or currentMode == MODE_STATE.VICTORY then
        log_debug(string.format("[Serpent] Transitioning from mode %d to SHOP", currentMode))
        currentMode = MODE_STATE.SHOP
        -- TODO: Reset shop state
        -- - Update player resources
        -- - Refresh shop inventory
        -- - Show shop UI
        return true
    else
        log_debug(string.format("[Serpent] Invalid transition to SHOP from mode %d", currentMode))
        return false
    end
end

function serpent_main.transitionToVictory()
    if currentMode == MODE_STATE.COMBAT then
        log_debug("[Serpent] Transitioning from COMBAT to VICTORY")
        currentMode = MODE_STATE.VICTORY
        -- TODO: Handle victory
        -- - Calculate rewards
        -- - Show victory screen
        -- - Update player progress
        return true
    else
        log_debug(string.format("[Serpent] Invalid transition to VICTORY from mode %d", currentMode))
        return false
    end
end

function serpent_main.transitionToGameOver()
    log_debug(string.format("[Serpent] Transitioning from mode %d to GAME_OVER", currentMode))
    currentMode = MODE_STATE.GAME_OVER
    -- TODO: Handle game over
    -- - Save high score
    -- - Show game over screen
    -- - Prepare restart options
    return true
end

-- Mode-specific update functions
function updateShopMode(dt)
    -- TODO: Update shop logic
    -- - Handle shop UI
    -- - Process purchases
    -- - Manage inventory
end

function updateCombatMode(dt)
    -- TODO: Update combat logic
    -- - Handle player input
    -- - Update enemies
    -- - Process combat mechanics
    -- - Check win/lose conditions
end

function updateVictoryMode(dt)
    -- TODO: Update victory state
    -- - Display victory UI
    -- - Handle rewards
    -- - Transition to next level or shop
end

function updateGameOverMode(dt)
    -- TODO: Update game over state
    -- - Display game over UI
    -- - Handle restart/quit options
    -- - Reset game state if needed
end

-- Test function to spawn segment entities with SERPENT_SEGMENT tags
function spawn_test_segments()
    log_debug("[Serpent] Spawning test segment entities...")

    -- Create a simple 3-segment snake for testing
    local segments = {
        { instance_id = 1, x = 300, y = 200, radius = 16 },  -- Head segment
        { instance_id = 2, x = 280, y = 200, radius = 16 },  -- Body segment
        { instance_id = 3, x = 260, y = 200, radius = 16 },  -- Tail segment
    }

    for _, segment in ipairs(segments) do
        local entity_id = snake_entity_adapter.spawn_segment(
            segment.instance_id,
            segment.x,
            segment.y,
            segment.radius
        )

        log_debug(string.format("[Serpent] Test segment spawned: instance_id=%d, entity_id=%d, pos=(%.1f,%.1f)",
                                segment.instance_id, entity_id, segment.x, segment.y))
    end

    log_debug("[Serpent] Test segment spawning complete")
end

-- Register physics collision callbacks globally for Serpent game
function register_physics_callbacks()
    log_debug("[Serpent] Registering physics callbacks...")

    -- Get the main physics world
    local world = PhysicsManager and PhysicsManager.get_world and PhysicsManager.get_world("world")
    if not world then
        log_error("[Serpent] Failed to get physics world for callback registration")
        return
    end

    -- Add SERPENT_SEGMENT collision tag if not already present
    if not C.CollisionTags.SERPENT_SEGMENT then
        physics.AddCollisionTag("SERPENT_SEGMENT")
        C.CollisionTags.SERPENT_SEGMENT = "SERPENT_SEGMENT"
        log_debug("[Serpent] Added SERPENT_SEGMENT collision tag")
    end

    -- Enable collision between SERPENT_SEGMENT and ENEMY tags
    if C.CollisionTags.ENEMY and C.CollisionTags.SERPENT_SEGMENT then
        physics.enable_collision_between(C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY)
        log_debug("[Serpent] Enabled collision between SERPENT_SEGMENT and ENEMY")
    else
        log_warning("[Serpent] Could not enable collision - missing collision tags")
    end

    -- Register collision begin callback between serpent segments and enemies
    physics.on_pair_begin(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, function(arb)
        log_debug("[Serpent] Collision begin: serpent segment hit enemy")

        local entity_a, entity_b = arb:entities()

        -- Create contact event for the contact collector system
        local contact_event = {
            type = "collision_begin",
            entity_a = entity_a,
            entity_b = entity_b,
            timestamp = love.timer.getTime()
        }

        -- TODO: Integrate with contact_collector.process_contacts()
        -- This will be handled by the combat system which has access to the collector state

        log_debug(string.format("[Serpent] Contact begin: entity_a=%d, entity_b=%d", entity_a, entity_b))
    end)

    -- Register collision separate callback between serpent segments and enemies
    physics.on_pair_separate(world, C.CollisionTags.SERPENT_SEGMENT, C.CollisionTags.ENEMY, function(arb)
        log_debug("[Serpent] Collision separate: serpent segment separated from enemy")

        local entity_a, entity_b = arb:entities()

        -- Create contact event for tracking separation
        local contact_event = {
            type = "collision_separate",
            entity_a = entity_a,
            entity_b = entity_b,
            timestamp = love.timer.getTime()
        }

        log_debug(string.format("[Serpent] Contact separate: entity_a=%d, entity_b=%d", entity_a, entity_b))
    end)

    log_debug("[Serpent] Physics callbacks registered successfully")
end

return serpent_main