--[[
================================================================================
CAST BLOCK FLASH UI
================================================================================
Shows a short-lived row of cards whenever a cast block fires during the action
phase. The row:
- Pops in as rounded pills with the wand name above it
- Jiggles its rotation briefly
- Tweens card fill toward red, then fades out
]]--

local CastBlockFlashUI = {}

-- Dependencies
local z_orders = require("core.z_orders")
local entity_cache = require("core.entity_cache")

-- Configuration
local MAX_ITEMS = 3
local FLASH_LIFETIME = 1.25
local FADE_OUT_TIME = 0.35
local COLOR_TWEEN_TIME = 0.25
local JIGGLE_INTERVAL_MIN = 0.04
local JIGGLE_INTERVAL_MAX = 0.08
local JIGGLE_STRENGTH = 12
local SLIDE_DURATION = 0.25
local ENTRY_SCALE_START = 0.9
local EXIT_SCALE_TARGET = 0.8

local CARD_WIDTH = 48
local CARD_HEIGHT = 24
local CARD_RADIUS = 8
local CARD_SPACING = 6
local CARD_HIGHLIGHT_STEP = 0.08
local CARD_HIGHLIGHT_DURATION = 0.25

local HEADER_FONT_SIZE = 13
local CARD_FONT_SIZE = 12
local HEADER_SPACING = 6
local STACK_VERTICAL_GAP = 10
local BACKGROUND_PADDING_X = 12
local BACKGROUND_PADDING_Y = 8
local BACKGROUND_RADIUS = 12
local BACKGROUND_ALPHA = 255

local BLOCK_HEIGHT = BACKGROUND_PADDING_Y * 2 + HEADER_FONT_SIZE + HEADER_SPACING + CARD_HEIGHT
local STACK_SPACING = BLOCK_HEIGHT + STACK_VERTICAL_GAP

local SPRING_STIFFNESS = 220
local SPRING_DAMPING = 18
local SPRING_SMOOTHING = 0.85
local SPRING_MAX_VELOCITY = 26

-- State
CastBlockFlashUI.items = {}
CastBlockFlashUI.isActive = false

-- Utils
local function resolveColor(name, fallback, hardFallback)
    if util and util.getColor then
        local ok, c = pcall(util.getColor, name)
        if ok and c then return c end
        if fallback then
            local ok2, c2 = pcall(util.getColor, fallback)
            if ok2 and c2 then return c2 end
        end
    end
    return hardFallback or { r = 255, g = 255, b = 255, a = 255 }
end

local colors = {
    card = resolveColor("gold", "apricot", { r = 255, g = 210, b = 90, a = 255 }),
    cardIdle = resolveColor("pale_mint", "white", { r = 220, g = 240, b = 220, a = 255 }),
    highlight = resolveColor("red", nil, { r = 255, g = 70, b = 70, a = 255 }),
    text = resolveColor("black", nil, { r = 16, g = 16, b = 16, a = 255 }),
    wand = resolveColor("white", nil, { r = 255, g = 255, b = 255, a = 255 }),
    outline = resolveColor("black", nil, { r = 0, g = 0, b = 0, a = 255 }),
    backdrop = { r = 18, g = 18, b = 24, a = BACKGROUND_ALPHA },
}

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function easeOutCubic(t)
    local inv = 1 - t
    return 1 - (inv * inv * inv)
end

local function randomRange(min, max)
    return min + (max - min) * math.random()
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(a, b, t)
    return {
        r = lerp(a.r or 255, b.r or 255, t),
        g = lerp(a.g or 255, b.g or 255, t),
        b = lerp(a.b or 255, b.b or 255, t),
        a = lerp(a.a or 255, b.a or 255, t),
    }
end

