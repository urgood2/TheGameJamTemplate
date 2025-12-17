--[[
================================================================================
TEXT BUILDER DEMO - Visual showcase for main menu
================================================================================
Demonstrates the TextBuilder API with various text effects, patterns, and features.
Designed to run in the top portion of the main menu.

NOTE: This simplified version avoids scale-based effects (pop, pulse, shake)
that have issues in CommandBufferText's matrix transform path.

Usage:
    local TextBuilderDemo = require("demos.text_builder_demo")
    TextBuilderDemo.start()    -- Start the demo
    TextBuilderDemo.stop()     -- Stop and cleanup
]]

local TextBuilderDemo = {}

local Text = require("core.text")
local timer = require("core.timer")

-- Demo state
local _active = false
local _timers = {}
local _demoTag = "text_builder_demo"

-- Screen helpers
local function screenW()
    return globals and globals.screenWidth and globals.screenWidth() or 1920
end

local function screenH()
    return globals and globals.screenHeight and globals.screenHeight() or 1080
end

--------------------------------------------------------------------------------
-- RECIPES - Define reusable text styles (simplified, no scale effects)
--------------------------------------------------------------------------------

-- Damage number style - red, rises up
-- NOTE: rise effect has params: speed, fade, stagger, color
-- Using rise's color param instead of separate color effect (rise overwrites color)
local damageRecipe = Text.define()
    :content("[%d](rise=60,true,0,red)")
    :size(28)
    :fade()
    :lifespan(0.8, 1.2)
    :anchor("center")
    :space("screen")

-- Heal number style - green, rises up
local healRecipe = Text.define()
    :content("[+%d](rise=50,true,0,green)")
    :size(24)
    :fade()
    :lifespan(0.7, 1.0)
    :anchor("center")
    :space("screen")

-- Critical hit style - gold, larger
local critRecipe = Text.define()
    :content("[CRIT! %d](rise=40,true,0,gold)")
    :size(36)
    :fade()
    :fadeIn(0.1)
    :lifespan(1.0)
    :anchor("center")
    :space("screen")

-- Status effect style - cyan
local statusRecipe = Text.define()
    :content("[%s](rise=30,true,0,cyan)")
    :size(18)
    :fade()
    :lifespan(1.5)
    :anchor("center")
    :space("screen")

-- Title announcement style - gold, large (no rise, just color)
local titleRecipe = Text.define()
    :content("[%s](color=gold)")
    :size(42)
    :fade()
    :fadeIn(0.3)
    :lifespan(2.5)
    :anchor("center")
    :space("screen")

-- Combo counter style - purple
local comboRecipe = Text.define()
    :content("[%dx COMBO](rise=35,true,0,purple)")
    :size(32)
    :fade()
    :lifespan(0.8)
    :anchor("center")
    :space("screen")

-- XP gain style - blue
local xpRecipe = Text.define()
    :content("[+%d XP](rise=45,true,0,blue)")
    :size(20)
    :fade()
    :lifespan(1.2)
    :anchor("center")
    :space("screen")

--------------------------------------------------------------------------------
-- DEMO PATTERNS
--------------------------------------------------------------------------------

-- Pattern 1: Random damage numbers across the demo area
local function spawnRandomDamage()
    local x = screenW() * (0.15 + math.random() * 0.7)  -- 15%-85% of screen width
    local y = 50 + math.random() * 120  -- Top area
    local damage = math.random(10, 99)

    damageRecipe:spawn(damage):at(x, y):tag(_demoTag)
end

-- Pattern 2: Heal numbers
local function spawnRandomHeal()
    local x = screenW() * (0.2 + math.random() * 0.6)
    local y = 80 + math.random() * 100
    local heal = math.random(5, 30)

    healRecipe:spawn(heal):at(x, y):tag(_demoTag)
end

-- Pattern 3: Occasional critical hit
local function spawnCriticalHit()
    local x = screenW() * 0.5 + (math.random() - 0.5) * 400
    local y = 60 + math.random() * 80
    local damage = math.random(100, 250)

    critRecipe:spawn(damage):at(x, y):tag(_demoTag)
end

