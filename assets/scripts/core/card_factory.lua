--[[
================================================================================
core/card_factory.lua - Card Definition DSL
================================================================================
Reduces boilerplate when defining cards by:
- Auto-setting id from the key
- Applying type-specific defaults
- Auto-generating test_label from id
- Providing presets for common card archetypes

Usage:
    local CardFactory = require("core.card_factory")

    -- Minimal definition (defaults applied automatically)
    local card = CardFactory.create("FIREBALL", {
        type = "action",
        damage = 25,
        damage_type = "fire",
        tags = { "Fire", "Projectile" },
    })

    -- Using presets
    local proj = CardFactory.projectile("ICE_BOLT", {
        damage = 20,
        damage_type = "ice",
        tags = { "Ice", "Projectile" },
    })

    -- Batch processing
    local Cards = CardFactory.batch({
        CARD_A = { type = "action", ... },
        CARD_B = { type = "modifier", ... },
    })
]]

local ContentDefaults = require("data.content_defaults")

local CardFactory = {}

-- Registered custom presets
local _presets = {}

--------------------------------------------------------------------------------
-- Internal Helpers
--------------------------------------------------------------------------------

--- Generate test_label from card id
--- Converts SNAKE_CASE to readable format with line breaks
local function generate_test_label(id)
    -- Split by underscore, lowercase, join with newlines
    local parts = {}
    for part in string.gmatch(id, "[^_]+") do
        table.insert(parts, part:upper())
    end
    return table.concat(parts, "\n")
end

--- Shallow merge two tables (b overrides a)
--- Note: Nested tables are replaced entirely, not deep-merged.
--- This is intentional - tags and other arrays should be fully replaced.
local function merge(a, b)
    local result = {}
    for k, v in pairs(a) do result[k] = v end
    for k, v in pairs(b) do result[k] = v end
    return result
end

--------------------------------------------------------------------------------
-- Core API
--------------------------------------------------------------------------------

--- Create a card with defaults applied
--- @param id string Card identifier (will be set as card.id)
--- @param def table Card definition
--- @param opts table? Options { validate = bool }
--- @return table card The complete card definition
function CardFactory.create(id, def, opts)
    opts = opts or {}

    -- Start with type-specific defaults
    local card = ContentDefaults.apply_card_defaults(def)

    -- Set id from parameter
    card.id = id

    -- Ensure tags exists
    if not card.tags then
        card.tags = {}
    end

    -- Auto-generate test_label if not provided
    if not card.test_label then
        card.test_label = generate_test_label(id)
    end

    -- Optional validation
    if opts.validate then
        local Schema = require("core.schema")
        Schema.validate(card, Schema.CARD, "Card:" .. id)
    end

    return card
end

--- Create a projectile/action card
--- @param id string Card identifier
--- @param def table Card definition (type will be set to "action")
--- @param opts table? Options
--- @return table card The complete card definition
function CardFactory.projectile(id, def, opts)
    def.type = "action"
    return CardFactory.create(id, def, opts)
end

--- Create a modifier card
--- @param id string Card identifier
--- @param def table Card definition (type will be set to "modifier")
--- @param opts table? Options
--- @return table card The complete card definition
function CardFactory.modifier(id, def, opts)
    def.type = "modifier"
    return CardFactory.create(id, def, opts)
end

--- Create a trigger card
--- @param id string Card identifier
--- @param def table Card definition (type will be set to "trigger")
--- @param opts table? Options
--- @return table card The complete card definition
function CardFactory.trigger(id, def, opts)
    def.type = "trigger"
    return CardFactory.create(id, def, opts)
end

--- Process multiple card definitions at once
--- @param cards table Table of { ID = def } pairs
--- @param opts table? Options passed to each create()
--- @return table cards Same table with ids set and defaults applied
function CardFactory.batch(cards, opts)
    local result = {}
    for id, def in pairs(cards) do
        result[id] = CardFactory.create(id, def, opts)
    end
    return result
end

--- Register custom presets for reuse
--- @param presets table Table of { name = base_def } pairs
function CardFactory.register_presets(presets)
    for name, def in pairs(presets) do
        _presets[name] = def
    end
end

--- Create a card from a registered preset
--- @param id string Card identifier
--- @param preset_name string Name of the registered preset
--- @param overrides table? Fields to override from the preset
--- @param opts table? Options
--- @return table card The complete card definition
function CardFactory.from_preset(id, preset_name, overrides, opts)
    local preset = _presets[preset_name]
    if not preset then
        error(string.format("[CardFactory] Unknown preset: %s", preset_name), 2)
    end

    local def = merge(preset, overrides or {})
    return CardFactory.create(id, def, opts)
end

--- Extend a base card definition with overrides
--- @param id string Card identifier
--- @param base table Base card definition to extend
--- @param overrides table Fields to override
--- @param opts table? Options
--- @return table card The complete card definition
function CardFactory.extend(id, base, overrides, opts)
    local def = merge(base, overrides or {})
    return CardFactory.create(id, def, opts)
end

--- Get all registered presets
--- @return table presets Copy of registered presets
function CardFactory.get_presets()
    local result = {}
    for k, v in pairs(_presets) do
        result[k] = v
    end
    return result
end

return CardFactory