local function measureText(text, size)
    if localization and localization.getTextWidthWithCurrentFont then
        return localization.getTextWidthWithCurrentFont(text, size, 1)
    end
    return (#tostring(text)) * size * 0.55
end

local function cardLabel(card)
    if not card then return "?" end
    if card.test_label and card.test_label ~= "" then
        return tostring(card.test_label)
    end
    return tostring(card.card_id or card.cardID or card.id or "?")
end

local function abbreviateLabel(label)
    label = tostring(label or "?")
    label = label:gsub("\n", " ")
    if #label <= 6 then return label end

    local words = {}
    for token in label:gmatch("%w+") do
        table.insert(words, token)
    end

    local abbrev = ""
    if #words > 1 then
        for _, w in ipairs(words) do
            abbrev = abbrev .. string.sub(w, 1, 1):upper()
            if #abbrev >= 4 then break end
        end
    end

    if #abbrev < 3 then
        local compact = label:gsub("[%s%p]+", "")
        abbrev = string.sub(compact, 1, 6)
    end

    return abbrev
end

local function buildTimeline(block, deck)
    local timeline = {}
    local usedLookup = {}
    local order = 0

    for _, card in ipairs(block.cards or {}) do
        order = order + 1
        usedLookup[card] = (order - 1) * CARD_HIGHLIGHT_STEP
    end

    local source = deck and #deck > 0 and deck or block.cards or {}
    for _, card in ipairs(source) do
        local start = usedLookup[card]
        table.insert(timeline, {
            label = abbreviateLabel(cardLabel(card)),
            start = start,
            used = start ~= nil
        })
    end

    if #timeline == 0 then
        table.insert(timeline, { label = "BLOCK", start = 0, used = true })
    end

    return timeline
end

local function destroySpringEntity(eid)
    if not registry or not eid or eid == entt_null then return end
    if registry.valid and not entity_cache.valid(eid) then return end
    registry:destroy(eid)
end

local function destroyItemSprings(item)
    if not item then return end
    destroySpringEntity(item.scaleSpringEntity)
    destroySpringEntity(item.rotationSpringEntity)
    item.scaleSpringEntity = nil
    item.rotationSpringEntity = nil
end

local function getItemSpring(item, kind)
    if not item then return nil end
    local entity = (kind == "scale") and item.scaleSpringEntity or item.rotationSpringEntity
    if not entity or not entity_cache.valid(entity) then return nil end
    local ok, ref = pcall(spring.get, registry, entity)
    if not ok then return nil end
    return ref
end

local function forceFadeOutSoon(item)
    if not item then return end
    local now = item.age or 0.0
    -- Clamp lifetime so this item fades out over the standard fade window
    local newLifetime = math.min(item.lifetime or FLASH_LIFETIME, now + FADE_OUT_TIME)
    item.lifetime = newLifetime

    local scaleSpring = getItemSpring(item, "scale")
    if scaleSpring then
        scaleSpring.targetValue = EXIT_SCALE_TARGET
    end
end

local function applyJiggle(item)
    local rotSpring = getItemSpring(item, "rotation")
    if rotSpring then
        local wobble = randomRange(-JIGGLE_STRENGTH, JIGGLE_STRENGTH)
        rotSpring.value = wobble
        rotSpring.targetValue = 0.0
        rotSpring.velocity = 0.0
    end
    item.jiggleCooldown = randomRange(JIGGLE_INTERVAL_MIN, JIGGLE_INTERVAL_MAX)
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

    local rotationEntity = spring.make(registry, 0.0, SPRING_STIFFNESS * 1.1, SPRING_DAMPING, {
        target = 0.0,
        smoothingFactor = SPRING_SMOOTHING,
        preventOvershoot = false,
        maxVelocity = SPRING_MAX_VELOCITY
    })
    item.rotationSpringEntity = rotationEntity

    local scaleSpring = getItemSpring(item, "scale")
    if scaleSpring then
        scaleSpring.value = ENTRY_SCALE_START
        scaleSpring.targetValue = 1.0
        scaleSpring.velocity = 0.0
    end

    applyJiggle(item)
end

local function computeAnchorY(index)
    if not globals then return 0 end
    local screenH = globals.screenHeight()
    return screenH * 0.18 + (index - 1) * STACK_SPACING
end

local function updateSlidePosition(item, index, dt)
    if not item then return end
    local targetY = computeAnchorY(index)

    if not item.currentY then
        item.currentY = targetY
        item.slideFromY = targetY
        item.slideToY = targetY
        item.slideTime = SLIDE_DURATION
        return
    end

    if item.slideToY ~= targetY then
        item.slideFromY = item.currentY or targetY
        item.slideToY = targetY
        item.slideTime = 0
    end

    if item.slideFromY and item.slideToY and item.slideTime < SLIDE_DURATION then
        item.slideTime = math.min(item.slideTime + dt, SLIDE_DURATION)
        local t = easeOutCubic(clamp01(item.slideTime / SLIDE_DURATION))
        item.currentY = lerp(item.slideFromY, item.slideToY, t)
    else
        item.currentY = item.slideToY or targetY
    end
end

local function removeItemAt(index)
    local item = CastBlockFlashUI.items[index]
    if item then
        destroyItemSprings(item)
    end
    table.remove(CastBlockFlashUI.items, index)
end

local function clearItems()
    for i = #CastBlockFlashUI.items, 1, -1 do
        removeItemAt(i)
    end
end

-- Public API
function CastBlockFlashUI.init()
    clearItems()
    CastBlockFlashUI.isActive = true
end

function CastBlockFlashUI.clear()
    clearItems()
    CastBlockFlashUI.isActive = false
end

--- Push a freshly executed cast block for visualization.
--- @param block table
--- @param opts table|nil { wandId = string }
function CastBlockFlashUI.pushBlock(block, opts)
    if not block or not block.cards or not CastBlockFlashUI.isActive then return end
    if not (registry and spring and command_buffer and layers and globals) then return end

    local item = {
        cards = buildTimeline(block, opts and opts.deck),
        wandName = opts and opts.wandId or "Wand",
        age = 0,
        alpha = 1.0,
        jiggleCooldown = 0.0,
        lifetime = FLASH_LIFETIME,
        jigglesTriggered = {},
    }

    attachSprings(item)
    table.insert(CastBlockFlashUI.items, item)

    if #CastBlockFlashUI.items > MAX_ITEMS then
        local overflow = #CastBlockFlashUI.items - MAX_ITEMS
        for i = 1, overflow do
            forceFadeOutSoon(CastBlockFlashUI.items[i])
        end
    end
end

function CastBlockFlashUI.update(dt)
    if not CastBlockFlashUI.isActive then return end

    for i = #CastBlockFlashUI.items, 1, -1 do
        local item = CastBlockFlashUI.items[i]
        item.age = item.age + dt
        item.alpha = 1.0

        -- Trigger jiggle when a used card reaches its start time
        for idx, card in ipairs(item.cards or {}) do
            if card.used and not item.jigglesTriggered[idx] and item.age >= (card.start or 0) then
                applyJiggle(item)
                item.jigglesTriggered[idx] = true
            end
        end

        -- Keep jiggling briefly after spawn
        if item.jiggleCooldown and item.age <= COLOR_TWEEN_TIME then
            item.jiggleCooldown = item.jiggleCooldown - dt
            if item.jiggleCooldown <= 0 then
                applyJiggle(item)
            end
        end

        -- Fade out near the end
        local lifetime = item.lifetime or FLASH_LIFETIME
        local fadeStart = lifetime - FADE_OUT_TIME
        if item.age >= fadeStart then
            local fadeProgress = clamp01((item.age - fadeStart) / FADE_OUT_TIME)
            item.alpha = 1.0 - fadeProgress
            local scaleSpring = getItemSpring(item, "scale")
            if scaleSpring then
                scaleSpring.targetValue = EXIT_SCALE_TARGET
            end
        end

        if item.age >= lifetime then
            removeItemAt(i)
        end
    end

    -- Update slide targets after removals so vertical motion starts the same frame
    for i, item in ipairs(CastBlockFlashUI.items) do
        updateSlidePosition(item, i, dt)
    end
end

local function drawItem(item, index)
    local renderAlpha = clamp01(item.alpha or 1.0)
    if renderAlpha <= 0 then return end

    local scaleSpring = getItemSpring(item, "scale")
    local rotationSpring = getItemSpring(item, "rotation")
    local scale = math.max((scaleSpring and scaleSpring.value) or 1.0, 0.01)
    local rotation = (rotationSpring and rotationSpring.value) or 0.0

    local screenW = globals.screenWidth()
    local anchorX = screenW * 0.5
    local anchorY = item.currentY or computeAnchorY(index)

    local colorMix = clamp01(item.age / COLOR_TWEEN_TIME)
    local defaultFill = lerpColor(colors.cardIdle, colors.card, colorMix)
    local cardColor = Col(math.floor(defaultFill.r), math.floor(defaultFill.g), math.floor(defaultFill.b), math.floor(renderAlpha * 255))
    local textColor = Col(math.floor(colors.text.r), math.floor(colors.text.g), math.floor(colors.text.b), math.floor(renderAlpha * 255))
    local wandColor = Col(math.floor(colors.wand.r), math.floor(colors.wand.g), math.floor(colors.wand.b), math.floor(renderAlpha * 255))

    local totalCards = #item.cards
    local rowWidth = totalCards * CARD_WIDTH + math.max(0, totalCards - 1) * CARD_SPACING
    local headerWidth = measureText(item.wandName, HEADER_FONT_SIZE)
    local bgWidth = math.max(rowWidth + BACKGROUND_PADDING_X * 2, headerWidth + BACKGROUND_PADDING_X * 2)
    local bgHeight = BLOCK_HEIGHT

    local space = layer.DrawCommandSpace.Screen
    local zBase = (z_orders.ui_tooltips or 0) + 10 -- single z so sorting keeps the matrix around all draws

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

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = 0
        c.y = 0
        c.w = bgWidth
        c.h = bgHeight
        c.rx = BACKGROUND_RADIUS
        c.ry = BACKGROUND_RADIUS
        local bgAlpha = math.floor(renderAlpha * (colors.backdrop.a or BACKGROUND_ALPHA))
        c.color = Col(math.floor(colors.backdrop.r), math.floor(colors.backdrop.g), math.floor(colors.backdrop.b), bgAlpha)
    end, zBase, space)

    -- Wand name
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = item.wandName or "Wand"
        c.font = localization.getFont and localization.getFont() or nil
        c.x = -headerWidth * 0.5 + 1
        c.y = -bgHeight * 0.5 + BACKGROUND_PADDING_Y + 1
        c.color = Col(0, 0, 0, math.floor(renderAlpha * 220))
        c.fontSize = HEADER_FONT_SIZE
    end, zBase, space)
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = item.wandName or "Wand"
        c.font = localization.getFont and localization.getFont() or nil
        c.x = -headerWidth * 0.5
        c.y = -bgHeight * 0.5 + BACKGROUND_PADDING_Y
        c.color = wandColor
        c.fontSize = HEADER_FONT_SIZE
    end, zBase, space)

    -- Cards row
    local startX = -rowWidth * 0.5
    local cardCenterY = -bgHeight * 0.5 + BACKGROUND_PADDING_Y + HEADER_FONT_SIZE + HEADER_SPACING + CARD_HEIGHT * 0.5

    for idx, cardInfo in ipairs(item.cards) do
        local cx = startX + (idx - 1) * (CARD_WIDTH + CARD_SPACING) + CARD_WIDTH * 0.5
        local label = cardInfo.label or "?"
        local start = cardInfo.start or 0
        local used = cardInfo.used

        local usedColor = cardColor
        if used and item.age >= start then
            local t = clamp01((item.age - start) / CARD_HIGHLIGHT_DURATION)
            local fill = lerpColor(colors.card, colors.highlight, t)
            usedColor = Col(math.floor(fill.r), math.floor(fill.g), math.floor(fill.b), math.floor(renderAlpha * 255))
        end

        -- Card outline for separation
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cardCenterY
            c.w = CARD_WIDTH + 4
            c.h = CARD_HEIGHT + 4
            c.rx = CARD_RADIUS + 2
            c.ry = CARD_RADIUS + 2
            c.color = Col(0, 0, 0, math.floor(renderAlpha * 255))
        end, zBase, space)

        -- Card body
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cardCenterY
            c.w = CARD_WIDTH
            c.h = CARD_HEIGHT
            c.rx = CARD_RADIUS
            c.ry = CARD_RADIUS
            c.color = usedColor
        end, zBase, space)

        -- Text shadow for readability
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = label
            c.font = localization.getFont and localization.getFont() or nil
            local tw = measureText(label, CARD_FONT_SIZE)
            c.x = cx - tw * 0.5 + 1
            c.y = cardCenterY - CARD_HEIGHT * 0.5 + (CARD_HEIGHT - CARD_FONT_SIZE) * 0.5 + 1
            c.color = Col(0, 0, 0, math.floor(renderAlpha * 255))
            c.fontSize = CARD_FONT_SIZE
        end, zBase, space)
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = label
            c.font = localization.getFont and localization.getFont() or nil
            local tw = measureText(label, CARD_FONT_SIZE)
            c.x = cx - tw * 0.5
            c.y = cardCenterY - CARD_HEIGHT * 0.5 + (CARD_HEIGHT - CARD_FONT_SIZE) * 0.5
            c.color = textColor
            c.fontSize = CARD_FONT_SIZE
        end, zBase, space)
    end

    command_buffer.queuePopMatrix(layers.ui, function() end, zBase, space)
end

function CastBlockFlashUI.draw()
    if not CastBlockFlashUI.isActive then return end
    if not layers or not command_buffer or not globals or not layer then return end

    for i, item in ipairs(CastBlockFlashUI.items) do
        drawItem(item, i)
    end
end

return CastBlockFlashUI
