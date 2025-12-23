--[[
Notification/message queue UI.
Displays stacked rounded-rect toasts with text and an icon (sprite or animation)
anchored to the bottom-right of the screen. Intended for achievements or other
lightweight notices.
]]

local MessageQueueUI = {}

local z_orders = require("core.z_orders")
local timer = require("core.timer")
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local Easing = require("util.easing")

local DEFAULT_TEST_MESSAGE = "Achievement unlocked!"
local DEFAULT_ICON = {
    animationId = "discord_icon_anim",  -- falls back to sprite if needed
    spriteId = "test_char_woman.png",
    size = 26
}

local DEFAULT_CONFIG = {
    maxVisible = 1,          -- now one-at-a-time
    enterDuration = 0.38,
    holdDuration = 2.8,
    exitDuration = 0.55,
    minWidth = 160,
    maxWidth = 240,
    height = 72,
    padding = 12,
    iconPadding = 8,
    marginX = 36,
    marginY = 44,
    cornerRadius = 14,
    iconSize = 26,
    fontSize = 14,
    baseZ = z_orders.ui_tooltips + 8,
    bgColor = { r = 14, g = 14, b = 24, a = 235 },
    accentColor = util.getColor("gold"),
    textColor = util.getColor("white"),
    shadowColor = Col(4, 8, 14, 140),
    accentWidth = 5,
    borderColor = Col(255, 255, 255, 70),
    slideDistance = 180
}

MessageQueueUI.pending = {}
MessageQueueUI.active = {}
MessageQueueUI.isActive = false
MessageQueueUI._timeSinceLastShow = 0
MessageQueueUI.onItemShown = nil

