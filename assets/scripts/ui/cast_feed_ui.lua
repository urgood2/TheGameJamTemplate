--[[
================================================================================
CAST FEED UI
================================================================================
Displays a feed of recognized Spell Types and Joker triggers.
Visualizes the "Pattern Matching" aspect of the wand system.
]] --

local CastFeedUI = {}

-- Dependencies
local timer = require("core.timer")
local Easing = require("util.easing")
local signal = require("external.hump.signal")
local layers = require("core.render_layers")

-- Configuration
local FEED_MAX_ITEMS = 5
local ITEM_LIFETIME = 3.0      -- seconds
local DISCOVERY_LIFETIME = 5.0 -- discoveries stay longer
local FADE_OUT_TIME = 0.5
local SLIDE_IN_TIME = 0.3

-- State
CastFeedUI.items = {} -- List of { text, color, age, alpha, y_offset }

-- Colors for Spell Types
local TYPE_COLORS = {
    ["Simple Cast"] = util.getColor("white"),
    ["Twin Cast"] = util.getColor("cyan"),
    ["Scatter Cast"] = util.getColor("orange"),
    ["Precision Cast"] = util.getColor("red"),
    ["Rapid Fire"] = util.getColor("yellow"),
    ["Mono-Element"] = util.getColor("purple"),
    ["Combo Chain"] = util.getColor("green"),
    ["Heavy Barrage"] = util.getColor("dark_red"),
    ["Chaos Cast"] = util.getColor("gray"),
}

-- Colors for Jokers
local JOKER_COLOR = util.getColor("gold")

-- Colors for Discoveries
local DISCOVERY_COLOR = util.getColor("cyan")
local TAG_DISCOVERY_COLOR = util.getColor("orange")

--- Initialize the Cast Feed UI
function CastFeedUI.init()
    CastFeedUI.items = {}

    -- Subscribe to events
    signal.register("on_spell_cast", CastFeedUI.onSpellCast)
    signal.register("on_joker_trigger", CastFeedUI.onJokerTrigger)

    -- Subscribe to discovery events
    signal.register("tag_threshold_discovered", CastFeedUI.onTagDiscovery)
    signal.register("spell_type_discovered", CastFeedUI.onSpellTypeDiscovery)

    print("[CastFeedUI] Initialized")
end

--- Update the UI (animation, fading)
--- @param dt number Delta time
function CastFeedUI.update(dt)
    for i = #CastFeedUI.items, 1, -1 do
        local item = CastFeedUI.items[i]
        item.age = item.age + dt

        -- Use different lifetime for discoveries
        local lifetime = item.isDiscovery and DISCOVERY_LIFETIME or ITEM_LIFETIME

        -- Handle fade out
        if item.age > (lifetime - FADE_OUT_TIME) then
            local fadeProgress = (item.age - (lifetime - FADE_OUT_TIME)) / FADE_OUT_TIME
            item.alpha = 1.0 - fadeProgress
        end

        -- Remove expired items
        if item.age >= lifetime then
            table.remove(CastFeedUI.items, i)
        end
    end
end

--- Draw the UI
function CastFeedUI.draw()
    local startX = globals.screenWidth() * 0.5
    local startY = globals.screenHeight() * 0.8 -- Bottom center
    local spacing = 30

    for i, item in ipairs(CastFeedUI.items) do
        local yPos = startY - ((#CastFeedUI.items - i) * spacing)

        -- Apply alpha to color
        local color = { item.color[1], item.color[2], item.color[3], item.alpha }

        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = item.text
            c.font = localization.getFont()
            c.x = startX - (localization.getTextWidthWithCurrentFont(item.text, 24, 1) * 0.5)
            c.y = yPos
            c.color = color
            c.fontSize = 24
        end, z_orders.ui + 10, layer.DrawCommandSpace.Screen)
    end
end

--- Event Handler: Spell Cast
function CastFeedUI.onSpellCast(data)
    if not data or not data.spell_type then return end

    local text = string.upper(data.spell_type)
    local color = TYPE_COLORS[data.spell_type] or util.getColor("white")

    CastFeedUI.addItem(text, color, false)
end

--- Event Handler: Joker Trigger
function CastFeedUI.onJokerTrigger(data)
    if not data or not data.joker_name then return end

    local text = data.joker_name .. "!"
    if data.message then
        text = text .. " (" .. data.message .. ")"
    end

    CastFeedUI.addItem(text, JOKER_COLOR, false)
end

--- Event Handler: Tag Threshold Discovery
function CastFeedUI.onTagDiscovery(data)
    if not data or not data.tag or not data.threshold then return end

    local text = string.format("🔥 DISCOVERY: %s x%d!", data.tag, data.threshold)
    CastFeedUI.addItem(text, TAG_DISCOVERY_COLOR, true) -- true = isDiscovery
end

--- Event Handler: Spell Type Discovery
function CastFeedUI.onSpellTypeDiscovery(data)
    if not data or not data.spell_type then return end

    local text = string.format("✨ NEW SPELL: %s!", string.upper(data.spell_type))
    CastFeedUI.addItem(text, DISCOVERY_COLOR, true) -- true = isDiscovery
end

--- Add an item to the feed
--- @param text string Text to display
--- @param color table Color {r, g, b, a}
--- @param isDiscovery boolean Whether this is a discovery (stays longer)
function CastFeedUI.addItem(text, color, isDiscovery)
    local item = {
        text = text,
        color = color,
        age = 0,
        alpha = 1.0,
        isDiscovery = isDiscovery or false
    }

    table.insert(CastFeedUI.items, item)

    -- Cap list size
    if #CastFeedUI.items > FEED_MAX_ITEMS then
        table.remove(CastFeedUI.items, 1)
    end
end

return CastFeedUI
