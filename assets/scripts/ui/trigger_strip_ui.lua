--[[
================================================================================
TRIGGER STRIP UI
================================================================================
Left-side action phase UI showing equipped trigger cards with wave-based
hover interaction and cooldown visualization.

Features:
- Persistent entities with state-based visibility
- Wave ripple effect (scale + slide-out) on hover
- Cooldown pie shader overlay
- Flash + pop on trigger activation
- Delayed tooltips on focus
================================================================================
]]

local TriggerStripUI = {}

local timer = require("core.timer")
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")
local z_orders = require("core.z_orders")
local ui_scale = require("ui.ui_scale")

-- Lazy-load WandTriggers to avoid circular dependencies
local WandTriggers
local function getWandTriggers()
    if not WandTriggers then
        local ok, mod = pcall(require, "wand.wand_triggers")
        if ok then WandTriggers = mod end
    end
    return WandTriggers
end

-- Lazy-load WandExecutor to avoid circular dependencies
local WandExecutor
local function getWandExecutor()
    if not WandExecutor then
        local ok, mod = pcall(require, "wand.wand_executor")
        if ok then WandExecutor = mod end
    end
    return WandExecutor
end

-- Constants
local CARD_WIDTH = ui_scale.ui(60)           -- 75% of 80
local CARD_HEIGHT = ui_scale.ui(84)          -- 75% of 112
local PEEK_X = ui_scale.ui(-30)              -- Resting X position (half hidden)
local WAVE_RADIUS = ui_scale.ui(80)          -- Wave influence radius in pixels
local MAX_SCALE_BUMP = 0.25     -- Max scale increase (1.0 -> 1.25)
local MAX_SLIDE_OUT = ui_scale.ui(40)        -- Max slide-out distance
local STRIP_HOVER_ZONE = ui_scale.ui(100)    -- Mouse X threshold for interaction
local TOOLTIP_DELAY = 0.3       -- Seconds before tooltip appears
local VERTICAL_SPACING = ui_scale.ui(20)     -- Gap between cards
local ACTIVATION_SCALE = 1.4    -- Scale on trigger activation
local FLASH_DURATION = 0.15     -- Flash effect duration

local MP_BAR_WIDTH = ui_scale.ui(6)
local MP_BAR_HEIGHT_RATIO = 0.75
local MP_BAR_OFFSET_X = ui_scale.ui(8)
local MP_BAR_VPAD = ui_scale.ui(6)

-- State
local strip_entries = {}        -- Array of {entity, sourceCardEntity, wandId, triggerId, centerY, influence, smoothManaRatio}
local strip_visible = false
local focusedEntry = nil
local previousFocusedEntry = nil
local activeTooltipEntry = nil
local tooltipTimerTag = nil
local handlers = nil
local manaState = {}            -- wandId -> {smoothRatio, currentMana, maxMana}

-- Screen dimensions cache
local screenHeight = 1080

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function getScreenHeight()
    if globals and globals.screenHeight then
        return globals.screenHeight()
    elseif globals and globals.getScreenHeight then
        return globals.getScreenHeight()
    end
    return 1080
end

local function calculateYPosition(index, totalCount)
    screenHeight = getScreenHeight()
    local totalHeight = (totalCount - 1) * (CARD_HEIGHT + VERTICAL_SPACING)
    local startY = (screenHeight - totalHeight) / 2
    return startY + (index - 1) * (CARD_HEIGHT + VERTICAL_SPACING)
end

local function destroyEntry(entry)
    if not entry then return end

    -- Hide tooltips if showing for this entry (both card and wand)
    if activeTooltipEntry == entry then
        if hideSimpleTooltip then
            hideSimpleTooltip("trigger_strip_card_" .. entry.entity)
            hideSimpleTooltip("trigger_strip_wand_" .. entry.entity)
        end
        activeTooltipEntry = nil
    end

    -- Destroy entity
    if entry.entity and registry and registry:valid(entry.entity) then
        registry:destroy(entry.entity)
    end
end

local function destroyAllEntries()
    for _, entry in ipairs(strip_entries) do
        destroyEntry(entry)
    end
    strip_entries = {}
    focusedEntry = nil
    previousFocusedEntry = nil
end

--------------------------------------------------------------------------------
-- ENTITY CREATION
--------------------------------------------------------------------------------

