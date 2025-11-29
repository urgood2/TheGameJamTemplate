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
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")
local entity_cache = require("core.entity_cache")

-- Configuration
local FEED_MAX_ITEMS = 5
local ITEM_LIFETIME = 3.0      -- seconds
local DISCOVERY_LIFETIME = 5.0 -- discoveries stay longer
local FADE_OUT_TIME = 0.5
local SLIDE_IN_TIME = 0.3

local SPRING_STIFFNESS = 160.0
local SPRING_DAMPING = 16.0
local SPRING_SMOOTHING = 0.9
local SPRING_MAX_VELOCITY = 22.0
local ENTRY_SCALE_START = 0.75
local ENTRY_ROTATION_RANGE = 10
local EXIT_SCALE_TARGET = 0.65
local EXIT_ROTATION_RANGE = 12

-- Board-change driven cleanup
local BOARD_CHANGE_SIGNAL = "board_changed" -- emitted by board updates

-- Rendering
local FONT_SIZE = 24
local TEXT_PADDING_X = 16
local TEXT_PADDING_Y = 8
local BACKGROUND_RADIUS = 12
local BACKGROUND_COLOR = { r = 12, g = 12, b = 16, a = 200 }

local DEMO_FEED_TAG = "cast_feed_ui_demo_feed"
local DEMO_FEED_INTERVAL = 1.4 -- seconds
local DEMO_FEED_ENABLED = true

-- State
CastFeedUI.items = {} -- List of { text, color, age, alpha, springs... }
CastFeedUI._demoIndex = 1
CastFeedUI.isActive = false
CastFeedUI._subscribed = false
CastFeedUI._boardVersion = 0

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

local DEMO_SEQUENCE = {
    { kind = "spell_cast", payload = { spell_type = "Twin Cast" } },
    { kind = "spell_cast", payload = { spell_type = "Scatter Cast" } },
    { kind = "joker", payload = { joker_name = "Tag Specialist", message = "Tag Focus! (Fire x3)" } },
    { kind = "tag_discovery", payload = { tag = "Fire", threshold = 3 } },
    { kind = "spell_cast", payload = { spell_type = "Heavy Barrage" } },
    { kind = "joker", payload = { joker_name = "Glass Cannon", message = "+Power / -Safety" } },
    { kind = "tag_discovery", payload = { tag = "Lightning", threshold = 2 } },
    { kind = "spell_type_discovery", payload = { spell_type = "Mono-Element" } },
    { kind = "spell_cast", payload = { spell_type = "Combo Chain" } },
}

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function randomRange(min, max)
    return min + (max - min) * math.random()
end

local function destroySpringEntity(entity)
    if not registry or not entity or entity == entt_null then return end
    if registry.valid and not entity_cache.valid(entity) then return end
    registry:destroy(entity)
end

local function getItemSpring(item, kind)
    if not item then return nil end
    local entity = (kind == "scale") and item.scaleSpringEntity or item.rotationSpringEntity
    if not entity or entity == entt_null then return nil end
    if not entity_cache.valid(entity) then return nil end
    local ok, springRef = pcall(spring.get, registry, entity)
    if not ok then return nil end
    return springRef
end

local function destroyItemSprings(item)
    if not item then return end
    destroySpringEntity(item.scaleSpringEntity)
    destroySpringEntity(item.rotationSpringEntity)
    item.scaleSpringEntity = nil
    item.rotationSpringEntity = nil
end

local function kickEntrySprings(item)
    if not item then return end

    local scaleSpring = getItemSpring(item, "scale")
    if scaleSpring then
        scaleSpring.value = ENTRY_SCALE_START
        scaleSpring.targetValue = 1.0
        scaleSpring.velocity = 0.0
    end

    local rotationSpring = getItemSpring(item, "rotation")
    if rotationSpring then
        local wobble = randomRange(-ENTRY_ROTATION_RANGE, ENTRY_ROTATION_RANGE)
        rotationSpring.value = wobble
        rotationSpring.targetValue = 0.0
        rotationSpring.velocity = 0.0
    end
end

