--[[
================================================================================
core/schema.lua - Data Validation & Typo Detection
================================================================================
Validates data tables against schemas at load time to catch:
- Missing required fields
- Wrong types
- Invalid enum values
- Unknown fields (typo detection)

Usage:
    local Schema = require("core.schema")

    -- Check without throwing
    local ok, errors, warnings = Schema.check(data, Schema.CARD)

    -- Validate with throw on error
    Schema.validate(card, Schema.CARD, "Card:FIREBALL")

    -- Validate a table of items
    Schema.validateAll(Cards, Schema.CARD, "Card")
]]

local Schema = {}

-- Global enable flag (can disable in production for performance)
Schema.ENABLED = true

--------------------------------------------------------------------------------
-- Schema Definitions
--------------------------------------------------------------------------------

-- Field spec: { type = "string"|"number"|"table"|"function"|"boolean",
--               required = bool, enum = {...} }

Schema.CARD = {
    _name = "CARD",
    _fields = {
        -- Required fields
        id          = { type = "string",  required = true },
        type        = { type = "string",  required = true, enum = { "action", "modifier", "trigger" } },
        tags        = { type = "table",   required = true },

        -- Display
        test_label  = { type = "string",  required = false },
        sprite      = { type = "string",  required = false },
        description = { type = "string",  required = false },

        -- Mana/Cost (shared by all types)
        mana_cost   = { type = "number",  required = false },
        max_uses    = { type = "number",  required = false },
        recharge_time = { type = "number", required = false },
        weight      = { type = "number",  required = false },

        -- Combat Stats (action cards)
        damage      = { type = "number",  required = false },
        damage_type = { type = "string",  required = false },
        radius_of_effect = { type = "number", required = false },

        -- Projectile Properties (action cards)
        projectile_speed = { type = "number", required = false },
        lifetime    = { type = "number",  required = false },
        spread_angle = { type = "number", required = false },
        homing_strength = { type = "number", required = false },
        ricochet_count = { type = "number", required = false },

        -- Timing
        cast_delay  = { type = "number",  required = false },
        timer_ms    = { type = "number",  required = false },

        -- Modifier Card Fields
        damage_modifier = { type = "number", required = false },
        speed_modifier = { type = "number", required = false },
        lifetime_modifier = { type = "number", required = false },
        spread_modifier = { type = "number", required = false },
        critical_hit_chance_modifier = { type = "number", required = false },
        multicast_count = { type = "number", required = false },

        -- Trigger Card Fields
        trigger_condition = { type = "function", required = false },
        trigger_chance = { type = "number", required = false },
        trigger_on_collision = { type = "boolean", required = false },

        -- Misc
        behavior_id = { type = "string",  required = false },
        cooldown    = { type = "number",  required = false },
    }
}

Schema.JOKER = {
    _name = "JOKER",
    _fields = {
        id          = { type = "string",   required = true },
        name        = { type = "string",   required = true },
        description = { type = "string",   required = true },
        rarity      = { type = "string",   required = true, enum = { "Common", "Uncommon", "Rare", "Epic", "Legendary" } },
        sprite      = { type = "string",   required = false },
        calculate   = { type = "function", required = false },
        on_add      = { type = "function", required = false },
        on_remove   = { type = "function", required = false },
    }
}

Schema.PROJECTILE = {
    _name = "PROJECTILE",
    _fields = {
        id              = { type = "string", required = true },
        speed           = { type = "number", required = false },
        damage_type     = { type = "string", required = false },
        movement        = { type = "string", required = false, enum = { "straight", "homing", "arc", "orbital" } },
        collision       = { type = "string", required = false, enum = { "destroy", "pierce", "bounce", "explode", "pass_through", "chain" } },
        explosion_radius = { type = "number", required = false },
        lifetime        = { type = "number", required = false },
        tags            = { type = "table",  required = false },
        sprite          = { type = "string", required = false },
    }
}

Schema.ENEMY = {
    _name = "ENEMY",
    _fields = {
        id          = { type = "string", required = true },
        name        = { type = "string", required = false },
        health      = { type = "number", required = false },
        damage      = { type = "number", required = false },
        speed       = { type = "number", required = false },
        sprite      = { type = "string", required = false },
        ai_type     = { type = "string", required = false },
        tags        = { type = "table",  required = false },
    }
}

--------------------------------------------------------------------------------
-- Validation Logic
--------------------------------------------------------------------------------

--- Check data against a schema
--- @param data table The data to validate
--- @param schema table The schema to validate against
--- @return boolean ok True if validation passed (no errors)
--- @return table errors List of error messages (empty if ok)
--- @return table warnings List of warning messages (unknown fields)
function Schema.check(data, schema)
    -- Short-circuit if disabled
    if not Schema.ENABLED then
        return true, {}, {}
    end

    local errors = {}
    local warnings = {}
    local fields = schema._fields

    -- Check required fields and types
    for fieldName, spec in pairs(fields) do
        local value = data[fieldName]

        -- Required field missing?
        if spec.required and value == nil then
            table.insert(errors, string.format("missing required field '%s'", fieldName))
        end

        -- Type check (if value exists)
        if value ~= nil then
            local actualType = type(value)
            if actualType ~= spec.type then
                table.insert(errors, string.format(
                    "field '%s' expected %s, got %s",
                    fieldName, spec.type, actualType
                ))
            end

            -- Enum check
            if spec.enum and actualType == "string" then
                local valid = false
                for _, allowed in ipairs(spec.enum) do
                    if value == allowed then
                        valid = true
                        break
                    end
                end
                if not valid then
                    table.insert(errors, string.format(
                        "field '%s' must be one of: %s (got '%s')",
                        fieldName, table.concat(spec.enum, ", "), value
                    ))
                end
            end
        end
    end

    -- Check for unknown fields (typo detection)
    for key, _ in pairs(data) do
        if not fields[key] then
            table.insert(warnings, string.format("unknown field '%s' (typo?)", key))
        end
    end

    local ok = #errors == 0
    return ok, errors, warnings
end

--- Validate data and throw on error
--- @param data table The data to validate
--- @param schema table The schema to validate against
--- @param name string Optional name for error context
function Schema.validate(data, schema, name)
    if not Schema.ENABLED then
        return
    end

    local ok, errors, warnings = Schema.check(data, schema)

    -- Log warnings
    if #warnings > 0 then
        local warnMsg = string.format("[Schema] %s: %s", name or schema._name, table.concat(warnings, "; "))
        if rawget(_G, "log_warn") then
            log_warn(warnMsg)
        else
            print("WARN: " .. warnMsg)
        end
    end

    -- Throw on errors
    if not ok then
        local errMsg = string.format(
            "[Schema] %s validation failed:\n  - %s",
            name or schema._name,
            table.concat(errors, "\n  - ")
        )
        error(errMsg, 2)
    end
end

--- Validate all items in a table
--- @param items table Table of items (keyed by ID)
--- @param schema table The schema to validate against
--- @param prefix string Prefix for error messages (e.g., "Card")
--- @return table The same items table (for chaining)
function Schema.validateAll(items, schema, prefix)
    if not Schema.ENABLED then
        return items
    end

    for key, item in pairs(items) do
        local name = string.format("%s:%s", prefix, key)
        Schema.validate(item, schema, name)
    end

    return items
end

return Schema
