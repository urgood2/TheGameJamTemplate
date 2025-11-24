--[[
================================================================================
CARD BEHAVIOR REGISTRY - Function-Based Custom Behaviors
================================================================================
Allows registering complex, function-based behaviors for card upgrades and
synergies. This complements the field-based approach with executable logic.

Key Features:
- Register behavior functions by ID
- Execute behaviors with context (player, target, card, etc.)
- Support for conditional logic, state tracking, and complex effects
- Easy to add new behaviors without modifying core systems

Usage Example:
  -- Register a complex behavior
  BehaviorRegistry.register("chain_explosion_recursive", function(ctx)
    local explosions = 0
    local maxChains = ctx.params.max_chains or 3

    local function explode(position, damage)
      if explosions >= maxChains then return end

      -- Spawn explosion
      local targets = findEnemiesInRadius(position, ctx.params.radius)
      for _, target in ipairs(targets) do
        dealDamage(target, damage)

        -- Recursive chain
        if math.random(100) <= ctx.params.chain_chance then
          explosions = explosions + 1
          explode(target.position, damage * ctx.params.damage_mult)
        end
      end
    end

    explode(ctx.position, ctx.damage)
  end)

  -- Execute behavior
  BehaviorRegistry.execute("chain_explosion_recursive", context)

================================================================================
]] --

local BehaviorRegistry = {}

-- ============================================================================
-- BEHAVIOR STORAGE
-- ============================================================================

--- Registered behaviors: { behaviorId = function(ctx) }
BehaviorRegistry.behaviors = {}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

--- Registers a behavior function
--- @param behaviorId string Unique behavior identifier
--- @param behaviorFunc function(ctx) Behavior function
--- @param description string Optional description
function BehaviorRegistry.register(behaviorId, behaviorFunc, description)
    if BehaviorRegistry.behaviors[behaviorId] then
        print(string.format("[BehaviorRegistry] Warning: Overwriting behavior '%s'", behaviorId))
    end

    BehaviorRegistry.behaviors[behaviorId] = {
        func = behaviorFunc,
        description = description or ""
    }

    print(string.format("[BehaviorRegistry] Registered behavior: %s", behaviorId))
end

-- ============================================================================
-- EXECUTION
-- ============================================================================

--- Executes a behavior with the given context
--- @param behaviorId string Behavior identifier
--- @param context table Execution context (player, target, card, params, etc.)
--- @return boolean Success
--- @return any Result from behavior function
function BehaviorRegistry.execute(behaviorId, context)
    local behavior = BehaviorRegistry.behaviors[behaviorId]
    if not behavior then
        print(string.format("[BehaviorRegistry] Error: Unknown behavior '%s'", behaviorId))
        return false, nil
    end

    -- Execute behavior function
    local success, result = pcall(behavior.func, context)

    if not success then
        print(string.format("[BehaviorRegistry] Error executing '%s': %s", behaviorId, result))
        return false, nil
    end

    return true, result
end

--- Checks if a behavior is registered
--- @param behaviorId string Behavior identifier
--- @return boolean True if registered
function BehaviorRegistry.has(behaviorId)
    return BehaviorRegistry.behaviors[behaviorId] ~= nil
end

-- ============================================================================
-- UTILITY
-- ============================================================================

--- Lists all registered behaviors
--- @return table Array of { id, description }
function BehaviorRegistry.list()
    local list = {}
    for behaviorId, behavior in pairs(BehaviorRegistry.behaviors) do
        table.insert(list, {
            id = behaviorId,
            description = behavior.description
        })
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Prints all registered behaviors
function BehaviorRegistry.printAll()
    print("\n[BehaviorRegistry] Registered Behaviors:")
    local list = BehaviorRegistry.list()
    for _, item in ipairs(list) do
        if item.description ~= "" then
            print(string.format("  %s - %s", item.id, item.description))
        else
            print(string.format("  %s", item.id))
        end
    end
