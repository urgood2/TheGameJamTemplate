--[[
================================================================================
CARD REGISTRY
================================================================================
Provides access to card definitions loaded from data files.
]]

local CardRegistry = {}

-- Cache
local cards_cache = nil
local trigger_cards_cache = nil

local function load_data()
    if cards_cache then return end
    
    local data = require("data.cards")
    cards_cache = data.Cards or {}
    trigger_cards_cache = data.TriggerCards or {}
    
    print("[CardRegistry] Loaded " .. table.count(cards_cache) .. " cards and " .. table.count(trigger_cards_cache) .. " trigger cards.")
end

-- Helper to count table size
function table.count(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

--- Get a card definition by ID
--- @param card_id string
--- @return table|nil
function CardRegistry.get_card(card_id)
    load_data()
    return cards_cache[card_id] or trigger_cards_cache[card_id]
end

--- Get all action/modifier cards
--- @return table
function CardRegistry.get_all_cards()
    load_data()
    return cards_cache
end

--- Get all trigger cards
--- @return table
function CardRegistry.get_all_trigger_cards()
    load_data()
    return trigger_cards_cache
end

--- Get cards by tag (if tags are implemented)
--- @param tag string
--- @return table List of cards
function CardRegistry.get_cards_by_tag(tag)
    load_data()
    local result = {}
    for _, card in pairs(cards_cache) do
        if card.tags then
            for _, t in ipairs(card.tags) do
                if t == tag then
                    table.insert(result, card)
                    break
                end
            end
        end
    end
    return result
end

return CardRegistry