local function createStripEntry(sourceCardEntity, wandId, triggerId, index, totalCount, actionBoardId)
    if not animation_system then
        log_error("TriggerStripUI: animation_system not available")
        return nil
    end

    -- Get sprite from source card
    local spriteId = "sample_card.png"  -- Default fallback
    if sourceCardEntity and registry:valid(sourceCardEntity) then
        local sourceScript = getScriptTableFromEntityID(sourceCardEntity)
        if sourceScript then
            -- Try cardID lookup first
            if sourceScript.cardID then
                local cardDef = WandEngine and WandEngine.trigger_card_defs and WandEngine.trigger_card_defs[sourceScript.cardID]
                if cardDef and cardDef.sprite then
                    spriteId = cardDef.sprite
                end
            end
            -- Fall back to sprite directly on script
            if spriteId == "sample_card.png" and sourceScript.sprite then
                spriteId = sourceScript.sprite
            end
        end
    end
    log_debug("TriggerStripUI: creating entry with sprite:", spriteId, "for trigger", triggerId)

    -- Calculate position
    local yPos = calculateYPosition(index, totalCount)

    -- Create animated entity
    local entity = animation_system.createAnimatedObjectWithTransform(spriteId, true, PEEK_X, yPos, nil, false)
    if not ensure_entity(entity) then
        log_error("TriggerStripUI: failed to create entity for trigger", triggerId)
        return nil
    end

    -- Set to screen space
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end

    -- NOTE: Don't add ObjectAttachedToUITag - it excludes entities from shader rendering pipeline!
    -- Screen-space rendering is handled by transform.set_space("screen") above.
    -- The shader pipeline requires entities to go through the normal animation rendering path.

    -- Add ScreenSpaceCollisionMarker for proper screen-space coordinate handling
    if registry and registry.valid and collision and collision.ScreenSpaceCollisionMarker and registry:valid(entity) then
        if not registry:has(entity, collision.ScreenSpaceCollisionMarker) then
            registry:emplace(entity, collision.ScreenSpaceCollisionMarker)
        end
    end

    -- Resize to trigger strip size
    animation_system.resizeAnimationObjectsInEntityToFit(entity, CARD_WIDTH, CARD_HEIGHT)

    -- Apply shader preset with cooldown pie (top-down fill)
    if applyShaderPreset then
        applyShaderPreset(registry, entity, "trigger_card", {
            cooldown_progress = 0.0,   -- 0.0 = ready, 1.0 = full cooldown
            dim_amount = 0.5,
            flash_intensity = 0.0,
        })
    end

    -- Ensure entity is drawn through the legacy pipeline for shader rendering
    -- This is required because the shader pipeline component needs DrawTransformEntityWithAnimationWithPipeline
    local animComp = component_cache.get(entity, AnimationQueueComponent)
    if animComp then
        animComp.drawWithLegacyPipeline = true
    end

    -- Start hidden (not in any render state)
    if clear_state_tags then
        clear_state_tags(entity)
    end

    return {
        entity = entity,
        sourceCardEntity = sourceCardEntity,
        wandId = wandId,
        actionBoardId = actionBoardId,
        triggerId = triggerId,
        centerY = yPos + CARD_HEIGHT / 2,
        influence = 0,
        popUntil = 0,
    }
end

--------------------------------------------------------------------------------
-- SYNC WITH WAND TRIGGERS
--------------------------------------------------------------------------------

