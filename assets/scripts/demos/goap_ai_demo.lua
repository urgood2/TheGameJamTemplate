--[[
================================================================================
GOAP AI DEMO - Comprehensive demonstration of GOAP AI System Improvements
================================================================================
Phase 1.3 of GOAP AI System Improvement Plan.

This demo showcases:
- Goal selection with competing priorities (bands)
- Plan building and action execution
- Trace buffer logging (visible in AI Inspector)
- Worldstate atoms and goal state matching
- Reactive replanning when worldstate changes

Usage:
    local GOAPDemo = require("demos.goap_ai_demo")
    GOAPDemo.start()   -- Start the demo
    GOAPDemo.stop()    -- Stop the demo and cleanup
]]

local GOAPDemo = {}

-- Dependencies
local timer = require("core.timer")
local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local AIInspector = require("ui.ai_inspector")

-- Demo state
local state = {
    active = false,
    entities = {},
    ui_elements = {},
    timers = {},
}

local DEMO_TIMER_GROUP = "goap_demo"

--------------------------------------------------------------------------------
-- ENTITY CREATION
--------------------------------------------------------------------------------

local function createDemoBot(x, y, name)
    -- Use the gold_digger type (existing well-tested type)
    -- This demonstrates the GOAP AI Inspector and trace buffer features
    local eid = create_ai_entity("gold_digger")

    if not eid or eid == entt_null then
        log_warn("[GOAP Demo] Failed to create demo bot")
        return nil
    end

    log_debug("[GOAP Demo] Created entity:", eid, "- setting up visuals...")

    -- Set up animation using a distinctive sprite
    animation_system.setupAnimatedObjectOnEntity(
        eid,
        "frame0012.png", -- Use a simple sprite
        true, -- use sprite identifier
        nil,
        true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(eid, 48, 48)

    -- Position the entity
    local transform = component_cache.get(eid, Transform)
    if transform then
        transform.actualX = x
        transform.actualY = y
        transform.visualX = x
        transform.visualY = y
    end

    -- Store reference
    state.entities[name] = {
        ai_eid = eid,
        name = name
    }

    log_debug("[GOAP Demo] Created demo bot:", name, "at", x, y, "entity:", eid)
    return eid
end

--------------------------------------------------------------------------------
-- WORLDSTATE MANIPULATION (for demo controls)
-- Uses gold_digger atoms: hungry, enemyvisible, resourceAvailable, underAttack, candigforgold
--------------------------------------------------------------------------------

local function triggerUnderAttack(eid)
    if not eid or not registry:valid(eid) then return end
    log_debug("[GOAP Demo] Setting underAttack=true for entity", eid)
    ai.patch_worldstate(eid, "underAttack", true)
    ai.patch_worldstate(eid, "enemyvisible", true)
    -- AI system automatically detects worldstate changes on next tick
end

local function triggerHungry(eid)
    if not eid or not registry:valid(eid) then return end
    log_debug("[GOAP Demo] Setting hungry=true for entity", eid)
    ai.patch_worldstate(eid, "hungry", true)
    -- AI system automatically detects worldstate changes on next tick
end

local function enableDigging(eid)
    if not eid or not registry:valid(eid) then return end
    log_debug("[GOAP Demo] Setting candigforgold=true for entity", eid)
    ai.patch_worldstate(eid, "candigforgold", true)
    -- AI system automatically detects worldstate changes on next tick
end

local function clearStates(eid)
    if not eid or not registry:valid(eid) then return end
    log_debug("[GOAP Demo] Clearing states for entity", eid)
    ai.patch_worldstate(eid, "underAttack", false)
    ai.patch_worldstate(eid, "enemyvisible", false)
    -- AI system automatically detects worldstate changes on next tick
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

local function createControlPanel()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Get first demo entity for controls
    local firstBot = nil
    for _, bot in pairs(state.entities) do
        firstBot = bot
        break
    end

    local controlDef = dsl.strict.root {
        config = {
            color = util.getColor("blackberry"),
            padding = 12,
            emboss = 3,
            shadow = true,
        },
        children = {
            dsl.strict.vbox {
                config = { padding = 8 },
                children = {
                    dsl.strict.text("GOAP AI Demo", {
                        fontSize = 20,
                        color = "cyan",
                        shadow = true
                    }),
                    dsl.strict.spacer(8),
                    dsl.strict.text("Controls:", {
                        fontSize = 14,
                        color = "white"
                    }),
                    dsl.strict.spacer(8),

                    -- Trigger Under Attack button
                    dsl.strict.button("Set Under Attack", {
                        fontSize = 12,
                        color = "indian_red",
                        textColor = "white",
                        minWidth = 200,
                        onClick = function()
                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                            for _, bot in pairs(state.entities) do
                                triggerUnderAttack(bot.ai_eid)
                            end
                        end
                    }),
                    dsl.strict.spacer(4),

                    -- Trigger Hungry button
                    dsl.strict.button("Set Hungry", {
                        fontSize = 12,
                        color = "goldenrod",
                        textColor = "white",
                        minWidth = 200,
                        onClick = function()
                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                            for _, bot in pairs(state.entities) do
                                triggerHungry(bot.ai_eid)
                            end
                        end
                    }),
                    dsl.strict.spacer(4),

                    -- Enable Digging button
                    dsl.strict.button("Enable Digging", {
                        fontSize = 12,
                        color = "green_jade",
                        textColor = "white",
                        minWidth = 200,
                        onClick = function()
                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                            for _, bot in pairs(state.entities) do
                                enableDigging(bot.ai_eid)
                            end
                        end
                    }),
                    dsl.strict.spacer(4),

                    -- Clear States button
                    dsl.strict.button("Clear Threats", {
                        fontSize = 12,
                        color = "purple_slate",
                        textColor = "white",
                        minWidth = 200,
                        onClick = function()
                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                            for _, bot in pairs(state.entities) do
                                clearStates(bot.ai_eid)
                            end
                        end
                    }),
                    dsl.strict.spacer(12),

                    -- Info text
                    dsl.strict.text("Worldstate atoms:", {
                        fontSize = 12,
                        color = "gray_light"
                    }),
                    dsl.strict.text("hungry, candigforgold, underAttack", {
                        fontSize = 10,
                        color = "cyan"
                    }),
                    dsl.strict.spacer(8),

                    -- Close button
                    dsl.strict.button("Close Demo", {
                        fontSize = 12,
                        color = "purple_slate",
                        textColor = "white",
                        minWidth = 200,
                        onClick = function()
                            if playSoundEffect then playSoundEffect("effects", "button-click") end
                            GOAPDemo.stop()
                        end
                    }),
                }
            }
        }
    }

    state.ui_elements.control_panel = dsl.spawn(
        { x = 20, y = 100 },
        controlDef,
        "ui",
        200
    )
    ui.box.set_draw_layer(state.ui_elements.control_panel, "ui")

    log_debug("[GOAP Demo] Control panel created")
end

local function createInfoPanel()
    local screenW = globals.screenWidth()

    local infoDef = dsl.strict.root {
        config = {
            color = util.getColor("dark_lavender"),
            padding = 10,
            emboss = 2,
        },
        children = {
            dsl.strict.vbox {
                config = { padding = 4 },
                children = {
                    dsl.strict.text("AI Inspector shows:", {
                        fontSize = 12,
                        color = "white"
                    }),
                    dsl.strict.text("- State: Current goal, retries", {
                        fontSize = 10,
                        color = "gray_light"
                    }),
                    dsl.strict.text("- Plan: Action queue", {
                        fontSize = 10,
                        color = "gray_light"
                    }),
                    dsl.strict.text("- Atoms: Worldstate values", {
                        fontSize = 10,
                        color = "gray_light"
                    }),
                    dsl.strict.text("- Trace: Event history", {
                        fontSize = 10,
                        color = "gray_light"
                    }),
                }
            }
        }
    }

    state.ui_elements.info_panel = dsl.spawn(
        { x = 20, y = 420 },
        infoDef,
        "ui",
        200
    )
    ui.box.set_draw_layer(state.ui_elements.info_panel, "ui")
end

--------------------------------------------------------------------------------
-- DEMO LIFECYCLE
--------------------------------------------------------------------------------

function GOAPDemo.start()
    if state.active then
        log_warn("[GOAP Demo] Demo already active")
        return
    end

    log_debug("[GOAP Demo] Starting GOAP AI demonstration...")
    state.active = true

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Create demo entities in center of screen
    local centerX = screenW / 2
    local centerY = screenH / 2 - 50

    createDemoBot(centerX - 80, centerY, "Bot1")
    createDemoBot(centerX + 80, centerY, "Bot2")

    -- Create UI
    createControlPanel()
    createInfoPanel()

    -- Open AI Inspector and select first entity
    AIInspector.open()
    for _, bot in pairs(state.entities) do
        AIInspector.set_target(bot.ai_eid)
        break
    end

    -- Periodic worldstate randomization for demo variety (every 6 seconds)
    timer.every(
        6.0,
        function()
            if not state.active then return end

            -- Randomly trigger events for demo
            local rand = math.random()
            for _, bot in pairs(state.entities) do
                if rand < 0.25 then
                    log_debug("[GOAP Demo] Timer: Triggering underAttack")
                    triggerUnderAttack(bot.ai_eid)
                elseif rand < 0.5 then
                    log_debug("[GOAP Demo] Timer: Triggering hungry")
                    triggerHungry(bot.ai_eid)
                elseif rand < 0.75 then
                    log_debug("[GOAP Demo] Timer: Enabling digging")
                    enableDigging(bot.ai_eid)
                else
                    log_debug("[GOAP Demo] Timer: Clearing states")
                    clearStates(bot.ai_eid)
                end
            end
        end,
        0, -- infinite
        false, -- don't start immediately
        nil,
        "goap_demo_random_events",
        DEMO_TIMER_GROUP
    )

    log_debug("[GOAP Demo] Demo started successfully")
end

function GOAPDemo.stop()
    if not state.active then
        log_warn("[GOAP Demo] Demo not active")
        return
    end

    log_debug("[GOAP Demo] Stopping GOAP AI demonstration...")

    -- Close AI Inspector
    AIInspector.close()

    -- Kill timers
    timer.kill_group(DEMO_TIMER_GROUP)

    -- Destroy entities
    for name, bot in pairs(state.entities) do
        if bot.ai_eid and registry:valid(bot.ai_eid) then
            registry:destroy(bot.ai_eid)
        end
    end
    state.entities = {}

    -- Destroy UI
    for name, element in pairs(state.ui_elements) do
        if element and registry:valid(element) then
            ui.box.Remove(registry, element)
        end
    end
    state.ui_elements = {}

    state.active = false
    log_debug("[GOAP Demo] Demo stopped")
end

function GOAPDemo.isActive()
    return state.active
end

function GOAPDemo.toggle()
    if state.active then
        GOAPDemo.stop()
    else
        GOAPDemo.start()
    end
end

return GOAPDemo
