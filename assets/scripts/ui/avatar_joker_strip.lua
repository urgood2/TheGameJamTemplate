--[[
Avatar & Joker Strip (manual layout)
Shows equipped avatars on the bottom-left and active jokers on the bottom-right
as lightweight animated sprites. Backgrounds and labels are drawn via
command_buffer; sprites are standalone animated entities sized smaller than
cards. Tooltips are attached directly to the sprite entities.
]]

local AvatarJokerStrip = {}

local z_orders = require("core.z_orders")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local JokerSystem = require("wand.joker_system")
local avatarDefs = require("data.avatars")

AvatarJokerStrip.isActive = false
AvatarJokerStrip.avatars = {}
AvatarJokerStrip.jokers = {}
AvatarJokerStrip.avatarSprites = {}
AvatarJokerStrip.jokerSprites = {}
AvatarJokerStrip._dirty = true
AvatarJokerStrip._avatarSig = ""
AvatarJokerStrip._jokerSig = ""
AvatarJokerStrip._layoutCache = nil
AvatarJokerStrip._activeTooltipOwner = nil
AvatarJokerStrip._fallbackHover = nil

AvatarJokerStrip.layout = {
    margin = 14,
    pad = 10,
    spacing = 8,
    cardW = 48,
    cardH = 64,
    labelSize = 14,
    bgRadius = 12,
    rotateAmplitude = 6,
    floatSpeed = 1.3,
    glowPadding = 8,
    glowBaseAlpha = 55,
    glowPulseAlpha = 70,
    glowPulseSpeed = 1.6,
    avatarSprite = "4165-TheRoguelike_1_10_alpha_958.png",
    jokerSprite = "4169-TheRoguelike_1_10_alpha_962.png"
}

local colors = {
    panel = Col(12, 14, 24, 205),
    outline = util.getColor("apricot_cream"),
    avatarAccent = util.getColor("mint_green"),
    jokerAccent = util.getColor("gold"),
    text = util.getColor("white"),
    muted = util.getColor("gray"),
    divider = Col(80, 90, 110, 180)
}

local function now()
    if GetTime then return GetTime() end
    return os.clock()
end

local function makeSignature(list)
    local parts = {}
    for _, item in ipairs(list or {}) do
        table.insert(parts, string.format("%s|%s|%s",
            item.id or "?", item.name or "?", item.rarity or ""))
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function destroyList(list)
    if not list then return end
    for _, item in ipairs(list) do
        if item.entity and registry and registry.valid and registry:valid(item.entity) then
            registry:destroy(item.entity)
        end
    end
end

local function applyTooltip(entity, title, body)
    if not entity or not component_cache then return end
    local go = component_cache.get(entity, GameObject)
    if not go then return end

    local state = go.state
    local methods = go.methods
    if not state or not methods then return end

    state.hoverEnabled = true
    state.collisionEnabled = true
    state.triggerOnReleaseEnabled = true
    state.clickEnabled = true

    local function canShowTooltip()
        return showTooltip
            and globals and globals.ui
            and globals.ui.tooltipTitleText
            and globals.ui.tooltipBodyText
            and globals.ui.tooltipUIBox
    end

    methods.onHover = function()
        if canShowTooltip() then
            showTooltip(title or "Unknown", body or "")
            AvatarJokerStrip._activeTooltipOwner = entity
        else
            AvatarJokerStrip._fallbackHover = {
                entity = entity,
                title = title or "Unknown",
                body = body or ""
            }
        end
    end

    methods.onStopHover = function()
        if AvatarJokerStrip._activeTooltipOwner and AvatarJokerStrip._activeTooltipOwner ~= entity then
            return
        end
        if hideTooltip then hideTooltip() end
        AvatarJokerStrip._activeTooltipOwner = nil
        if AvatarJokerStrip._fallbackHover and AvatarJokerStrip._fallbackHover.entity == entity then
            AvatarJokerStrip._fallbackHover = nil
        end
    end
end

