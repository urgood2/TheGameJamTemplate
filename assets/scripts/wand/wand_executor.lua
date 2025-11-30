--[[
================================================================================
WAND EXECUTION ENGINE (Main Orchestrator)
================================================================================
The main orchestrator that connects triggers -> card evaluation -> action execution.

Responsibilities:
- Wand state management (cooldowns, mana, charges)
- Cast block sequencing
- Integration with card evaluator
- Execution context management
- Sub-cast handling (timer, collision triggers)

Flow:
1. Trigger fires → WandExecutor.execute(wandId)
2. Check cooldowns & mana → evaluate cards
3. Execute cast blocks sequentially
4. Apply delays and update state

Integration:
- Uses WandTriggers for trigger management
- Uses card_eval_order_test.simulate_wand for card evaluation
- Uses WandActions for action execution
- Uses WandModifiers for modifier aggregation
================================================================================
]] --

local WandExecutor = {}

-- Dependencies
local timer = require("core.timer")
local cardEval = require("core.card_eval_order_test")
local WandActions = require("wand.wand_actions")
local WandModifiers = require("wand.wand_modifiers")
local WandTriggers = require("wand.wand_triggers")
local ProjectileSystem = require("combat.projectile_system")
local SpellTypeEvaluator = require("wand.spell_type_evaluator")
local JokerSystem = require("wand.joker_system")
local okSignal, signal = pcall(require, "external.hump.signal")

local DEBUG_SUBCAST = rawget(_G, "DEBUG_SUBCAST") ~= nil and rawget(_G, "DEBUG_SUBCAST") or true

local graphUI = nil
local blockFlashUI = nil

-- Generate a stable-ish id for a sub-cast so we can correlate schedule/enqueue/execute
local function makeSubcastTraceId(context, parent, triggerType)
    local wandId = context and (context.wandId or context.wandDefinition and context.wandDefinition.id) or "wand"
    local blockIdx = parent and parent.blockIndex or "?"
    local cardIdx = parent and parent.cardIndex or "?"
    local trigger = triggerType or "sub"
    return string.format("%s-%s-%s-%s-%.3f", tostring(wandId), tostring(blockIdx), tostring(cardIdx), tostring(trigger),
        os.clock())
end

local function emitSubcastDebug(stage, payload)
    if not DEBUG_SUBCAST then return end
    payload = payload or {}
    payload.stage = stage
    payload.timestamp = os.clock()

    local wandId = payload.wandId or (payload.context and payload.context.wandId) or "?"
    local trigger = payload.trigger or payload.triggerType or "?"
    local blockIdx = payload.blockIndex or (payload.parent and payload.parent.blockIndex) or "?"
    local cardIdx = payload.cardIndex or (payload.parent and payload.parent.cardIndex) or "?"
    local delay = payload.delay or payload.delaySeconds

    local parts = {
        "[SUBCAST]",
        stage,
        "wand=" .. tostring(wandId),
        "trigger=" .. tostring(trigger),
        "block=" .. tostring(blockIdx),
        "card=" .. tostring(cardIdx)
    }
    if delay then
        table.insert(parts, string.format("delay=%.3fs", tonumber(delay) or 0))
    end
    if payload.traceId then
        table.insert(parts, "id=" .. tostring(payload.traceId))
    end

    print(table.concat(parts, " "))

    if okSignal and signal and signal.emit then
        signal.emit("debug_subcast", payload)
    end
end

-- Exposed for other modules (e.g., wand_actions) to reuse the tracer
function WandExecutor.debugSubcastEvent(stage, payload)
    emitSubcastDebug(stage, payload)
end

local function shallowCopyTable(source)
    local copy = {}
    for k, v in pairs(source or {}) do
        if type(v) == "table" then
            local t = {}
            for i, vv in ipairs(v) do
                t[i] = vv
            end
            copy[k] = t
        else
            copy[k] = v
        end
    end
    return copy
end

local function maybeRenderExecutionGraph(blocks, wandId)
    if graphUI == false then return end
    if not blocks or #blocks == 0 then return end
    if not ui or not ui.box then return end

    if not graphUI then
        local ok, mod = pcall(require, "ui.cast_execution_graph_ui")
        if not ok then
            graphUI = false
            print("[WandExecutor] Execution graph UI unavailable: " .. tostring(mod))
            return
        end
        graphUI = mod
    end

    if graphUI and graphUI.render then
        graphUI.render(blocks, { wandId = wandId, title = "Last Cast" })
    end
end

local function maybeFlashBlock(block, context)
    if blockFlashUI == false then return end
    if not block or not block.cards or #block.cards == 0 then return end

    -- Only show during action phase if state helpers are available
    if is_state_active and ACTION_STATE and not is_state_active(ACTION_STATE) then
        return
    end

    -- Bail early if UI systems are unavailable (e.g., headless tests)
    if not (registry and spring and command_buffer and layers and layer and globals) then
        return
    end

    if not blockFlashUI then
        local ok, mod = pcall(require, "ui.cast_block_flash_ui")
        if not ok then
            blockFlashUI = false
            print("[WandExecutor] Cast block flash UI unavailable: " .. tostring(mod))
            return
        end
        blockFlashUI = mod
    end

    if blockFlashUI and blockFlashUI.pushBlock then
        local wandId = (context and context.wandDefinition and context.wandDefinition.id) or (context and context.wandId)
        blockFlashUI.pushBlock(block, { wandId = wandId, deck = context and context.cardPool })
    end
