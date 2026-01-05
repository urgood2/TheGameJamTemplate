--[[
================================================================================
LIGHTING DEMO - Interactive Feature Showcase
================================================================================
Demonstrates ALL Lighting system features with sequential tests.

Usage:
    local LightingDemo = require("demos.lighting_demo")
    LightingDemo.start()    -- Start the demo
    LightingDemo.stop()     -- Stop and cleanup

Press keys during demo:
    1-6: Jump to specific test
    SPACE: Skip to next test
    ESC: Stop demo
]]

local LightingDemo = {}

local Lighting = require("core.lighting")
local timer = require("core.timer")
local Text = require("core.text")
local EntityBuilder = require("core.entity_builder")
local component_cache = require("core.component_cache")

-- Get Transform component type (C++ binding)
local Transform = _G.Transform

-- Demo state
local _active = false
local _currentTest = 0
local _testEntities = {}
local _lights = {}
local _demoTag = "lighting_demo"
local TIMER_GROUP = "lighting_demo"

-- Screen helpers
local function screenW()
    return globals and globals.screenWidth and globals.screenWidth() or 1920
end

local function screenH()
    return globals and globals.screenHeight and globals.screenHeight() or 1080
end

local function centerX() return screenW() * 0.5 end
local function centerY() return screenH() * 0.5 end

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

-- Show a label at top of screen
local function showLabel(text, duration)
    duration = duration or 3.0
    Text.define()
        :content(string.format("[%s](color=gold)", text))
        :size(28)
        :anchor("center")
        :space("screen")
        :lifespan(duration)
        :spawn()
        :at(centerX(), 40)
        :tag(_demoTag)
end

-- Show sub-label below main label
local function showSubLabel(text, duration)
    duration = duration or 3.0
    Text.define()
        :content(string.format("[%s](color=white)", text))
        :size(18)
        :anchor("center")
        :space("screen")
        :lifespan(duration)
        :spawn()
        :at(centerX(), 75)
        :tag(_demoTag)
end

-- Create a simple test entity (sprite)
local function createTestEntity(x, y, sprite)
    sprite = sprite or "enemy_type_1.png"
    local entity = EntityBuilder.simple(sprite, x, y, 64, 64)
    table.insert(_testEntities, entity)
    return entity
end

-- Cleanup all test entities and lights
local function cleanup()
    -- Destroy all lights
    for _, light in ipairs(_lights) do
        if light and light:isValid() then
            light:destroy()
        end
    end
    _lights = {}
    
    -- Destroy all test entities
    for _, entity in ipairs(_testEntities) do
        if registry:valid(entity) then
            registry:destroy(entity)
        end
    end
    _testEntities = {}
    
    -- Kill timers
    timer.kill_group(TIMER_GROUP)
    
    -- Disable lighting on layer
    if Lighting.isEnabled("sprites") then
        Lighting.disable("sprites")
    end
end

--------------------------------------------------------------------------------
-- TEST DEFINITIONS
--------------------------------------------------------------------------------

local tests = {}

-- Test 1: Point light at fixed position
tests[1] = {
    name = "Point Light (Fixed Position)",
    desc = "Static point light in center of screen",
    duration = 4,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.1)
        
        local light = Lighting.point()
            :at(centerX(), centerY())
            :radius(200)
            :intensity(1.0)
            :color("orange")
            :create()
        table.insert(_lights, light)
    end
}

-- Test 2: Point light attached to moving entity
tests[2] = {
    name = "Point Light (Attached to Entity)",
    desc = "Light follows a moving entity",
    duration = 5,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.15)
        
        -- Create entity
        local entity = createTestEntity(centerX(), centerY(), "enemy_type_1.png")
        
        -- Attach light
        local light = Lighting.point()
            :attachTo(entity)
            :radius(180)
            :intensity(1.0)
            :color("cyan")
            :create()
        table.insert(_lights, light)
        
        -- Animate entity movement in a circle
        local startTime = GetTime()
        timer.every_opts({
            delay = 0.016,
            action = function()
                if not registry:valid(entity) then return end
                local t = GetTime() - startTime
                local transform = component_cache.get(entity, Transform)
                if transform then
                    transform.actualX = centerX() + math.cos(t * 2) * 150
                    transform.actualY = centerY() + math.sin(t * 2) * 100
                end
            end,
            tag = "entity_move",
            group = TIMER_GROUP
        })
    end
}