end

-- ============================================================================
-- EXAMPLE BEHAVIORS
-- ============================================================================

--- Initializes example behaviors
function BehaviorRegistry.initExamples()
    -- Example 1: Recursive chain explosion
    BehaviorRegistry.register("chain_explosion_recursive", function(ctx)
        local explosions = 0
        local maxChains = ctx.params.max_chains or 3
        local radius = ctx.params.radius or 100
        local chainChance = ctx.params.chain_chance or 50
        local damageMult = ctx.params.damage_mult or 0.7

        local function explode(position, damage, depth)
            if explosions >= maxChains or depth > 10 then return end

            -- Find targets (mock for now)
            print(string.format("  [Chain %d] Explosion at (%.0f, %.0f) for %.0f damage",
                explosions + 1, position.x, position.y, damage))

            -- Simulate finding targets
            local numTargets = math.random(1, 3)
            for i = 1, numTargets do
                if math.random(100) <= chainChance then
                    explosions = explosions + 1
                    local newPos = {
                        x = position.x + math.random(-radius, radius),
                        y = position.y + math.random(-radius, radius)
                    }
                    explode(newPos, damage * damageMult, depth + 1)
                end
            end
        end

        explode(ctx.position, ctx.damage, 0)
        return explosions
    end, "Recursive chain explosions with diminishing damage")

    -- Example 2: Conditional summon based on player state
    BehaviorRegistry.register("summon_on_low_health", function(ctx)
        local player = ctx.player
        local threshold = ctx.params.health_threshold or 0.3

        local healthPercent = player.hp / player.max_health
        if healthPercent <= threshold then
            print(string.format("  Player at %.0f%% health - summoning ally!", healthPercent * 100))
            -- Summon logic here
            return true
        end

        return false
    end, "Summons ally when player health is low")

    -- Example 3: Stacking buff with complex decay
    BehaviorRegistry.register("momentum_stacks", function(ctx)
        local player = ctx.player
        if not player._momentum_stacks then
            player._momentum_stacks = 0
            player._momentum_last_hit = 0
        end

        local currentTime = ctx.time or 0
        local timeSinceLastHit = currentTime - player._momentum_last_hit
        local decayTime = ctx.params.decay_time or 2.0

        -- Decay stacks if too much time passed
        if timeSinceLastHit > decayTime then
            player._momentum_stacks = 0
        end

        -- Add stack
        player._momentum_stacks = math.min(player._momentum_stacks + 1, ctx.params.max_stacks or 10)
        player._momentum_last_hit = currentTime

        -- Apply bonus
        local damageBonus = player._momentum_stacks * (ctx.params.damage_per_stack or 5)
        print(string.format("  Momentum: %d stacks (+%.0f%% damage)",
            player._momentum_stacks, damageBonus))

        return damageBonus
    end, "Stacking damage buff that decays over time")

    -- Example 4: Trigger chance with cooldown
    BehaviorRegistry.register("trigger_with_cooldown", function(ctx)
        local player = ctx.player
        local behaviorId = ctx.params.behavior_id or "default"
        local cooldownKey = "cooldown_" .. behaviorId

        if not player._behavior_cooldowns then
            player._behavior_cooldowns = {}
        end

        local currentTime = ctx.time or 0
        local lastTrigger = player._behavior_cooldowns[cooldownKey] or 0
        local cooldown = ctx.params.cooldown or 5.0

        if currentTime - lastTrigger < cooldown then
            return false -- On cooldown
        end

        -- Check trigger chance
        local chance = ctx.params.chance or 25
        if math.random(100) <= chance then
            player._behavior_cooldowns[cooldownKey] = currentTime
            print(string.format("  Triggered %s (next available in %.1fs)",
                behaviorId, cooldown))
            return true
        end

        return false
    end, "Trigger with chance and cooldown")

    print("[BehaviorRegistry] Initialized example behaviors")
end

return BehaviorRegistry
