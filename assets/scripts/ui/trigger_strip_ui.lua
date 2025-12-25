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

-- Dependencies
local timer = require("core.timer")
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")

-- Constants
local CARD_WIDTH = 60           -- 75% of 80
local CARD_HEIGHT = 84          -- 75% of 112
local PEEK_X = -30              -- Resting X position (half hidden)
local WAVE_RADIUS = 80          -- Wave influence radius in pixels
local MAX_SCALE_BUMP = 0.25     -- Max scale increase (1.0 -> 1.25)
local MAX_SLIDE_OUT = 40        -- Max slide-out distance
local STRIP_HOVER_ZONE = 100    -- Mouse X threshold for interaction
local TOOLTIP_DELAY = 0.3       -- Seconds before tooltip appears
local VERTICAL_SPACING = 20     -- Gap between cards
local ACTIVATION_SCALE = 1.4    -- Scale on trigger activation
local FLASH_DURATION = 0.15     -- Flash effect duration

-- State
local strip_entries = {}        -- Array of {entity, sourceCardEntity, wandId, triggerId, centerY, influence}
local strip_visible = false
local focusedEntry = nil
local previousFocusedEntry = nil
local activeTooltipEntry = nil
local tooltipTimerTag = nil
local handlers = nil

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

local function createStripEntry(sourceCardEntity, wandId, triggerId, index, totalCount)
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

    -- Mark as UI-attached for proper screen-space rendering
    if registry and registry.valid and ObjectAttachedToUITag and registry:valid(entity) then
        if not registry:has(entity, ObjectAttachedToUITag) then
            registry:emplace(entity, ObjectAttachedToUITag)
        end
    end

    -- Resize to trigger strip size
    animation_system.resizeAnimationObjectsInEntityToFit(entity, CARD_WIDTH, CARD_HEIGHT)

    -- Apply shader preset with cooldown pie
    if applyShaderPreset then
        applyShaderPreset(registry, entity, "trigger_card", {
            cooldown_progress = 0.0,
            dim_amount = 0.4,
            flash_intensity = 0.0,
        })
    end

    -- Start hidden (not in any render state)
    if clear_state_tags then
        clear_state_tags(entity)
    end

    return {
        entity = entity,
        sourceCardEntity = sourceCardEntity,
        wandId = wandId,
        triggerId = triggerId,
        centerY = yPos + CARD_HEIGHT / 2,
        influence = 0,
    }
end

--------------------------------------------------------------------------------
-- SYNC WITH WAND TRIGGERS
--------------------------------------------------------------------------------

local function collectEquippedTriggers()
    local triggers = {}

    -- Access the trigger_board_id_to_action_board_id mapping from gameplay
    if not trigger_board_id_to_action_board_id then return triggers end
    if not boards then return triggers end

    local index = 1
    for triggerBoardID, actionBoardID in pairs(trigger_board_id_to_action_board_id) do
        if ensure_entity(triggerBoardID) then
            local triggerBoard = boards[triggerBoardID]
            if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                local cardEntity = triggerBoard.cards[1]
                if ensure_entity(cardEntity) then
                    local script = getScriptTableFromEntityID(cardEntity)
                    local triggerId = script and script.cardID or "unknown"
                    table.insert(triggers, {
                        cardEntity = cardEntity,
                        wandId = actionBoardID,  -- Use action board ID as wand identifier
                        triggerId = triggerId,
                        index = index,
                    })
                    index = index + 1
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
                totalCount
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

        -- Apply wave to transform
        local t = component_cache.get(entry.entity, Transform)
        if t then
            local scale = 1.0 + (MAX_SCALE_BUMP * entry.influence)
            t.scale = scale
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

    -- Handle tooltip
    TriggerStripUI.updateTooltip()

    -- Update cooldowns
    TriggerStripUI.updateCooldowns()
end

--------------------------------------------------------------------------------
-- TOOLTIPS
--------------------------------------------------------------------------------

-- Smaller font sizes for compact dual-tooltip display
local TOOLTIP_TITLE_SIZE = 18
local TOOLTIP_BODY_SIZE = 14
local TOOLTIP_GAP = 4  -- Gap between stacked tooltips

-- Helper to get wandDef from entry's wandId (action board entity)
local function getWandDefForEntry(entry)
    if not entry or not entry.wandId then return nil end
    if not board_sets then return nil end

    for _, boardSet in ipairs(board_sets) do
        if boardSet.action_board_id == entry.wandId then
            return boardSet.wandDef
        end
    end
    return nil
end

