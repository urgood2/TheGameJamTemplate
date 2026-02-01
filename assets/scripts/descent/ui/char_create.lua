-- assets/scripts/descent/ui/char_create.lua
--[[
================================================================================
DESCENT CHARACTER CREATION UI
================================================================================
Character creation screen for Descent roguelike mode.

Features:
- Species selection (Human only in MVP)
- Background selection (Gladiator only in MVP)
- Starting gear display
- Cancel returns to main menu

Usage:
    local char_create = require("descent.ui.char_create")
    char_create.open(on_confirm, on_cancel)
================================================================================
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")
local items  -- Lazy loaded

--------------------------------------------------------------------------------
-- Species Definitions
--------------------------------------------------------------------------------

local SPECIES = {
    human = {
        id = "human",
        name = "Human",
        description = "Versatile and adaptable. No special strengths or weaknesses.",
        stat_mods = {
            str = 0,
            dex = 0,
            int = 0,
            hp_mod = 0,
            mp_mod = 0,
        },
        available = true,  -- Available in MVP
    },
}

--------------------------------------------------------------------------------
-- Background Definitions
--------------------------------------------------------------------------------

local BACKGROUNDS = {
    gladiator = {
        id = "gladiator",
        name = "Gladiator",
        description = "A warrior trained in the arena. Starts with combat gear.",
        stat_mods = {
            str = 2,
            dex = 1,
            int = -1,
        },
        starting_items = {
            { template_id = "short_sword", quantity = 1 },
            { template_id = "leather_armor", quantity = 1 },
            { template_id = "health_potion", quantity = 2 },
        },
        starting_gold = 50,
        skills = { "melee" },
        available = true,
    },
}

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local state = {
    open = false,
    species_index = 1,
    background_index = 1,
    available_species = {},
    available_backgrounds = {},
    on_confirm = nil,
    on_cancel = nil,
    selected_field = "species",  -- "species" or "background"
}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Build available lists
local function build_available_lists()
    state.available_species = {}
    state.available_backgrounds = {}
    
    for _, sp in pairs(SPECIES) do
        if sp.available then
            table.insert(state.available_species, sp)
        end
    end
    table.sort(state.available_species, function(a, b) return a.id < b.id end)
    
    for _, bg in pairs(BACKGROUNDS) do
        if bg.available then
            table.insert(state.available_backgrounds, bg)
        end
    end
    table.sort(state.available_backgrounds, function(a, b) return a.id < b.id end)
end

--- Get currently selected species
--- @return table Species data
local function get_selected_species()
    return state.available_species[state.species_index] or SPECIES.human
end

--- Get currently selected background
--- @return table Background data
local function get_selected_background()
    return state.available_backgrounds[state.background_index] or BACKGROUNDS.gladiator
end

--- Create character data from selection
--- @return table Character data
local function create_character()
    local species = get_selected_species()
    local background = get_selected_background()
    
    -- Calculate base stats
    local base_stats = spec.stats.base_attributes
    local stats = {
        str = base_stats.str + (species.stat_mods.str or 0) + (background.stat_mods.str or 0),
        dex = base_stats.dex + (species.stat_mods.dex or 0) + (background.stat_mods.dex or 0),
        int = base_stats.int + (species.stat_mods.int or 0) + (background.stat_mods.int or 0),
    }
    
    -- Calculate HP/MP
    local hp_base = spec.stats.hp.base
    local hp_mod = species.stat_mods.hp_mod or 0
    local hp = math.floor(hp_base + hp_mod)
    
    local mp_base = spec.stats.mp.base
    local mp_mod = species.stat_mods.mp_mod or 0
    local mp = math.floor(mp_base + mp_mod)
    
    -- Create starting inventory
    local starting_items = {}
    for _, item_def in ipairs(background.starting_items or {}) do
        table.insert(starting_items, {
            template_id = item_def.template_id,
            quantity = item_def.quantity or 1,
        })
    end
    
    return {
        species_id = species.id,
        species_name = species.name,
        background_id = background.id,
        background_name = background.name,
        level = spec.stats.starting_level,
        xp = 0,
        stats = stats,
        hp = hp,
        max_hp = hp,
        mp = mp,
        max_mp = mp,
        gold = background.starting_gold or 0,
        starting_items = starting_items,
        skills = background.skills or {},
    }
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize character creation module
function M.init()
    items = require("descent.items")
    build_available_lists()
end

--- Open character creation screen
--- @param on_confirm function Callback(character_data) when confirmed
--- @param on_cancel function Callback() when cancelled
function M.open(on_confirm, on_cancel)
    if not items then
        items = require("descent.items")
    end
    build_available_lists()
    
    state.open = true
    state.species_index = 1
    state.background_index = 1
    state.selected_field = "species"
    state.on_confirm = on_confirm
    state.on_cancel = on_cancel
end

--- Close character creation
function M.close()
    state.open = false
    state.on_confirm = nil
    state.on_cancel = nil
end

--- Check if character creation is open
--- @return boolean
function M.is_open()
    return state.open
end

--- Handle input
--- @param key string Key pressed
--- @return boolean True if input was handled
function M.handle_input(key)
    if not state.open then
        return false
    end
    
    -- Navigation
    if key == "Up" or key == "W" or key == "K" then
        if state.selected_field == "background" then
            state.selected_field = "species"
        end
        return true
    elseif key == "Down" or key == "S" or key == "J" then
        if state.selected_field == "species" then
            state.selected_field = "background"
        end
        return true
    elseif key == "Left" or key == "A" or key == "H" then
        if state.selected_field == "species" then
            state.species_index = math.max(1, state.species_index - 1)
        else
            state.background_index = math.max(1, state.background_index - 1)
        end
        return true
    elseif key == "Right" or key == "D" or key == "L" then
        if state.selected_field == "species" then
            state.species_index = math.min(#state.available_species, state.species_index + 1)
        else
            state.background_index = math.min(#state.available_backgrounds, state.background_index + 1)
        end
        return true
    end
    
    -- Confirm
    if key == "Enter" or key == "Space" then
        local character = create_character()
        if state.on_confirm then
            state.on_confirm(character)
        end
        M.close()
        return true
    end
    
    -- Cancel
    if key == "Escape" or key == "Q" then
        if state.on_cancel then
            state.on_cancel()
        end
        M.close()
        return true
    end
    
    return false
end

--- Get current selection for display
--- @return table Selection state
function M.get_selection()
    return {
        species = get_selected_species(),
        background = get_selected_background(),
        selected_field = state.selected_field,
        species_index = state.species_index,
        species_count = #state.available_species,
        background_index = state.background_index,
        background_count = #state.available_backgrounds,
    }
end

--- Get preview of character stats
--- @return table Character preview
function M.get_preview()
    return create_character()
end

--- Format for console display
--- @return string Formatted text
function M.format()
    if not state.open then
        return ""
    end
    
    local lines = {}
    table.insert(lines, "=== CHARACTER CREATION ===")
    table.insert(lines, "")
    
    local species = get_selected_species()
    local background = get_selected_background()
    local preview = create_character()
    
    -- Species section
    local sp_marker = state.selected_field == "species" and "> " or "  "
    table.insert(lines, sp_marker .. "SPECIES: " .. species.name)
    table.insert(lines, "    " .. species.description)
    table.insert(lines, "")
    
    -- Background section
    local bg_marker = state.selected_field == "background" and "> " or "  "
    table.insert(lines, bg_marker .. "BACKGROUND: " .. background.name)
    table.insert(lines, "    " .. background.description)
    table.insert(lines, "")
    
    -- Stats preview
    table.insert(lines, "--- STATS ---")
    table.insert(lines, string.format("  STR: %d  DEX: %d  INT: %d", 
        preview.stats.str, preview.stats.dex, preview.stats.int))
    table.insert(lines, string.format("  HP: %d  MP: %d  Gold: %d",
        preview.hp, preview.mp, preview.gold))
    table.insert(lines, "")
    
    -- Starting gear
    table.insert(lines, "--- STARTING GEAR ---")
    for _, item_def in ipairs(background.starting_items or {}) do
        local template = items and items.get_template(item_def.template_id)
        local name = template and template.name or item_def.template_id
        if item_def.quantity > 1 then
            table.insert(lines, "  " .. name .. " x" .. item_def.quantity)
        else
            table.insert(lines, "  " .. name)
        end
    end
    table.insert(lines, "")
    
    -- Controls
    table.insert(lines, "[Enter] Confirm  [Esc] Cancel")
    table.insert(lines, "[Up/Down] Switch field  [Left/Right] Change selection")
    
    return table.concat(lines, "\n")
end

--- Get all available species
--- @return table Array of species
function M.get_species()
    build_available_lists()
    return state.available_species
end

--- Get all available backgrounds
--- @return table Array of backgrounds
function M.get_backgrounds()
    build_available_lists()
    return state.available_backgrounds
end

--- Directly create character with specific choices
--- @param species_id string Species ID
--- @param background_id string Background ID
--- @return table Character data
function M.create_with(species_id, background_id)
    -- Find indices
    for i, sp in ipairs(state.available_species) do
        if sp.id == species_id then
            state.species_index = i
            break
        end
    end
    
    for i, bg in ipairs(state.available_backgrounds) do
        if bg.id == background_id then
            state.background_index = i
            break
        end
    end
    
    return create_character()
end

--- Register additional species
--- @param species table Species definition
function M.register_species(species)
    SPECIES[species.id] = species
    build_available_lists()
end

--- Register additional background
--- @param background table Background definition
function M.register_background(background)
    BACKGROUNDS[background.id] = background
    build_available_lists()
end

return M
