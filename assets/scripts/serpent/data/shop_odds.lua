-- assets/scripts/serpent/data/shop_odds.lua
--[[
    Shop Tier Probability Tables

    Defines tier odds for different wave brackets as specified in PLAN.md.
    Used by the shop system to determine unit tier rarity across game progression.
]]

local shop_odds = {}

--- Shop tier probabilities by wave bracket
--- Each entry contains cumulative probabilities for tier selection
--- Format: { tier1, tier2, tier3, tier4 } where values sum to 1.0
shop_odds.TIER_ODDS = {
    -- Waves 1-5: Early game - mostly low tier units
    [1] = { 0.70, 0.25, 0.05, 0.00 },  -- 70% T1, 25% T2, 5% T3, 0% T4

    -- Waves 6-10: Mid-early - slight tier increase
    [6] = { 0.55, 0.30, 0.13, 0.02 },  -- 55% T1, 30% T2, 13% T3, 2% T4

    -- Waves 11-15: Mid-game - balanced distribution
    [11] = { 0.35, 0.35, 0.22, 0.08 }, -- 35% T1, 35% T2, 22% T3, 8% T4

    -- Waves 16-20: End game - high tier units common
    [16] = { 0.20, 0.30, 0.33, 0.17 }  -- 20% T1, 30% T2, 33% T3, 17% T4
}

--- Get tier odds for a given wave number
--- @param wave_num number Wave number (1-20)
--- @return table Probability table for tiers { tier1, tier2, tier3, tier4 }
function shop_odds.get_tier_odds(wave_num)
    if wave_num <= 5 then
        return shop_odds.TIER_ODDS[1]
    elseif wave_num <= 10 then
        return shop_odds.TIER_ODDS[6]
    elseif wave_num <= 15 then
        return shop_odds.TIER_ODDS[11]
    else -- wave_num >= 16
        return shop_odds.TIER_ODDS[16]
    end
end

--- Get wave bracket for a given wave number
--- @param wave_num number Wave number (1-20)
--- @return string Wave bracket identifier
function shop_odds.get_wave_bracket(wave_num)
    if wave_num <= 5 then
        return "1-5"
    elseif wave_num <= 10 then
        return "6-10"
    elseif wave_num <= 15 then
        return "11-15"
    else
        return "16-20"
    end
end

--- Select tier based on RNG roll and wave number
--- @param wave_num number Wave number (1-20)
--- @param rng_roll number Random float [0.0, 1.0)
--- @return number Tier number (1-4)
function shop_odds.select_tier(wave_num, rng_roll)
    local odds = shop_odds.get_tier_odds(wave_num)
    local cumulative = 0.0

    for tier = 1, 4 do
        cumulative = cumulative + odds[tier]
        if rng_roll < cumulative then
            return tier
        end
    end

    -- Fallback (should not happen with proper probabilities)
    return 4
end

return shop_odds