local function triggerFadeOutSprings(item)
    if not item or item.fadeSpringsTriggered then return end
    item.fadeSpringsTriggered = true

    local scaleSpring = getItemSpring(item, "scale")
    if scaleSpring then
        scaleSpring.targetValue = EXIT_SCALE_TARGET
        scaleSpring.value = math.max(scaleSpring.value or 1.0, 1.05)
        if scaleSpring.pull then
            scaleSpring:pull(-0.25)
        end
    end

    local rotationSpring = getItemSpring(item, "rotation")
    if rotationSpring then
        local targetTilt = randomRange(-EXIT_ROTATION_RANGE, EXIT_ROTATION_RANGE)
        rotationSpring.targetValue = targetTilt
        rotationSpring.value = (rotationSpring.value or 0.0) + targetTilt * 0.15
    end
end

local function attachSprings(item)
    if not spring or not registry then return end

    local scaleEntity = spring.make(registry, 1.0, SPRING_STIFFNESS, SPRING_DAMPING, {
        target = 1.0,
        smoothingFactor = SPRING_SMOOTHING,
        preventOvershoot = false,
        maxVelocity = SPRING_MAX_VELOCITY
    })
    item.scaleSpringEntity = scaleEntity

    local rotationEntity = spring.make(registry, 0.0, SPRING_STIFFNESS, SPRING_DAMPING, {
        target = 0.0,
        smoothingFactor = SPRING_SMOOTHING,
        preventOvershoot = false,
        maxVelocity = SPRING_MAX_VELOCITY
    })
    item.rotationSpringEntity = rotationEntity

    kickEntrySprings(item)
end

local function removeItemAt(index)
    local item = CastFeedUI.items[index]
    if item then
        destroyItemSprings(item)
    end
    table.remove(CastFeedUI.items, index)
end

local function clearItems()
    for i = #CastFeedUI.items, 1, -1 do
        removeItemAt(i)
    end
end

local function emitDemoEvent(entry)
    if not entry then return end

    if entry.kind == "spell_cast" then
        CastFeedUI.onSpellCast(entry.payload)
    elseif entry.kind == "joker" then
        CastFeedUI.onJokerTrigger(entry.payload)
    elseif entry.kind == "tag_discovery" then
        CastFeedUI.onTagDiscovery(entry.payload)
    elseif entry.kind == "spell_type_discovery" then
        CastFeedUI.onSpellTypeDiscovery(entry.payload)
    end
end

local function startDemoFeed()
    if not DEMO_FEED_ENABLED then return end

    timer.cancel(DEMO_FEED_TAG)
    CastFeedUI._demoIndex = 1

    timer.every(DEMO_FEED_INTERVAL, function()
        emitDemoEvent(DEMO_SEQUENCE[CastFeedUI._demoIndex])
        CastFeedUI._demoIndex = CastFeedUI._demoIndex + 1
        if CastFeedUI._demoIndex > #DEMO_SEQUENCE then
            CastFeedUI._demoIndex = 1
        end
    end, 0, true, nil, DEMO_FEED_TAG, "cast_feed_ui")
end

--- Stop the automatic demo feed
function CastFeedUI.stopDemoFeed()
    timer.cancel(DEMO_FEED_TAG)
end

--- Initialize the Cast Feed UI
function CastFeedUI.init()
    clearItems()
    CastFeedUI.isActive = true

    -- Subscribe to events once
    if not CastFeedUI._subscribed then
        signal.register("on_spell_cast", CastFeedUI.onSpellCast)
        signal.register("on_joker_trigger", CastFeedUI.onJokerTrigger)

        -- Subscribe to discovery events
        signal.register("tag_threshold_discovered", CastFeedUI.onTagDiscovery)
        signal.register("spell_type_discovered", CastFeedUI.onSpellTypeDiscovery)
        CastFeedUI._subscribed = true

        -- Board changes clear the feed
        signal.register(BOARD_CHANGE_SIGNAL, CastFeedUI.onBoardChanged)
    end

    startDemoFeed()

    print("[CastFeedUI] Initialized")
end

