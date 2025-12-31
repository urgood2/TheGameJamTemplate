--[[
================================================================================
SYNERGY ICONS - Icon configuration for tag synergy grid panel
================================================================================
Maps synergy tags to their visual representation.
Uses tile131.png as placeholder with color tinting until real art is available.

To replace with real art later:
    Fire = { sprite = "fire_synergy_icon.png", tint = false },

The 'tint' field controls whether the sprite should be tinted with the synergy
color. Set to false when using pre-colored art assets.
================================================================================
]]

local SynergyIcons = {
    -- Elemental synergies
    Fire = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "fiery_red",
        order = 1,
    },
    Ice = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "baby_blue",
        order = 2,
    },
    Poison = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "moss_green",
        order = 7,
    },

    -- Buff/utility synergies
    Buff = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "mint_green",
        order = 3,
    },
    Arcane = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "purple",
        order = 4,
    },

    -- Movement/positioning synergies
    Mobility = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "teal_blue",
        order = 5,
    },

    -- Defensive synergies
    Defense = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "plum",
        order = 6,
    },

    -- Summoner/hazard synergies
    Summon = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "apricot",
        order = 8,
    },
    Hazard = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "orange",
        order = 9,
    },

    -- Physical synergies
    Brute = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "fiery_red",  -- Same as Fire for now
        order = 10,
    },
    Fatty = {
        sprite = "tile131.png",
        tint = true,
        colorKey = "marigold",
        order = 11,
    },
}

-- Grid layout order (3 columns × 4 rows)
-- This defines which synergies appear where in the grid
SynergyIcons.GRID_ORDER = {
    -- Row 1
    "Fire", "Ice", "Buff",
    -- Row 2
    "Arcane", "Mobility", "Defense",
    -- Row 3
    "Poison", "Summon", "Hazard",
    -- Row 4
    "Brute", "Fatty", nil,  -- Last cell empty
}

-- Get ordered list of synergy tags for grid rendering
function SynergyIcons.getGridOrder()
    return SynergyIcons.GRID_ORDER
end

-- Get icon config for a specific tag
function SynergyIcons.getConfig(tag)
    return SynergyIcons[tag]
end

-- Get all configured tags
function SynergyIcons.getAllTags()
    local tags = {}
    for tag, config in pairs(SynergyIcons) do
        if type(config) == "table" and config.sprite then
            tags[#tags + 1] = tag
        end
    end
    table.sort(tags, function(a, b)
        local orderA = SynergyIcons[a] and SynergyIcons[a].order or 999
        local orderB = SynergyIcons[b] and SynergyIcons[b].order or 999
        return orderA < orderB
    end)
    return tags
end

return SynergyIcons