-- Test 3: Spotlight with direction
tests[3] = {
    name = "Spotlight with Direction",
    desc = "Cone-shaped light rotating around center",
    duration = 5,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.05)
        
        local spot = Lighting.spot()
            :at(centerX(), centerY())
            :direction(0)
            :angle(35)
            :radius(350)
            :intensity(1.0)
            :color("white")
            :create()
        table.insert(_lights, spot)
        

    end
}

-- Test 4: Subtractive vs Additive blend modes
tests[4] = {
    name = "Blend Modes: Subtractive vs Additive",
    desc = "Left: Subtractive (reveals), Right: Additive (glows)",
    duration = 5,
    run = function()
        -- Use subtractive mode on layer
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.1)
        
        -- Left: normal subtractive light
        local subLight = Lighting.point()
            :at(centerX() - 200, centerY())
            :radius(150)
            :intensity(1.0)
            :color("white")
            :create()
        table.insert(_lights, subLight)
        
        -- Right: force additive (glowing effect)
        local addLight = Lighting.point()
            :at(centerX() + 200, centerY())
            :radius(150)
            :intensity(0.8)
            :color("cyan")
            :additive()
            :create()
        table.insert(_lights, addLight)
        
        -- Labels
        Text.define()
            :content("[Subtractive](color=yellow)")
            :size(16):anchor("center"):space("screen"):lifespan(4.5)
            :spawn():at(centerX() - 200, centerY() - 100):tag(_demoTag)
        Text.define()
            :content("[Additive](color=cyan)")
            :size(16):anchor("center"):space("screen"):lifespan(4.5)
            :spawn():at(centerX() + 200, centerY() - 100):tag(_demoTag)
    end
}

-- Test 5: Multiple lights (up to 16)
tests[5] = {
    name = "16 Simultaneous Lights",
    desc = "Testing max light count with colored ring",
    duration = 6,
    run = function()
        Lighting.enable("sprites", { mode = "additive" })
        
        local colors = { "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink" }
        
        for i = 1, 16 do
            local angle = (i - 1) * (360 / 16)
            local rad = math.rad(angle)
            local x = centerX() + math.cos(rad) * 250
            local y = centerY() + math.sin(rad) * 180
            local color = colors[(i - 1) % #colors + 1]
            
            local light = Lighting.point()
                :at(x, y)
                :radius(80)
                :intensity(0.7)
                :color(color)
                :create()
            table.insert(_lights, light)
        end
        
        -- Show count
        Text.define()
            :content("[16 lights active](color=green)")
            :size(20):anchor("center"):space("screen"):lifespan(5.5)
            :spawn():at(centerX(), centerY()):tag(_demoTag)
    end
}

-- Test 6: 17th light overflow warning
tests[6] = {
    name = "17th Light (Overflow Test)",
    desc = "Should log warning when exceeding 16 lights",
    duration = 4,
    run = function()
        Lighting.enable("sprites", { mode = "additive" })
        
        -- Create 17 lights
        for i = 1, 17 do
            local x = 100 + (i - 1) * 100
            local y = centerY()
            
            local light = Lighting.point()
                :at(x, y)
                :radius(40)
                :intensity(0.8)
                :color("white")
                :create()
            table.insert(_lights, light)
        end
        
        Text.define()
            :content("[Check console for overflow warning!](color=red)")
            :size(20):anchor("center"):space("screen"):lifespan(3.5)
            :spawn():at(centerX(), centerY() - 50):tag(_demoTag)
    end
}

-- Test 7: Entity destruction cleanup
tests[7] = {
    name = "Entity Destruction Cleanup",
    desc = "Light auto-destroys when entity is destroyed",
    duration = 5,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.1)
        
        local entity = createTestEntity(centerX(), centerY(), "enemy_type_1.png")
        
        local light = Lighting.point()
            :attachTo(entity)
            :radius(200)
            :intensity(1.0)
            :color("fire")
            :create()
        table.insert(_lights, light)
        
        -- Destroy entity after 2.5 seconds
        timer.after_opts({
            delay = 2.5,
            action = function()
                if registry:valid(entity) then
                    registry:destroy(entity)
                    Text.define()
                        :content("[Entity destroyed - light should vanish!](color=yellow)")
                        :size(18):anchor("center"):space("screen"):lifespan(2)
                        :spawn():at(centerX(), centerY() + 80):tag(_demoTag)
                end
            end,
            tag = "destroy_entity",
            group = TIMER_GROUP
        })
    end
}