end

-- Wand states (persistent)
WandExecutor.wandStates = {}

-- Active wand instances (loaded wands with cards)
WandExecutor.activeWands = {}

-- Pending sub-casts (delayed/triggered casts)
WandExecutor.pendingSubCasts = {}

--[[
================================================================================
INITIALIZATION
================================================================================
]] --

--- Initializes the wand executor system
function WandExecutor.init()
    WandExecutor.wandStates = {}
    WandExecutor.activeWands = {}
    WandExecutor.pendingSubCasts = {}

    -- Initialize dependencies
    WandTriggers.init()
    ProjectileSystem.init()

    -- Fail fast if card definitions introduce fields we don't handle
    print("[WandExecutor] Initialized")
end

--- Updates the wand executor system
--- @param dt number Delta time in seconds
function WandExecutor.update(dt)
    -- Update triggers
    local playerEntity = WandExecutor.getPlayerEntity()
    WandTriggers.update(dt, playerEntity)

    -- Update projectiles
    ProjectileSystem.update(dt)

    -- Run any queued sub-casts (collision/death) outside physics callbacks
    WandExecutor.processPendingSubCasts()

    -- Update cooldowns
    WandExecutor.updateCooldowns(dt)

    -- Update mana regeneration
    WandExecutor.updateManaRegen(dt)

    -- Update charge regeneration
    WandExecutor.updateChargeRegen(dt)
end

--- Cleans up the wand executor system
function WandExecutor.cleanup()
    WandTriggers.cleanup()
    ProjectileSystem.cleanup()

    WandExecutor.wandStates = {}
    WandExecutor.activeWands = {}
    WandExecutor.pendingSubCasts = {}

    print("[WandExecutor] Cleaned up")
end

--[[
================================================================================
WAND LOADING & REGISTRATION
================================================================================
]] --

--- Loads a wand and registers its trigger
--- @param wandDef table Wand definition from card_eval_order_test
--- @param cardPool table Pool of card instances
--- @param triggerDef table Trigger definition
--- @return string Wand ID
function WandExecutor.loadWand(wandDef, cardPool, triggerDef)
    local wandId = wandDef.id

    -- Initialize wand state if doesn't exist
    if not WandExecutor.wandStates[wandId] then
        WandExecutor.wandStates[wandId] = WandExecutor.createWandState(wandDef)
    end

    -- Store active wand
    WandExecutor.activeWands[wandId] = {
        definition = wandDef,
        cardPool = cardPool,
        triggerDef = triggerDef,
    }

    -- Register trigger
    if triggerDef then
        WandTriggers.register(wandId, triggerDef, function(wId, triggerType)
            WandExecutor.execute(wId, triggerType)
        end, {
            canCast = function(targetWandId)
                return WandExecutor.canCast(targetWandId or wandId)
            end
        })
    end

    print("[WandExecutor] Loaded wand:", wandId)

    return wandId
end

--- Unloads a wand
--- @param wandId string Wand identifier
function WandExecutor.unloadWand(wandId)
    WandTriggers.unregister(wandId)
    WandExecutor.activeWands[wandId] = nil

    print("[WandExecutor] Unloaded wand:", wandId)
end

--[[
================================================================================
WAND STATE MANAGEMENT
================================================================================
]] --

--- Creates initial wand state
--- @param wandDef table Wand definition
--- @return table Wand state
function WandExecutor.createWandState(wandDef)
    local maxCharges = wandDef.max_charges or 0

    return {
        wandId = wandDef.id,

        -- Cooldown tracking
        cooldownRemaining = 0,
        lastCastTime = 0,

        -- Charge tracking
        charges = maxCharges,
        maxCharges = maxCharges,
        chargeRegenTime = wandDef.charge_regen_time or 0,
        lastChargeTime = os.clock(),

        -- Mana tracking
        currentMana = wandDef.mana_max or 100,
        maxMana = wandDef.mana_max or 100,
        manaRegenRate = wandDef.mana_recharge_rate or 5, -- per second

        -- Cast execution state
        currentBlockIndex = 1,
        deckIndex = 1,
        isRecharging = false,
        isCasting = false,

        -- Runtime state
        lastEvaluationResult = nil, -- cached evaluation result
    }
end

--- Gets wand state, creating if doesn't exist
--- @param wandId string Wand identifier
--- @return table Wand state
function WandExecutor.getWandState(wandId)
    if not WandExecutor.wandStates[wandId] then
        local activeWand = WandExecutor.activeWands[wandId]
        if activeWand then
            WandExecutor.wandStates[wandId] = WandExecutor.createWandState(activeWand.definition)
        else
            print("[WandExecutor] Warning: No active wand for", wandId)
            return nil
        end
    end

    return WandExecutor.wandStates[wandId]
end

--- Updates cooldowns for all wands
--- @param dt number Delta time in seconds
function WandExecutor.updateCooldowns(dt)
    for wandId, state in pairs(WandExecutor.wandStates) do
        if state.cooldownRemaining > 0 then
            state.cooldownRemaining = math.max(0, state.cooldownRemaining - dt)
        end
    end
