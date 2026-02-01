-- assets/scripts/descent/items_scrolls.lua
--[[
================================================================================
DESCENT SCROLL IDENTIFICATION MODULE
================================================================================
Scroll identification system for Descent roguelike mode.

Key features (per spec):
- Labels randomized per run seed
- Labels unique within run
- Identification persists and updates display
- Using scroll identifies all scrolls of that type

Usage:
    local scrolls = require("descent.items_scrolls")
    scrolls.init(seed)  -- Initialize with run seed
    
    local label = scrolls.get_label(scroll_type)  -- "scroll of ashen"
    scrolls.identify(scroll_type)  -- Mark type as identified
================================================================================
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")
local rng  -- Lazy loaded

--------------------------------------------------------------------------------
-- Scroll Type Definitions
--------------------------------------------------------------------------------

-- Base scroll types and their effects
local SCROLL_TYPES = {
    identify = {
        id = "identify",
        name = "Scroll of Identify",
        effect = { action = "identify" },
        description = "Reveals the true nature of an item.",
        rarity = 10,
    },
    teleport = {
        id = "teleport",
        name = "Scroll of Teleport",
        effect = { action = "teleport", range = "random" },
        description = "Transports you to a random location on the floor.",
        rarity = 8,
    },
    magic_mapping = {
        id = "magic_mapping",
        name = "Scroll of Magic Mapping",
        effect = { action = "reveal_map" },
        description = "Reveals the layout of the current floor.",
        rarity = 6,
    },
    fear = {
        id = "fear",
        name = "Scroll of Fear",
        effect = { action = "fear", radius = 5, duration = 10 },
        description = "Causes nearby enemies to flee in terror.",
        rarity = 7,
    },
    enchant_weapon = {
        id = "enchant_weapon",
        name = "Scroll of Enchant Weapon",
        effect = { action = "enchant", target = "weapon", bonus = 1 },
        description = "Permanently enhances your weapon.",
        rarity = 4,
    },
    enchant_armor = {
        id = "enchant_armor",
        name = "Scroll of Enchant Armor",
        effect = { action = "enchant", target = "armor", bonus = 1 },
        description = "Permanently enhances your armor.",
        rarity = 4,
    },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    seed = 0,
    initialized = false,
    
    -- Label assignments: scroll_type -> label (e.g., "identify" -> "ashen")
    labels = {},
    
    -- Identification state: scroll_type -> boolean
    identified = {},
    
    -- Available labels (shuffled from spec.scrolls.label_pool)
    label_pool = {},
    label_index = 1,
}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Get next unique label from pool
--- @return string Label
local function get_next_label()
    if state.label_index > #state.label_pool then
        -- Wrap around (shouldn't happen if pool is large enough)
        state.label_index = 1
    end
    
    local label = state.label_pool[state.label_index]
    state.label_index = state.label_index + 1
    return label
end

--- Assign labels to all scroll types deterministically
local function assign_labels()
    state.labels = {}
    state.label_index = 1
    
    -- Get sorted list of scroll types for determinism
    local types = {}
    for type_id in pairs(SCROLL_TYPES) do
        table.insert(types, type_id)
    end
    table.sort(types)
    
    -- Assign labels in order
    for _, type_id in ipairs(types) do
        state.labels[type_id] = get_next_label()
    end
end

--- Shuffle label pool using RNG
local function shuffle_label_pool()
    -- Copy labels from spec
    state.label_pool = {}
    local pool = spec.scrolls and spec.scrolls.label_pool or {}
    for _, label in ipairs(pool) do
        table.insert(state.label_pool, label)
    end
    
    -- Fisher-Yates shuffle
    for i = #state.label_pool, 2, -1 do
        local j = rng.random_int(1, i)
        state.label_pool[i], state.label_pool[j] = state.label_pool[j], state.label_pool[i]
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize scroll system with run seed
--- @param seed number Run seed
function M.init(seed)
    rng = require("descent.rng")
    
    state.seed = seed or 0
    state.identified = {}
    
    -- Initialize RNG with scroll-specific subseed
    local scroll_seed = seed + 7777  -- Magic offset for scroll labels
    rng.init(scroll_seed)
    
    -- Shuffle labels and assign
    shuffle_label_pool()
    assign_labels()
    
    state.initialized = true
end

--- Reset identification state (keeps labels)
function M.reset_identification()
    state.identified = {}
end

--- Get the display label for a scroll type
--- @param scroll_type string Scroll type ID
--- @return string Display label (e.g., "scroll of ashen")
function M.get_label(scroll_type)
    local label = state.labels[scroll_type]
    if not label then
        return "scroll of unknown"
    end
    return "scroll of " .. label
end

--- Get the raw label (without "scroll of" prefix)
--- @param scroll_type string Scroll type ID
--- @return string|nil Raw label or nil
function M.get_raw_label(scroll_type)
    return state.labels[scroll_type]
end

--- Check if a scroll type is identified
--- @param scroll_type string Scroll type ID
--- @return boolean
function M.is_identified(scroll_type)
    return state.identified[scroll_type] == true
end

--- Identify a scroll type
--- @param scroll_type string Scroll type ID
--- @return boolean True if newly identified
function M.identify(scroll_type)
    if state.identified[scroll_type] then
        return false  -- Already identified
    end
    
    state.identified[scroll_type] = true
    return true
end

--- Get display name for a scroll
--- @param scroll_type string Scroll type ID
--- @return string Display name
function M.get_display_name(scroll_type)
    if M.is_identified(scroll_type) then
        local scroll_def = SCROLL_TYPES[scroll_type]
        return scroll_def and scroll_def.name or ("Scroll of " .. scroll_type)
    else
        return M.get_label(scroll_type)
    end
end

--- Get scroll type definition
--- @param scroll_type string Scroll type ID
--- @return table|nil Scroll definition
function M.get_scroll_type(scroll_type)
    return SCROLL_TYPES[scroll_type]
end

--- Get all scroll type IDs
--- @return table Array of type IDs
function M.get_all_types()
    local types = {}
    for type_id in pairs(SCROLL_TYPES) do
        table.insert(types, type_id)
    end
    table.sort(types)
    return types
end

--- Get identification state for all scrolls
--- @return table Map of scroll_type -> boolean
function M.get_identification_state()
    local state_copy = {}
    for type_id, is_id in pairs(state.identified) do
        state_copy[type_id] = is_id
    end
    return state_copy
end

--- Load identification state (for save/load)
--- @param id_state table Map of scroll_type -> boolean
function M.load_identification_state(id_state)
    state.identified = id_state or {}
end

--- Get label assignment (for save/load)
--- @return table Map of scroll_type -> label
function M.get_label_state()
    local labels_copy = {}
    for type_id, label in pairs(state.labels) do
        labels_copy[type_id] = label
    end
    return labels_copy
end

--- Load label state (for save/load with same seed)
--- @param labels table Map of scroll_type -> label
function M.load_label_state(labels)
    state.labels = labels or {}
end

--- Register a new scroll type
--- @param scroll_type table Scroll type definition with id, name, effect
function M.register_scroll_type(scroll_type)
    if scroll_type.id then
        SCROLL_TYPES[scroll_type.id] = scroll_type
        
        -- Assign label if initialized
        if state.initialized and not state.labels[scroll_type.id] then
            state.labels[scroll_type.id] = get_next_label()
        end
    end
end

--- Find scroll type by label
--- @param label string Label to search for
--- @return string|nil Scroll type ID or nil
function M.find_by_label(label)
    for type_id, type_label in pairs(state.labels) do
        if type_label == label then
            return type_id
        end
    end
    return nil
end

--- Get count of identified scroll types
--- @return number, number Identified count, total count
function M.get_identification_progress()
    local identified = 0
    local total = 0
    for _ in pairs(SCROLL_TYPES) do
        total = total + 1
    end
    for _ in pairs(state.identified) do
        identified = identified + 1
    end
    return identified, total
end

return M