local function dummyData()
    return {
        avatars = {
            {
                id = "wildfire",
                name = "Avatar of Wildfire",
                description = "Dummy avatar: flames tick faster and hits chain.",
                sprite = AvatarJokerStrip.layout.avatarSprite
            }
        },
        jokers = {
            {
                id = "tag_master",
                name = "Tag Master",
                description = "Scales off total tags. Placeholder effect text.",
                rarity = "Uncommon",
                sprite = AvatarJokerStrip.layout.jokerSprite
            }
        }
    }
end

local function createSprite(entry, defaultSprite, accent)
    if not animation_system then return nil end

    local spriteId = entry.sprite or defaultSprite
    local entity = animation_system.createAnimatedObjectWithTransform(spriteId, true, 0, 0, nil, false)
    if not entity or entity == entt_null or not (entity_cache.valid and entity_cache.valid(entity)) then
        return nil
    end

    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end

    if registry and registry.valid and ObjectAttachedToUITag and registry:valid(entity) then
        if not registry:has(entity, ObjectAttachedToUITag) then
            registry:emplace(entity, ObjectAttachedToUITag)
        end
    end

    animation_system.resizeAnimationObjectsInEntityToFit(entity,
        AvatarJokerStrip.layout.cardW, AvatarJokerStrip.layout.cardH)
    animation_system.setFGColorForAllAnimationObjects(entity, accent or Col(255, 255, 255, 255))

    applyTooltip(entity, entry.name or entry.id, entry.description)

    return entity
end

local function rebuildSprites()
    destroyList(AvatarJokerStrip.avatarSprites)
    destroyList(AvatarJokerStrip.jokerSprites)
    AvatarJokerStrip.avatarSprites = {}
    AvatarJokerStrip.jokerSprites = {}

    for _, a in ipairs(AvatarJokerStrip.avatars or {}) do
        local entity = createSprite(a, AvatarJokerStrip.layout.avatarSprite, colors.avatarAccent)
        if entity then
            table.insert(AvatarJokerStrip.avatarSprites, {
                id = a.id,
                name = a.name,
                rarity = a.rarity,
                entity = entity,
                description = a.description
            })
        end
    end

    for _, j in ipairs(AvatarJokerStrip.jokers or {}) do
        local entity = createSprite(j, AvatarJokerStrip.layout.jokerSprite, colors.jokerAccent)
        if entity then
            table.insert(AvatarJokerStrip.jokerSprites, {
                id = j.id,
                name = j.name,
                rarity = j.rarity,
                entity = entity,
                description = j.description
            })
        end
    end

    AvatarJokerStrip._dirty = false
end