end

--- Updates mana regeneration for all wands
--- @param dt number Delta time in seconds
function WandExecutor.updateManaRegen(dt)
    for wandId, state in pairs(WandExecutor.wandStates) do
        if state.currentMana < state.maxMana then
            state.currentMana = math.min(state.maxMana, state.currentMana + state.manaRegenRate * dt)
        end
    end
end

--- Updates charge regeneration for all wands
--- @param dt number Delta time in seconds
function WandExecutor.updateChargeRegen(dt)
    local currentTime = os.clock()

    for wandId, state in pairs(WandExecutor.wandStates) do
        if state.charges < state.maxCharges and state.chargeRegenTime > 0 then
            local timeSinceLastCharge = currentTime - state.lastChargeTime

            if timeSinceLastCharge >= state.chargeRegenTime then
                state.charges = math.min(state.maxCharges, state.charges + 1)
                state.lastChargeTime = currentTime
            end
        end
    end
end

--[[
================================================================================
MAIN EXECUTION
================================================================================
]] --

--- Executes a wand (called by trigger)
--- @param wandId string Wand identifier
--- @param triggerType string Trigger type that fired
--- @return boolean Success
function WandExecutor.execute(wandId, triggerType)
    local activeWand = WandExecutor.activeWands[wandId]
    if not activeWand then
        print("[WandExecutor] Error: No active wand", wandId)
        return false
    end

    local state = WandExecutor.getWandState(wandId)
    if not state then
        print("[WandExecutor] Error: No wand state", wandId)
        return false
    end

    -- Check if can cast
    if not WandExecutor.canCast(wandId) then
        print("[WandExecutor] Cannot cast wand", wandId, "- on cooldown or out of charges")
        return false
    end

    -- Create execution context
    local context = WandExecutor.createExecutionContext(wandId, state, activeWand)

    -- Evaluate cards
    local evaluationResult = cardEval.simulate_wand(activeWand.definition, activeWand.cardPool)
    state.lastEvaluationResult = evaluationResult

    if not evaluationResult or not evaluationResult.blocks or #evaluationResult.blocks == 0 then
        print("[WandExecutor] Warning: No cast blocks from evaluation")
        return false
    end

    maybeRenderExecutionGraph(evaluationResult.blocks, wandId)

    state.isCasting = true
    state.currentCastProgress = {
        total = #evaluationResult.blocks,
        executed = 0,
    }

    local function finalizeExecution(success, totalCastDelay)
        state.isCasting = false
        state.currentCastProgress = nil
        if not success then
            print("[WandExecutor] Cast aborted for wand", wandId)
            return
        end

        -- Apply recharge time (only once, after all blocks)
        local baseRechargeTime = (activeWand.definition.recharge_time or 0) / 1000
        local rechargeTime = baseRechargeTime
        local cooldownReduction = 0

        -- Apply Player CDR to recharge time
        if context.playerStats and context.playerStats.get then
            cooldownReduction = context.playerStats:get("cooldown_reduction") or 0
            if cooldownReduction > 0 then
                rechargeTime = rechargeTime * (1.0 - cooldownReduction / 100)
            end
        end

        context.cumulative.recharge.base = baseRechargeTime
        context.cumulative.recharge.afterCdr = rechargeTime

        -- Total cooldown = accumulated cast delay + recharge time
        local cooldownBeforePenalty = totalCastDelay + rechargeTime
        local totalCooldown = cooldownBeforePenalty
        local cooldownPenaltyMult = 1.0

        -- Apply overheat penalty to total cooldown if we went negative on mana/flux
        if state.currentMana < 0 then
            local deficit = math.abs(state.currentMana)
            local maxFlux = context.wandDefinition.mana_max or state.maxMana or 100
            local overloadRatio = deficit / math.max(maxFlux, 1)
            local penaltyFactor = context.wandDefinition.overheat_penalty_factor or 5.0

            cooldownPenaltyMult = 1.0 + (overloadRatio * penaltyFactor)
            totalCooldown = totalCooldown * cooldownPenaltyMult

            context.cumulative.overheatPenaltyMult = math.max(context.cumulative.overheatPenaltyMult or 1.0,
                cooldownPenaltyMult)

            print(string.format(
                "[WandExecutor] Overheat penalty applied - deficit: %.1f, ratio: %.2f, mult: %.2f, cooldown: %.3fs",
                deficit, overloadRatio, cooldownPenaltyMult, totalCooldown))
        end

        state.cooldownRemaining = totalCooldown
        state.lastCastTime = os.clock()

        -- Consume a charge if the wand uses charges
        if state.maxCharges > 0 then
            state.charges = math.max(0, state.charges - 1)
            state.lastChargeTime = os.clock()
        end

        -- Store last execution state for debugging/telemetry
        state.lastExecutionState = {
            timestamp = os.clock(),
            totalManaSpent = context.cumulative.manaSpent,
            manaSpentActions = context.cumulative.manaSpentActions,
            manaSpentModifiers = context.cumulative.manaSpentModifiers,
            manaCostMultiplier = context.cumulative.manaCostMultiplier,
            totalProjectiles = context.cumulative.projectileCount,
            totalCastDelay = (context.cumulative.castDelayAdjusted > 0 and context.cumulative.castDelayAdjusted
                or totalCastDelay) * 1000, -- ms
            baseCastDelay = context.cumulative.castDelayBase * 1000,        -- ms
            totalRecharge = rechargeTime * 1000,                            -- ms
            baseRecharge = baseRechargeTime * 1000,                         -- ms
            cooldownReduction = cooldownReduction,
            cooldownBeforePenalty = cooldownBeforePenalty,
            cooldownPenaltyMult = cooldownPenaltyMult,
            overheatPenaltyMult = context.cumulative.overheatPenaltyMult or 1.0,
            cooldownSeconds = totalCooldown,
            blocksExecuted = #evaluationResult.blocks,
            blocks = context.cumulative.blocks
        }
    end

    -- Execute cast blocks sequentially over time
    WandExecutor.executeCastBlocks(evaluationResult.blocks, context, state, finalizeExecution)

    return true
