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

local DEFAULT_TEST_MESSAGE = "Achievement unlocked!"
local DEFAULT_ICON = {
    animationId = "discord_icon_anim",  -- falls back to sprite if needed
    spriteId = "test_char_woman.png",
    size = 52
}

local DEFAULT_CONFIG = {
    maxVisible = 3,
    lifetime = 4.0,
    fadeIn = 0.22,
    fadeOut = 0.45,
    minWidth = 300,
    maxWidth = 540,
    height = 96,
    padding = 16,
    iconPadding = 12,
    marginX = 28,
    marginY = 28,
    stackSpacing = 12,
    cornerRadius = 14,
    iconSize = 52,
    fontSize = 24,
    baseZ = z_orders.ui_tooltips + 8,
    bgColor = { r = 12, g = 12, b = 16, a = 220 },
    accentColor = util.getColor("gold"),
    textColor = util.getColor("white"),
    accentWidth = 6
}

MessageQueueUI.pending = {}
MessageQueueUI.active = {}
MessageQueueUI.isActive = false

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
    if icon.entity and icon.entity ~= entt_null and entity_cache.valid(icon.entity) then
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
    local cfg = MessageQueueUI.config
    while #MessageQueueUI.active < cfg.maxVisible and #MessageQueueUI.pending > 0 do
        local nextItem = table.remove(MessageQueueUI.pending, 1)
        nextItem.age = 0
        table.insert(MessageQueueUI.active, nextItem)
    end
end

function MessageQueueUI.init(opts)
    MessageQueueUI.reset()
    MessageQueueUI.config = shallowCopy(DEFAULT_CONFIG)
    mergeConfig(MessageQueueUI.config, opts)
    MessageQueueUI.isActive = true
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
        item.age = item.age + dt

        if item.age >= item.lifetime then
            destroyIcon(item.icon)
            table.remove(MessageQueueUI.active, i)
        end
    end

    promotePending()
end

local function computeAlpha(age, lifetime, fadeIn, fadeOut)
    local alphaIn = fadeIn > 0 and clamp01(age / fadeIn) or 1
    local remaining = lifetime - age
    local alphaOut = (fadeOut > 0 and remaining < fadeOut)
        and clamp01(remaining / fadeOut)
        or 1
    return clamp01(math.min(alphaIn, alphaOut))
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
    local total = #MessageQueueUI.active

    for i, item in ipairs(MessageQueueUI.active) do
        local rawText = item.text or ""
        local textWidth = localization.getTextWidthWithCurrentFont(rawText, cfg.fontSize, 1)
        local idealWidth = textWidth + cfg.padding * 2 + cfg.iconSize + cfg.iconPadding
        local boxWidth = math.max(cfg.minWidth, math.min(cfg.maxWidth, idealWidth))
        local boxHeight = cfg.height
        local availableTextWidth = boxWidth - (cfg.padding * 2 + cfg.iconSize + cfg.iconPadding)

        -- Stack upward from the bottom-right so the newest toast sits closest to the corner.
        local stackIndex = total - i
        local centerX = baseX - boxWidth * 0.5
        local centerY = baseY - stackIndex * (boxHeight + cfg.stackSpacing) - boxHeight * 0.5

        local alpha = computeAlpha(item.age, item.lifetime, cfg.fadeIn, cfg.fadeOut)
        local bgColor = colWithAlpha(item.bgColor, alpha)
        local textColor = colWithAlpha(item.textColor, alpha)
        local accentColor = colWithAlpha(item.accentColor, alpha)

        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = centerX
            c.y = centerY
            c.w = boxWidth
            c.h = boxHeight
            c.rx = cfg.cornerRadius
            c.ry = cfg.cornerRadius
            c.color = bgColor
        end, cfg.baseZ, space)

        -- Accent stripe on the left edge
        command_buffer.queueDrawRectangle(layers.ui, function(c)
            c.x = centerX - boxWidth * 0.5
            c.y = centerY
            c.width = cfg.accentWidth
            c.height = boxHeight
            c.color = accentColor
            c.lineWidth = 0
        end, cfg.baseZ + 1, space)

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
        end, cfg.baseZ + 2, space)

        drawIcon(item, boxWidth, boxHeight, centerX, centerY, alpha, cfg.baseZ +100, space)
    end
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