--- Update the UI (animation, fading)
--- @param dt number Delta time
function CastFeedUI.update(dt)
    if not CastFeedUI.isActive then return end

    for i = #CastFeedUI.items, 1, -1 do
        local item = CastFeedUI.items[i]
        item.age = item.age + dt

        -- Use different lifetime for discoveries
        local lifetime = item.isDiscovery and DISCOVERY_LIFETIME or ITEM_LIFETIME
        local fadeStart = lifetime - FADE_OUT_TIME
        local isFading = item.age >= fadeStart

        if isFading then
            if not item.fadeSpringsTriggered then
                triggerFadeOutSprings(item)
            end

            local fadeProgress = clamp01((item.age - fadeStart) / FADE_OUT_TIME)
            item.alpha = 1.0 - fadeProgress
        end

        -- Handle fade out
        if item.age >= lifetime then
            removeItemAt(i)
        end
    end
end

--- Draw the UI
function CastFeedUI.draw()
    if not CastFeedUI.isActive then return end

    local startX = globals.screenWidth() * 0.5
    local startY = globals.screenHeight() * 0.8 -- Bottom center
    local spacing = (FONT_SIZE + TEXT_PADDING_Y * 2) + 6
    local space = layer.DrawCommandSpace.Screen
    local zBase = z_orders.ui_tooltips + 9

    for i, item in ipairs(CastFeedUI.items) do
        local yPos = startY - ((#CastFeedUI.items - i) * spacing)

        local alpha = clamp01(item.alpha or 1.0)
        local scaleSpring = getItemSpring(item, "scale")
        local rotationSpring = getItemSpring(item, "rotation")
        local scale = math.max((scaleSpring and scaleSpring.value) or 1.0, 0.1)
        local rotation = (rotationSpring and rotationSpring.value) or 0.0
        
        -- Apply alpha to color
        local color = Col(item.color.r, item.color.g, item.color.b, alpha * 255)

        local textWidth = localization.getTextWidthWithCurrentFont(item.text, FONT_SIZE, 1)
        local boxWidth = textWidth + (TEXT_PADDING_X * 2)
        local boxHeight = FONT_SIZE + (TEXT_PADDING_Y * 2)
        local anchorX = startX
        local anchorY = yPos + boxHeight * 0.5

        local bgAlpha = math.floor((BACKGROUND_COLOR.a or 255) * alpha)
        local bgColor = Col(BACKGROUND_COLOR.r, BACKGROUND_COLOR.g, BACKGROUND_COLOR.b, bgAlpha)

        command_buffer.queuePushMatrix(layers.ui, function() end, zBase, space)
        command_buffer.queueTranslate(layers.ui, function(c)
            c.x = anchorX
            c.y = anchorY
        end, zBase, space)
        command_buffer.queueRotate(layers.ui, function(c)
            c.angle = rotation
        end, zBase, space)
        command_buffer.queueScale(layers.ui, function(c)
            c.scaleX = scale
            c.scaleY = scale
        end, zBase, space)

        -- Background rect (centered)
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = 0
            c.y = 0
            c.w = boxWidth
            c.h = boxHeight
            c.rx = BACKGROUND_RADIUS
            c.ry = BACKGROUND_RADIUS
            c.color = bgColor
        end, zBase, space)

        -- Text centered on the same anchor
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = item.text
            c.font = localization.getFont()
            c.x = -textWidth * 0.5
            c.y = -boxHeight * 0.5 + TEXT_PADDING_Y
            c.color = color
            c.fontSize = FONT_SIZE
        end, zBase, space)

        command_buffer.queuePopMatrix(layers.ui, function() end, zBase, space)
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

--- Event Handler: Board change / board dirty
function CastFeedUI.onBoardChanged()
    CastFeedUI._boardVersion = CastFeedUI._boardVersion + 1
    clearItems()
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
        isDiscovery = isDiscovery or false,
        boardVersion = CastFeedUI._boardVersion,
        fadeSpringsTriggered = false
    }

    attachSprings(item)
    table.insert(CastFeedUI.items, item)

    -- Cap list size
    if #CastFeedUI.items > FEED_MAX_ITEMS then
        removeItemAt(1)
    end
end

return CastFeedUI