end

--- Checks if a wand can be cast
--- @param wandId string Wand identifier
--- @return boolean True if can cast
function WandExecutor.canCast(wandId)
    local state = WandExecutor.getWandState(wandId)
    if not state then return false end

    -- Check cooldown
    if state.cooldownRemaining > 0 then
        return false
    end

    -- Prevent re-entrancy while a cast chain is in progress
    if state.isCasting then
        return false
    end

    -- Check charges
    if state.maxCharges > 0 and state.charges <= 0 then
        return false
    end

    return true
end

--[[
================================================================================
CAST BLOCK EXECUTION
================================================================================
]] --

--- Executes a sequence of cast blocks
--- @param blocks table Array of cast blocks from card evaluation
--- @param context table Execution context
--- @param state table Wand state
--- @param onComplete function Callback(success:boolean, totalCastDelay:number)
function WandExecutor.executeCastBlocks(blocks, context, state, onComplete)
    local totalCastDelay = 0 -- Accumulate cast delay across all blocks

    local function runBlock(blockIndex)
        if blockIndex > #blocks then
            if onComplete then onComplete(true, totalCastDelay) end
            return
        end

        local block = blocks[blockIndex]
        local success, blockCastDelay = WandExecutor.executeCastBlock(block, context, state, blockIndex)

        if not success then
            print("[WandExecutor] Warning: Cast block", blockIndex, "failed")
            if onComplete then onComplete(false, totalCastDelay) end
            return
        end

        if state.currentCastProgress then
            state.currentCastProgress.executed = blockIndex
        end

        -- Accumulate cast delay
        totalCastDelay = totalCastDelay + blockCastDelay

        -- Apply cast delay between blocks
        local interBlockDelay = 0
        if blockIndex < #blocks then
            local delay = block.block_delay or 0
            if delay > 0 then
                interBlockDelay = delay / 1000
                totalCastDelay = totalCastDelay + interBlockDelay
            end
        end

        if blockIndex < #blocks then
            local delaySeconds = math.max(0, blockCastDelay + interBlockDelay)
            timer.after(delaySeconds, function()
                runBlock(blockIndex + 1)
            end, "wand_block_" .. tostring(context.wandId) .. "_" .. tostring(blockIndex) .. "_" .. tostring(os.clock()))
        else
            if onComplete then onComplete(true, totalCastDelay) end
        end
    end

    runBlock(1)
end

local function buildChildCastMap(block, blockIndex, context)
    local lookup = {}
    for _, child in ipairs(block.children or {}) do
        if child.trigger then
            lookup[child.trigger] = {
                block = child.block,
                delay = child.delay,
                collision = child.collision,
                death = child.death,
                triggerType = child.collision and "collision" or child.death and "death" or child.delay and "timer"
                    or "unknown",
                parent = {
                    blockIndex = blockIndex,
                    wandId = context.wandId
                }
            }
        end
    end
    return lookup
end

