--[[
Lightweight level-up modal:
- Shows three sprite choices (default: Physique, Cunning, Spirit).
- Fades in a dark backdrop, staggers entries, and jiggles on hover.
- Pauses physics while open; queues additional level-up events.
]]

local LevelUpScreen = {}

local z_orders = require("core.z_orders")
local Easing = require("util.easing")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local layer_order_system = _G.layer_order_system

LevelUpScreen.isActive = false
LevelUpScreen._queue = {}
LevelUpScreen._choices = {}
LevelUpScreen._elapsed = 0
LevelUpScreen._backdrop = 0
LevelUpScreen._state = "idle"
LevelUpScreen._hoverIndex = nil
LevelUpScreen._pausedGameplay = false
LevelUpScreen._layout = {
    size = 132,
    spacing = 260,
    sprite = "sample_pack.png",
    hitboxW = 220,
    hitboxH = 240,
}

local defaultChoices = {
    {
        id = "physique",
        title = localization.get("stats.physique"),
        description = localization.get("ui.levelup_physique_desc"),
        apply = function(actor)
            if not actor or not actor.stats then return end
            actor.stats:add_base("physique", 2)
            actor.stats:recompute()
            actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
        end
    },
    {
        id = "cunning",
        title = localization.get("stats.cunning"),
        description = localization.get("ui.levelup_cunning_desc"),
        apply = function(actor)
            if not actor or not actor.stats then return end
            actor.stats:add_base("cunning", 2)
            actor.stats:recompute()
            actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
        end
    },
    {
        id = "spirit",
        title = localization.get("stats.spirit"),
        description = localization.get("ui.levelup_spirit_desc"),
        apply = function(actor)
            if not actor or not actor.stats then return end
            actor.stats:add_base("spirit", 2)
            actor.stats:recompute()
            actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
        end
    }
}

local function resolveScreen()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    return screenW, screenH
end

local function resolveActor(ctx)
    if ctx and ctx.actor then return ctx.actor end
    if ctx and ctx.playerEntity and entity_cache.valid(ctx.playerEntity) then
        local script = getScriptTableFromEntityID(ctx.playerEntity)
        if script and script.combatTable then
            return script.combatTable
        end
    end
    if survivorEntity and entity_cache.valid(survivorEntity) then
        local script = getScriptTableFromEntityID(survivorEntity)
        if script and script.combatTable then
            return script.combatTable
        end
    end
    return nil
end

local function pauseGameplay()
    if LevelUpScreen._pausedGameplay then return end
    LevelUpScreen._pausedGameplay = true
    if PhysicsManager and PhysicsManager.enable_step then
        PhysicsManager.enable_step("world", false)
    end
end

local function resumeGameplay()
    if not LevelUpScreen._pausedGameplay then return end
    LevelUpScreen._pausedGameplay = false
    if PhysicsManager and PhysicsManager.enable_step then
        PhysicsManager.enable_step("world", true)
    end
end

local function buildChoices(ctx)
    LevelUpScreen._choices = {}
    LevelUpScreen._hitboxes = {}
    local screenW, screenH = resolveScreen()
    local spacing = math.min(LevelUpScreen._layout.spacing, screenW * 0.35)
    local startX = screenW * 0.5 - spacing
    local baseY = screenH * 0.5

    for i, def in ipairs(defaultChoices) do
        local slot = {
            id = def.id,
            title = def.title,
            description = def.description,
            index = i,
            apply = def.apply,
            sprite = LevelUpScreen._layout.sprite,
            pos = { x = startX + (i - 1) * spacing, y = baseY },
            progress = 0,
            delay = (i - 1) * 0.1,
            hoverT = 0,
            jiggle = 0,
            idlePhase = (i - 1) * 0.7,
            clickFlash = 0,
            hitbox = nil,
            _isHovered = false,
        }
        LevelUpScreen._choices[i] = slot
    end

    LevelUpScreen._actor = resolveActor(ctx)