-- Test 8: Pause/Resume
tests[8] = {
    name = "Pause/Resume Lighting",
    desc = "Layer pauses (dark) then resumes (lit)",
    duration = 6,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.1)
        
        local light = Lighting.point()
            :at(centerX(), centerY())
            :radius(200)
            :intensity(1.0)
            :color("gold")
            :create()
        table.insert(_lights, light)
        
        -- Pause after 2s
        timer.after_opts({
            delay = 2,
            action = function()
                Lighting.pause("sprites")
                Text.define()
                    :content("[PAUSED](color=red)")
                    :size(24):anchor("center"):space("screen"):lifespan(1.8)
                    :spawn():at(centerX(), centerY()):tag(_demoTag)
            end,
            group = TIMER_GROUP
        })
        
        -- Resume after 4s
        timer.after_opts({
            delay = 4,
            action = function()
                Lighting.resume("sprites")
                Text.define()
                    :content("[RESUMED](color=green)")
                    :size(24):anchor("center"):space("screen"):lifespan(1.8)
                    :spawn():at(centerX(), centerY()):tag(_demoTag)
            end,
            group = TIMER_GROUP
        })
    end
}

-- Test 9: Timer-based animation (flicker)
tests[9] = {
    name = "Animated Light (Flicker + Pulse)",
    desc = "Torch flicker and pulsing glow effects",
    duration = 6,
    run = function()
        Lighting.enable("sprites", { mode = "subtractive" })
        Lighting.setAmbient("sprites", 0.05)
        
        -- Flickering torch (left)
        local torch = Lighting.point()
            :at(centerX() - 200, centerY())
            :radius(120)
            :intensity(0.9)
            :color("orange")
            :create()
        table.insert(_lights, torch)
        
        timer.every_opts({
            delay = 0.08,
            action = function()
                if torch:isValid() then
                    torch:setIntensity(0.7 + math.random() * 0.3)
                    torch:setRadius(100 + math.random() * 30)
                end
            end,
            tag = "flicker",
            group = TIMER_GROUP
        })
        
        -- Pulsing glow (right)
        local glow = Lighting.point()
            :at(centerX() + 200, centerY())
            :radius(100)
            :intensity(1.0)
            :color("cyan")
            :create()
        table.insert(_lights, glow)
        
        local pulseStart = GetTime()
        timer.every_opts({
            delay = 0.016,
            action = function()
                if glow:isValid() then
                    local t = GetTime() - pulseStart
                    local pulse = 0.5 + 0.5 * math.sin(t * 3)
                    glow:setRadius(80 + pulse * 60)
                    glow:setIntensity(0.6 + pulse * 0.4)
                end
            end,
            tag = "pulse",
            group = TIMER_GROUP
        })
        
        -- Labels
        Text.define()
            :content("[Flicker](color=orange)")
            :size(16):anchor("center"):space("screen"):lifespan(5.5)
            :spawn():at(centerX() - 200, centerY() - 80):tag(_demoTag)
        Text.define()
            :content("[Pulse](color=cyan)")
            :size(16):anchor("center"):space("screen"):lifespan(5.5)
            :spawn():at(centerX() + 200, centerY() - 80):tag(_demoTag)
    end
}