--- Executes a single cast block
--- @param block table Cast block from evaluation
--- @param context table Execution context
--- @param state table Wand state
--- @param blockIndex number Block index
--- @return boolean Success
--- @return number Cast delay for this block (in seconds, with overheat applied)
function WandExecutor.executeCastBlock(block, context, state, blockIndex)
    -- Aggregate modifiers from this block
    local modifierCards = {}
    for _, modInfo in ipairs(block.applied_modifiers or {}) do
        table.insert(modifierCards, modInfo.card)
    end

    local modifiers = WandModifiers.aggregate(modifierCards)

    -- --- SPELL TYPE EVALUATION & JOKER INTEGRATION ---
    -- 1. Identify Spell Type
    local actions = {}
    for _, card in ipairs(block.cards) do
        if card.type == "action" then
            table.insert(actions, card) 
        end
    end

    local spellType = SpellTypeEvaluator.evaluate({ actions = actions, modifiers = modifiers })

    -- 2. Analyze tag composition (NEW: Per-cast tag metrics)
    local tagAnalysis = SpellTypeEvaluator.analyzeTags(actions)

    -- 3. Trigger Jokers (Artifacts)
    if spellType or tagAnalysis then
        -- Collect tags from all actions
        local allTags = {}
        for _, action in ipairs(actions) do
            if action.tags then
                for _, tag in ipairs(action.tags) do
                    allTags[tag] = true
                end
            end
        end

        local jokerContext = {
            spell_type = spellType,
            tag_analysis = tagAnalysis, -- NEW: Per-cast tag metrics
            tags = allTags,
            player = context.playerScript or context.playerEntity,
            wand_id = context.wandId
        }

        local jokerEffects = JokerSystem.trigger_event("on_spell_cast", jokerContext)

        -- 3. Apply Joker Effects to Modifiers
        if jokerEffects then
            -- Damage Multiplier
            if jokerEffects.damage_mult and jokerEffects.damage_mult ~= 1 then
                modifiers.damageMultiplier = modifiers.damageMultiplier * jokerEffects.damage_mult
            end

            -- Damage Bonus (Flat)
            if jokerEffects.damage_mod and jokerEffects.damage_mod ~= 0 then
                modifiers.damageBonus = modifiers.damageBonus + jokerEffects.damage_mod
            end

            -- Multicast / Repeat Cast
            if jokerEffects.repeat_cast and jokerEffects.repeat_cast > 0 then
                modifiers.multicastCount = modifiers.multicastCount + jokerEffects.repeat_cast
            end

            -- UI Feedback (Messages)
            if jokerEffects.messages and #jokerEffects.messages > 0 then
                for _, msg in ipairs(jokerEffects.messages) do
                    -- print(string.format("[JOKER] %s triggered: %s", msg.joker, msg.text))
                    -- Emit signal for UI
                    local signal = require("external.hump.signal")
                    signal.emit("on_joker_trigger", { joker_name = msg.joker, message = msg.text })
                end
            end

            if spellType then
                -- Check for spell type discovery
                local TagDiscoverySystem = require("wand.tag_discovery_system")
                local spellDiscovery = TagDiscoverySystem.checkSpellType(context.playerScript or context.playerEntity,
                    spellType)

                if spellDiscovery then
                    local signal = require("external.hump.signal")
                    signal.emit("spell_type_discovered", {
                        spell_type = spellType
                    })
                    print(string.format("[DISCOVERY] New Spell Type: %s!", spellType))
                end

                print(string.format("[WandExecutor] Spell Type: %s (Joker Mods: x%.2f Dmg)", spellType,
                    jokerEffects.damage_mult or 1))
                -- Emit signal for UI
                local signal = require("external.hump.signal")
                signal.emit("on_spell_cast", {
                    spell_type = spellType,
                    tag_analysis = tagAnalysis, -- NEW: Include tag metrics
                    actions = actions
                })
            end
        end
    end
    -- -------------------------------------------------

    -- Merge player stats into modifiers
    if context.playerStats then
        WandModifiers.mergePlayerStats(modifiers, context.playerStats)
    end

    local manaCostMultiplier = math.max(0, modifiers.manaCostMultiplier or 1.0)
    context.cumulative.manaCostMultiplier = manaCostMultiplier

    local baseBlockDelay = ((block.total_cast_delay or 0) + (context.wandDefinition.cast_delay or 0)) / 1000

    local blockMetrics = {
        mana = { modifiers = 0, actions = 0, total = 0, multiplier = manaCostMultiplier },
        projectiles = 0,
        castDelay = {
            base = baseBlockDelay,
            adjusted = nil,
            castSpeedPct = modifiers.statsSnapshot.cast_speed or 0,
            overheatMult = 1.0
        }
    }
    context.cumulative.blocks[blockIndex] = blockMetrics

    -- Consume Modifier Mana (once per block)
    local modifierManaCost = modifiers.manaCost or 0
    if modifierManaCost > 0 then
        modifierManaCost = math.max(0, modifierManaCost * manaCostMultiplier)
        -- Overheat Mechanic: Allow casting even if insufficient mana
        -- We just track the deficit/usage.
        state.currentMana = state.currentMana - modifierManaCost
        context.cumulative.manaSpent = context.cumulative.manaSpent + modifierManaCost
        context.cumulative.manaSpentModifiers = context.cumulative.manaSpentModifiers + modifierManaCost
        blockMetrics.mana.modifiers = modifierManaCost
    end

    -- Pre-index child casts for this block so we can hand metadata into actions
    local childCastMap = buildChildCastMap(block, blockIndex, context)
    context._childCastMap = childCastMap

    -- Execute each action card in the block
    for cardIndex, actionCard in ipairs(block.cards) do
        if actionCard.type == "action" then
            local childInfo = childCastMap[actionCard]
            if childInfo then
                childInfo.inheritedModifiers = modifiers
                childInfo.context = context
                childInfo.parent.cardIndex = cardIndex
            end

            -- Check mana cost (Overheat: Allow negative mana)
            local manaCost = math.max(0, (actionCard.mana_cost or 0) * manaCostMultiplier)

            -- Execute action
            local result = WandActions.execute(actionCard, modifiers, context, childInfo)

            if result then
                -- Consume mana (allow negative)
                state.currentMana = state.currentMana - manaCost
                context.cumulative.manaSpent = context.cumulative.manaSpent + manaCost
                context.cumulative.manaSpentActions = context.cumulative.manaSpentActions + manaCost
                context.cumulative.projectileCount = context.cumulative.projectileCount + 1
                blockMetrics.mana.actions = blockMetrics.mana.actions + manaCost
                blockMetrics.projectiles = blockMetrics.projectiles + 1

                -- Handle sub-casts (timer, collision triggers)
                WandExecutor.handleSubCasts(block, actionCard, modifiers, context, cardIndex, childInfo)
            else
                print("[WandExecutor] Warning: Action execution failed:", actionCard.card_id)
            end
        end
    end

    -- Calculate cast delay for this block
    local blockCastDelay = blockMetrics.castDelay.base -- Convert ms to seconds

    -- Apply player cast speed to this block's delay
    if context.playerStats and context.playerStats.get then
        local castSpeed = blockMetrics.castDelay.castSpeedPct
        if castSpeed > 0 then
            blockCastDelay = blockCastDelay / (1.0 + castSpeed / 100)
        end
    end

    blockMetrics.mana.total = blockMetrics.mana.modifiers + blockMetrics.mana.actions
    context.cumulative.castDelayBase = context.cumulative.castDelayBase + blockMetrics.castDelay.base

    -- Apply Overheat Penalty to this block's cast delay
    if state.currentMana < 0 then
        local deficit = math.abs(state.currentMana)
        local maxFlux = context.wandDefinition.mana_max or 100
        local overloadRatio = deficit / maxFlux
        local penaltyFactor = 5.0

        local cooldownMultiplier = 1.0 + (overloadRatio * penaltyFactor)
        blockMetrics.castDelay.overheatMult = cooldownMultiplier
        context.cumulative.overheatPenaltyMult = math.max(context.cumulative.overheatPenaltyMult or 1.0,
            cooldownMultiplier)

        local baseDelay = blockCastDelay
        local penalizedDelay = baseDelay * cooldownMultiplier
        blockCastDelay = penalizedDelay
        print(string.format(
            "[WandExecutor] Block %d Overheat! Deficit: %.1f, Ratio: %.2f, Mult: %.2f, BlockDelay: %.3fs -> %.3fs",
            blockIndex, deficit, overloadRatio, cooldownMultiplier, baseDelay, penalizedDelay))
    end

    blockMetrics.castDelay.adjusted = blockCastDelay
    context.cumulative.castDelayAdjusted = context.cumulative.castDelayAdjusted + blockCastDelay

    maybeFlashBlock(block, context)
    context._childCastMap = nil

    return true, blockCastDelay