end

local function spawnSelectionBurst(choice)
    if not (choice and particle and particle.spawnRadialParticles) then return end

    local screenW, screenH = resolveScreen()
    local cx = (choice.pos and choice.pos.x) or screenW * 0.5
    local cy = (choice.pos and choice.pos.y) or screenH * 0.5
    local palette = {
        util.getColor("apricot_cream"),
        util.getColor("cyan"),
        util.getColor("pink"),
        util.getColor("gold"),
        util.getColor("mint_green"),
    }

    particle.spawnRadialParticles(cx, cy, 42, 0.55, {
        colors = palette,
        minSpeed = 220,
        maxSpeed = 520,
        minScale = 6,
        maxScale = 14,
        lifetimeJitter = 0.35,
        scaleJitter = 0.25,
        renderType = particle.ParticleRenderType.CIRCLE_FILLED,
        rotationSpeed = 180,
        rotationJitter = 0.5,
        space = "screen",
        z = (z_orders.ui_transition or 1000) + 40,
    })

    if particle.spawnRing then
        particle.spawnRing(cx, cy, 22, 0.5, 52, {
            colors = palette,
            expandFactor = 1.1,
            renderType = particle.ParticleRenderType.CIRCLE_LINE,
            durationVariance = 0.1,
            space = "screen",
            z = (z_orders.ui_transition or 1000) + 35,
        })
    end
end

local function startSession(ctx)
    LevelUpScreen._state = "opening"
    LevelUpScreen.isActive = true
    LevelUpScreen._elapsed = 0
    LevelUpScreen._backdrop = 0
    LevelUpScreen._hoverIndex = nil
    LevelUpScreen._hitboxes = {}
    buildChoices(ctx)
    pauseGameplay()
end