-- NOTE: Updated for grid inventory (Phase 5)
-- Now checks wand_grid_adapter first, then falls back to board_sets for legacy wand boards
local function collectEquippedTriggers()
    local triggers = {}
    local index = 1

    -- Try grid adapter first (Phase 5 grid inventory)
    local ok, wandAdapter = pcall(require, "ui.wand_grid_adapter")
    if ok and wandAdapter and wandAdapter.getWandCount then
        local wandCount = wandAdapter.getWandCount()
        for wandIndex = 1, wandCount do
            local loadout = wandAdapter.getLoadout(wandIndex)
            if loadout and loadout.trigger then
                local cardEntity = loadout.trigger
                if ensure_entity(cardEntity) then
                    local script = getScriptTableFromEntityID(cardEntity)
                    local triggerId = script and (script.cardID or script.card_id) or "unknown"
                    local wandDef = wandAdapter.getWandDef(wandIndex)
                    local wandId = wandDef and wandDef.id or ("wand_" .. wandIndex)

                    table.insert(triggers, {
                        cardEntity = cardEntity,
                        wandId = wandId,
                        actionBoardId = nil,  -- Grid inventory doesn't use board IDs
                        triggerId = triggerId,
                        index = index,
                    })
                    index = index + 1
                end
            end
        end
    end

    -- Fallback: check board_sets for legacy wand boards (still used for action/trigger boards)
    if #triggers == 0 and board_sets then
        for _, boardSet in ipairs(board_sets) do
            local triggerBoardID = boardSet.trigger_board_id
            local actionBoardID = boardSet.action_board_id
            local wandDef = boardSet.wandDef

            if triggerBoardID and ensure_entity(triggerBoardID) and boards then
                local triggerBoard = boards[triggerBoardID]
                if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                    local cardEntity = triggerBoard.cards[1]
                    if ensure_entity(cardEntity) then
                        local script = getScriptTableFromEntityID(cardEntity)
                        local triggerId = script and script.cardID or "unknown"

                        -- Use wandDef.id as wandId to match WandTriggers registration key
                        local wandId = wandDef and wandDef.id or tostring(actionBoardID)

                        table.insert(triggers, {
                            cardEntity = cardEntity,
                            wandId = wandId,
                            actionBoardId = actionBoardID,
                            triggerId = triggerId,
                            index = index,
                        })
                        index = index + 1
                    end
                end
            end
        end
    end

    return triggers
end

local function findEntryBySource(sourceCardEntity)
    for _, entry in ipairs(strip_entries) do
        if entry.sourceCardEntity == sourceCardEntity then
            return entry
        end
    end
    return nil
end

local function findEntryByWandId(wandId)
    for _, entry in ipairs(strip_entries) do
        if entry.wandId == wandId then
            return entry
        end
    end
    return nil
end