local function clamp01(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function shallowCopy(src)
    local out = {}
    for k, v in pairs(src or {}) do
        out[k] = v
    end
    return out
end

local function mergeConfig(target, src)
    if not src then return end
    for k, v in pairs(src) do
        target[k] = v
    end
end

MessageQueueUI.config = shallowCopy(DEFAULT_CONFIG)

local function colWithAlpha(color, alpha)
    if not color then
        return Col(255, 255, 255, math.floor(alpha * 255))
    end
    local a = math.floor((color.a or 255) * alpha)
    return Col(color.r or 255, color.g or 255, color.b or 255, a)
end

local function destroyIcon(icon)
    if not icon or not registry or not registry.valid then return end
    if ensure_entity(icon.entity) then
        registry:destroy(icon.entity)
    end
end

local function tryMakeIcon(id, forceSprite, size)
    if not animation_system or not id then return nil end

    local entity = animation_system.createAnimatedObjectWithTransform(id, forceSprite or false, 0, 0, nil, false)
    if not entity or entity == entt_null or not entity_cache.valid(entity) then
        return nil
    end
    
    transform.set_space(entity, "screen")
    if registry and registry.valid and ObjectAttachedToUITag and registry:valid(entity) then
        -- Keep icons out of the world/sprite render pass so we can render them on the UI layer manually.
        if not registry:has(entity, ObjectAttachedToUITag) then
            registry:emplace(entity, ObjectAttachedToUITag)
        end
    end
    

    animation_system.resizeAnimationObjectsInEntityToFit(entity, size, size)
    animation_system.setFGColorForAllAnimationObjects(entity, Col(255, 255, 255, 255))

    return {
        entity = entity,
        id = id,
        size = size,
        forceSprite = forceSprite
    }
end

local function buildIcon(opts, config)
    local size = (opts and (opts.iconSize or opts.size)) or config.iconSize or DEFAULT_ICON.size

    -- Prefer explicit animation, then explicit sprite, then defaults.
    local icon = nil
    if opts then
        if opts.iconAnimation or opts.animationId or opts.animation then
            icon = tryMakeIcon(opts.iconAnimation or opts.animationId or opts.animation, false, size)
        end
        if not icon and (opts.iconSprite or opts.spriteId or opts.sprite) then
            icon = tryMakeIcon(opts.iconSprite or opts.spriteId or opts.sprite, true, size)
        end
    end

    if not icon then
        icon = tryMakeIcon(DEFAULT_ICON.animationId, false, size)
    end
    if not icon then
        icon = tryMakeIcon(DEFAULT_ICON.spriteId, true, size)
    end

    return icon
end

local function makeItem(text, opts)
    local cfg = MessageQueueUI.config
    local item = {
        text = text or DEFAULT_TEST_MESSAGE,
        lifetime = (opts and opts.duration) or cfg.lifetime,
        age = 0,
        bgColor = (opts and opts.bgColor) or cfg.bgColor,
        accentColor = (opts and opts.accentColor) or cfg.accentColor,
        textColor = (opts and opts.textColor) or cfg.textColor,
        iconColor = opts and (opts.iconColor or opts.iconTint or opts.tintColor),
        icon = buildIcon(opts, cfg)
    }
    return item
end

local function promotePending()
    if #MessageQueueUI.active > 0 then return end
    if #MessageQueueUI.pending == 0 then return end

    local nextItem = table.remove(MessageQueueUI.pending, 1)
    nextItem.state = "enter"
    nextItem.t = 0
    table.insert(MessageQueueUI.active, nextItem)
    if MessageQueueUI.onItemShown then
        pcall(MessageQueueUI.onItemShown, nextItem)
    end
    playSoundEffect("effects", "new_achievement")
end

function MessageQueueUI.init(opts)
    MessageQueueUI.reset()
    MessageQueueUI.config = shallowCopy(DEFAULT_CONFIG)
    mergeConfig(MessageQueueUI.config, opts)
    MessageQueueUI.isActive = true
    MessageQueueUI._timeSinceLastShow = 0
end

function MessageQueueUI.reset()
    for _, item in ipairs(MessageQueueUI.active) do
        destroyIcon(item.icon)
    end
    for _, item in ipairs(MessageQueueUI.pending) do
        destroyIcon(item.icon)
    end
    MessageQueueUI.pending = {}
    MessageQueueUI.active = {}
    MessageQueueUI._timeSinceLastShow = DEFAULT_CONFIG.spawnInterval or 0
end

function MessageQueueUI.enqueue(text, opts)
    if not MessageQueueUI.isActive then
        MessageQueueUI.init()
    end

    local item = makeItem(text, opts)
    table.insert(MessageQueueUI.pending, item)
    promotePending()
end

function MessageQueueUI.enqueueTest()
    MessageQueueUI.enqueue(DEFAULT_TEST_MESSAGE, {
        animation = DEFAULT_ICON.animationId,
        iconSize = DEFAULT_ICON.size
    })
end

function MessageQueueUI.update(dt)
    if not MessageQueueUI.isActive then return end
    if not dt then dt = GetFrameTime() end

    for i = #MessageQueueUI.active, 1, -1 do
        local item = MessageQueueUI.active[i]
        item.t = (item.t or 0) + dt

        if item.state == "enter" and item.t >= MessageQueueUI.config.enterDuration then
            item.state = "hold"
            item.t = 0
        elseif item.state == "hold" and item.t >= MessageQueueUI.config.holdDuration then
            item.state = "exit"
            item.t = 0
        elseif item.state == "exit" and item.t >= MessageQueueUI.config.exitDuration then
            destroyIcon(item.icon)
            table.remove(MessageQueueUI.active, i)
        end
    end

    MessageQueueUI._timeSinceLastShow = (MessageQueueUI._timeSinceLastShow or 0) + dt
    promotePending()
end

function MessageQueueUI.setOnShow(callback)
    MessageQueueUI.onItemShown = callback
end

local function stateAlpha(item)
    local cfg = MessageQueueUI.config
    if item.state == "enter" then
        local p = clamp01(item.t / cfg.enterDuration)
        return Easing.outQuad.f(p)
    elseif item.state == "exit" then
        local p = clamp01(item.t / cfg.exitDuration)
        return 1 - Easing.inQuad.f(p)
    end
    return 1
end

local function wrapTextToWidth(text, maxWidth, fontSize)
    if not text or text == "" then return "" end
    local spaceWidth = localization.getTextWidthWithCurrentFont(" ", fontSize, 1)
    local lines = {}
    local current = ""
    local currentWidth = 0

    for word in text:gmatch("%S+") do
        local w = localization.getTextWidthWithCurrentFont(word, fontSize, 1)
        if current == "" then
            current = word
            currentWidth = w
        elseif currentWidth + spaceWidth + w <= maxWidth then
            current = current .. " " .. word
            currentWidth = currentWidth + spaceWidth + w
        else
            table.insert(lines, current)
            current = word
            currentWidth = w
        end
    end
    if current ~= "" then
        table.insert(lines, current)
    end

    return table.concat(lines, "\n")
end

local function drawIcon(item, boxWidth, boxHeight, centerX, centerY, alpha, z, space)
    if not item.icon or not item.icon.entity or not registry or not registry.valid or not registry:valid(item.icon.entity) then
        return
    end

    local cfg = MessageQueueUI.config
    local size = item.icon.size or cfg.iconSize
    local iconCenterX = centerX - (boxWidth * 0.5) + cfg.padding + size * 0.5
    local iconCenterY = centerY
    local iconTint = colWithAlpha(item.iconColor or item.accentColor or cfg.accentColor or cfg.textColor, alpha)

    local transform = component_cache.get(item.icon.entity, Transform)
    if transform then
        transform.actualX = iconCenterX - size * 0.5
        transform.actualY = iconCenterY - size * 0.5
        transform.visualX = transform.actualX
        transform.visualY = transform.actualY
        transform.actualW = size
        transform.actualH = size
        transform.visualW = size
        transform.visualH = size
        if transform.markDirty then
            transform:markDirty()
        end
    end

    -- Match fade with the toast and ensure the engine renders it above the toast.
    if animation_system and animation_system.setFGColorForAllAnimationObjects then
        animation_system.setFGColorForAllAnimationObjects(item.icon.entity, iconTint)
    end
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(item.icon.entity, z)
    end

    -- Manually queue the icon onto the UI layer (screen space) so it sits above the toast background.
    if command_buffer and layers and layers.ui then
        local hasPipeline = false
        if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
            hasPipeline = registry:has(item.icon.entity, shader_pipeline.ShaderPipelineComponent)
        end

        local queue = hasPipeline
            and command_buffer.queueDrawTransformEntityAnimationPipeline
            or command_buffer.queueDrawTransformEntityAnimation

        if queue then
            queue(layers.ui, function(cmd)
                cmd.registry = registry
                cmd.e = item.icon.entity
            end, z, space or layer.DrawCommandSpace.Screen)
        end
    end
end

function MessageQueueUI.draw()
    if not MessageQueueUI.isActive or #MessageQueueUI.active == 0 then return end

    local cfg = MessageQueueUI.config
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    if not screenW or not screenH then return end

    local baseX = screenW - cfg.marginX
    local baseY = screenH - cfg.marginY
    local space = layer.DrawCommandSpace.Screen
    local font = localization.getFont()
    local item = MessageQueueUI.active[1]
    local rawText = item.text or ""
    local textWidth = localization.getTextWidthWithCurrentFont(rawText, cfg.fontSize, 1)
    local idealWidth = textWidth + cfg.padding * 2 + cfg.iconSize + cfg.iconPadding
    local boxWidth = math.max(cfg.minWidth, math.min(cfg.maxWidth, idealWidth))
    local boxHeight = cfg.height
    local availableTextWidth = boxWidth - (cfg.padding * 2 + cfg.iconSize + cfg.iconPadding)
    local cornerRadius = cfg.cornerRadius or DEFAULT_CONFIG.cornerRadius or 0
    local borderWidth = 2
    local borderRadius = cornerRadius + borderWidth
    local bodyZ = cfg.baseZ + 1
    local accentZ = bodyZ + 1
    local textZ = accentZ + 1

    local alpha = stateAlpha(item)
    local slideDist = cfg.slideDistance or (boxWidth + 40)
    local offset = 0
    if item.state == "enter" then
        local p = clamp01(item.t / cfg.enterDuration)
        offset = (1 - Easing.outQuad.f(p)) * slideDist
    elseif item.state == "exit" then
        local p = clamp01(item.t / cfg.exitDuration)
        offset = Easing.outBack.f(p) * slideDist
    end

    local centerX = baseX - boxWidth * 0.5 + offset
    local centerY = baseY - boxHeight * 0.5

    local bgColor = colWithAlpha(item.bgColor, alpha)
    local textColor = colWithAlpha(item.textColor, alpha)
    local accentColor = colWithAlpha(item.accentColor, alpha)
    local shadowColor = colWithAlpha(cfg.shadowColor, alpha)

    -- Drop shadow
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = centerX + 6
        c.y = centerY + 10
        c.w = boxWidth + 14
        c.h = boxHeight + 10
        c.rx = cornerRadius + 6
        c.ry = cornerRadius + 6
        c.color = shadowColor
    end, cfg.baseZ - 1, space)

    -- Border
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = centerX
        c.y = centerY
        c.w = boxWidth + borderWidth * 2
        c.h = boxHeight + borderWidth * 2
        c.rx = borderRadius
        c.ry = borderRadius
        c.color = colWithAlpha(cfg.borderColor, alpha)
    end, cfg.baseZ, space)

    -- Main body
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = centerX
        c.y = centerY
        c.w = boxWidth
        c.h = boxHeight
        c.rx = cornerRadius
        c.ry = cornerRadius
        c.color = bgColor
    end, bodyZ, space)

    -- Accent slash
    local slashX1 = centerX + boxWidth * 0.2
    local slashX2 = centerX + boxWidth * 0.45
    local slashY1 = centerY - boxHeight * 0.55
    local slashY2 = centerY + boxHeight * 0.6
    command_buffer.queueDrawLine(layers.ui, function(c)
        c.x1 = slashX1
        c.y1 = slashY1
        c.x2 = slashX2
        c.y2 = slashY2
        c.lineWidth = cfg.accentWidth
        c.color = accentColor
    end, accentZ, space)

    command_buffer.queueDrawText(layers.ui, function(c)
        local function wrapAndMeasure(fontSize)
            local wrapped = wrapTextToWidth(rawText, availableTextWidth, fontSize)
            local maxLineWidth = 0
            for line in wrapped:gmatch("[^\n]+") do
                local w = localization.getTextWidthWithCurrentFont(line, fontSize, 1)
                if w > maxLineWidth then maxLineWidth = w end
            end
            return wrapped, maxLineWidth
        end

        local fontSize = cfg.fontSize
        local wrappedText, maxLineWidth = wrapAndMeasure(fontSize)
        if maxLineWidth > availableTextWidth and maxLineWidth > 0 then
            local ratio = availableTextWidth / maxLineWidth
            fontSize = math.max(12, math.floor(fontSize * ratio))
            wrappedText, maxLineWidth = wrapAndMeasure(fontSize)
        end

        local lineCount = select(2, wrappedText:gsub("\n", "")) + 1
        local textBlockHeight = lineCount * fontSize * 1.05
        local maxHeight = boxHeight - cfg.padding * 2
        if textBlockHeight > maxHeight and lineCount > 0 then
            local ratio = maxHeight / textBlockHeight
            fontSize = math.max(10, math.floor(fontSize * ratio))
            wrappedText, maxLineWidth = wrapAndMeasure(fontSize)
            lineCount = select(2, wrappedText:gsub("\n", "")) + 1
            textBlockHeight = lineCount * fontSize * 1.05
        end

        c.text = wrappedText
        c.font = font
        c.x = centerX - boxWidth * 0.5 + cfg.padding + cfg.iconSize + cfg.iconPadding
        c.y = centerY - textBlockHeight * 0.5
        c.color = textColor
        c.fontSize = fontSize
    end, textZ, space)

    drawIcon(item, boxWidth, boxHeight, centerX, centerY, alpha, cfg.baseZ + 100, space)
end

function MessageQueueUI.startDemo(interval)
    interval = interval or 6.5
    timer.every(interval, function()
        MessageQueueUI.enqueue(DEFAULT_TEST_MESSAGE, {
            animation = DEFAULT_ICON.animationId,
            iconSize = DEFAULT_ICON.size
        })
    end, 0, true, nil, "message_queue_ui_demo")
end

return MessageQueueUI
