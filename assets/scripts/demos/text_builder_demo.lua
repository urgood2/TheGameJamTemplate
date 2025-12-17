--[[
================================================================================
TEXT BUILDER DEMO - Comprehensive Feature Showcase
================================================================================
Demonstrates ALL TextBuilder features with staggered display and labels.
Each feature is shown individually with its name so you know exactly what's being tested.

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
local _currentDemo = 0
local _demoQueue = {}

-- Screen helpers
local function screenW()
    return globals and globals.screenWidth and globals.screenWidth() or 1920
end

local function screenH()
    return globals and globals.screenHeight and globals.screenHeight() or 1080
end

--------------------------------------------------------------------------------
-- DEMO SEQUENCE DEFINITIONS
--------------------------------------------------------------------------------

-- Each demo entry: { name = "...", duration = N, spawn = function() end }
-- spawn() creates the text elements for that demo

local function buildDemoQueue()
    _demoQueue = {}

    local cx = screenW() * 0.5  -- Center X
    local baseY = 120           -- Base Y for demo content
    local labelY = 50           -- Y for section labels

    -- Helper: Add a section header
    local function addSection(name, demos)
        -- Section header
        table.insert(_demoQueue, {
            name = "SECTION: " .. name,
            duration = 1.5,
            spawn = function()
                Text.define()
                    :content(string.format("[=== %s ===](color=gold)", name))
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(1.4)
                    :spawn()
                    :at(cx, labelY)
                    :tag(_demoTag)
            end
        })
        -- Add all demos in this section
        for _, demo in ipairs(demos) do
            table.insert(_demoQueue, demo)
        end
    end

    --------------------------------------------------------------------------
    -- SECTION: COLORS
    --------------------------------------------------------------------------
    addSection("COLORS", {
        {
            name = "color: Named Colors",
            duration = 3,
            spawn = function()
                local colors = { "red", "orange", "yellow", "green", "cyan", "blue", "purple", "pink" }
                local spacing = screenW() / (#colors + 1)
                for i, col in ipairs(colors) do
                    Text.define()
                        :content(string.format("[%s](color=%s)", col, col))
                        :size(22)
                        :anchor("center")
                        :space("screen")
                        :lifespan(2.8)
                        :spawn()
                        :at(spacing * i, baseY)
                        :tag(_demoTag)
                end
                -- Label
                Text.define()
                    :content("[color=<name>](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "rainbow: HSV Cycling",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[RAINBOW EFFECT](rainbow=60,10)")
                    :size(36)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[rainbow=speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: MOVEMENT EFFECTS
    --------------------------------------------------------------------------
    addSection("MOVEMENT", {
        {
            name = "float: Vertical Bob",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[Floating Text](float=8,2,0.3)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[float=amp,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "shake: Random Jitter",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[SHAKING!](shake=3,15;color=red)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[shake=intensity,speed](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "wave: Traveling Sine",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[~~ WAVE MOTION ~~](wave=10,4,0.4)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[wave=amp,speed,wavelength](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "rise: Drift Upward",
            duration = 3,
            spawn = function()
                -- Spawn multiple rising texts
                for i = 1, 5 do
                    timer.after(i * 0.4, function()
                        if not _active then return end
                        local x = cx + (i - 3) * 100
                        Text.define()
                            :content(string.format("[+%d](rise=50,true,0,green)", i * 10))
                            :size(24)
                            :anchor("center")
                            :space("screen")
                            :fade()
                            :lifespan(1.5)
                            :spawn()
                            :at(x, baseY + 30)
                            :tag(_demoTag)
                    end, nil, nil, "demo_rise_" .. i, "text_demo")
                end
                Text.define()
                    :content("[rise=speed,fade,stagger,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 80)
                    :tag(_demoTag)
            end
        },
        {
            name = "orbit: Circular Motion",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[ORBITING](orbit=5,3,0.8;color=cyan)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[orbit=radius,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: ROTATION & SCALE
    --------------------------------------------------------------------------
    addSection("ROTATION & SCALE", {
        {
            name = "wiggle: Fast Oscillation",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[Wiggle Wiggle](wiggle=15,12,0.8)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[wiggle=angle,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "spin: 360 Rotation",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[S][P][I][N](spin=1.5,0.3)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[spin=rotations_per_sec,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "pulse: Scale Oscillation",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[PULSE](pulse=0.7,1.3,3,0.2;color=purple)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[pulse=min,max,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "fan: Spread Rotation",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[FANNED OUT](fan=20)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[fan=max_angle](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: ONESHOT ANIMATIONS
    --------------------------------------------------------------------------
    addSection("ONESHOT ANIMATIONS", {
        {
            name = "pop: Scale In",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[POP IN!](pop=0.4,0.1,in;color=gold)")
                    :size(36)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[pop=duration,stagger,mode](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "slide: Directional Entry",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[SLIDE FROM LEFT](slide=0.5,0.08,l,in)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[slide=dur,stagger,dir,fade](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "bounce: Physics Drop",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[BOUNCE!](bounce=30,800,0.08;color=orange)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 30)
                    :tag(_demoTag)
                Text.define()
                    :content("[bounce=height,gravity,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 80)
                    :tag(_demoTag)
            end
        },
        {
            name = "scramble: Character Cycling",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[DECRYPTING](scramble=0.8,0.1,20;color=green)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[scramble=duration,stagger,rate](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "cascade: Waterfall Reveal",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[CASCADE REVEAL](cascade=0.1,0.4,cyan)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[cascade=delay,duration,start_color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: JUICY EFFECTS
    --------------------------------------------------------------------------
    addSection("JUICY EFFECTS", {
        {
            name = "jelly: Squash & Stretch",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[JELLY](jelly=0.4,6,0.15)")
                    :size(36)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[jelly=squash,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "hop: Quick Jumps",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[HOP HOP HOP](hop=8,6,0.25;color=green)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[hop=height,speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "slam: Impact Entry",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[SLAM!](slam=0.3,0.06,2.5,orange)")
                    :size(36)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[slam=dur,stagger,scale,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "heartbeat: Lub-Dub Rhythm",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[<3 LOVE <3](heartbeat=1.4,2,pink)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[heartbeat=scale,speed,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "tremble: Fear Effect",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[TERRIFIED...](tremble=1.5,25,red)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[tremble=intensity,speed,tint](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: MAGICAL EFFECTS
    --------------------------------------------------------------------------
    addSection("MAGICAL EFFECTS", {
        {
            name = "shimmer: Color Flicker",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[SHIMMERING](shimmer=10,0.1,silver,white,cyan)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[shimmer=speed,stagger,colors...](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "glow_pulse: Alpha Pulse",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[GLOWING](glow_pulse=0.4,1,2,gold)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[glow_pulse=min,max,speed,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "enchant: Magic Float",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[ENCHANTED](enchant=3,0.2,purple)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[enchant=speed,stagger,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "phase: Ghostly Fade",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[PHASING...](phase=0.2,0.9,2,lightblue)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[phase=min,max,speed,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "sparkle: Random Flash",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[*SPARKLE*](sparkle=0.05,white,gold,cyan)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[sparkle=chance,colors...](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: ELEMENTAL EFFECTS
    --------------------------------------------------------------------------
    addSection("ELEMENTAL EFFECTS", {
        {
            name = "fire: Flame Effect",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[BURNING!](fire=8,4)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[fire=speed,flicker](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "ice: Frozen Shimmer",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[FROZEN](ice=1.5)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[ice=speed](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "electric: Lightning",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[SHOCKED!](electric=25,3,cyan)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[electric=speed,jitter,color](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "poison: Toxic Pulse",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[POISONED](poison=3,0.6)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[poison=speed,intensity](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "holy: Divine Glow",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[BLESSED](holy=2.5,0.15)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[holy=speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "void: Dark Energy",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[V O I D](void=2,0.25)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("[void=speed,stagger](color=silver)")
                    :size(16)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: COMBINED EFFECTS
    --------------------------------------------------------------------------
    addSection("COMBINED EFFECTS", {
        {
            name = "Multiple Effects",
            duration = 4,
            spawn = function()
                Text.define()
                    :content("[COMBINED](color=gold;float=5,2,0.3;pulse=0.9,1.1,3)")
                    :size(32)
                    :anchor("center")
                    :space("screen")
                    :lifespan(3.8)
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content("Effects chain with semicolons: effect1;effect2;effect3")
                    :size(16)
                    :color("silver")
                    :anchor("center")
                    :space("screen")
                    :lifespan(3.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "Game-Style Damage Numbers",
            duration = 4,
            spawn = function()
                -- Simulate combat numbers
                local types = {
                    { fmt = "[%d](rise=60,true,0,red)", val = math.random(50, 150), label = "Damage" },
                    { fmt = "[+%d](rise=50,true,0,green)", val = math.random(20, 60), label = "Heal" },
                    { fmt = "[CRIT %d](rise=40,true,0,gold;pulse=0.9,1.2,4)", val = math.random(200, 400), label = "Critical" },
                    { fmt = "[MISS](rise=30,true,0,silver)", val = nil, label = "Miss" },
                }
                local spacing = screenW() / (#types + 1)
                for i, t in ipairs(types) do
                    local content = t.val and string.format(t.fmt, t.val) or t.fmt
                    Text.define()
                        :content(content)
                        :size(24)
                        :anchor("center")
                        :space("screen")
                        :fade()
                        :lifespan(2)
                        :spawn()
                        :at(spacing * i, baseY)
                        :tag(_demoTag)
                    Text.define()
                        :content(t.label)
                        :size(14)
                        :color("silver")
                        :anchor("center")
                        :space("screen")
                        :lifespan(3.8)
                        :spawn()
                        :at(spacing * i, baseY + 60)
                        :tag(_demoTag)
                end
            end
        },
    })

    --------------------------------------------------------------------------
    -- SECTION: API FEATURES
    --------------------------------------------------------------------------
    addSection("API FEATURES", {
        {
            name = "Fade & Lifespan",
            duration = 3,
            spawn = function()
                Text.define()
                    :content("[Auto-fading text](color=cyan)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :fade()           -- Enable fade
                    :lifespan(2.5)    -- Die after 2.5s
                    :spawn()
                    :at(cx, baseY)
                    :tag(_demoTag)
                Text.define()
                    :content(":fade() + :lifespan(seconds)")
                    :size(16)
                    :color("silver")
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "Template Substitution",
            duration = 3,
            spawn = function()
                local recipe = Text.define()
                    :content("[Score: %d](color=gold)")
                    :size(28)
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)

                -- Spawn with different values
                recipe:spawn(1000):at(cx - 150, baseY):tag(_demoTag)
                recipe:spawn(2500):at(cx, baseY):tag(_demoTag)
                recipe:spawn(5000):at(cx + 150, baseY):tag(_demoTag)

                Text.define()
                    :content(":content('[Score: %d]') + :spawn(value)")
                    :size(16)
                    :color("silver")
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
        {
            name = "Tags & Bulk Operations",
            duration = 3,
            spawn = function()
                -- Spawn tagged text
                for i = 1, 5 do
                    Text.define()
                        :content(string.format("[Tag #%d](color=purple)", i))
                        :size(22)
                        :anchor("center")
                        :space("screen")
                        :lifespan(2.8)
                        :spawn()
                        :at(cx + (i - 3) * 120, baseY)
                        :tag(_demoTag)
                end
                Text.define()
                    :content(":tag('name') + Text.stopByTag('name')")
                    :size(16)
                    :color("silver")
                    :anchor("center")
                    :space("screen")
                    :lifespan(2.8)
                    :spawn()
                    :at(cx, baseY + 50)
                    :tag(_demoTag)
            end
        },
    })

    -- Final summary
    table.insert(_demoQueue, {
        name = "DEMO COMPLETE",
        duration = 3,
        spawn = function()
            Text.define()
                :content("[Demo Complete!](rainbow=90,15)")
                :size(36)
                :anchor("center")
                :space("screen")
                :lifespan(2.8)
                :spawn()
                :at(cx, baseY)
                :tag(_demoTag)
            Text.define()
                :content(string.format("Showcased %d features", #_demoQueue - 1))
                :size(20)
                :color("silver")
                :anchor("center")
                :space("screen")
                :lifespan(2.8)
                :spawn()
                :at(cx, baseY + 50)
                :tag(_demoTag)
        end
    })
end

--------------------------------------------------------------------------------
-- DEMO CONTROL
--------------------------------------------------------------------------------

local function runNextDemo()
    if not _active then return end

    _currentDemo = _currentDemo + 1
    if _currentDemo > #_demoQueue then
        _currentDemo = 1  -- Loop
    end

    local demo = _demoQueue[_currentDemo]
    if not demo then return end

    -- Clear previous demo text
    Text.stopByTag(_demoTag)

    -- Show progress indicator
    local progress = string.format("[%d/%d](color=silver)", _currentDemo, #_demoQueue)
    Text.define()
        :content(progress)
        :size(14)
        :anchor("topleft")
        :space("screen")
        :lifespan(demo.duration - 0.1)
        :spawn()
        :at(20, 20)
        :tag(_demoTag)

    -- Spawn demo content
    demo.spawn()

    -- Schedule next demo
    _timers.nextDemo = timer.after(
        demo.duration,
        runNextDemo,
        nil,
        nil,
        "text_demo_next",
        "text_demo"
    )
end

--- Start the text builder demo
function TextBuilderDemo.start()
    if _active then return end
    _active = true

    print("[TextBuilderDemo] Starting comprehensive feature showcase")

    -- Build the demo queue
    buildDemoQueue()
    _currentDemo = 0

    -- Clear any existing demo text
    Text.stopByTag(_demoTag)

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

    -- Start first demo
    runNextDemo()

    log_debug("[TextBuilderDemo] Started - " .. #_demoQueue .. " demos queued")
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

    _currentDemo = 0
    _demoQueue = {}

    log_debug("[TextBuilderDemo] Stopped")
end

--- Check if demo is active
function TextBuilderDemo.isActive()
    return _active
end

--- Get current demo index
function TextBuilderDemo.getCurrentDemo()
    return _currentDemo, #_demoQueue
end

--- Skip to next demo
function TextBuilderDemo.next()
    if not _active then return end
    timer.kill("text_demo_next")
    runNextDemo()
end

--- Skip to previous demo
function TextBuilderDemo.prev()
    if not _active then return end
    _currentDemo = _currentDemo - 2
    if _currentDemo < 0 then _currentDemo = #_demoQueue - 1 end
    timer.kill("text_demo_next")
    runNextDemo()
end

--- Get active text count (for debugging)
function TextBuilderDemo.getActiveCount()
    return Text.getActiveCount()
end

return TextBuilderDemo