end

--- Handles sub-casts for actions with triggers
--- @param block table Parent cast block
--- @param actionCard table Action card that triggered sub-cast
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param cardIndex number Card index in block
--- @param childInfo table|nil Child cast metadata
function WandExecutor.handleSubCasts(block, actionCard, modifiers, context, cardIndex, childInfo)
    if not childInfo or not childInfo.block then
        return
    end

    -- Assign a trace id so we can correlate schedule → enqueue → execute
    if not childInfo.traceId then
        childInfo.traceId = makeSubcastTraceId(context, childInfo.parent, childInfo.triggerType)
    end

    -- Timer-based sub-cast
    if childInfo.delay and childInfo.delay > 0 then
        local delaySeconds = childInfo.delay / 1000

        WandExecutor.debugSubcastEvent("scheduled_timer", {
            traceId = childInfo.traceId,
            wandId = context.wandId,
            trigger = "timer",
            blockIndex = childInfo.parent and childInfo.parent.blockIndex,
            cardIndex = childInfo.parent and childInfo.parent.cardIndex,
            delay = delaySeconds
        })

        timer.after(delaySeconds, function()
            print("[WandExecutor] Executing timer sub-cast after", delaySeconds, "seconds")
            WandExecutor.enqueueSubCast({
                block = childInfo.block,
                inheritedModifiers = modifiers,
                context = context,
                source = {
                    trigger = "timer",
                    blockIndex = childInfo.parent and childInfo.parent.blockIndex,
                    cardIndex = childInfo.parent and childInfo.parent.cardIndex,
                    wandId = childInfo.parent and childInfo.parent.wandId
                },
                traceId = childInfo.traceId
            })
        end, "wand_subcast_" .. context.wandId .. "_" .. os.clock())
    end

    -- Collision-based sub-cast
    if childInfo.collision then
        WandExecutor.debugSubcastEvent("registered_collision", {
            traceId = childInfo.traceId,
            wandId = context.wandId,
            trigger = "collision",
            blockIndex = childInfo.parent and childInfo.parent.blockIndex,
            cardIndex = childInfo.parent and childInfo.parent.cardIndex
        })
        -- Stored on the projectile via WandActions
        print("[WandExecutor] Registered collision sub-cast for action:", actionCard.card_id)
    end

    if childInfo.death then
        WandExecutor.debugSubcastEvent("registered_death", {
            traceId = childInfo.traceId,
            wandId = context.wandId,
            trigger = "death",
            blockIndex = childInfo.parent and childInfo.parent.blockIndex,
            cardIndex = childInfo.parent and childInfo.parent.cardIndex
        })
        print("[WandExecutor] Registered death sub-cast for action:", actionCard.card_id)
    end
end