local function computeLayout(list, anchorRight, title)
    local layout = AvatarJokerStrip.layout
    local screenW = (globals.screenWidth and globals.screenWidth()) or (globals.getScreenWidth and globals.getScreenWidth()) or 1920
    local screenH = (globals.screenHeight and globals.screenHeight()) or (globals.getScreenHeight and globals.getScreenHeight()) or 1080

    local count = math.max(1, #list)
    local contentW = count * layout.cardW + math.max(0, count - 1) * layout.spacing
    local w = contentW + layout.pad * 2
    local label = title or ""
    local labelW = 0
    if localization and localization.getTextWidthWithCurrentFont then
        labelW = localization.getTextWidthWithCurrentFont(label, layout.labelSize, 1)
    end
    if labelW > 0 then
        w = math.max(w, labelW + layout.pad * 2)
    end
    local h = layout.pad * 2 + layout.cardH + layout.labelSize + 6

    local x = anchorRight and (screenW - layout.margin - w) or layout.margin
    local y = screenH - layout.margin - h

    return {
        x = x,
        y = y,
        w = w,
        h = h,
        startX = x + layout.pad,
        startY = y + layout.pad + layout.labelSize + 4,
        titleX = x + layout.pad,
        titleY = y + layout.pad - 2,
        title = title or "",
        screenW = screenW,
        screenH = screenH
    }
end

local function applyTransforms(list, box, baseZ, opts)
    local layout = AvatarJokerStrip.layout
    local animate = opts and opts.animate
    local tNow = animate and now() or 0
    local function easedSine(time, phase)
        local raw = math.sin(time + phase)
        if not animate then return raw end
        local tNorm = (raw + 1) * 0.5
        local eased = (3 - 2 * tNorm) * tNorm * tNorm -- simple quad-ish ease (smoothstep)
        return eased * 2 - 1 -- back to [-1,1]
    end

    for i, item in ipairs(list) do
        if item.entity and registry and registry.valid and registry:valid(item.entity) then
            local t = component_cache.get(item.entity, Transform)
            if t then
                local x = box.startX + (i - 1) * (layout.cardW + layout.spacing)
                local y = box.startY

                t.actualX = x
                t.actualY = y
                t.visualX = t.actualX
                t.visualY = t.actualY
                t.actualW = layout.cardW
                t.actualH = layout.cardH
                t.visualW = layout.cardW
                t.visualH = layout.cardH
                local angle = 0
                if animate then
                    local phase = (i - 1) * 0.7
                    angle = easedSine(tNow * layout.floatSpeed, phase) * layout.rotateAmplitude
                end
                t.actualR = angle
                t.visualR = angle
                if t.markDirty then t:markDirty() end
            end

            if layer_order_system and layer_order_system.assignZIndexToEntity then
                layer_order_system.assignZIndexToEntity(item.entity, baseZ + 3)
            end
        end
    end
end

local function drawSprites(list, z, space)
    if not command_buffer or not layers or not layers.ui then return end

    for _, item in ipairs(list) do
        if item.entity and registry and registry.valid and registry:valid(item.entity) then
            local hasPipeline = false
            if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
                hasPipeline = registry:has(item.entity, shader_pipeline.ShaderPipelineComponent)
            end

            local queue = hasPipeline and command_buffer.queueDrawTransformEntityAnimationPipeline
                or command_buffer.queueDrawTransformEntityAnimation

            if queue then
                queue(layers.ui, function(cmd)
                    cmd.registry = registry
                    cmd.e = item.entity
                end, z, space or layer.DrawCommandSpace.Screen)
            end
        end
    end
end

local function drawGlow(list, accent, z, space)
    if not command_buffer or not layers or not list then return end
    local layout = AvatarJokerStrip.layout
    local pulseTime = now() * layout.glowPulseSpeed

    for i, item in ipairs(list) do
        if item.entity and registry and registry.valid and registry:valid(item.entity) then
            local t = component_cache.get(item.entity, Transform)
            if t then
                local pulse = 0.5 + 0.5 * math.sin(pulseTime + i * 0.8)
                local alpha = layout.glowBaseAlpha + layout.glowPulseAlpha * pulse
                local color = accent or colors.jokerAccent
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                    c.x = t.actualX + (t.actualW or layout.cardW) * 0.5
                    c.y = t.actualY + (t.actualH or layout.cardH) * 0.5
                    c.w = (t.actualW or layout.cardW) + layout.glowPadding * 2
                    c.h = (t.actualH or layout.cardH) + layout.glowPadding * 2
                    c.rx = layout.bgRadius + 4
                    c.ry = layout.bgRadius + 4
                    c.color = Col(color.r, color.g, color.b, math.min(255, math.max(0, math.floor(alpha))))
                end, z, space or layer.DrawCommandSpace.Screen)
            end
        end
    end
end

local function drawGroup(box, accent, label, baseZ)
    if not command_buffer or not layers then return end
    local space = layer.DrawCommandSpace.Screen
    local radius = AvatarJokerStrip.layout.bgRadius
    local font = localization.getFont()

    -- Outline layer (slightly larger)
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = box.x + box.w * 0.5
        c.y = box.y + box.h * 0.5
        c.w = box.w + 4
        c.h = box.h + 4
        c.rx = radius + 2
        c.ry = radius + 2
        c.color = colors.outline
    end, baseZ, space)

    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
        c.x = box.x + box.w * 0.5
        c.y = box.y + box.h * 0.5
        c.w = box.w
        c.h = box.h
        c.rx = radius
        c.ry = radius
        c.color = colors.panel
    end, baseZ + 1, space)

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = label
        c.font = font
        c.x = box.titleX
        c.y = box.titleY
        c.color = accent
        c.fontSize = AvatarJokerStrip.layout.labelSize
    end, baseZ + 2, space)
