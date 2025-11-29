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

local graphUI = nil
local blockFlashUI = nil

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
        end)
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

    -- Execute cast blocks sequentially
    local success, totalCastDelay = WandExecutor.executeCastBlocks(evaluationResult.blocks, context, state)

    if success then
        -- Apply recharge time (only once, after all blocks)
        local rechargeTime = (activeWand.definition.recharge_time or 0) / 1000

        -- Apply Player CDR to recharge time
        if context.playerStats and context.playerStats.get then
            local cdr = context.playerStats:get("cooldown_reduction") or 0
            if cdr > 0 then
                rechargeTime = rechargeTime * (1.0 - cdr / 100)
            end
        end

        -- Total cooldown = accumulated cast delay + recharge time
        local totalCooldown = totalCastDelay + rechargeTime

        -- Apply overheat penalty to total cooldown if we went negative on mana/flux
        if state.currentMana < 0 then
            local deficit = math.abs(state.currentMana)
            local maxFlux = context.wandDefinition.mana_max or state.maxMana or 100
            local overloadRatio = deficit / math.max(maxFlux, 1)
            local penaltyFactor = context.wandDefinition.overheat_penalty_factor or 5.0

            local cooldownMultiplier = 1.0 + (overloadRatio * penaltyFactor)
            totalCooldown = totalCooldown * cooldownMultiplier

            print(string.format(
                "[WandExecutor] Overheat penalty applied - deficit: %.1f, ratio: %.2f, mult: %.2f, cooldown: %.3fs",
                deficit, overloadRatio, cooldownMultiplier, totalCooldown))
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
            totalProjectiles = context.cumulative.projectileCount,
            totalCastDelay = totalCastDelay * 1000, -- Convert back to ms for logging
            totalRecharge = activeWand.definition.recharge_time,
            blocksExecuted = #evaluationResult.blocks
        }

        print(string.format("[WandExecutor] Executed wand %s - total delay: %.3fs, recharge: %.3fs, cooldown: %.3fs",
            wandId, totalCastDelay, rechargeTime, totalCooldown))
    end

    return success
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
--- @return boolean Success
--- @return number Total cast delay accumulated (in seconds)
function WandExecutor.executeCastBlocks(blocks, context, state)
    local totalCastDelay = 0 -- Accumulate cast delay across all blocks

    for blockIndex, block in ipairs(blocks) do
        local success, blockCastDelay = WandExecutor.executeCastBlock(block, context, state, blockIndex)

        if not success then
            print("[WandExecutor] Warning: Cast block", blockIndex, "failed")
            return false, totalCastDelay
        end

        -- Accumulate cast delay
        totalCastDelay = totalCastDelay + blockCastDelay

        -- Apply cast delay between blocks
        if blockIndex < #blocks then
            local delay = block.total_cast_delay or 0
            -- TODO: Implement delay between blocks (needs timer or coroutine)
        end
    end

    return true, totalCastDelay
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
                    print(string.format("[JOKER] %s triggered: %s", msg.joker, msg.text))
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

    -- Consume Modifier Mana (once per block)
    local modifierManaCost = modifiers.manaCost or 0
    if modifierManaCost > 0 then
        -- Overheat Mechanic: Allow casting even if insufficient mana
        -- We just track the deficit/usage.
        state.currentMana = state.currentMana - modifierManaCost
        context.cumulative.manaSpent = context.cumulative.manaSpent + modifierManaCost
    end

    -- Execute each action card in the block
    for cardIndex, actionCard in ipairs(block.cards) do
        if actionCard.type == "action" then
            -- Check mana cost (Overheat: Allow negative mana)
            local manaCost = actionCard.mana_cost or 0

            -- Execute action
            local result = WandActions.execute(actionCard, modifiers, context)

            if result then
                -- Consume mana (allow negative)
                state.currentMana = state.currentMana - manaCost
                context.cumulative.manaSpent = context.cumulative.manaSpent + manaCost
                context.cumulative.projectileCount = context.cumulative.projectileCount + 1

                -- Handle sub-casts (timer, collision triggers)
                WandExecutor.handleSubCasts(block, actionCard, modifiers, context, cardIndex)
            else
                print("[WandExecutor] Warning: Action execution failed:", actionCard.card_id)
            end
        end
    end

    -- Calculate cast delay for this block
    local blockCastDelay = (block.total_cast_delay or 0) / 1000 -- Convert ms to seconds

    -- Apply player cast speed to this block's delay
    if context.playerStats and context.playerStats.get then
        local castSpeed = context.playerStats:get("cast_speed") or 0
        if castSpeed > 0 then
            blockCastDelay = blockCastDelay / (1.0 + castSpeed / 100)
        end
    end

    -- Apply Overheat Penalty to this block's cast delay
    if state.currentMana < 0 then
        local deficit = math.abs(state.currentMana)
        local maxFlux = context.wandDefinition.mana_max or 100
        local overloadRatio = deficit / maxFlux
        local penaltyFactor = 5.0

        local cooldownMultiplier = 1.0 + (overloadRatio * penaltyFactor)
        blockCastDelay = blockCastDelay * cooldownMultiplier

        print(string.format(
            "[WandExecutor] Block %d Overheat! Deficit: %.1f, Ratio: %.2f, Mult: %.2f, BlockDelay: %.3fs",
            blockIndex, deficit, overloadRatio, cooldownMultiplier, blockCastDelay))
    end

    maybeFlashBlock(block, context)

    return true, blockCastDelay
