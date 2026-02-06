--[[
Lightweight level-up modal:
- Shows three offers (item rewards by default, stat fallback if content is missing).
- Fades in a dark backdrop, staggers entries, and jiggles on hover.
- Pauses physics while open; queues additional level-up events.
]]

local LevelUpScreen = {}

local z_orders = require("core.z_orders")
local Easing = require("util.easing")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local layer_order_system = _G.layer_order_system
local shader_pipeline = _G.shader_pipeline

local OFFER_SHADER_PASS = "3d_skew_polychrome"

local RARITY_TEXT_STYLES = {
    common = {
        title = { r = 235, g = 235, b = 235, a = 255 },
        rarity = { r = 205, g = 205, b = 205, a = 255 },
    },
    uncommon = {
        title = { r = 132, g = 245, b = 132, a = 255 },
        rarity = { r = 172, g = 240, b = 172, a = 255 },
    },
    rare = {
        title = { r = 114, g = 206, b = 255, a = 255 },
        rarity = { r = 164, g = 225, b = 255, a = 255 },
    },
    epic = {
        title = { r = 212, g = 148, b = 255, a = 255 },
        rarity = { r = 233, g = 188, b = 255, a = 255 },
    },
    legendary = {
        title = { r = 255, g = 214, b = 128, a = 255 },
        rarity = { r = 255, g = 234, b = 172, a = 255 },
    },
    mythic = {
        title = { r = 255, g = 150, b = 218, a = 255 },
        rarity = { r = 255, g = 196, b = 234, a = 255 },
    },
}

LevelUpScreen.isActive = false
LevelUpScreen._queue = {}
LevelUpScreen._choices = {}
LevelUpScreen._elapsed = 0
LevelUpScreen._backdrop = 0
LevelUpScreen._state = "idle"
LevelUpScreen._hoverIndex = nil
LevelUpScreen._pausedGameplay = false
LevelUpScreen._offerEntities = {}
LevelUpScreen._layout = {
    size = 132,
    spacing = 260,
    sprite = "frame0012.png",
    hitboxW = 220,
    hitboxH = 240,
}

local function withAlpha(color, alpha)
    if not color then
        return Col(255, 255, 255, alpha)
    end
    return Col(color.r or 255, color.g or 255, color.b or 255, alpha)
end

local function rarityStyle(rarity)
    local key = tostring(rarity or "common"):lower()
    return RARITY_TEXT_STYLES[key] or RARITY_TEXT_STYLES.common
end