--- Executes a sub-cast block (from timer or collision trigger)
--- @param subBlock table Sub-cast block
--- @param context table Execution context
--- @param inheritedModifiers table Modifiers inherited from parent
--- @param meta table|nil Additional metadata (trigger, parent block/card)
--- @return boolean Success
function WandExecutor.executeSubCast(subBlock, context, inheritedModifiers, meta)
    -- Aggregate modifiers using inherited cards plus the child block's modifiers
    local combinedCards = {}
    if inheritedModifiers and inheritedModifiers.modifierCards then
        for _, card in ipairs(inheritedModifiers.modifierCards) do
            table.insert(combinedCards, card)
        end
    end
    for _, modInfo in ipairs(subBlock.applied_modifiers or {}) do
        table.insert(combinedCards, modInfo.card)
    end

    local modifiers = inheritedModifiers or WandModifiers.createAggregate()
    if #combinedCards > 0 then
        modifiers = WandModifiers.aggregate(combinedCards)
    else
        modifiers = shallowCopyTable(inheritedModifiers or WandModifiers.createAggregate())
    end

    if inheritedModifiers then
        modifiers.damageMultiplier = (modifiers.damageMultiplier or 1.0) *
            (inheritedModifiers.damageMultiplier or 1.0)
        modifiers.damageBonus = (modifiers.damageBonus or 0) + (inheritedModifiers.damageBonus or 0)
        modifiers.multicastCount = math.max(modifiers.multicastCount or 1, inheritedModifiers.multicastCount or 1)
        modifiers.manaCostMultiplier = (modifiers.manaCostMultiplier or 1.0) *
            (inheritedModifiers.manaCostMultiplier or 1.0)
        modifiers.explosionDamageMult = (modifiers.explosionDamageMult or 1.0) *
            (inheritedModifiers.explosionDamageMult or 1.0)
        if inheritedModifiers.bounceDampening then
            modifiers.bounceDampening = inheritedModifiers.bounceDampening
        end
    end

    -- Merge player stats into modifiers (inherited from context)
    if context.playerStats then
        WandModifiers.mergePlayerStats(modifiers, context.playerStats)
    end

    -- Execute actions in sub-cast block (no mana/delay/overheat costs)
    local childMap = buildChildCastMap(subBlock, meta and meta.parentBlockIndex or 0, context)
    for cardIndex, actionCard in ipairs(subBlock.cards or {}) do
        if actionCard.type == "action" then
            local childInfo = childMap[actionCard]
            if childInfo then
                childInfo.inheritedModifiers = modifiers
                childInfo.context = context
                childInfo.parent.cardIndex = cardIndex
                childInfo.parent.blockIndex = meta and meta.parentBlockIndex or childInfo.parent.blockIndex
            end
            WandActions.execute(actionCard, modifiers, context, childInfo)
            WandExecutor.handleSubCasts(subBlock, actionCard, modifiers, context, cardIndex, childInfo)
        end
    end

    if meta then
        WandExecutor.debugSubcastEvent("executed", {
            traceId = meta.traceId,
            wandId = context.wandId,
            trigger = meta.trigger,
            blockIndex = meta.parentBlockIndex,
            cardIndex = meta.parentCardIndex
        })
        print(string.format("[WandExecutor] Executed sub-cast via %s (block %s card %s)", meta.trigger or "child",
            tostring(meta.parentBlockIndex), tostring(meta.parentCardIndex)))
    end

    return true
end

