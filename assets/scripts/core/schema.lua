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
-- String Similarity (Levenshtein Distance)
--------------------------------------------------------------------------------

--- Calculate Levenshtein distance between two strings
--- @param s1 string First string
--- @param s2 string Second string
--- @return number Distance (0 = identical)
local function levenshtein(s1, s2)
    local len1, len2 = #s1, #s2

    -- Early exit for identical strings
    if s1 == s2 then return 0 end
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end

    -- Create distance matrix (using two rows for memory efficiency)
    local prev = {}
    local curr = {}

    -- Initialize first row
    for j = 0, len2 do
        prev[j] = j
    end

    -- Fill matrix
    for i = 1, len1 do
        curr[0] = i
        for j = 1, len2 do
            local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
            curr[j] = math.min(
                prev[j] + 1,      -- deletion
                curr[j - 1] + 1,  -- insertion
                prev[j - 1] + cost -- substitution
            )
        end
        prev, curr = curr, prev
    end

    return prev[len2]
end

--- Calculate similarity ratio (0-1, higher = more similar)
--- @param s1 string First string
--- @param s2 string Second string
--- @return number Similarity (0 = completely different, 1 = identical)
local function similarity(s1, s2)
    local maxLen = math.max(#s1, #s2)
    if maxLen == 0 then return 1 end
    return 1 - (levenshtein(s1, s2) / maxLen)
end

--- Find the best matching field name for a typo
--- @param typo string The unknown field name
--- @param validFields table Table of valid field names
--- @param threshold number Minimum similarity (default 0.5)
--- @return string|nil bestMatch The closest matching field, or nil if none close enough
local function findBestMatch(typo, validFields, threshold)
    threshold = threshold or 0.5
    local bestMatch = nil
    local bestSim = threshold

    for fieldName, _ in pairs(validFields) do
        local sim = similarity(typo:lower(), fieldName:lower())
        if sim > bestSim then
            bestSim = sim
            bestMatch = fieldName
        end
    end

    return bestMatch
end

-- Export for testing
Schema._levenshtein = levenshtein
Schema._similarity = similarity
Schema._findBestMatch = findBestMatch

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
-- UI Component Schemas
--------------------------------------------------------------------------------
-- These schemas validate props passed to ui_syntax_sugar (DSL) components.
-- Note: The DSL wraps these into internal definitions, so validation happens
-- on the opts/config tables passed by users.

--[[
PRIMITIVE COMPONENTS
These are leaf nodes that display content but don't contain children.
]]

Schema.UI_TEXT = {
    _name = "UI_TEXT",
    _fields = {
        -- Content (first positional arg becomes text)
        text        = { type = "string",   required = false }, -- Can be passed positionally

        -- Styling
        fontSize    = { type = "number",   required = false },
        fontName    = { type = "string",   required = false },
        color       = { type = "string",   required = false }, -- Color name or table
        shadow      = { type = "boolean",  required = false },
        align       = { type = "number",   required = false }, -- AlignmentFlag bitmask

        -- Interaction
        onClick     = { type = "function", required = false },
        hover       = { type = "table",    required = false }, -- { title, body }
        tooltip     = { type = "table",    required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_RICH_TEXT = {
    _name = "UI_RICH_TEXT",
    _fields = {
        -- Content (markup string like "[Health](color=red): 100")
        text        = { type = "string",   required = false },

        -- Styling defaults
        fontSize    = { type = "number",   required = false },
        fontName    = { type = "string",   required = false },
        color       = { type = "string",   required = false },
        shadow      = { type = "boolean",  required = false },
    }
}

Schema.UI_DYNAMIC_TEXT = {
    _name = "UI_DYNAMIC_TEXT",
    _fields = {
        -- Content (function that returns text)
        fn          = { type = "function", required = false }, -- Value getter

        -- Styling
        fontSize    = { type = "number",   required = false },
        effect      = { type = "string",   required = false },
        color       = { type = "string",   required = false },

        -- Auto-alignment
        autoAlign   = { type = "boolean",  required = false },
        alignRate   = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_ANIM = {
    _name = "UI_ANIM",
    _fields = {
        -- Content (sprite/animation ID passed as first arg)
        id          = { type = "string",   required = false },

        -- Dimensions
        w           = { type = "number",   required = false },
        h           = { type = "number",   required = false },

        -- Display
        shadow      = { type = "boolean",  required = false },
        isAnimation = { type = "boolean",  required = false }, -- true = existing anim, false = sprite
    }
}

Schema.UI_SPACER = {
    _name = "UI_SPACER",
    _fields = {
        -- Dimensions (positional: w, h)
        w           = { type = "number",   required = false },
        h           = { type = "number",   required = false },
    }
}

Schema.UI_FILLER = {
    _name = "UI_FILLER",
    _fields = {
        -- Flex weight for proportional space distribution (default: 1)
        flex        = { type = "number",   required = false },
        -- Maximum fill size in pixels (0 = unlimited)
        maxFill     = { type = "number",   required = false },
    }
}

Schema.UI_DIVIDER = {
    _name = "UI_DIVIDER",
    _fields = {
        -- Direction (positional: "horizontal" or "vertical")
        direction   = { type = "string",   required = false, enum = { "horizontal", "vertical" } },

        -- Styling
        color       = { type = "string",   required = false },
        thickness   = { type = "number",   required = false },
        length      = { type = "number",   required = false },
    }
}

Schema.UI_ICON_LABEL = {
    _name = "UI_ICON_LABEL",
    _fields = {
        -- Content (positional: iconId, label)
        iconId      = { type = "string",   required = false },
        label       = { type = "string",   required = false },

        -- Dimensions
        iconSize    = { type = "number",   required = false },

        -- Styling
        fontSize    = { type = "number",   required = false },
        textColor   = { type = "string",   required = false },
        shadow      = { type = "boolean",  required = false },
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

--[[
LAYOUT COMPONENTS
These are container nodes that organize children.
]]

Schema.UI_ROOT = {
    _name = "UI_ROOT",
    _fields = {
        -- Structure
        children    = { type = "table",    required = false },
        config      = { type = "table",    required = false },

        -- Config fields (can also be in config table)
        color       = { type = "string",   required = false },
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_VBOX = {
    _name = "UI_VBOX",
    _fields = {
        -- Structure
        children    = { type = "table",    required = false },
        config      = { type = "table",    required = false },

        -- Layout
        spacing     = { type = "number",   required = false },
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Styling
        color       = { type = "string",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_HBOX = {
    _name = "UI_HBOX",
    _fields = {
        -- Structure
        children    = { type = "table",    required = false },
        config      = { type = "table",    required = false },

        -- Layout
        spacing     = { type = "number",   required = false },
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Styling
        color       = { type = "string",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_SECTION = {
    _name = "UI_SECTION",
    _fields = {
        -- Content (positional: title)
        title       = { type = "string",   required = false },

        -- Structure
        children    = { type = "table",    required = false },

        -- Title styling
        titleSize   = { type = "number",   required = false },
        titleColor  = { type = "string",   required = false },
        titleBg     = { type = "string",   required = false },
        titlePadding = { type = "number",  required = false },

        -- Content styling
        color       = { type = "string",   required = false },
        padding     = { type = "number",   required = false },
        emboss      = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_GRID = {
    _name = "UI_GRID",
    _fields = {
        -- Dimensions (positional: rows, cols)
        rows        = { type = "number",   required = false },
        cols        = { type = "number",   required = false },

        -- Generator function (positional: gen)
        gen         = { type = "function", required = false },
    }
}

--[[
INTERACTIVE COMPONENTS
These handle user input.
]]

Schema.UI_BUTTON = {
    _name = "UI_BUTTON",
    _fields = {
        -- Content (positional: label)
        label       = { type = "string",   required = false },

        -- Interaction
        onClick     = { type = "function", required = false },
        disabled    = { type = "boolean",  required = false },
        hover       = { type = "table",    required = false },
        tooltip     = { type = "table",    required = false },

        -- Styling
        color       = { type = "string",   required = false },
        textColor   = { type = "string",   required = false },
        fontSize    = { type = "number",   required = false },
        shadow      = { type = "boolean",  required = false },
        emboss      = { type = "number",   required = false },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_SPRITE_BUTTON = {
    _name = "UI_SPRITE_BUTTON",
    _fields = {
        -- Sprite (base name or explicit states)
        sprite      = { type = "string",   required = false },
        states      = { type = "table",    required = false }, -- { normal, hover, pressed, disabled }
        borders     = { type = "table",    required = false }, -- [left, top, right, bottom]

        -- Content
        label       = { type = "string",   required = false },
        text        = { type = "string",   required = false }, -- Alias for label
        children    = { type = "table",    required = false },

        -- Interaction
        onClick     = { type = "function", required = false },
        disabled    = { type = "boolean",  required = false },

        -- Styling
        textColor   = { type = "string",   required = false },
        fontSize    = { type = "number",   required = false },
        shadow      = { type = "boolean",  required = false },
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_PROGRESS_BAR = {
    _name = "UI_PROGRESS_BAR",
    _fields = {
        -- Value
        getValue    = { type = "function", required = false },
        maxValue    = { type = "number",   required = false },

        -- Styling
        color       = { type = "string",   required = false },
        emptyColor  = { type = "string",   required = false },
        fullColor   = { type = "string",   required = false },
        align       = { type = "number",   required = false },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },

        -- Structure
        children    = { type = "table",    required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

--[[
PANEL COMPONENTS
These provide styled backgrounds with nine-patch support.
]]

Schema.UI_SPRITE_PANEL = {
    _name = "UI_SPRITE_PANEL",
    _fields = {
        -- Sprite
        sprite      = { type = "string",   required = false },
        borders     = { type = "table",    required = false }, -- [left, top, right, bottom] or { left, top, right, bottom }
        sizing      = { type = "string",   required = false, enum = { "fit_content", "fixed", "stretch", "fit_sprite" } },
        tint        = { type = "string",   required = false },

        -- Structure
        children    = { type = "table",    required = false },
        containerType = { type = "string", required = false, enum = { "VERTICAL_CONTAINER", "HORIZONTAL_CONTAINER" } },

        -- Layout
        padding     = { type = "number",   required = false },
        align       = { type = "number",   required = false },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },
        maxWidth    = { type = "number",   required = false },
        maxHeight   = { type = "number",   required = false },

        -- Decorations
        decorations = { type = "table",    required = false },
        regions     = { type = "table",    required = false },

        -- Interaction
        hover       = { type = "boolean",  required = false },
        canCollide  = { type = "boolean",  required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_SPRITE_BOX = {
    _name = "UI_SPRITE_BOX",
    _fields = {
        -- Sprite config
        sprite      = { type = "table",    required = false }, -- { sprite, fixed, ... }

        -- Structure
        children    = { type = "table",    required = false },
        vertical    = { type = "boolean",  required = false },

        -- Layout
        padding     = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_CUSTOM_PANEL = {
    _name = "UI_CUSTOM_PANEL",
    _fields = {
        -- Callbacks
        onDraw      = { type = "function", required = false },
        onUpdate    = { type = "function", required = false },
        onInput     = { type = "function", required = false },

        -- Dimensions
        minWidth    = { type = "number",   required = false },
        minHeight   = { type = "number",   required = false },
        preferredWidth = { type = "number", required = false },
        preferredHeight = { type = "number", required = false },

        -- Interaction
        focusable   = { type = "boolean",  required = false },

        -- Config wrapper
        config      = { type = "table",    required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

--[[
COMPLEX COMPONENTS
These are composite components with internal state management.
]]

Schema.UI_TABS = {
    _name = "UI_TABS",
    _fields = {
        -- Tab definitions
        tabs        = { type = "table",    required = true }, -- Array of { id, label, content }
        activeTab   = { type = "string",   required = false },

        -- Tab bar styling
        tabBarPadding = { type = "number", required = false },
        tabBarAlign = { type = "number",   required = false },
        buttonColor = { type = "string",   required = false },
        activeButtonColor = { type = "string", required = false },
        buttonPadding = { type = "number", required = false },
        buttonMinWidth = { type = "number", required = false },
        buttonMinHeight = { type = "number", required = false },

        -- Content area styling
        contentPadding = { type = "number", required = false },
        contentColor = { type = "string",  required = false },
        contentMinWidth = { type = "number", required = false },
        contentMinHeight = { type = "number", required = false },

        -- Container styling
        containerPadding = { type = "number", required = false },
        containerColor = { type = "string", required = false },

        -- Text styling
        fontSize    = { type = "number",   required = false },
        textColor   = { type = "string",   required = false },
        emboss      = { type = "number",   required = false },

        -- Identity
        id          = { type = "string",   required = false },
    }
}

Schema.UI_INVENTORY_GRID = {
    _name = "UI_INVENTORY_GRID",
    _fields = {
        -- Grid dimensions
        rows        = { type = "number",   required = false },
        cols        = { type = "number",   required = false },
        slotSize    = { type = "table",    required = false }, -- { w, h }
        slotSpacing = { type = "number",   required = false },

        -- Callbacks
        onSlotChange = { type = "function", required = false },
        onSlotClick = { type = "function", required = false },
        onItemStack = { type = "function", required = false },

        -- Slot configuration
        slots       = { type = "table",    required = false }, -- Per-slot config
        config      = { type = "table",    required = false }, -- Grid-wide config

        -- Identity
        id          = { type = "string",   required = false },
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

    -- Check for unknown fields (typo detection with suggestions)
    for key, _ in pairs(data) do
        if not fields[key] then
            local suggestion = findBestMatch(key, fields, 0.5)
            if suggestion then
                table.insert(warnings, string.format(
                    "unknown field '%s' - did you mean '%s'?",
                    key, suggestion
                ))
            else
                table.insert(warnings, string.format("unknown field '%s'", key))
            end
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