local function prettifyWord(value)
    local text = tostring(value or "")
    text = text:gsub("_", " ")
    text = text:gsub("(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    return text
end

local function summarizeItemStats(itemDef)
    if not itemDef or type(itemDef.stats) ~= "table" then
        return ""
    end

    local keys = {}
    for k, v in pairs(itemDef.stats) do
        if type(v) == "number" then
            keys[#keys + 1] = k
        end
    end

    table.sort(keys)

    local parts = {}
    local maxParts = math.min(2, #keys)
    for i = 1, maxParts do
        local statKey = keys[i]
        local rawValue = itemDef.stats[statKey]
        local sign = rawValue >= 0 and "+" or ""
        local label = prettifyWord(statKey):gsub(" Pct$", "%%")
        parts[#parts + 1] = string.format("%s%s %s", sign, tostring(rawValue), label)
    end

    return table.concat(parts, "  ")
end

local function createInventoryItemEntity(itemDef)
    if not (animation_system and animation_system.createAnimatedObjectWithTransform) then
        return nil, nil
    end

    local sprite = (itemDef and itemDef.sprite) or LevelUpScreen._layout.sprite
    local entity = animation_system.createAnimatedObjectWithTransform(
        sprite, true, -9999, -9999, nil, true
    )

    if not (entity and entity_cache.valid(entity)) then
        return nil, nil
    end

    if add_state_tag then
        add_state_tag(entity, "default_state")
    end

    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end

    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderPipelineComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
        if shaderPipelineComp then
            shaderPipelineComp:addPass(OFFER_SHADER_PASS)
            local passes = shaderPipelineComp.passes
            local idx = passes and #passes
            if idx and idx >= 1 then
                local pass = passes[idx]
                if pass and pass.shaderName and pass.shaderName:sub(1, 7) == "3d_skew" then
                    local seed = math.random() * 10000
                    local shaderName = pass.shaderName
                    pass.customPrePassFunction = function()
                        if globalShaderUniforms then
                            globalShaderUniforms:set(shaderName, "rand_seed", seed)
                        end
                    end
                end
            end
        end
    end

    local scriptData = {
        entity = entity,
        id = itemDef and itemDef.id,
        name = itemDef and itemDef.name,
        slot = itemDef and itemDef.slot,
        category = "equipment",
        cardData = itemDef,
        equipmentDef = itemDef,
        noVisualSnap = true,
    }

    if setScriptTableForEntityID then
        setScriptTableForEntityID(entity, scriptData)
    end

    return entity, scriptData
end

local function grantItemToInventory(itemDef)
    local okInventory, PlayerInventory = pcall(require, "ui.player_inventory")
    if (not okInventory) or (not PlayerInventory) or type(PlayerInventory.addCard) ~= "function" then
        return false
    end

    local itemEntity, cardData = createInventoryItemEntity(itemDef)
    if not itemEntity then
        return false
    end

    local added = PlayerInventory.addCard(itemEntity, "equipment", cardData)
    if not added and registry and registry.valid and registry:valid(itemEntity) then
        registry:destroy(itemEntity)
    end

    return added
end

local function collectItemDefinitions()
    local defs = {}
    local seen = {}

    local function addFrom(module)
        if not module or type(module.getAll) ~= "function" then return end
        local items = module.getAll() or {}
        for _, def in ipairs(items) do
            if type(def) == "table" and def.id and not seen[def.id] then
                seen[def.id] = true
                defs[#defs + 1] = def
            end
        end
    end

    local okEquip, Equipment = pcall(require, "data.equipment")
    if okEquip then
        addFrom(Equipment)
    end

    local okDemo, DemoEquipment = pcall(require, "data.demo_equipment")
    if okDemo then
        addFrom(DemoEquipment)
    end

    return defs
end

local function shuffledCopy(items)
    local out = {}
    for i = 1, #items do
        out[i] = items[i]
    end
    for i = #out, 2, -1 do
        local j = math.random(i)
        out[i], out[j] = out[j], out[i]
    end
    return out
end

local function getDefaultChoices()
    return {
        {
            id = "physique",
            title = localization.get("stats.physique") or "Physique",
            description = localization.get("ui.levelup_physique_desc") or "+2 Physique",
            rarity = localization.get("ui.level_up_fallback") or "Fallback",
            titleColor = util.getColor("white"),
            rarityColor = util.getColor("apricot_cream"),
            apply = function(actor)
                if not actor or not actor.stats then return end
                actor.stats:add_base("physique", 2)
                actor.stats:recompute()
                actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
            end,
        },
        {
            id = "cunning",
            title = localization.get("stats.cunning") or "Cunning",
            description = localization.get("ui.levelup_cunning_desc") or "+2 Cunning",
            rarity = localization.get("ui.level_up_fallback") or "Fallback",
            titleColor = util.getColor("white"),
            rarityColor = util.getColor("apricot_cream"),
            apply = function(actor)
                if not actor or not actor.stats then return end
                actor.stats:add_base("cunning", 2)
                actor.stats:recompute()
                actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
            end,
        },
        {
            id = "spirit",
            title = localization.get("stats.spirit") or "Spirit",
            description = localization.get("ui.levelup_spirit_desc") or "+2 Spirit",
            rarity = localization.get("ui.level_up_fallback") or "Fallback",
            titleColor = util.getColor("white"),
            rarityColor = util.getColor("apricot_cream"),
            apply = function(actor)
                if not actor or not actor.stats then return end
                actor.stats:add_base("spirit", 2)
                actor.stats:recompute()
                actor.attr_points = math.max(0, (actor.attr_points or 0) - 1)
            end,
        },
    }
end

local function getItemOfferChoices()
    local pool = collectItemDefinitions()
    if #pool == 0 then
        return getDefaultChoices()
    end

    local offers = {}
    local picked = shuffledCopy(pool)
    local count = math.min(3, #picked)

    for i = 1, count do
        local itemDef = picked[i]
        local pickedItem = itemDef
        local rarity = itemDef.rarity or "Common"
        local style = rarityStyle(rarity)
        local statSummary = summarizeItemStats(itemDef)
        local slotLabel = itemDef.slot and prettifyWord(itemDef.slot) or "Item"
        local description = statSummary ~= "" and statSummary or ("Slot: " .. slotLabel)

        offers[#offers + 1] = {
            id = itemDef.id or ("item_offer_" .. tostring(i)),
            title = itemDef.name or itemDef.id or "Unknown Item",
            description = description,
            rarity = tostring(rarity),
            titleColor = style.title,
            rarityColor = style.rarity,
            sprite = itemDef.sprite or LevelUpScreen._layout.sprite,
            itemDef = itemDef,
            apply = function(_actor)
                grantItemToInventory(pickedItem)
            end,
        }
    end

    if #offers < 3 then
        local fallback = getDefaultChoices()
        for i = #offers + 1, 3 do
            offers[i] = fallback[i]
        end
    end

    return offers
end

local function resolveChoices(ctx)
    if ctx and type(ctx.choices) == "table" and #ctx.choices > 0 then
        return ctx.choices
    end
    return getItemOfferChoices()
end

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

local function ensureOfferEntity(slot)
    if slot.offerEntity and entity_cache.valid(slot.offerEntity) then
        return
    end

    if not (animation_system and animation_system.createAnimatedObjectWithTransform) then
        return
    end

    local offerEntity = animation_system.createAnimatedObjectWithTransform(
        slot.sprite or LevelUpScreen._layout.sprite,
        true
    )

    if not (offerEntity and entity_cache.valid(offerEntity)) then
        return
    end

    slot.offerEntity = offerEntity
    table.insert(LevelUpScreen._offerEntities, offerEntity)

    if add_state_tag then
        add_state_tag(offerEntity, "default_state")
    end

    if transform and transform.set_space then
        transform.set_space(offerEntity, "screen")
    end

    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        local shaderPipelineComp = registry:emplace(offerEntity, shader_pipeline.ShaderPipelineComponent)
        if shaderPipelineComp then
            shaderPipelineComp:addPass(OFFER_SHADER_PASS)

            local passes = shaderPipelineComp.passes
            local idx = passes and #passes
            if idx and idx >= 1 then
                local pass = passes[idx]
                if pass and pass.shaderName and pass.shaderName:sub(1, 7) == "3d_skew" then
                    local seed = slot.skewSeed or math.random() * 10000
                    local shaderName = pass.shaderName
                    pass.customPrePassFunction = function()
                        if globalShaderUniforms then
                            globalShaderUniforms:set(shaderName, "rand_seed", seed)
                        end
                    end
                end
            end
        end
    end

    local animComp = component_cache.get(offerEntity, AnimationQueueComponent)
    if animComp then
        animComp.drawWithLegacyPipeline = false
        animComp.noDraw = false
    end

    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(offerEntity, (z_orders.ui_transition or 1000) + 20 + slot.index)
    end
end

local function syncOfferEntity(slot)
    if not (slot.offerEntity and entity_cache.valid(slot.offerEntity)) then
        return
    end

    local visible = slot.progress > 0.01 and LevelUpScreen._backdrop > 0.01
    local animComp = component_cache.get(slot.offerEntity, AnimationQueueComponent)
    if animComp then
        animComp.noDraw = not visible
        animComp.drawWithLegacyPipeline = false
    end

    if not visible then
        return
    end

    local t = component_cache.get(slot.offerEntity, Transform)
    if not t then return end

    local size = slot.renderSize or LevelUpScreen._layout.size
    local cx = slot.renderX or slot.pos.x
    local cy = slot.renderY or slot.pos.y

    t.actualW = size
    t.actualH = size
    t.visualW = size
    t.visualH = size

    t.actualX = cx - size * 0.5
    t.actualY = cy - size * 0.5
    t.visualX = t.actualX
    t.visualY = t.actualY
end

local function buildChoices(ctx)
    LevelUpScreen._choices = {}
    LevelUpScreen._hitboxes = {}
    LevelUpScreen._offerEntities = {}

    local screenW, screenH = resolveScreen()
    local spacing = math.min(LevelUpScreen._layout.spacing, screenW * 0.35)
    local startX = screenW * 0.5 - spacing
    local baseY = screenH * 0.5

    local defs = resolveChoices(ctx)

    for i, def in ipairs(defs) do
        local slot = {
            id = def.id,
            title = def.title,
            description = def.description,
            rarity = def.rarity,
            titleColor = def.titleColor or util.getColor("white"),
            rarityColor = def.rarityColor or util.getColor("apricot_cream"),
            index = i,
            apply = def.apply,
            sprite = def.sprite or LevelUpScreen._layout.sprite,
            itemDef = def.itemDef,
            pos = { x = startX + (i - 1) * spacing, y = baseY },
            progress = 0,
            delay = (i - 1) * 0.1,
            hoverT = 0,
            jiggle = 0,
            idlePhase = (i - 1) * 0.7,
            clickFlash = 0,
            hitbox = nil,
            offerEntity = nil,
            skewSeed = math.random() * 10000,
            renderX = startX + (i - 1) * spacing,
            renderY = baseY,
            renderSize = LevelUpScreen._layout.size,
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
    LevelUpScreen._offerEntities = {}
    buildChoices(ctx)
    pauseGameplay()
end

local function wrapTextToTwoLines(text, maxChars)
    if not text then return { "" } end
    if #text <= maxChars then return { text } end

    local breakPos = math.min(#text, maxChars)
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
    LevelUpScreen._offerEntities = {}
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

    for _, eid in ipairs(LevelUpScreen._offerEntities or {}) do
        if eid and entity_cache.valid(eid) then
            registry:destroy(eid)
        end
    end

    LevelUpScreen._hitboxes = {}
    LevelUpScreen._offerEntities = {}
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
    if playSoundEffect then
        playSoundEffect("effects", "level-up-choose", 0.9 + math.random() * 0.2)
    end
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

        ensureOfferEntity(slot)

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

        slot.renderX = slot.pos.x + idleOffsetX
        slot.renderY = slot.pos.y + idleOffsetY - offsetY
        slot.renderSize = size

        syncOfferEntity(slot)
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
    local titleText = localization and localization.get and localization.get("ui.level_up_title") or "LEVEL UP"
    local titleSize = 44 + pulse * 6
    local titleWidth = (localization.getTextWidthWithCurrentFont and localization.getTextWidthWithCurrentFont(titleText, titleSize, 1))
        or (#titleText * (titleSize * 0.55))
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
        c.color = withAlpha(titleGlow, math.floor(120 * LevelUpScreen._backdrop))
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

            if slot.offerEntity and entity_cache.valid(slot.offerEntity)
                and command_buffer and command_buffer.queueDrawBatchedEntities then
                local drawEntity = slot.offerEntity
                command_buffer.queueDrawBatchedEntities(layers.sprites or layers.ui, function(cmd)
                    cmd.registry = registry
                    cmd.entities = { drawEntity }
                    cmd.autoOptimize = true
                end, baseZ + idx * 2, space)
            else
                command_buffer.queueDrawSpriteCentered(layers.ui, function(c)
                    c.spriteName = slot.sprite or LevelUpScreen._layout.sprite
                    c.x = posX
                    c.y = posY
                    c.dstW = size
                    c.dstH = size
                    c.tint = Col(255, 255, 255, math.floor(255 * alpha))
                end, baseZ + idx * 2, space)
            end

            local textBaseY = slot.pos.y + LevelUpScreen._layout.size * 0.75
            local titleSize = 18
            local raritySize = 13
            local descSize = 14
            local columnWidth = LevelUpScreen._layout.spacing - 40

            local titleWidth = (localization.getTextWidthWithCurrentFont
                and localization.getTextWidthWithCurrentFont(slot.title, titleSize, 1))
                or (#slot.title * (titleSize * 0.55))
            local titleX = slot.pos.x - titleWidth * 0.5

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
                c.color = withAlpha(slot.titleColor, math.floor(255 * alpha))
                c.fontSize = titleSize
            end, baseZ + idx * 2 + 1, space)

            local rarityYOffset = 0
            if slot.rarity and slot.rarity ~= "" then
                local rarityText = tostring(slot.rarity)
                local rarityWidth = (localization.getTextWidthWithCurrentFont
                    and localization.getTextWidthWithCurrentFont(rarityText, raritySize, 1))
                    or (#rarityText * (raritySize * 0.55))
                local rarityX = slot.pos.x - rarityWidth * 0.5
                local rarityY = textBaseY + titleSize + 3

                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = rarityText
                    c.font = font
                    c.x = rarityX + 1
                    c.y = rarityY + 1
                    c.color = Col(0, 0, 0, math.floor(150 * alpha))
                    c.fontSize = raritySize
                end, baseZ + idx * 2 + 1, space)

                command_buffer.queueDrawText(layers.ui, function(c)
                    c.text = rarityText
                    c.font = font
                    c.x = rarityX
                    c.y = rarityY
                    c.color = withAlpha(slot.rarityColor, math.floor(235 * alpha))
                    c.fontSize = raritySize
                end, baseZ + idx * 2 + 1, space)

                rarityYOffset = raritySize + 6
            end

            local descLines = wrapTextToTwoLines(slot.description or "", math.max(12, math.floor(columnWidth / 7)))
            for lineIdx, line in ipairs(descLines) do
                local lineWidth = (localization.getTextWidthWithCurrentFont
                    and localization.getTextWidthWithCurrentFont(line, descSize, 1))
                    or (#line * (descSize * 0.55))
                local lineX = slot.pos.x - lineWidth * 0.5
                local lineY = textBaseY + 22 + rarityYOffset + (lineIdx - 1) * (descSize + 4)

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
                    c.color = withAlpha(util.getColor("apricot_cream"), math.floor(200 * alpha))
                    c.fontSize = descSize
                end, baseZ + idx * 2 + 1, space)
            end
        end
    end
end

return LevelUpScreen
