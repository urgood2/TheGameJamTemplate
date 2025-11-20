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
]]--

local WandExecutor = {}

-- Dependencies
local timer = require("core.timer")
local cardEval = require("assets.scripts.core.card_eval_order_test")
local WandActions = require("assets.scripts.wand.wand_actions")
local WandModifiers = require("assets.scripts.wand.wand_modifiers")
local WandTriggers = require("assets.scripts.wand.wand_triggers")
local ProjectileSystem = require("assets.scripts.combat.projectile_system")

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
]]--

--- Initializes the wand executor system
function WandExecutor.init()
    WandExecutor.wandStates = {}
    WandExecutor.activeWands = {}
    WandExecutor.pendingSubCasts = {}

    -- Initialize dependencies
    WandTriggers.init()
    ProjectileSystem.init()

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
]]--

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
]]--

--- Creates initial wand state
--- @param wandDef table Wand definition
--- @return table Wand state
function WandExecutor.createWandState(wandDef)
    return {
        wandId = wandDef.id,

        -- Cooldown tracking
        cooldownRemaining = 0,
        lastCastTime = 0,

        -- Charge tracking
        charges = wandDef.max_charges or 1,
        maxCharges = wandDef.max_charges or 1,
        chargeRegenTime = wandDef.charge_regen_time or 0,
        lastChargeTime = 0,

        -- Mana tracking
        currentMana = wandDef.mana_max or 100,
        maxMana = wandDef.mana_max or 100,
        manaRegenRate = wandDef.mana_recharge_rate or 5,  -- per second

        -- Cast execution state
        currentBlockIndex = 1,
        deckIndex = 1,
        isRecharging = false,

        -- Runtime state
        lastEvaluationResult = nil,  -- cached evaluation result
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
]]--

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
        print("[WandExecutor] Cannot cast wand", wandId, "- on cooldown or insufficient resources")
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

    -- Execute cast blocks sequentially
    local success = WandExecutor.executeCastBlocks(evaluationResult.blocks, context, state)

    if success then
        -- Apply cooldown
        local totalCooldown = (evaluationResult.total_cast_delay or 0) / 1000  -- convert ms to seconds
        totalCooldown = totalCooldown + (activeWand.definition.recharge_time or 0) / 1000

        state.cooldownRemaining = totalCooldown
        state.lastCastTime = os.clock()

        print("[WandExecutor] Executed wand", wandId, "- cooldown:", totalCooldown, "seconds")
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

    -- Check mana (basic check - more detailed check happens during evaluation)
    if state.currentMana <= 0 then
        return false
    end

    return true
end

--[[
================================================================================
CAST BLOCK EXECUTION
================================================================================
]]--

--- Executes a sequence of cast blocks
--- @param blocks table Array of cast blocks from card evaluation
--- @param context table Execution context
--- @param state table Wand state
--- @return boolean Success
function WandExecutor.executeCastBlocks(blocks, context, state)
    for blockIndex, block in ipairs(blocks) do
        local success = WandExecutor.executeCastBlock(block, context, state, blockIndex)

        if not success then
            print("[WandExecutor] Warning: Cast block", blockIndex, "failed")
            return false
        end

        -- Apply cast delay between blocks
        if blockIndex < #blocks then
            local delay = block.total_cast_delay or 0
            -- TODO: Implement delay between blocks (needs timer or coroutine)
        end
    end

    return true
end

--- Executes a single cast block
--- @param block table Cast block from evaluation
--- @param context table Execution context
--- @param state table Wand state
--- @param blockIndex number Block index
--- @return boolean Success
function WandExecutor.executeCastBlock(block, context, state, blockIndex)
    -- Aggregate modifiers from this block
    local modifierCards = {}
    for _, modInfo in ipairs(block.applied_modifiers or {}) do
        table.insert(modifierCards, modInfo.card)
    end

    local modifiers = WandModifiers.aggregate(modifierCards)

    -- Execute each action card in the block
    for cardIndex, actionCard in ipairs(block.cards) do
        if actionCard.type == "action" then
            -- Check mana cost
            local manaCost = actionCard.mana_cost or 0
            if state.currentMana < manaCost then
                print("[WandExecutor] Insufficient mana for action:", actionCard.card_id)
                return false
            end

            -- Execute action
            local result = WandActions.execute(actionCard, modifiers, context)

            if result then
                -- Consume mana
                state.currentMana = state.currentMana - manaCost

                -- Handle sub-casts (timer, collision triggers)
                WandExecutor.handleSubCasts(block, actionCard, modifiers, context, cardIndex)
            else
                print("[WandExecutor] Warning: Action execution failed:", actionCard.card_id)
            end
        end
    end

    return true
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
]]--

--- Creates an execution context for wand casting
--- @param wandId string Wand identifier
--- @param state table Wand state
--- @param activeWand table Active wand data
--- @return table Execution context
function WandExecutor.createExecutionContext(wandId, state, activeWand)
    local playerEntity = WandExecutor.getPlayerEntity()
    local playerPos = WandExecutor.getPlayerPosition(playerEntity)
    local playerAngle = WandExecutor.getPlayerFacingAngle(playerEntity)

    return {
        wandId = wandId,
        wandState = state,
        wandDefinition = activeWand.definition,

        playerEntity = playerEntity,
        playerPosition = playerPos,
        playerAngle = playerAngle,

        timestamp = os.clock(),

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
]]--

--- Gets the player entity
--- @return number Player entity ID
function WandExecutor.getPlayerEntity()
    -- TODO: Get actual player entity from game state
    return player or 0
end

--- Gets player position
--- @param playerEntity number Player entity ID
--- @return table {x, y} position
function WandExecutor.getPlayerPosition(playerEntity)
    if not playerEntity or not component_cache then
        return {x = 0, y = 0}
    end

    local transform = component_cache.get(playerEntity, Transform)
    if transform then
        return {
            x = transform.actualX,
            y = transform.actualY
        }
    end

    return {x = 0, y = 0}
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
]]--

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