-- Test 10: Multi-colored scene
tests[10] = {
    name = "Demo Complete!",
    desc = "Multi-colored finale scene",
    duration = 5,
    run = function()
        Lighting.enable("sprites", { mode = "additive" })
        
        -- Create a nice arrangement of colored lights
        local positions = {
            { x = centerX(), y = centerY() - 150, color = "cyan", radius = 180 },
            { x = centerX() - 200, y = centerY() + 50, color = "fire", radius = 150 },
            { x = centerX() + 200, y = centerY() + 50, color = "purple", radius = 150 },
            { x = centerX(), y = centerY() + 150, color = "gold", radius = 120 },
        }
        
        for _, p in ipairs(positions) do
            local light = Lighting.point()
                :at(p.x, p.y)
                :radius(p.radius)
                :intensity(0.8)
                :color(p.color)
                :create()
            table.insert(_lights, light)
        end
        
        -- Animate all lights pulsing
        local startTime = GetTime()
        timer.every_opts({
            delay = 0.016,
            action = function()
                local t = GetTime() - startTime
                for i, light in ipairs(_lights) do
                    if light:isValid() then
                        local phase = t * 2 + i * 0.5
                        local pulse = 0.7 + 0.3 * math.sin(phase)
                        light:setIntensity(pulse)
                    end
                end
            end,
            group = TIMER_GROUP
        })
    end
}

--------------------------------------------------------------------------------
-- MAIN API
--------------------------------------------------------------------------------

local function runTest(index)
    print(string.format("[LightingDemo] Starting test %d", index))

    cleanup()
    _currentTest = index

    local test = tests[index]
    if not test then
        showLabel("Demo Complete!", 3)
        timer.after_opts({
            delay = 3,
            action = function() LightingDemo.stop() end,
            group = TIMER_GROUP
        })
        return
    end

    showLabel(string.format("Test %d/%d: %s", index, #tests, test.name), test.duration)
    showSubLabel(test.desc, test.duration)

    -- Run test with error handling
    local ok, err = pcall(test.run)
    if not ok then
        print(string.format("[LightingDemo] ERROR in test %d: %s", index, tostring(err)))
        log_error(string.format("[LightingDemo] Test %d failed: %s", index, tostring(err)))
    end

    -- Schedule next test
    timer.after_opts({
        delay = test.duration,
        action = function()
            if _active then
                runTest(index + 1)
            else
                print("[LightingDemo] Demo stopped, not running next test")
            end
        end,
        tag = "next_test",
        group = TIMER_GROUP
    })
end

function LightingDemo.start()
    if _active then return end
    _active = true
    _currentTest = 0
    
    print("[LightingDemo] Starting lighting system demo...")
    log_info("[LightingDemo] Starting lighting system demo")
    
    -- Start first test after brief delay
    timer.after_opts({
        delay = 0.5,
        action = function() runTest(1) end,
        group = TIMER_GROUP
    })
end

function LightingDemo.stop()
    if not _active then return end
    _active = false
    
    print("[LightingDemo] Stopping demo...")
    log_info("[LightingDemo] Stopping demo")
    
    cleanup()
end

function LightingDemo.isActive()
    return _active
end

function LightingDemo.skipToTest(index)
    if not _active then return end
    if index >= 1 and index <= #tests then
        timer.kill_group(TIMER_GROUP)
        runTest(index)
    end
end

function LightingDemo.nextTest()
    if not _active then return end
    timer.kill_group(TIMER_GROUP)
    runTest(_currentTest + 1)
end

return LightingDemo