end

function AvatarJokerStrip.setData(data)
    local avatars = data.avatars or {}
    local jokers = data.jokers or {}
    local avatarSig = makeSignature(avatars)
    local jokerSig = makeSignature(jokers)

    if avatarSig == AvatarJokerStrip._avatarSig and jokerSig == AvatarJokerStrip._jokerSig then
        return
    end

    AvatarJokerStrip._avatarSig = avatarSig
    AvatarJokerStrip._jokerSig = jokerSig
    AvatarJokerStrip.avatars = avatars
    AvatarJokerStrip.jokers = jokers
    AvatarJokerStrip._dirty = true
end

function AvatarJokerStrip.syncFrom(player, jokers)
    local data = { avatars = {}, jokers = {} }

    if player and player.avatar_state then
        local equipped = player.avatar_state.equipped
        if equipped then
            local def = avatarDefs[equipped]
            table.insert(data.avatars, {
                id = equipped,
                name = (def and def.name) or equipped,
                description = (def and def.description) or "Equipped avatar",
                sprite = AvatarJokerStrip.layout.avatarSprite
            })
        end
        for avatarId, unlocked in pairs(player.avatar_state.unlocked or {}) do
            if unlocked and avatarId ~= equipped then
                local def = avatarDefs[avatarId]
                table.insert(data.avatars, {
                    id = avatarId,
                    name = (def and def.name) or avatarId,
                    description = (def and def.description) or "Unlocked avatar",
                    sprite = AvatarJokerStrip.layout.avatarSprite
                })
            end
        end
    end

    local activeJokers = jokers or JokerSystem.jokers
    for _, joker in ipairs(activeJokers or {}) do
        local def = JokerSystem.definitions[joker.id]
        table.insert(data.jokers, {
            id = joker.id,
            name = joker.name or (def and def.name) or joker.id,
            description = (def and def.description) or "Passive joker",
            rarity = (def and def.rarity) or joker.rarity,
            sprite = AvatarJokerStrip.layout.jokerSprite
        })
    end

    if (#data.avatars == 0) and (#data.jokers == 0) then
        AvatarJokerStrip.setData(dummyData())
    else
        AvatarJokerStrip.setData(data)
    end
end

function AvatarJokerStrip.init(opts)
    opts = opts or {}
    AvatarJokerStrip.layout.margin = opts.margin or AvatarJokerStrip.layout.margin
    AvatarJokerStrip.isActive = true
    AvatarJokerStrip._dirty = true
    AvatarJokerStrip._layoutCache = nil
    AvatarJokerStrip._avatarSig = ""
    AvatarJokerStrip._jokerSig = ""
    AvatarJokerStrip._activeTooltipOwner = nil
    AvatarJokerStrip._fallbackHover = nil
    AvatarJokerStrip.setData(dummyData())
end

function AvatarJokerStrip.update()
    if not AvatarJokerStrip.isActive then return end

    if AvatarJokerStrip._dirty then
        rebuildSprites()
    end

    local avatarBox = computeLayout(AvatarJokerStrip.avatarSprites, false, "Avatars")
    local jokerBox = computeLayout(AvatarJokerStrip.jokerSprites, true, "Jokers")
    AvatarJokerStrip._layoutCache = { avatar = avatarBox, joker = jokerBox }

    local baseZ = (z_orders.ui_tooltips or 0) - 8
    applyTransforms(AvatarJokerStrip.avatarSprites, avatarBox, baseZ, { animate = true })
    applyTransforms(AvatarJokerStrip.jokerSprites, jokerBox, baseZ, { animate = true })
end

function AvatarJokerStrip.draw()
    if not AvatarJokerStrip.isActive then return end
    if not AvatarJokerStrip._layoutCache then return end

    local baseZ = (z_orders.ui_tooltips or 0) - 8
    local space = layer.DrawCommandSpace.Screen

    drawGroup(AvatarJokerStrip._layoutCache.avatar, colors.avatarAccent, "Avatars", baseZ)
    drawGroup(AvatarJokerStrip._layoutCache.joker, colors.jokerAccent, "Jokers", baseZ)

    drawGlow(AvatarJokerStrip.jokerSprites, colors.jokerAccent, baseZ + 2, space)

    drawSprites(AvatarJokerStrip.avatarSprites, baseZ + 3, space)
    drawSprites(AvatarJokerStrip.jokerSprites, baseZ + 3, space)

    -- Optional center divider for balance
    local a = AvatarJokerStrip._layoutCache.avatar
    local j = AvatarJokerStrip._layoutCache.joker
    if a and j and command_buffer and layers then
        local left = a.x + a.w
        local right = j.x
        local mid = left + (right - left) * 0.5
        local dividerH = math.max(a.h, j.h) - 12
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = mid
            c.y = math.min(a.y, j.y) + 6 + dividerH * 0.5
            c.w = 3
            c.h = dividerH
            c.rx = 2
            c.ry = 2
            c.color = colors.divider
        end, baseZ + 1, space)
    end

    -- Fallback tooltip (only when shared tooltip UI isn't available)
    if AvatarJokerStrip._fallbackHover and AvatarJokerStrip._fallbackHover.entity then
        local anchor = AvatarJokerStrip._fallbackHover.entity
        if registry and registry.valid and registry:valid(anchor) then
            local t = component_cache.get(anchor, Transform)
            if t then
                local font = localization.getFont()
                local label = AvatarJokerStrip._fallbackHover.title or "Unknown"
                local body = AvatarJokerStrip._fallbackHover.body or ""
                local labelSize = 14
                local bodySize = 12
                local padding = 8
                local textW = math.max(
                    localization.getTextWidthWithCurrentFont(label, labelSize, 1),
                    localization.getTextWidthWithCurrentFont(body, bodySize, 1)
                )
                local w = textW + padding * 2
                local h = padding * 2 + labelSize + bodySize + 6
                local x = t.actualX + (t.actualW or AvatarJokerStrip.layout.cardW) * 0.5
                local y = t.actualY - h - 6
                local screenW = AvatarJokerStrip._layoutCache.avatar.screenW or 1920
                local screenH = AvatarJokerStrip._layoutCache.avatar.screenH or 1080

                -- Clamp
                x = math.max(padding, math.min(x, screenW - padding - w))
                y = math.max(padding, math.min(y, screenH - padding - h))

                command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                    c.x = x + w * 0.5
                    c.y = y + h * 0.5
                    c.w = w
                    c.h = h
                    c.rx = 8
                    c.ry = 8
                    c.color = Col(16, 16, 24, 230)
                end, baseZ + 5, space)

                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = label
                    c.font = font
                    c.x = x + padding
                    c.y = y + padding
                    c.color = colors.text
                    c.fontSize = labelSize
                end, baseZ + 6, space)

                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = body
                    c.font = font
                    c.x = x + padding
                    c.y = y + padding + labelSize + 2
                    c.color = colors.muted
                    c.fontSize = bodySize
                end, baseZ + 6, space)
            end
        else
            AvatarJokerStrip._fallbackHover = nil
        end
    end
end

function AvatarJokerStrip.shutdown()
    destroyList(AvatarJokerStrip.avatarSprites)
    destroyList(AvatarJokerStrip.jokerSprites)
    AvatarJokerStrip.avatarSprites = {}
    AvatarJokerStrip.jokerSprites = {}
    AvatarJokerStrip.isActive = false
    AvatarJokerStrip._layoutCache = nil
end

return AvatarJokerStrip
