-- Spell Type Evaluator
-- Analyzes a CastBlock (list of actions/modifiers) and identifies its "Spell Type" (Pattern).
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

--- Analyze a Cast Block and return its Spell Type
-- @param block: Table containing .actions (list of cards) and .modifiers (aggregated stats)
-- @return string: The SpellTypeEvaluator.Types value
function SpellTypeEvaluator.evaluate(block)
    if not block or not block.actions or #block.actions == 0 then
        return nil
    end

    local action_count = #block.actions
    local mods = block.modifiers or {}

    -- --- Single Action Patterns ---
    if action_count == 1 then
        local action = block.actions[1]

        -- Check for Multicast
        local multicastCount = mods.multicastCount or 1

        if multicastCount == 1 then
            -- Check for Precision (Speed/Damage up, no spread)
            if (mods.projectile_speed_multiplier and mods.projectile_speed_multiplier > 1.2) or
                (mods.damage_multiplier and mods.damage_multiplier > 1.2) then
                return SpellTypeEvaluator.Types.PRECISION
            end

            -- Check for Rapid Fire (Low Cast Delay)
            if mods.cast_delay_multiplier and mods.cast_delay_multiplier < 0.8 then
                return SpellTypeEvaluator.Types.RAPID
            end

            return SpellTypeEvaluator.Types.SIMPLE
        elseif multicastCount == 2 then
            -- Total 2 projectiles
            return SpellTypeEvaluator.Types.TWIN
        elseif multicastCount > 2 then
            -- Check for Spread
            if mods.spreadAngleBonus and mods.spreadAngleBonus > 0 then
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

        for _, card in ipairs(block.actions) do
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

        -- Mono-Element: All actions share at least one common element
        -- (Simplified check: if we have 3+ actions and only 1 distinct element type among major elements)
        -- Better check: Is there an element present in ALL actions?
        local common_element = nil
        -- Get tags of first card
        local first_tags = block.actions[1].tags or {}

        for _, tag in ipairs(first_tags) do
            local is_common = true
            for i = 2, action_count do
                local other_tags = block.actions[i].tags or {}
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

--- Analyze tag composition of a cast block
-- This provides metrics for Jokers to react to tag density/diversity
-- @param actions: List of action cards in the cast
-- @return table: Tag analysis metrics
function SpellTypeEvaluator.analyzeTags(actions)
    local tagCounts = {}
    local totalTags = 0

    -- Count all tags across all actions
    for _, action in ipairs(actions) do
        if action.tags then
            for _, tag in ipairs(action.tags) do
                tagCounts[tag] = (tagCounts[tag] or 0) + 1
                totalTags = totalTags + 1
            end
        end
    end

    -- Find primary tag (most common)
    local primaryTag = nil
    local primaryCount = 0
    for tag, count in pairs(tagCounts) do
        if count > primaryCount then
            primaryTag = tag
            primaryCount = count
        end
    end

    -- Calculate diversity (number of distinct tag types)
    local diversity = 0
    for _ in pairs(tagCounts) do
        diversity = diversity + 1
    end

    return {
        tag_counts = tagCounts,       -- Table of tag -> count
        primary_tag = primaryTag,     -- Most common tag
        primary_count = primaryCount, -- Count of primary tag
        diversity = diversity,        -- Number of distinct tags
        total_tags = totalTags,       -- Total tag instances

        -- Threshold flags for Jokers to check
        is_tag_heavy = primaryCount >= 3,               -- 3+ actions with same tag
        is_mono_tag = diversity == 1,                   -- Only one tag type
        is_diverse = diversity >= 3,                    -- 3+ different tag types
        is_multi_tag = diversity >= 2 and #actions == 1 -- Single action with multiple tags
    }
end

return SpellTypeEvaluator