function TriggerStripUI.sync()
    local currentTriggers = collectEquippedTriggers()
    local totalCount = #currentTriggers

    -- Build lookup of current source entities
    local currentSources = {}
    for _, trigger in ipairs(currentTriggers) do
        currentSources[trigger.cardEntity] = trigger
    end

    -- Remove orphaned entries (triggers no longer equipped)
    for i = #strip_entries, 1, -1 do
        local entry = strip_entries[i]
        if not currentSources[entry.sourceCardEntity] then
            destroyEntry(entry)
            table.remove(strip_entries, i)
        end
    end

    -- Add missing entries and update positions
    for idx, trigger in ipairs(currentTriggers) do
        local existing = findEntryBySource(trigger.cardEntity)
        if existing then
            -- Update position
            existing.centerY = calculateYPosition(idx, totalCount) + CARD_HEIGHT / 2
            if registry:valid(existing.entity) then
                local t = component_cache.get(existing.entity, Transform)
                if t then
                    t.actualY = calculateYPosition(idx, totalCount)
                end
            end
        else
            -- Create new entry
            local entry = createStripEntry(
                trigger.cardEntity,
                trigger.wandId,
                trigger.triggerId,
                idx,
                totalCount,
                trigger.actionBoardId
            )
            if entry then
                table.insert(strip_entries, entry)
                -- If strip is visible, add state tag
                if strip_visible and add_state_tag then
                    add_state_tag(entry.entity, ACTION_STATE)
                end
            end
        end
    end

    log_debug("TriggerStripUI: synced", #strip_entries, "trigger entries")
end

--------------------------------------------------------------------------------
-- VISIBILITY STATE
--------------------------------------------------------------------------------

function TriggerStripUI.show()
    if strip_visible then return end

    -- Sync first to ensure we have current triggers
    TriggerStripUI.sync()

    for _, entry in ipairs(strip_entries) do
        if registry:valid(entry.entity) then
            -- Add to action state for rendering
            if add_state_tag then
                add_state_tag(entry.entity, ACTION_STATE)
            end

            -- Reset to peeking position
            local t = component_cache.get(entry.entity, Transform)
            if t then
                t.actualX = PEEK_X
                t.scale = 1.0
            end
        end
    end

    strip_visible = true
    focusedEntry = nil
    previousFocusedEntry = nil

    log_debug("TriggerStripUI: shown with", #strip_entries, "triggers")
end

function TriggerStripUI.hide()
    if not strip_visible then return end

    log_debug("TriggerStripUI.hide called from:", debug.traceback())

    -- Hide any active tooltips (both card and wand)
    if activeTooltipEntry then
        if hideSimpleTooltip then
            hideSimpleTooltip("trigger_strip_card_" .. activeTooltipEntry.entity)
            hideSimpleTooltip("trigger_strip_wand_" .. activeTooltipEntry.entity)
        end
        activeTooltipEntry = nil
    end

    -- Cancel tooltip timer
    if tooltipTimerTag then
        timer.cancel(tooltipTimerTag)
        tooltipTimerTag = nil
    end

    -- Remove from all render states
    for _, entry in ipairs(strip_entries) do
        if registry:valid(entry.entity) then
            if clear_state_tags then
                clear_state_tags(entry.entity)
            end
        end
    end

    strip_visible = false
    focusedEntry = nil
    previousFocusedEntry = nil

    log_debug("TriggerStripUI: hidden")
end

function TriggerStripUI.isVisible()
    return strip_visible
end

--------------------------------------------------------------------------------
-- WAVE INTERACTION
--------------------------------------------------------------------------------

local function calculateWaveInfluence(cardCenterY, mouseY)
    local distance = math.abs(cardCenterY - mouseY)
    if distance > WAVE_RADIUS then return 0 end

    -- Smooth cosine falloff: 1.0 at center, 0 at edge
    local t = distance / WAVE_RADIUS
    return 0.5 * (1 + math.cos(t * math.pi))
end

function TriggerStripUI.update(dt)
    if not strip_visible then return end
    if #strip_entries == 0 then return end

    -- Get mouse position (screen space)
    local mouseX, mouseY = 0, 0
    if input then
        -- input.getMousePosition() returns a table {x=..., y=...}
        if input.getMousePos then
            local m = input.getMousePos()
            if m and m.x and m.y then
                mouseX, mouseY = m.x, m.y
            end
        elseif input.getMousePosition then
            local m = input.getMousePosition()
            if m and m.x and m.y then
                mouseX, mouseY = m.x, m.y
            end
        end
    elseif globals and globals.mouseX then
        mouseX = globals.mouseX
        mouseY = globals.mouseY or 0
    end

    local inStripArea = mouseX < STRIP_HOVER_ZONE

    -- Debug: log periodically when in strip area
    if inStripArea then
        if not TriggerStripUI._lastDebugTime or (os.clock() - TriggerStripUI._lastDebugTime) > 1.0 then
            TriggerStripUI._lastDebugTime = os.clock()
            log_debug("TriggerStripUI: mouse=", mouseX, ",", mouseY, " entries=", #strip_entries)
        end
    end

    previousFocusedEntry = focusedEntry
    focusedEntry = nil
    local maxInfluence = 0.3  -- Minimum threshold to count as focused

    for _, entry in ipairs(strip_entries) do
        if not registry:valid(entry.entity) then goto continue end

        -- Calculate wave influence
        if inStripArea then
            entry.influence = calculateWaveInfluence(entry.centerY, mouseY)
        else
            entry.influence = 0
        end

        -- Track most-focused card
        if entry.influence > maxInfluence then
            maxInfluence = entry.influence
            focusedEntry = entry
        end

        local t = component_cache.get(entry.entity, Transform)
        if t then
            local now = GetTime and GetTime() or 0
            local isActivationPopActive = entry.popUntil and now < entry.popUntil

            if not isActivationPopActive then
                t.scale = 1.0 + (MAX_SCALE_BUMP * entry.influence)
            end
            t.actualX = PEEK_X + (MAX_SLIDE_OUT * entry.influence)
        end

        ::continue::
    end

    -- Jiggle on focus change
    if focusedEntry and focusedEntry ~= previousFocusedEntry then
        if transform and transform.InjectDynamicMotion then
            transform.InjectDynamicMotion(focusedEntry.entity, 0, 1)
        end
    end

    TriggerStripUI.updateTooltip()
    TriggerStripUI.updateCooldowns()
    TriggerStripUI.updateManaState(dt)
end

--------------------------------------------------------------------------------
-- TOOLTIPS
--------------------------------------------------------------------------------

local TOOLTIP_TITLE_SIZE = 16
local TOOLTIP_BODY_SIZE = 12
local TOOLTIP_GAP = 3

-- Helper to get wandDef from entry's wandId
-- NOTE: Updated for grid inventory (Phase 5)
local function getWandDefForEntry(entry)
    if not entry then return nil end

    -- Try grid adapter first (Phase 5)
    local ok, wandAdapter = pcall(require, "ui.wand_grid_adapter")
    if ok and wandAdapter and wandAdapter.getWandCount then
        local wandCount = wandAdapter.getWandCount()
        for wandIndex = 1, wandCount do
            local wandDef = wandAdapter.getWandDef(wandIndex)
            if wandDef and wandDef.id == entry.wandId then
                return wandDef
            end
        end
    end

    -- Fallback to board_sets
    if board_sets then
        for _, boardSet in ipairs(board_sets) do
            -- Match by actionBoardId (entity) or wandId (definition ID)
            if boardSet.action_board_id == entry.actionBoardId then
                return boardSet.wandDef
            elseif boardSet.wandDef and boardSet.wandDef.id == entry.wandId then
                return boardSet.wandDef
            end
        end
    end
    return nil
end

-- Build wand stats text (multi-line for proper wrapping)
local function buildWandStatsText(wandDef)
    if not wandDef then return "" end

    local lines = {}

    if wandDef.cast_block_size and wandDef.cast_block_size > 0 then
        table.insert(lines, "Cast: " .. wandDef.cast_block_size)
    end
    if wandDef.cast_delay and wandDef.cast_delay > 0 then
        table.insert(lines, "Delay: " .. string.format("%.1fs", wandDef.cast_delay))
    end
    if wandDef.recharge_time and wandDef.recharge_time > 0 then
        table.insert(lines, "Recharge: " .. string.format("%.1fs", wandDef.recharge_time))
    end
    if wandDef.total_card_slots and wandDef.total_card_slots > 0 then
        table.insert(lines, "Slots: " .. wandDef.total_card_slots)
    end

    return table.concat(lines, "\n")
end

local function showTriggerTooltip(entry)
    if not entry or not registry:valid(entry.entity) then return end
    if not ensureSimpleTooltip then return end

    -- Get trigger card definition
    local triggerTitle = entry.triggerId or "Trigger"
    local triggerBody = ""

    if WandEngine and WandEngine.trigger_card_defs then
        local cardDef = WandEngine.trigger_card_defs[entry.triggerId]
        if cardDef then
            triggerTitle = cardDef.name or entry.triggerId
            triggerBody = cardDef.description or ""
        end
    end

    -- Get wand definition
    local wandDef = getWandDefForEntry(entry)
    local wandTitle = wandDef and (wandDef.name or wandDef.id or "Wand") or "Wand"
    local wandBody = buildWandStatsText(wandDef)

    -- Get card position and dimensions
    local entryTransform = component_cache.get(entry.entity, Transform)
    if not entryTransform then return end

    local cardX = entryTransform.actualX or 0
    local cardY = entryTransform.actualY or 0
    local cardW = entryTransform.actualW or CARD_WIDTH
    local cardH = entryTransform.actualH or CARD_HEIGHT
    local cardCenterY = cardY + cardH / 2

    -- X position: to the right of the card
    local tooltipX = cardX + cardW + 10

    -- Create both tooltips first (to measure their heights)
    local triggerKey = "trigger_strip_card_" .. entry.entity
    local triggerTooltip = ensureSimpleTooltip(triggerKey, triggerTitle, triggerBody, {
        titleFontSize = TOOLTIP_TITLE_SIZE,
        bodyFontSize = TOOLTIP_BODY_SIZE,
        maxWidth = 200,
    })

    local wandKey = "trigger_strip_wand_" .. entry.entity
    local wandTooltip = ensureSimpleTooltip(wandKey, wandTitle, wandBody, {
        titleFontSize = TOOLTIP_TITLE_SIZE,
        bodyFontSize = TOOLTIP_BODY_SIZE,
        maxWidth = 200,
    })

    -- Measure tooltip heights
    local triggerHeight = 0
    local wandHeight = 0

    if triggerTooltip and registry:valid(triggerTooltip) then
        local tt = component_cache.get(triggerTooltip, Transform)
        if tt then triggerHeight = tt.actualH or 40 end
    end

    if wandTooltip and registry:valid(wandTooltip) then
        local wt = component_cache.get(wandTooltip, Transform)
        if wt then wandHeight = wt.actualH or 40 end
    end

    -- Calculate total height and centered Y position
    local totalHeight = triggerHeight + TOOLTIP_GAP + wandHeight
    local startY = cardCenterY - totalHeight / 2

    -- Position trigger tooltip (on top)
    if triggerTooltip and registry:valid(triggerTooltip) then
        if ui and ui.box and ui.box.AddStateTagToUIBox then
            ui.box.ClearStateTagsFromUIBox(triggerTooltip)
            if PLANNING_STATE then ui.box.AddStateTagToUIBox(triggerTooltip, PLANNING_STATE) end
            if ACTION_STATE then ui.box.AddStateTagToUIBox(triggerTooltip, ACTION_STATE) end
        end

        local tt = component_cache.get(triggerTooltip, Transform)
        if tt then
            tt.actualX = tooltipX
            tt.actualY = startY
            tt.visualX = tt.actualX
            tt.visualY = tt.actualY
        end
    end

    -- Position wand tooltip (below trigger tooltip)
    if wandTooltip and registry:valid(wandTooltip) then
        if ui and ui.box and ui.box.AddStateTagToUIBox then
            ui.box.ClearStateTagsFromUIBox(wandTooltip)
            if PLANNING_STATE then ui.box.AddStateTagToUIBox(wandTooltip, PLANNING_STATE) end
            if ACTION_STATE then ui.box.AddStateTagToUIBox(wandTooltip, ACTION_STATE) end
        end

        local wt = component_cache.get(wandTooltip, Transform)
        if wt then
            wt.actualX = tooltipX
            wt.actualY = startY + triggerHeight + TOOLTIP_GAP
            wt.visualX = wt.actualX
            wt.visualY = wt.actualY
        end
    end

    activeTooltipEntry = entry
end

local function hideTriggerTooltips(entry)
    if not entry then return end
    if hideSimpleTooltip then
        hideSimpleTooltip("trigger_strip_card_" .. entry.entity)
        hideSimpleTooltip("trigger_strip_wand_" .. entry.entity)
    end
end

function TriggerStripUI.updateTooltip()
    -- Focus changed - reset tooltip
    if focusedEntry ~= activeTooltipEntry then
        -- Hide existing tooltips (both card and wand)
        if activeTooltipEntry then
            hideTriggerTooltips(activeTooltipEntry)
        end

        -- Cancel pending tooltip timer
        if tooltipTimerTag then
            timer.cancel(tooltipTimerTag)
            tooltipTimerTag = nil
        end

        -- Track the new focused entry immediately to prevent timer reset loop
        activeTooltipEntry = focusedEntry

        -- Start new delayed tooltip if we have a focused entry
        if focusedEntry then
            tooltipTimerTag = "trigger_strip_tooltip_" .. focusedEntry.entity
            timer.after_opts({
                delay = TOOLTIP_DELAY,
                action = function()
                    -- Verify focus hasn't changed during delay
                    if activeTooltipEntry == focusedEntry and strip_visible then
                        showTriggerTooltip(focusedEntry)
                    end
                end,
                tag = tooltipTimerTag
            })
        end
    end
end

--------------------------------------------------------------------------------
-- COOLDOWN UPDATES
--------------------------------------------------------------------------------

-- Helper to set per-entity shader uniform (using ShaderUniformComponent pattern)
local function setEntityShaderUniform(entity, shaderName, uniformName, value)
    if not registry:valid(entity) then
        log_debug("setEntityShaderUniform: invalid entity")
        return false
    end
    if not shaders or not shaders.ShaderUniformComponent then
        log_debug("setEntityShaderUniform: shaders or ShaderUniformComponent not available")
        return false
    end

    -- Ensure ShaderUniformComponent exists
    if not registry:has(entity, shaders.ShaderUniformComponent) then
        log_debug("setEntityShaderUniform: emplacing ShaderUniformComponent for entity", entity)
        registry:emplace(entity, shaders.ShaderUniformComponent)
    end

    local uniforms = registry:get(entity, shaders.ShaderUniformComponent)
    if uniforms and uniforms.set then
        uniforms:set(shaderName, uniformName, value)
        log_debug("setEntityShaderUniform: set", shaderName, uniformName, "=", value, "on entity", entity)
        return true
    else
        log_debug("setEntityShaderUniform: uniforms.set not available")
        return false
    end
end

-- Debug: throttle logging
local lastCooldownLogTime = 0
local COOLDOWN_LOG_INTERVAL = 2.0  -- Log every 2 seconds

function TriggerStripUI.updateCooldowns()
    local now = GetTime and GetTime() or 0
    local shouldLog = (now - lastCooldownLogTime) > COOLDOWN_LOG_INTERVAL

    if shouldLog then
        log_debug("TriggerStripUI.updateCooldowns: checking", #strip_entries, "entries")
        lastCooldownLogTime = now
    end

    local triggers = getWandTriggers()

    for _, entry in ipairs(strip_entries) do
        if not registry:valid(entry.entity) then goto continue end

        local progress = 1.0  -- 1.0 = ready, 0.0 = just fired

        if triggers and triggers.getRegistration then
            local registration = triggers.getRegistration(entry.wandId)
            if registration then
                if registration.triggerType == "every_N_seconds" then
                    local elapsed = registration.elapsed or 0
                    local interval = registration.interval or 1.0
                    progress = math.min(1.0, elapsed / interval)

                    if shouldLog then
                        log_debug("  TIMER:", entry.wandId, "elapsed:", elapsed, "interval:", interval, "progress:", progress)
                    end
                elseif registration.triggerType == "on_distance_traveled" then
                    local distTracking = triggers.distanceTracking and triggers.distanceTracking[entry.wandId]
                    if distTracking then
                        local dist = distTracking.totalDistance or 0
                        local threshold = distTracking.threshold or 100
                        progress = math.min(1.0, dist / threshold)
                    end
                end
            end
        end

        progress = math.max(0, math.min(1, progress))

        -- shaderProgress: 0.0 = ready (no dim), 1.0 = full cooldown (full dim)
        local shaderProgress = 1.0 - progress
        setEntityShaderUniform(entry.entity, "cooldown_pie", "cooldown_progress", shaderProgress)

        if shouldLog and shaderProgress > 0.01 then
            log_debug("COOLDOWN ACTIVE: entity", entry.entity, "shaderProgress =", shaderProgress)
        end

        ::continue::
    end
end

function TriggerStripUI.updateManaState(dt)
    local executor = getWandExecutor()
    if not executor then return end
    
    for _, entry in ipairs(strip_entries) do
        local state = executor.getWandState and executor.getWandState(entry.wandId)
        if state then
            local ms = manaState[entry.wandId] or { smoothRatio = 1, currentMana = 0, maxMana = 0 }
            ms.currentMana = state.currentMana or 0
            ms.maxMana = state.maxMana or 0
            
            local targetRatio = 1
            if ms.maxMana > 0 then
                targetRatio = math.max(0, math.min(1, ms.currentMana / ms.maxMana))
            end
            
            local lerpRate = math.min(1, dt * 8)
            ms.smoothRatio = ms.smoothRatio + (targetRatio - ms.smoothRatio) * lerpRate
            manaState[entry.wandId] = ms
        end
    end
end

--------------------------------------------------------------------------------
-- ACTIVATION FEEDBACK
--------------------------------------------------------------------------------

local POP_DURATION = 0.25

function TriggerStripUI.onTriggerActivated(wandId, triggerId)
    local entry = findEntryByWandId(wandId)
    if not entry then
        log_debug("TriggerStripUI: no entry found for wandId", wandId)
        return
    end
    if not registry:valid(entry.entity) then return end

    log_debug("TriggerStripUI: triggering activation feedback for wand", wandId, "entity", entry.entity)

    local now = GetTime and GetTime() or 0
    entry.popUntil = now + POP_DURATION

    local t = component_cache.get(entry.entity, Transform)
    if t then
        t.scale = ACTIVATION_SCALE
        log_debug("TriggerStripUI: set scale to", ACTIVATION_SCALE)
    end

    if transform and transform.InjectDynamicMotion then
        transform.InjectDynamicMotion(entry.entity, 0.3, 1.5)
        log_debug("TriggerStripUI: injected dynamic motion")
    end

    setEntityShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 1.0)

    timer.after_opts({
        delay = FLASH_DURATION,
        action = function()
            if registry:valid(entry.entity) then
                setEntityShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 0.0)
            end
        end,
        tag = "trigger_flash_" .. entry.entity
    })

    timer.after_opts({
        delay = POP_DURATION,
        action = function()
            if registry:valid(entry.entity) then
                local tr = component_cache.get(entry.entity, Transform)
                if tr then tr.scale = 1.0 end
            end
        end,
        tag = "trigger_pop_reset_" .. entry.entity
    })

    log_debug("TriggerStripUI: activation feedback complete for wand", wandId)
end

--------------------------------------------------------------------------------
-- DRAW
--------------------------------------------------------------------------------

function TriggerStripUI.draw()
    if not strip_visible then
        return
    end
    if not command_buffer or not layers or not layers.ui then
        log_debug("TriggerStripUI.draw: missing command_buffer or layers")
        return
    end

    local z = (z_orders and z_orders.ui_tooltips or 0) - 5
    local space = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen

    local drawCount = 0
    for _, entry in ipairs(strip_entries) do
        if entry.entity and registry and registry:valid(entry.entity) then
            local hasPipeline = false
            if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
                hasPipeline = registry:has(entry.entity, shader_pipeline.ShaderPipelineComponent)
            end

            local queue = hasPipeline and command_buffer.queueDrawTransformEntityAnimationPipeline
                or command_buffer.queueDrawTransformEntityAnimation

            if queue then
                queue(layers.ui, function(cmd)
                    cmd.registry = registry
                    cmd.e = entry.entity
                end, z, space)
                drawCount = drawCount + 1
            end
            
            local ms = manaState[entry.wandId]
            if ms and ms.smoothRatio < 0.99 then
                local t = component_cache.get(entry.entity, Transform)
                if t then
                    local barHeight = CARD_HEIGHT * MP_BAR_HEIGHT_RATIO
                    local barX = t.actualX + CARD_WIDTH + MP_BAR_OFFSET_X
                    local barCenterY = t.actualY + CARD_HEIGHT * 0.5
                    local barTop = barCenterY - barHeight * 0.5
                    
                    command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                        c.x = barX + MP_BAR_WIDTH * 0.5
                        c.y = barCenterY
                        c.w = MP_BAR_WIDTH
                        c.h = barHeight
                        c.rx = MP_BAR_WIDTH * 0.5
                        c.ry = MP_BAR_WIDTH * 0.5
                        c.color = Col(40, 40, 50, 80)
                    end, z + 1, space)
                    
                    local fillH = barHeight * ms.smoothRatio
                    if fillH > 1 then
                        local fillY = barTop + barHeight - fillH * 0.5
                        local barColor
                        if ms.smoothRatio < 0.25 then
                            barColor = Col(255, 80, 80, 200)
                        elseif ms.smoothRatio < 0.50 then
                            barColor = Col(255, 200, 80, 200)
                        else
                            barColor = Col(80, 200, 255, 200)
                        end
                        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
                            c.x = barX + MP_BAR_WIDTH * 0.5
                            c.y = fillY
                            c.w = MP_BAR_WIDTH
                            c.h = fillH
                            c.rx = MP_BAR_WIDTH * 0.5
                            c.ry = MP_BAR_WIDTH * 0.5
                            c.color = barColor
                        end, z + 2, space)
                    end
                end
            end
        end
    end

    if drawCount > 0 then
        log_debug("TriggerStripUI.draw: queued", drawCount, "entities")
    end
end

--------------------------------------------------------------------------------
-- INITIALIZATION & CLEANUP
--------------------------------------------------------------------------------

function TriggerStripUI.init()
    -- Register for sync signals using signal_group for proper cleanup
    handlers = signal_group.new("trigger_strip_ui")
    handlers:on("deck_changed", function()
        if strip_visible then
            TriggerStripUI.sync()
        end
    end)

    -- Note: trigger_activated signal needs to be emitted from wand_triggers.lua
    -- This will be handled in the integration task

    log_debug("TriggerStripUI: initialized")
end

function TriggerStripUI.cleanup()
    TriggerStripUI.hide()
    destroyAllEntries()

    -- Cleanup signal handlers
    if handlers then
        handlers:cleanup()
    end

    log_debug("TriggerStripUI: cleaned up")
end

return TriggerStripUI