-- Pattern 4: Status effects
local function spawnStatusEffect()
    local statuses = { "STUNNED", "BURNING", "FROZEN", "POISONED", "BLESSED" }
    local status = statuses[math.random(#statuses)]
    local x = screenW() * (0.25 + math.random() * 0.5)
    local y = 100 + math.random() * 60

    statusRecipe:spawn(status):at(x, y):tag(_demoTag)
end

-- Pattern 5: Combo counter
local function spawnCombo()
    local combo = math.random(2, 10)
    local x = screenW() * 0.5
    local y = 40

    comboRecipe:spawn(combo):at(x, y):tag(_demoTag)
end

-- Pattern 6: XP gains
local function spawnXPGain()
    local x = screenW() * (0.3 + math.random() * 0.4)
    local y = 130 + math.random() * 40
    local xp = math.random(10, 50) * 5

    xpRecipe:spawn(xp):at(x, y):tag(_demoTag)
end

-- Pattern 7: Title announcement (rare)
local function spawnTitleAnnouncement()
    local titles = {
        "WAVE COMPLETE",
        "LEVEL UP!",
        "BOSS INCOMING",
        "PERFECT!",
        "UNSTOPPABLE"
    }
    local title = titles[math.random(#titles)]
    local x = screenW() * 0.5
    local y = 90

    titleRecipe:spawn(title):at(x, y):tag(_demoTag)
end

--------------------------------------------------------------------------------
-- DEMO CONTROL
--------------------------------------------------------------------------------

--- Start the text builder demo
function TextBuilderDemo.start()
    if _active then return end
    _active = true

    -- Clear any existing demo text
    Text.stopByTag(_demoTag)

    -- Schedule periodic spawns with variety (slower rates to reduce load)

    -- Damage numbers: every 0.6 seconds
    _timers.damage = timer.every(
        0.6,
        function()
            if not _active then return end
            spawnRandomDamage()
        end,
        0,    -- infinite
        true, -- immediate
        nil,
        "text_demo_damage",
        "text_demo"
    )

    -- Heals: every 1.5 seconds
    _timers.heal = timer.every(
        1.5,
        function()
            if not _active then return end
            spawnRandomHeal()
        end,
        0,
        false, -- not immediate
        nil,
        "text_demo_heal",
        "text_demo"
    )

    -- Crits: every 3 seconds
    _timers.crit = timer.every(
        3.0,
        function()
            if not _active then return end
            spawnCriticalHit()
        end,
        0,
        false,
        nil,
        "text_demo_crit",
        "text_demo"
    )

    -- Status effects: every 2 seconds
    _timers.status = timer.every(
        2.0,
        function()
            if not _active then return end
            spawnStatusEffect()
        end,
        0,
        false,
        nil,
        "text_demo_status",
        "text_demo"
    )

    -- Combos: every 4 seconds
    _timers.combo = timer.every(
        4.0,
        function()
            if not _active then return end
            spawnCombo()
        end,
        0,
        false,
        nil,
        "text_demo_combo",
        "text_demo"
    )

    -- XP: every 2.5 seconds
    _timers.xp = timer.every(
        2.5,
        function()
            if not _active then return end
            spawnXPGain()
        end,
        0,
        false,
        nil,
        "text_demo_xp",
        "text_demo"
    )

    -- Title announcements: every 6 seconds
    _timers.title = timer.every(
        6.0,
        function()
            if not _active then return end
            spawnTitleAnnouncement()
        end,
        0,
        false,
        nil,
        "text_demo_title",
        "text_demo"
    )

    -- Update loop for Text.update(dt)
    _timers.update = timer.every(
        0.016, -- ~60fps
        function()
            if not _active then return end
            Text.update(0.016)
        end,
        0,
        true,
        nil,
        "text_demo_update",
        "text_demo"
    )

    log_debug("[TextBuilderDemo] Started")
end

--- Stop the text builder demo
function TextBuilderDemo.stop()
    if not _active then return end
    _active = false

    -- Kill all demo timers
    timer.kill_group("text_demo")
    _timers = {}

    -- Clean up all demo text
    Text.stopByTag(_demoTag)
    Text.update(0) -- Process removals

    log_debug("[TextBuilderDemo] Stopped")
end

--- Check if demo is active
function TextBuilderDemo.isActive()
    return _active
end

--- Get active text count (for debugging)
function TextBuilderDemo.getActiveCount()
    return Text.getActiveCount()
end

return TextBuilderDemo