end

--- Handles sub-casts for actions with triggers
--- @param block table Parent cast block
--- @param actionCard table Action card that triggered sub-cast
--- @param modifiers table Modifier aggregate
--- @param context table Execution context
--- @param cardIndex number Card index in block
function WandExecutor.handleSubCasts(block, actionCard, modifiers, context, cardIndex)
    -- Find child block for this action card
    local childBlock = nil
    for _, child in ipairs(block.children or {}) do
        if child.trigger == actionCard then
            childBlock = child
            break
        end
    end

    if not childBlock or not childBlock.block then
        return
    end

    -- Timer-based sub-cast
    if childBlock.delay and childBlock.delay > 0 then
        local delaySeconds = childBlock.delay / 1000

        timer.after(delaySeconds, function()
            print("[WandExecutor] Executing timer sub-cast after", delaySeconds, "seconds")
            WandExecutor.executeSubCast(childBlock.block, context, modifiers)
        end, "wand_subcast_" .. context.wandId .. "_" .. os.clock())
    end

    -- Collision-based sub-cast
    if childBlock.collision then
        -- Store sub-cast info for projectile on-hit callback
        -- This is handled via modifier tracking in WandActions
        print("[WandExecutor] Registered collision sub-cast for action:", actionCard.card_id)
    end
end

--- Executes a sub-cast block (from timer or collision trigger)
--- @param subBlock table Sub-cast block
--- @param context table Execution context
--- @param inheritedModifiers table Modifiers inherited from parent
--- @return boolean Success
function WandExecutor.executeSubCast(subBlock, context, inheritedModifiers)
    -- Aggregate modifiers (inherited + block's own)
    local modifierCards = {}
    for _, modInfo in ipairs(subBlock.applied_modifiers or {}) do
        table.insert(modifierCards, modInfo.card)
    end

    local modifiers = WandModifiers.aggregate(modifierCards)

    -- Merge player stats into modifiers (inherited from context)
    if context.playerStats then
        WandModifiers.mergePlayerStats(modifiers, context.playerStats)
    end

    -- Execute actions in sub-cast block
    for _, actionCard in ipairs(subBlock.cards) do
        if actionCard.type == "action" then
            WandActions.execute(actionCard, modifiers, context)
        end
    end

    return true
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

    -- Fetch player stats (mock or real)
    local playerStats = {
        damage_mult = 1.0,
        speed_mult = 1.0,
        -- Add other defaults or fetch from component
    }

    -- TODO: Fetch actual stats from player entity components
    if playerEntity and component_cache and component_cache.get then
        -- Example: local stats = component_cache.get(playerEntity, "PlayerStats")
        -- if stats then ... end
    end

    return {
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
            projectileCount = 0,
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

        canAffordCast = function(manaCost)
            return state.currentMana >= manaCost
        end,
    }
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