-- Build compact wand stats text
local function buildWandStatsText(wandDef)
    if not wandDef then return "" end

    local parts = {}

    if wandDef.cast_block_size and wandDef.cast_block_size > 0 then
        table.insert(parts, "Cast: " .. wandDef.cast_block_size)
    end
    if wandDef.cast_delay and wandDef.cast_delay > 0 then
        table.insert(parts, "Delay: " .. string.format("%.1fs", wandDef.cast_delay))
    end
    if wandDef.recharge_time and wandDef.recharge_time > 0 then
        table.insert(parts, "Recharge: " .. string.format("%.1fs", wandDef.recharge_time))
    end
    if wandDef.total_card_slots and wandDef.total_card_slots > 0 then
        table.insert(parts, "Slots: " .. wandDef.total_card_slots)
    end

    return table.concat(parts, " | ")
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

    -- Calculate position for stacked tooltips
    -- We'll position the trigger tooltip above, and wand tooltip below it
    local entryTransform = component_cache.get(entry.entity, Transform)
    if not entryTransform then return end

    local anchorX = (entryTransform.actualX or 0) + (entryTransform.actualW or CARD_WIDTH) + 10
    local anchorY = entryTransform.actualY or 0

    -- Create/show trigger tooltip (on top)
    local triggerKey = "trigger_strip_card_" .. entry.entity
    local triggerTooltip = ensureSimpleTooltip(triggerKey, triggerTitle, triggerBody, {
        titleFontSize = TOOLTIP_TITLE_SIZE,
        bodyFontSize = TOOLTIP_BODY_SIZE,
        maxWidth = 200,
    })

    if triggerTooltip and registry:valid(triggerTooltip) then
        -- Add state tags for visibility
        if ui and ui.box and ui.box.AddStateTagToUIBox then
            ui.box.ClearStateTagsFromUIBox(triggerTooltip)
            if PLANNING_STATE then ui.box.AddStateTagToUIBox(triggerTooltip, PLANNING_STATE) end
            if ACTION_STATE then ui.box.AddStateTagToUIBox(triggerTooltip, ACTION_STATE) end
        end

        -- Position to the right of the card
        local tt = component_cache.get(triggerTooltip, Transform)
        if tt then
            tt.actualX = anchorX
            tt.actualY = anchorY
            tt.visualX = tt.actualX
            tt.visualY = tt.actualY
        end
    end

    -- Create/show wand tooltip (below trigger tooltip)
    local wandKey = "trigger_strip_wand_" .. entry.entity
    local wandTooltip = ensureSimpleTooltip(wandKey, wandTitle, wandBody, {
        titleFontSize = TOOLTIP_TITLE_SIZE,
        bodyFontSize = TOOLTIP_BODY_SIZE,
        maxWidth = 200,
    })

    if wandTooltip and registry:valid(wandTooltip) then
        -- Add state tags for visibility
        if ui and ui.box and ui.box.AddStateTagToUIBox then
            ui.box.ClearStateTagsFromUIBox(wandTooltip)
            if PLANNING_STATE then ui.box.AddStateTagToUIBox(wandTooltip, PLANNING_STATE) end
            if ACTION_STATE then ui.box.AddStateTagToUIBox(wandTooltip, ACTION_STATE) end
        end

        -- Position below trigger tooltip
        local triggerHeight = 0
        if triggerTooltip and registry:valid(triggerTooltip) then
            local triggerT = component_cache.get(triggerTooltip, Transform)
            if triggerT then
                triggerHeight = triggerT.actualH or 40
            end
        end

        local wt = component_cache.get(wandTooltip, Transform)
        if wt then
            wt.actualX = anchorX
            wt.actualY = anchorY + triggerHeight + TOOLTIP_GAP
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

function TriggerStripUI.updateCooldowns()
    if not WandTriggers or not WandTriggers.registrations then return end
    if not setShaderUniform then return end

    for _, entry in ipairs(strip_entries) do
        if not registry:valid(entry.entity) then goto continue end

        local registration = WandTriggers.registrations[entry.wandId]
        if registration then
            local progress = 0.0

            -- Calculate cooldown progress based on trigger type
            if registration.triggerType == "every_N_seconds" then
                -- Timer-based: check remaining time
                local interval = registration.triggerDef.interval or 1.0
                local elapsed = registration.elapsed or 0
                progress = 1.0 - (elapsed / interval)
                progress = math.max(0, math.min(1, progress))
            end

            -- Update shader uniform
            setShaderUniform(entry.entity, "cooldown_pie", "cooldown_progress", progress)
        end

        ::continue::
    end
end

--------------------------------------------------------------------------------
-- ACTIVATION FEEDBACK
--------------------------------------------------------------------------------

function TriggerStripUI.onTriggerActivated(wandId, triggerId)
    local entry = findEntryByWandId(wandId)
    if not entry then return end
    if not registry:valid(entry.entity) then return end

    -- Pop: quick scale bump
    local t = component_cache.get(entry.entity, Transform)
    if t then
        t.scale = ACTIVATION_SCALE
    end

    -- Jiggle
    if transform and transform.InjectDynamicMotion then
        transform.InjectDynamicMotion(entry.entity, 0.3, 1.5)
    end

    -- Flash via shader uniform
    if setShaderUniform then
        setShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 1.0)

        -- Reset flash after short delay
        timer.after_opts({
            delay = FLASH_DURATION,
            action = function()
                if registry:valid(entry.entity) then
                    setShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 0.0)
                end
            end,
            tag = "trigger_flash_" .. entry.entity
        })
    end

    log_debug("TriggerStripUI: activation feedback for wand", wandId)
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
