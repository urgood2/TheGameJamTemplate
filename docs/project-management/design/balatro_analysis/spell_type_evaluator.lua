-- Spell Type Evaluator
-- Analyzes a CastBlock (from card_eval_order_test.lua) and identifies its "Spell Type" (Pattern).
-- This is the "Poker Hand" equivalent for the Wand System.

local SpellTypeEvaluator = {}

-- Enum for Spell Types
SpellTypeEvaluator.Types = {
    SIMPLE = "Simple Cast",       -- 1 Action, 0 Mods
    TWIN = "Twin Cast",           -- 1 Action, Multicast x2
    SCATTER = "Scatter Cast",     -- 1 Action, Multicast > 2 + Spread
    PRECISION = "Precision Cast", -- 1 Action, Speed/Damage Mod, No Spread
    RAPID = "Rapid Fire",         -- 1 Action, Low Delay
    MONO = "Mono-Element",        -- 3+ Actions, Same Element
    COMBO = "Combo Chain",        -- 3+ Actions, Different Types
    HEAVY = "Heavy Barrage",      -- 3+ Actions, High Cost/Damage
    CHAOS = "Chaos Cast"          -- Fallback / Mixed
}

--- Helper: Count actions in a cast block
local function count_actions(block)
    local count = 0
    for _, card in ipairs(block.cards or {}) do
        if card.type == "action" then
            count = count + 1
        end
    end
    return count
end

--- Helper: Get all action cards from a cast block
local function get_actions(block)
    local actions = {}
    for _, card in ipairs(block.cards or {}) do
        if card.type == "action" then
            table.insert(actions, card)
        end
    end
    return actions
end

--- Helper: Aggregate modifiers from applied_modifiers
local function aggregate_modifiers(block)
    local agg = {
        multicast = 0,
        spread = 0,
        projectile_speed_multiplier = 1,
        damage_multiplier = 1,
        cast_delay_multiplier = 1,
    }

    for _, mod_entry in ipairs(block.applied_modifiers or {}) do
        local card = mod_entry.card
        if card then
            -- Aggregate multicast (additive)
            if card.multicast then
                agg.multicast = agg.multicast + card.multicast
            end

            -- Aggregate spread (additive)
            if card.spread then
                agg.spread = agg.spread + card.spread
            end

            -- Aggregate speed (multiplicative)
            if card.projectile_speed_multiplier then
                agg.projectile_speed_multiplier = agg.projectile_speed_multiplier * card.projectile_speed_multiplier
            end

            -- Aggregate damage (multiplicative)
            if card.damage_multiplier then
                agg.damage_multiplier = agg.damage_multiplier * card.damage_multiplier
            end

            -- Aggregate delay (multiplicative)
            if card.cast_delay_multiplier then
                agg.cast_delay_multiplier = agg.cast_delay_multiplier * card.cast_delay_multiplier
            end
        end
    end

    return agg
end

--- Analyze a Cast Block and return its Spell Type
-- @param block: Table from card_eval_order_test.lua containing:
--               { cards = {...}, applied_modifiers = {...}, total_cast_delay = ..., ... }
-- @return string: The SpellTypeEvaluator.Types value
function SpellTypeEvaluator.evaluate(block)
    if not block or not block.cards or #block.cards == 0 then
        return nil
    end

    local action_count = count_actions(block)
    local actions = get_actions(block)
    local mods = aggregate_modifiers(block)

    -- --- Single Action Patterns ---
    if action_count == 1 then
        local action = actions[1]

        -- Check for Multicast
        local multicast = mods.multicast

        if multicast == 0 then
            -- Check for Precision (Speed/Damage up, no spread)
            if (mods.projectile_speed_multiplier > 1.2) or (mods.damage_multiplier > 1.2) then
                return SpellTypeEvaluator.Types.PRECISION
            end

            -- Check for Rapid Fire (Low Cast Delay)
            if mods.cast_delay_multiplier < 0.8 then
                return SpellTypeEvaluator.Types.RAPID
            end

            return SpellTypeEvaluator.Types.SIMPLE
        elseif multicast == 1 then
            -- Total 2 projectiles (1 base + 1 multicast)
            return SpellTypeEvaluator.Types.TWIN
        elseif multicast > 1 then
            -- Check for Spread
            if mods.spread > 0 then
                return SpellTypeEvaluator.Types.SCATTER
            end
            -- High multicast without spread is still a form of barrage/rapid
            return SpellTypeEvaluator.Types.RAPID
        end
    end

    -- --- Multi-Action Patterns (3+ Actions) ---
    if action_count >= 3 then
        local elements = {}
        local distinct_elements = 0
        local total_cost = 0

        for _, card in ipairs(actions) do
            -- Track Elements (Tags)
            if card.tags then
                for _, tag in ipairs(card.tags) do
                    if not elements[tag] then
                        elements[tag] = true
                        distinct_elements = distinct_elements + 1
                    end
                end
            end

            -- Track Cost
            total_cost = total_cost + (card.mana_cost or 0)
        end

        -- Mono-Element: Is there an element present in ALL actions?
        local common_element = nil
        local first_tags = actions[1].tags or {}

        for _, tag in ipairs(first_tags) do
            local is_common = true
            for i = 2, action_count do
                local other_tags = actions[i].tags or {}
                local found = false
                for _, ot in ipairs(other_tags) do
                    if ot == tag then
                        found = true; break
                    end
                end
                if not found then
                    is_common = false; break
                end
            end
            if is_common then
                common_element = tag
                break
            end
        end

        if common_element then
            return SpellTypeEvaluator.Types.MONO
        end

        -- Combo Chain: 3+ Actions, NO common element (or specifically distinct types)
        if distinct_elements >= 3 then
            return SpellTypeEvaluator.Types.COMBO
        end

        -- Heavy Barrage: High Cost
        if total_cost > 50 then -- Arbitrary threshold for now
            return SpellTypeEvaluator.Types.HEAVY
        end
    end

    -- Fallback for 2 actions or undefined 3+ patterns
    if action_count == 2 then
        return SpellTypeEvaluator.Types.TWIN -- Loose definition for now, maybe "Dual Cast" later
    end

    return SpellTypeEvaluator.Types.CHAOS
end

return SpellTypeEvaluator