--- Queues a sub-cast to be processed on the next update (avoids physics callback issues)
--- @param payload table { block, inheritedModifiers, context, source = { trigger, blockIndex, cardIndex, wandId } }
function WandExecutor.enqueueSubCast(payload)
    if not payload or not payload.block then return end
    WandExecutor.debugSubcastEvent("enqueued", {
        traceId = payload.traceId,
        wandId = payload.source and payload.source.wandId or (payload.context and payload.context.wandId),
        trigger = payload.source and payload.source.trigger,
        blockIndex = payload.source and payload.source.blockIndex,
        cardIndex = payload.source and payload.source.cardIndex
    })
    WandExecutor.pendingSubCasts[#WandExecutor.pendingSubCasts + 1] = payload
end

--- Processes any pending sub-casts
function WandExecutor.processPendingSubCasts()
    if #WandExecutor.pendingSubCasts == 0 then return end

    local queue = WandExecutor.pendingSubCasts
    WandExecutor.pendingSubCasts = {}

    for _, payload in ipairs(queue) do
        WandExecutor.executeSubCast(payload.block, payload.context or {}, payload.inheritedModifiers, {
            trigger = payload.source and payload.source.trigger,
            parentBlockIndex = payload.source and payload.source.blockIndex,
            parentCardIndex = payload.source and payload.source.cardIndex,
            traceId = payload.traceId
        })
    end
end

local function createStatsProxy(source)
    if source and type(source.get) == "function" then
        return source
    end

    local values = source or {}
    local proxy = {
        _values = values,
    }

    function proxy:get(name)
        local val = self._values[name]
        if val ~= nil then return val end
        return 0
    end

    return proxy
end

local function resolvePlayerStats(playerEntity, playerScript)
    if playerScript and playerScript.combatTable and playerScript.combatTable.stats then
        return playerScript.combatTable.stats
    end

    return nil
end

--[[
================================================================================
EXECUTION CONTEXT
================================================================================
]] --

--- Creates an execution context for wand casting
--- @param wandId string Wand identifier
--- @param state table Wand state
--- @param activeWand table Active wand data
--- @return table Execution context
function WandExecutor.createExecutionContext(wandId, state, activeWand)
    local playerEntity = WandExecutor.getPlayerEntity()
    local playerScript = WandExecutor.getPlayerScript(playerEntity)
    local playerPos = WandExecutor.getPlayerPosition(playerEntity)
    local playerAngle = WandExecutor.getPlayerFacingAngle(playerEntity)

    -- Fetch player stats (prefer combatTable stats, fall back to a proxy with safe get)
    local playerStats = resolvePlayerStats(playerEntity, playerScript)
    playerStats = createStatsProxy(playerStats)

    local context = {
        wandId = wandId,
        wandState = state,
        wandDefinition = activeWand.definition,
        cardPool = activeWand.cardPool,

        playerEntity = playerEntity,
        playerScript = playerScript,
        playerPosition = playerPos,
        playerAngle = playerAngle,
        playerStats = playerStats,

        timestamp = os.clock(),

        -- Cumulative tracking for this execution
        cumulative = {
            manaSpent = 0,
            manaSpentActions = 0,
            manaSpentModifiers = 0,
            manaCostMultiplier = 1.0,
            projectileCount = 0,
            castDelayBase = 0,
            castDelayAdjusted = 0,
            blocks = {},
            recharge = {
                base = 0,
                afterCdr = 0,
            },
            overheatPenaltyMult = 1.0,
        },

        -- Helper functions
        getPlayerPosition = function()
            return WandExecutor.getPlayerPosition(playerEntity)
        end,

        getPlayerFacingAngle = function()
            return WandExecutor.getPlayerFacingAngle(playerEntity)
        end,

        findNearestEnemy = function(position, radius)
            return WandExecutor.findNearestEnemy(position, radius)
        end,
    }

    context.canAffordCast = function(manaCost)
        local mult = context.cumulative and context.cumulative.manaCostMultiplier or 1.0
        return state.currentMana >= (manaCost or 0) * mult
    end

    return context
end

--[[
================================================================================
HELPER FUNCTIONS
================================================================================
]] --

--- Gets the player entity
--- @return number Player entity ID
function WandExecutor.getPlayerEntity()
    -- TODO: Get actual player entity from game state
    return player or 0
end

--- Gets the player script table (if attached)
--- @param playerEntity number Player entity ID
--- @return table|nil Player script table
function WandExecutor.getPlayerScript(playerEntity)
    if not playerEntity or not getScriptTableFromEntityID then
        return nil
    end

    return getScriptTableFromEntityID(playerEntity)
end

--- Gets player position
--- @param playerEntity number Player entity ID
--- @return table {x, y} position
function WandExecutor.getPlayerPosition(playerEntity)
    if not playerEntity or not component_cache then
        return { x = 0, y = 0 }
    end

    local transform = component_cache.get(playerEntity, Transform)
    if transform then
        return {
            x = transform.actualX + (transform.actualW or 0) * 0.5,
            y = transform.actualY + (transform.actualH or 0) * 0.5
        }
    end

    return { x = 0, y = 0 }
end

--- Gets player facing angle
--- @param playerEntity number Player entity ID
--- @return number Angle in radians
function WandExecutor.getPlayerFacingAngle(playerEntity)
    -- TODO: Get actual facing angle
    -- For now, use mouse position if available
    if input and input.getMousePosition then
        local mousePos = input.getMousePosition()
        local playerPos = WandExecutor.getPlayerPosition(playerEntity)

        local dx = mousePos.x - playerPos.x
        local dy = mousePos.y - playerPos.y

        return math.atan2(dy, dx)
    end

    return 0
end

--- Finds nearest enemy within radius
--- @param position table {x, y}
--- @param radius number Search radius in pixels
--- @return number|nil Enemy entity ID
function WandExecutor.findNearestEnemy(position, radius)
    -- TODO: Implement spatial query
    -- Requires access to enemy entities and spatial partitioning
    return nil
end

--[[
================================================================================
UTILITY FUNCTIONS
================================================================================
]] --

--- Resets a wand (clears cooldown, restores charges/mana)
--- @param wandId string Wand identifier
function WandExecutor.resetWand(wandId)
    local state = WandExecutor.getWandState(wandId)
    if not state then return end

    state.cooldownRemaining = 0
    state.charges = state.maxCharges
    state.currentMana = state.maxMana
    state.isCasting = false

    print("[WandExecutor] Reset wand", wandId)
end

--- Gets wand cooldown remaining
--- @param wandId string Wand identifier
--- @return number Cooldown in seconds
function WandExecutor.getCooldown(wandId)
    local state = WandExecutor.getWandState(wandId)
    return state and state.cooldownRemaining or 0
end

--- Gets wand mana
--- @param wandId string Wand identifier
--- @return number Current mana
function WandExecutor.getMana(wandId)
    local state = WandExecutor.getWandState(wandId)
    return state and state.currentMana or 0
end

--- Gets wand charges
--- @param wandId string Wand identifier
--- @return number Current charges
function WandExecutor.getCharges(wandId)
    local state = WandExecutor.getWandState(wandId)
    return state and state.charges or 0
end

return WandExecutor