local function wrapTextToTwoLines(text, maxChars)
    if not text then return { "" } end
    if #text <= maxChars then return { text } end

    local breakPos = math.min(#text, maxChars)
    -- try to break at the last space before maxChars
    for i = breakPos, math.max(1, breakPos - 12), -1 do
        if text:sub(i, i) == " " then
            breakPos = i
            break
        end
    end

    local first = text:sub(1, breakPos):gsub("%s+$", "")
    local second = text:sub(breakPos + 1):gsub("^%s+", "")
    return { first, second }
end

function LevelUpScreen.init()
    LevelUpScreen.isActive = false
    LevelUpScreen._queue = {}
    LevelUpScreen._choices = {}
    LevelUpScreen._hitboxes = {}
    LevelUpScreen._state = "idle"
    LevelUpScreen._hoverIndex = nil
end

function LevelUpScreen.push(ctx)
    table.insert(LevelUpScreen._queue, ctx or {})
    if not LevelUpScreen.isActive then
        local nextCtx = table.remove(LevelUpScreen._queue, 1)
        startSession(nextCtx)
    end
end

local function finishSession()
    LevelUpScreen._state = "idle"
    LevelUpScreen.isActive = false
    for _, eid in ipairs(LevelUpScreen._hitboxes or {}) do
        if eid and entity_cache.valid(eid) then
            registry:destroy(eid)
        end
    end
    LevelUpScreen._hitboxes = {}
    LevelUpScreen._choices = {}
    if #LevelUpScreen._queue > 0 then
        local nextCtx = table.remove(LevelUpScreen._queue, 1)
        startSession(nextCtx)
    else
        resumeGameplay()
    end
end

function LevelUpScreen.select(choice)
    if not choice or LevelUpScreen._state == "closing" then return end
    LevelUpScreen._state = "closing"
    spawnSelectionBurst(choice)
    if choice.apply then
        choice.apply(LevelUpScreen._actor)
    end
end

function LevelUpScreen.update(dt)
    if not LevelUpScreen.isActive then return end
    dt = dt or GetFrameTime()

    LevelUpScreen._elapsed = LevelUpScreen._elapsed + dt
    LevelUpScreen._backdrop = math.min(1, LevelUpScreen._backdrop + dt * 3.2)

    local mouse = nil
    if input then
        if input.getMousePosition then
            mouse = input.getMousePosition()
        elseif input.getMousePos then
            mouse = input.getMousePos()
        end
    end
    LevelUpScreen._hoverIndex = nil

    for i, slot in ipairs(LevelUpScreen._choices) do
        slot._isHovered = false
        -- Ensure hitbox exists and is wired for hover/click via engine collision
        if (not slot.hitbox) or (not entity_cache.valid(slot.hitbox)) then
            slot.hitbox = create_transform_entity()
            table.insert(LevelUpScreen._hitboxes, slot.hitbox)
            local go = component_cache.get(slot.hitbox, GameObject)
            if go then
                go.state.hoverEnabled = true
                go.state.clickEnabled = true
                go.state.collisionEnabled = true
                go.methods.onHover = function()
                    slot._isHovered = true
                    LevelUpScreen._hoverIndex = slot.index
                end
                go.methods.onStopHover = function()
                    slot._isHovered = false
                    if LevelUpScreen._hoverIndex == slot.index then
                        LevelUpScreen._hoverIndex = nil
                    end
                end
                go.methods.onClick = function()
                    if LevelUpScreen._state ~= "closing" then
                        slot.clickFlash = 1.0
                        LevelUpScreen.select(slot)
                    end
                end
            end
            if layer_order_system and layer_order_system.assignZIndexToEntity then
                layer_order_system.assignZIndexToEntity(slot.hitbox, (z_orders.ui_transition or 1000) + 60)
            end
        end

        if LevelUpScreen._elapsed >= slot.delay then
            slot.progress = math.min(1, slot.progress + dt / 0.25)
        end

        if mouse and slot.progress > 0.01 then
            local idleOffsetY = math.sin(LevelUpScreen._elapsed * 1.6 + slot.idlePhase) * 6
            local idleOffsetX = math.sin(LevelUpScreen._elapsed * 1.2 + slot.idlePhase * 0.6) * 4
            local halfW = (LevelUpScreen._layout.size * 0.75) + 52
            local halfH = (LevelUpScreen._layout.size * 0.75) + 56
            local cx = slot.pos.x + idleOffsetX
            local cy = slot.pos.y + idleOffsetY
            if mouse.x >= cx - halfW and mouse.x <= cx + halfW
                and mouse.y >= cy - halfH and mouse.y <= cy + halfH then
                LevelUpScreen._hoverIndex = i
                slot._isHovered = true
            end
        end

        -- Keep hitbox aligned to animated position so engine hover/click stay accurate
        local hbW = LevelUpScreen._layout.hitboxW
        local hbH = LevelUpScreen._layout.hitboxH
        local t = component_cache.get(slot.hitbox, Transform)
        if t then
            t.actualW = hbW
            t.actualH = hbH
            t.visualW = hbW
            t.visualH = hbH
            t.actualX = (slot.pos.x + math.sin(LevelUpScreen._elapsed * 1.2 + slot.idlePhase * 0.6) * 4) - hbW * 0.5
            t.actualY = (slot.pos.y + math.sin(LevelUpScreen._elapsed * 1.6 + slot.idlePhase) * 6) - hbH * 0.5
            t.visualX = t.actualX
            t.visualY = t.actualY
        end

        if LevelUpScreen._hoverIndex == i or slot._isHovered then
            slot.hoverT = math.min(1, slot.hoverT + dt * 10)
            slot.jiggle = (slot.jiggle or 0) + dt * 10
        else
            slot.hoverT = math.max(0, slot.hoverT - dt * 6)
        end

        slot.clickFlash = math.max(0, (slot.clickFlash or 0) - dt * 4)
    end

    if LevelUpScreen._state ~= "closing" and LevelUpScreen._hoverIndex and input and input.action_pressed then
        if input.action_pressed("mouse_click") then
            local choice = LevelUpScreen._choices[LevelUpScreen._hoverIndex]
            if choice then
                choice.clickFlash = 1.0
                LevelUpScreen.select(choice)
            end
        end
    end

    if LevelUpScreen._state == "closing" then
        LevelUpScreen._backdrop = math.max(0, LevelUpScreen._backdrop - dt * 5)
        local allHidden = true
        for _, slot in ipairs(LevelUpScreen._choices) do
            slot.progress = math.max(0, slot.progress - dt * 6)
            if slot.progress > 0.05 then
                allHidden = false
            end
        end
        if LevelUpScreen._backdrop <= 0.01 and allHidden then
            finishSession()
        end
    end
end

function LevelUpScreen.draw()
    if not LevelUpScreen.isActive then return end
    local screenW, screenH = resolveScreen()
    local font = localization.getFont()
    local space = layer.DrawCommandSpace.Screen
    local baseZ = (z_orders.ui_transition or 1000) + 10
    local t = GetTime()
    local function lerp(a, b, k) return a + (b - a) * k end
    local function lerpColor(c1, c2, k)
        return Col(
            math.floor(lerp(c1.r, c2.r, k)),
            math.floor(lerp(c1.g, c2.g, k)),
            math.floor(lerp(c1.b, c2.b, k)),
            math.floor(lerp(c1.a or 255, c2.a or 255, k))
        )
    end
    local pulse = (math.sin(t * 2.4) + 1) * 0.5
    local titleColor = lerpColor(util.getColor("apricot_cream"), util.getColor("cyan"), pulse)
    local titleGlow = lerpColor(util.getColor("pink"), util.getColor("white"), pulse * 0.6 + 0.2)
    local titleText = "LEVEL UP"
    local titleSize = 44 + pulse * 6
    local titleWidth = (localization.getTextWidthWithCurrentFont and localization.getTextWidthWithCurrentFont(titleText, titleSize, 1)) or (#titleText * (titleSize * 0.55))
    local titleX = screenW * 0.5 - titleWidth * 0.5

    if LevelUpScreen._backdrop > 0 then
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = screenW * 0.5
            c.y = screenH * 0.5
            c.w = screenW
            c.h = screenH
            c.rx = 0
            c.ry = 0
            c.color = Col(6, 8, 12, math.floor(210 * LevelUpScreen._backdrop))
        end, baseZ - 2, space)
    end

    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = titleText
        c.font = font
        c.x = titleX + 2
        c.y = screenH * 0.5 - LevelUpScreen._layout.size - 20 + 2
        c.color = Col(0, 0, 0, 180)
        c.fontSize = titleSize
    end, baseZ - 1, space)
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = titleText
        c.font = font
        c.x = titleX
        c.y = screenH * 0.5 - LevelUpScreen._layout.size - 20
        c.color = titleColor
        c.fontSize = titleSize
    end, baseZ - 1, space)
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = titleText
        c.font = font
        c.x = titleX
        c.y = screenH * 0.5 - LevelUpScreen._layout.size - 20 - 6
        c.color = titleGlow:setAlpha(math.floor(120 * LevelUpScreen._backdrop))
        c.fontSize = titleSize * 0.9
    end, baseZ - 1, space)

    for idx, slot in ipairs(LevelUpScreen._choices) do
        if slot.progress > 0 then
            local ease = Easing.outBack.f(math.min(1, slot.progress))
            local idleOffsetY = math.sin(LevelUpScreen._elapsed * 1.6 + slot.idlePhase) * 6
            local idleOffsetX = math.sin(LevelUpScreen._elapsed * 1.2 + slot.idlePhase * 0.6) * 4
            local jiggleScale = slot.hoverT * 0.12
            if slot.hoverT > 0 and slot.jiggle then
                jiggleScale = jiggleScale + math.sin(slot.jiggle * 6) * 0.05
            end
            local clickPop = (slot.clickFlash or 0) * 0.15
            local scale = (0.6 + 0.4 * ease) * (1 + jiggleScale + clickPop)
            local size = LevelUpScreen._layout.size * scale
            local offsetY = (1 - ease) * 30
            local alpha = math.min(1, LevelUpScreen._backdrop) * math.min(1, slot.progress + 0.1)
            local posX, posY = slot.pos.x + idleOffsetX, slot.pos.y + idleOffsetY - offsetY

            local hoverGlow = slot.hoverT
            local haloAlpha = math.floor(120 * alpha * (0.4 + hoverGlow))
            local haloRadius = size * (0.65 + hoverGlow * 0.3 + (slot.clickFlash or 0) * 0.5)

            command_buffer.queueDrawCenteredEllipse(layers.ui, function(c)
                c.x = posX
                c.y = posY + 6
                c.rx = haloRadius
                c.ry = haloRadius * 0.85
                c.color = Col(12, 16, 22, haloAlpha)
            end, baseZ + idx * 2 - 1, space)

            command_buffer.queueDrawCenteredEllipse(layers.ui, function(c)
                c.x = posX
                c.y = posY
                c.rx = haloRadius * 0.8
                c.ry = haloRadius * 0.8
                c.color = Col(255, 210, 140, math.floor(80 * alpha * (0.5 + hoverGlow)))
            end, baseZ + idx * 2, space)

            command_buffer.queueDrawSpriteCentered(layers.ui, function(c)
                c.spriteName = slot.sprite or LevelUpScreen._layout.sprite
                c.x = posX
                c.y = posY
                c.dstW = size
                c.dstH = size
                c.tint = Col(255, 255, 255, math.floor(255 * alpha))
            end, baseZ + idx * 2, space)

            -- Anchor text to the slot center, not the wobbling sprite, so it stays put on hover
            local textBaseY = slot.pos.y + LevelUpScreen._layout.size * 0.75
            local titleSize = 18
            local descSize = 14
            local columnWidth = LevelUpScreen._layout.spacing - 40
            local titleWidth = (localization.getTextWidthWithCurrentFont and localization.getTextWidthWithCurrentFont(slot.title, titleSize, 1)) or (#slot.title * (titleSize * 0.55))
            local titleX = slot.pos.x - titleWidth * 0.5
            local descLines = wrapTextToTwoLines(slot.description, math.max(12, math.floor(columnWidth / 7)))

            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = slot.title
                c.font = font
                c.x = titleX + 1
                c.y = textBaseY + 1
                c.color = Col(0, 0, 0, math.floor(180 * alpha))
                c.fontSize = titleSize
            end, baseZ + idx * 2 + 1, space)
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = slot.title
                c.font = font
                c.x = titleX
                c.y = textBaseY
                c.color = util.getColor("white"):setAlpha(math.floor(255 * alpha))
                c.fontSize = titleSize
            end, baseZ + idx * 2 + 1, space)

            for lineIdx, line in ipairs(descLines) do
                local lineWidth = (localization.getTextWidthWithCurrentFont and localization.getTextWidthWithCurrentFont(line, descSize, 1)) or (#line * (descSize * 0.55))
                local lineX = slot.pos.x - lineWidth * 0.5
                local lineY = textBaseY + 22 + (lineIdx - 1) * (descSize + 4)
                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = line
                    c.font = font
                    c.x = lineX + 1
                    c.y = lineY + 1
                    c.color = Col(0, 0, 0, math.floor(140 * alpha))
                    c.fontSize = descSize
                end, baseZ + idx * 2 + 1, space)
                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = line
                    c.font = font
                    c.x = lineX
                    c.y = lineY
                    c.color = util.getColor("apricot_cream"):setAlpha(math.floor(200 * alpha))
                    c.fontSize = descSize
                end, baseZ + idx * 2 + 1, space)
            end
        end
    end
end

return LevelUpScreen
