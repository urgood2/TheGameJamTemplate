--[[
================================================================================
STATS PANEL V2 - Single-Scroll Character Stats Sidebar
================================================================================
Replaces the tabbed stats panel with a streamlined single-scroll design:
- Shows all stats from both "Basic Stats" and "Detailed Stats" in one view
- Uses efficient caching with in-place element updates (no full rebuilds while visible)
- Clean, readable layout with full-width rows and section headers
- Grouped by category: Combat -> Resist -> Elements -> DoTs -> Utility

Usage:
    local StatsPanel = require("ui.stats_panel_v2")
    StatsPanel.toggle()  -- Toggle panel visibility
    StatsPanel.show()    -- Show panel
    StatsPanel.hide()    -- Hide panel
    StatsPanel.update(dt) -- Call in game loop

Dependencies:
    - ui.ui_syntax_sugar (DSL)
    - ui.player_stats_accessor
    - core.timer
    - core.component_cache
    - external.hump.signal
]]

local StatsPanel = {}

-- Check for reentrant load
if _G.__STATS_PANEL_V2__ then return _G.__STATS_PANEL_V2__ end

--------------------------------------------------------------------------------
-- Dependencies (lazy loaded to avoid circular requires)
--------------------------------------------------------------------------------
local component_cache = require("core.component_cache")
local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")
local signal = require("external.hump.signal")
local signal_group = require("core.signal_group")

local tooltip_registry = nil
local PlayerStatsAccessor = nil

local function ensureTooltipRegistry()
    if not tooltip_registry then
        local ok, tr = pcall(require, "core.tooltip_registry")
        if ok then tooltip_registry = tr end
    end
    return tooltip_registry
end

local function ensurePlayerStatsAccessor()
    if not PlayerStatsAccessor then
        local ok, psa = pcall(require, "ui.player_stats_accessor")
        if ok then PlayerStatsAccessor = psa end
    end
    return PlayerStatsAccessor
end

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local PANEL_WIDTH = 340
local PANEL_PADDING = 10
local SLIDE_DURATION = 0.3
local ROW_HEIGHT = 22
local ROW_FONT_SIZE = 13
local HEADER_FONT_SIZE = 14
local SECTION_HEADER_HEIGHT = 26

-- Section icons (emoji fallback if sprites not available)
local SECTION_ICONS = {
    combat = { sprite = "icon_sword", emoji = "crossed_swords" },
    resist = { sprite = "icon_shield", emoji = "shield" },
    elements = { sprite = "icon_lightning", emoji = "zap" },
    dots = { sprite = "icon_skull", emoji = "skull" },
    utility = { sprite = "icon_gear", emoji = "gear" },
}

-- Section definitions with stats per spec
local SECTIONS = {
    {
        id = "combat",
        label = "COMBAT",
        stats = {
            -- Primary attributes
            "physique",
            "cunning",
            "spirit",
            -- Core combat stats
            "offensive_ability",
            "damage",
            "all_damage_pct",
            "weapon_damage_pct",
            "crit_damage_pct",
            "life_steal_pct",
            "attack_speed",
            "cast_speed",
            "cooldown_reduction",
            "melee_damage_pct",
            "melee_crit_chance_pct",
            "penetration_all_pct",
            "armor_penetration_pct",
        }
    },
    {
        id = "resist",
        label = "RESIST",
        stats = {
            "defensive_ability",
            "armor",
            "dodge_chance_pct",
            "block_chance_pct",
            "block_amount",
            "block_recovery_reduction_pct",
            "percent_absorb_pct",
            "flat_absorb",
            "armor_absorption_bonus_pct",
            "damage_taken_reduction_pct",
            "reflect_damage_pct",
            "max_resist_cap_pct",
            "min_resist_cap_pct",
            "barrier_refresh_rate_pct",
        }
    },
    {
        id = "elements",
        label = "ELEMENTS",
        isGrid = true,  -- Special grid layout
    },
    {
        id = "dots",
        label = "DOTS",
        stats = {
            "burn_damage_pct",
            "burn_tick_rate_pct",
            "burn_duration_pct",
            "frostburn_duration_pct",
            "electrocute_duration_pct",
            "poison_duration_pct",
            "max_poison_stacks_pct",
            "vitality_decay_duration_pct",
            "bleed_duration_pct",
            "trauma_duration_pct",
            "damage_vs_frozen_pct",
        }
    },
    {
        id = "utility",
        label = "UTILITY",
        stats = {
            "run_speed",
            "move_speed_pct",
            "skill_energy_cost_reduction",
            "experience_gained_pct",
            "healing_received_pct",
            "health_pct",
            "health_regen",
            "buff_duration_pct",
            "buff_effect_pct",
            "summon_hp_pct",
            "summon_damage_pct",
            "summon_persistence",
            "hazard_radius_pct",
            "hazard_damage_pct",
            "hazard_duration",
            "chain_targets",
            "on_move_proc_frequency_pct",
        }
    },
}

-- Element types for grid
local ELEMENT_TYPES = {
    "fire", "cold", "lightning", "acid",
    "vitality", "aether", "chaos",
    "blood", "death",
    "physical", "pierce"
}

-- Element display config
local ELEMENT_CONFIG = {
    fire      = { color = "fire",     hasResist = true,  hasDuration = true },
    cold      = { color = "ice",      hasResist = true,  hasDuration = true },
    lightning = { color = "electric", hasResist = true,  hasDuration = true },
    acid      = { color = "poison",   hasResist = true,  hasDuration = true },
    vitality  = { color = "purple",   hasResist = true,  hasDuration = true },
    aether    = { color = "cyan",     hasResist = true,  hasDuration = true },
    chaos     = { color = "fiery_red",hasResist = true,  hasDuration = true },
    blood     = { color = "fiery_red",hasResist = true,  hasDuration = false },
    death     = { color = "purple",   hasResist = true,  hasDuration = false },
    physical  = { color = "gray",     hasResist = false, hasDuration = false },
    pierce    = { color = "gray",     hasResist = false, hasDuration = false },
}

--------------------------------------------------------------------------------
-- Color Palette
--------------------------------------------------------------------------------
local COLORS = nil

local function getColors()
    if COLORS then return COLORS end
    
    local FALLBACK_COLOR = Color and Color.new and Color.new(0, 0, 0, 255) or nil
    
    local function safeGetColor(name, fallbackName)
        if util and util.getColor then
            local ok, c = pcall(util.getColor, name)
            if ok and c and type(c) == "userdata" then return c end
            if fallbackName then
                local ok2, c2 = pcall(util.getColor, fallbackName)
                if ok2 and c2 and type(c2) == "userdata" then return c2 end
            end
        end
        return FALLBACK_COLOR
    end
    
    COLORS = {
        bg = safeGetColor("black"),
        header_bg = safeGetColor("dark_gray_slate", "black"),
        section_bg = safeGetColor("dark_gray_slate", "black"),
        row_bg = safeGetColor("black"),
        outline = safeGetColor("apricot_cream", "white"),
        positive = safeGetColor("mint_green", "green"),
        negative = safeGetColor("fiery_red", "red"),
        zero = safeGetColor("gray"),
        xp_bar_empty = safeGetColor("dark_gray_slate", "gray"),
        xp_bar_full = safeGetColor("gold", "yellow"),
    }
    
    return COLORS
end

--------------------------------------------------------------------------------
-- Panel State
--------------------------------------------------------------------------------
StatsPanel._state = {
    visible = false,
    slideProgress = 0,
    slideDirection = "idle",
    snapshot = nil,
    snapshotHash = nil,
    
    panelEntity = nil,
    signalHandlers = nil,  -- signal_group for cleanup
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function L(key, fallback)
    if localization and localization.get then
        local val = localization.get(key)
        if val and val ~= key then return val end
    end
    return fallback or key
end

local function getScreenSize()
    local w, h = 1920, 1080
    if globals then
        if globals.screenWidth then w = globals.screenWidth() end
        if globals.screenHeight then h = globals.screenHeight() end
    end
    return w, h
end

local function getStatDefs()
    return StatTooltipSystem and StatTooltipSystem.DEFS or {}
end

local function getStatLabel(statKey)
    if StatTooltipSystem and StatTooltipSystem.getLabel then
        local label = StatTooltipSystem.getLabel(statKey)
        if label and label ~= statKey then
            return label
        end
    end
    -- Fallback: convert snake_case to Title Case
    return statKey
        :gsub("_pct$", "")
        :gsub("_", " ")
        :gsub("(%a)([%w]*)", function(first, rest)
            return first:upper() .. rest
        end)
end

local function formatStatValue(statKey, value, snapshot)
    if StatTooltipSystem and StatTooltipSystem.formatValue then
        local formatted = StatTooltipSystem.formatValue(statKey, value, snapshot, false)
        if formatted then return formatted end
    end
    
    -- Fallback formatting
    if type(value) == "number" then
        if statKey:match("_pct$") then
            local sign = value > 0 and "+" or ""
            return string.format("%s%d%%", sign, math.floor(value + 0.5))
        else
            return tostring(math.floor(value + 0.5))
        end
    end
    return tostring(value or "-")
end

local function formatDelta(delta)
    if delta == nil or math.abs(delta) < 0.5 then
        return nil
    end
    local sign = delta > 0 and "+" or ""
    return string.format("(%s%d)", sign, math.floor(delta + 0.5))
end

local function getStatBaseValue(statKey)
    local psa = ensurePlayerStatsAccessor()
    if not psa then return nil end
    local raw = psa.get_raw(statKey)
    return raw and raw.base or nil
end

-- Returns color NAME for dsl.text()
local function getValueColor(value)
    if type(value) ~= "number" then return "white" end
    if value > 0 then return "mint_green" end
    if value < 0 then return "fiery_red" end
    return "gray"
end

local function buildStatTooltipBody(statKey, value, snapshot)
    local psa = ensurePlayerStatsAccessor()
    if not psa then return nil end
    
    local raw = psa.get_raw(statKey)
    if not raw then return nil end
    
    local lines = {}
    
    if raw.base and raw.base ~= 0 then
        table.insert(lines, string.format("Base: %d", math.floor(raw.base + 0.5)))
    end
    
    if raw.add_pct and math.abs(raw.add_pct) > 0.01 then
        local sign = raw.add_pct > 0 and "+" or ""
        table.insert(lines, string.format("Additive: %s%d%%", sign, math.floor(raw.add_pct + 0.5)))
    end
    
    if raw.mul_pct and math.abs(raw.mul_pct) > 0.01 then
        local sign = raw.mul_pct > 0 and "+" or ""
        table.insert(lines, string.format("Multiplier: %s%d%%", sign, math.floor(raw.mul_pct + 0.5)))
    end
    
    if value and type(value) == "number" then
        table.insert(lines, string.format("Current: %d", math.floor(value + 0.5)))
    end
    
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Snapshot Collection
--------------------------------------------------------------------------------
function StatsPanel._collectSnapshot()
    local psa = ensurePlayerStatsAccessor()
    if not psa then
        log_debug("[StatsPanelV2] _collectSnapshot: PlayerStatsAccessor not available")
        return nil
    end
    
    local player = psa.get_player()
    if not player then
        log_debug("[StatsPanelV2] _collectSnapshot: No player")
        return nil
    end
    
    local stats = psa.get_stats()
    if not stats then
        log_debug("[StatsPanelV2] _collectSnapshot: No stats")
        return nil
    end
    
    local snapshot = {
        level = player.level or 1,
        hp = player.hp or stats:get('health') or 0,
        max_hp = player.max_health or stats:get('health') or 0,
        xp = player.xp or 0,
        xp_to_next = player.xp_to_next or 100,
    }
    
    -- Collect all stats from DEFS
    local defs = getStatDefs()
    for key, def in pairs(defs) do
        if def.keys then
            for _, subKey in ipairs(def.keys) do
                if not snapshot[subKey] then
                    snapshot[subKey] = stats:get(subKey) or 0
                end
            end
        else
            snapshot[key] = stats:get(key) or 0
        end
    end
    
    -- Per-element data for grid
    local perType = {}
    if CombatSystem and CombatSystem.Core and CombatSystem.Core.DAMAGE_TYPES then
        for _, dt in ipairs(CombatSystem.Core.DAMAGE_TYPES) do
            perType[dt] = {
                resist = stats:get(dt .. "_resist_pct") or 0,
                damage = stats:get(dt .. "_modifier_pct") or 0,
                duration = stats:get(dt .. "_duration_pct") or 0,
            }
        end
    else
        -- Fallback
        for _, dt in ipairs(ELEMENT_TYPES) do
            perType[dt] = {
                resist = stats:get(dt .. "_resist_pct") or 0,
                damage = stats:get(dt .. "_modifier_pct") or 0,
                duration = stats:get(dt .. "_duration_pct") or 0,
            }
        end
    end
    snapshot.per_type = perType
    
    return snapshot
end

function StatsPanel._computeSnapshotHash(snapshot)
    if not snapshot then return "nil" end
    local parts = {}
    for k, v in pairs(snapshot) do
        if k ~= "per_type" then
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

--------------------------------------------------------------------------------
-- Easing Functions
--------------------------------------------------------------------------------
local function easeOutQuad(t)
    return t * (2 - t)
end

--------------------------------------------------------------------------------
-- UI Component Builders
--------------------------------------------------------------------------------

-- Build header with title, level, and XP bar
local function buildHeader(snapshot)
    local level = snapshot and snapshot.level or 1
    local xp = snapshot and snapshot.xp or 0
    local xpToNext = snapshot and snapshot.xp_to_next or 100
    local xpRatio = xpToNext > 0 and (xp / xpToNext) or 0
    
    local titleRow = dsl.hbox {
        config = {
            padding = 0,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.text(L("stats_panel.title", "Character Stats"), {
                fontSize = 16,
                color = "apricot_cream",
                shadow = true,
            }),
            dsl.spacer(10),
            dsl.text(string.format("Lv.%d", level), {
                id = "header_level",
                fontSize = 14,
                color = "gold",
                shadow = true,
            }),
        }
    }
    
    local xpBar = dsl.progressBar({
        id = "header_xp_bar",
        getValue = function() 
            local s = StatsPanel._state.snapshot
            if not s then return 0 end
            return s.xp_to_next > 0 and (s.xp / s.xp_to_next) or 0
        end,
        emptyColor = "dark_gray_slate",
        fullColor = "gold",
        minWidth = PANEL_WIDTH - 40,
        minHeight = 8,
    })
    
    local xpText = dsl.text(string.format("%d / %d XP", xp, xpToNext), {
        id = "header_xp_text",
        fontSize = 10,
        color = "gray",
    })
    
    return dsl.vbox {
        config = {
            id = "stats_panel_header",
            padding = 8,
            color = getColors().header_bg,
        },
        children = {
            titleRow,
            dsl.spacer(4),
            xpBar,
            dsl.spacer(2),
            xpText,
        }
    }
end

-- Build section header with icon
local function buildSectionHeader(sectionDef)
    local iconConfig = SECTION_ICONS[sectionDef.id]
    local iconText = iconConfig and iconConfig.emoji or "bullet"
    
    -- Try to use emoji via localization if available
    local displayIcon = localization and localization.get("emoji." .. iconText) or iconText
    
    return dsl.hbox {
        config = {
            padding = 6,
            color = getColors().section_bg,
            minHeight = SECTION_HEADER_HEIGHT,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.text(displayIcon .. " " .. sectionDef.label, {
                fontSize = HEADER_FONT_SIZE,
                color = "apricot_cream",
                shadow = true,
            }),
        }
    }
end

-- Build full-width stat row (label left, value right)
local function buildStatRow(statKey, snapshot)
    local defs = getStatDefs()
    local def = defs[statKey]
    
    local value
    if def and def.keys then
        value = snapshot[def.keys[1]]
    else
        value = snapshot[statKey]
    end
    
    if value == nil then value = 0 end
    
    local label = getStatLabel(statKey)
    local formatted = formatStatValue(statKey, value, snapshot)
    local valueColor = getValueColor(value)
    
    -- Build delta display
    local deltaChildren = {}
    local baseValue = getStatBaseValue(statKey)
    if baseValue and type(baseValue) == "number" and type(value) == "number" then
        local delta = value - baseValue
        local deltaStr = formatDelta(delta)
        if deltaStr then
            local deltaColor = delta > 0 and "mint_green" or "fiery_red"
            table.insert(deltaChildren, dsl.text(deltaStr, {
                id = "stat_delta_" .. statKey,
                fontSize = ROW_FONT_SIZE - 2,
                color = deltaColor,
            }))
        end
    end
    
    local tooltipBody = buildStatTooltipBody(statKey, value, snapshot)
    
    return dsl.hbox {
        config = {
            id = "stat_row_" .. statKey,
            padding = 4,
            minHeight = ROW_HEIGHT,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            hover = false,
            tooltip = nil,
        },
        children = {
            -- Label (left-aligned)
            dsl.text(label, {
                fontSize = ROW_FONT_SIZE,
                color = "white",
            }),
            -- Spacer to push value right
            dsl.hbox {
                config = {
                    padding = 0,
                    minWidth = 1,  -- Flex spacer
                    align = AlignmentFlag.HORIZONTAL_RIGHT,
                },
                children = {}
            },
            -- Value + Delta (right side)
            dsl.hbox {
                config = {
                    padding = 0,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_CENTER),
                },
                children = {
                    dsl.text(formatted, {
                        id = "stat_value_" .. statKey,
                        fontSize = ROW_FONT_SIZE,
                        color = valueColor,
                    }),
                    #deltaChildren > 0 and dsl.spacer(4) or nil,
                    #deltaChildren > 0 and deltaChildren[1] or nil,
                }
            },
        }
    }
end

-- Build elemental grid section
local function buildElementalGrid(snapshot)
    local perType = snapshot and snapshot.per_type or {}
    
    local COL_WIDTH = 55
    local ELEM_COL_WIDTH = 70
    
    -- Header row
    local headerRow = dsl.hbox {
        config = {
            padding = 2,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.text("Element", { fontSize = 10, color = "gray", minWidth = ELEM_COL_WIDTH }),
            dsl.text("Resist", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
            dsl.text("Damage", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
            dsl.text("Duration", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
        }
    }
    
    local rows = { headerRow }
    
    for _, elemType in ipairs(ELEMENT_TYPES) do
        local config = ELEMENT_CONFIG[elemType]
        local data = perType[elemType] or { resist = 0, damage = 0, duration = 0 }
        
        local displayName = elemType:sub(1,1):upper() .. elemType:sub(2)
        
        local function formatGridValue(val, available)
            if not available then return "--" end
            if val == nil or math.abs(val) < 0.01 then return "0%" end
            local sign = val > 0 and "+" or ""
            return string.format("%s%d%%", sign, math.floor(val + 0.5))
        end
        
        local function getGridColor(val, available)
            if not available then return "gray" end
            if val == nil or math.abs(val) < 0.01 then return "gray" end
            return val > 0 and "mint_green" or "fiery_red"
        end
        
        table.insert(rows, dsl.hbox {
            config = {
                id = "elem_row_" .. elemType,
                padding = 2,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            },
            children = {
                dsl.text(displayName, {
                    fontSize = ROW_FONT_SIZE - 1,
                    color = config.color,
                    minWidth = ELEM_COL_WIDTH,
                }),
                dsl.text(formatGridValue(data.resist, config.hasResist), {
                    id = "elem_" .. elemType .. "_resist",
                    fontSize = ROW_FONT_SIZE - 1,
                    color = getGridColor(data.resist, config.hasResist),
                    minWidth = COL_WIDTH,
                }),
                dsl.text(formatGridValue(data.damage, true), {
                    id = "elem_" .. elemType .. "_damage",
                    fontSize = ROW_FONT_SIZE - 1,
                    color = getGridColor(data.damage, true),
                    minWidth = COL_WIDTH,
                }),
                dsl.text(formatGridValue(data.duration, config.hasDuration), {
                    id = "elem_" .. elemType .. "_duration",
                    fontSize = ROW_FONT_SIZE - 1,
                    color = getGridColor(data.duration, config.hasDuration),
                    minWidth = COL_WIDTH,
                }),
            }
        })
    end
    
    return dsl.vbox {
        config = {
            padding = 4,
        },
        children = rows,
    }
end

-- Build a complete section
local function buildSection(sectionDef, snapshot)
    local children = {
        buildSectionHeader(sectionDef),
    }
    
    if sectionDef.isGrid then
        -- Special grid layout for elements
        table.insert(children, buildElementalGrid(snapshot))
    else
        -- Standard stat rows
        local statRows = {}
        for _, statKey in ipairs(sectionDef.stats or {}) do
            local row = buildStatRow(statKey, snapshot)
            if row then
                table.insert(statRows, row)
            end
        end
        
        if #statRows > 0 then
            table.insert(children, dsl.vbox {
                config = { padding = 4 },
                children = statRows,
            })
        end
    end
    
    return dsl.vbox {
        config = {
            id = "section_" .. sectionDef.id,
            padding = 0,
        },
        children = children,
    }
end

-- Build footer with keyboard hints
local function buildFooter()
    return dsl.hbox {
        config = {
            padding = 6,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.text("C: toggle   1-5: tabs   Esc: close", {
                fontSize = 9,
                color = "gray",
            }),
        }
    }
end

-- Build scroll pane
local function createScrollPane(children, opts)
    opts = opts or {}
    local _, screenH = getScreenSize()
    local height = opts.height or math.floor(screenH * 0.6)
    local width = PANEL_WIDTH - (PANEL_PADDING * 2) - 8
    
    return ui.definitions.def {
        type = "SCROLL_PANE",
        config = {
            id = opts.id or "stats_panel_scroll",
            maxHeight = height,
            height = height,
            maxWidth = width,
            width = width,
            padding = 4,
            color = getColors().bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = children,
    }
end

-- Build section content for a single tab
local function buildSectionContent(sectionDef, snapshot)
    if sectionDef.isGrid then
        return buildElementalGrid(snapshot)
    end
    
    local statRows = {}
    for _, statKey in ipairs(sectionDef.stats or {}) do
        local row = buildStatRow(statKey, snapshot)
        if row then
            table.insert(statRows, row)
        end
    end
    
    if #statRows == 0 then
        return dsl.text("No stats available", { fontSize = 11, color = "gray" })
    end
    
    return dsl.vbox {
        config = { padding = 4 },
        children = statRows,
    }
end

-- Build complete panel with tabs
local function buildPanelDefinition(snapshot)
    local _, screenH = getScreenSize()
    local scrollHeight = math.floor(screenH * 0.55)
    
    local tabDefs = {}
    for _, sectionDef in ipairs(SECTIONS) do
        table.insert(tabDefs, {
            id = sectionDef.id,
            label = sectionDef.label,
            content = function()
                local content = buildSectionContent(sectionDef, StatsPanel._state.snapshot or snapshot)
                local scrollContent = dsl.vbox {
                    config = { padding = 0 },
                    children = { content }
                }
                return createScrollPane({ scrollContent }, {
                    id = "stats_panel_scroll",
                    height = scrollHeight,
                })
            end
        })
    end
    
    local tabContainer = dsl.tabs {
        id = "stats_panel_tabs",
        tabs = tabDefs,
        activeTab = "combat",
        buttonColor = "dark_gray_slate",
        activeButtonColor = "gray",
        contentPadding = 0,
        tabBarPadding = 4,
        fontSize = 13,
        buttonPadding = 6,
        contentMinHeight = scrollHeight + 20,
    }
    
    return dsl.root {
        config = {
            id = "stats_panel_v2_root",
            color = getColors().bg,
            padding = PANEL_PADDING,
            outlineThickness = 2,
            outlineColor = getColors().outline,
            minWidth = PANEL_WIDTH,
            shadow = true,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            dsl.vbox {
                config = { padding = 0 },
                children = {
                    buildHeader(snapshot),
                    dsl.spacer(4),
                    tabContainer,
                    dsl.spacer(4),
                    buildFooter(),
                }
            }
        }
    }
end

--------------------------------------------------------------------------------
-- In-Place Update System
--------------------------------------------------------------------------------

function StatsPanel._updateStatValue(statKey, newValue, snapshot)
    local state = StatsPanel._state
    if not state.panelEntity then return end
    if not entity_cache or not entity_cache.valid(state.panelEntity) then return end
    
    local valueId = "stat_value_" .. statKey
    local valueEntity = ui.box.GetUIEByID(registry, state.panelEntity, valueId)
    if valueEntity and entity_cache.valid(valueEntity) then
        local formatted = formatStatValue(statKey, newValue, snapshot)
        local uiText = component_cache.get(valueEntity, UITextComponent)
        if uiText then
            uiText.text = formatted
            local colorName = getValueColor(newValue)
            if util and util.getColor then
                local ok, c = pcall(util.getColor, colorName)
                if ok and c then uiText.color = c end
            end
        end
    end
    
    local deltaId = "stat_delta_" .. statKey
    local deltaEntity = ui.box.GetUIEByID(registry, state.panelEntity, deltaId)
    if deltaEntity and entity_cache.valid(deltaEntity) then
        local baseValue = getStatBaseValue(statKey)
        local delta = baseValue and type(newValue) == "number" and (newValue - baseValue) or nil
        local deltaStr = formatDelta(delta)
        local uiText = component_cache.get(deltaEntity, UITextComponent)
        if uiText then
            uiText.text = deltaStr or ""
            if delta then
                local colorName = delta > 0 and "mint_green" or "fiery_red"
                if util and util.getColor then
                    local ok, c = pcall(util.getColor, colorName)
                    if ok and c then uiText.color = c end
                end
            end
        end
    end
end

function StatsPanel._updateElementalGrid(newPerType, oldPerType)
    local state = StatsPanel._state
    if not state.panelEntity then return end
    if not entity_cache or not entity_cache.valid(state.panelEntity) then return end
    
    for _, elemType in ipairs(ELEMENT_TYPES) do
        local newData = newPerType and newPerType[elemType] or { resist = 0, damage = 0, duration = 0 }
        local oldData = oldPerType and oldPerType[elemType] or { resist = 0, damage = 0, duration = 0 }
        
        local config = ELEMENT_CONFIG[elemType]
        
        local function updateCell(column, newVal, oldVal, available)
            if newVal == oldVal then return end
            
            local cellId = "elem_" .. elemType .. "_" .. column
            local cellEntity = ui.box.GetUIEByID(registry, state.panelEntity, cellId)
            if cellEntity and entity_cache.valid(cellEntity) then
                local uiText = component_cache.get(cellEntity, UITextComponent)
                if uiText then
                    if not available then
                        uiText.text = "--"
                    elseif newVal == nil or math.abs(newVal) < 0.01 then
                        uiText.text = "0%"
                    else
                        local sign = newVal > 0 and "+" or ""
                        uiText.text = string.format("%s%d%%", sign, math.floor(newVal + 0.5))
                    end
                    
                    local colorName = "gray"
                    if available and newVal and math.abs(newVal) >= 0.01 then
                        colorName = newVal > 0 and "mint_green" or "fiery_red"
                    end
                    if util and util.getColor then
                        local ok, c = pcall(util.getColor, colorName)
                        if ok and c then uiText.color = c end
                    end
                end
            end
        end
        
        updateCell("resist", newData.resist, oldData.resist, config.hasResist)
        updateCell("damage", newData.damage, oldData.damage, true)
        updateCell("duration", newData.duration, oldData.duration, config.hasDuration)
    end
end

function StatsPanel._updateHeader(snapshot)
    local state = StatsPanel._state
    if not state.panelEntity then return end
    
    local levelEntity = ui.box.GetUIEByID(registry, state.panelEntity, "header_level")
    if levelEntity and entity_cache.valid(levelEntity) then
        local uiText = component_cache.get(levelEntity, UITextComponent)
        if uiText then
            uiText.text = string.format("Lv.%d", snapshot.level or 1)
        end
    end
    
    local xpTextEntity = ui.box.GetUIEByID(registry, state.panelEntity, "header_xp_text")
    if xpTextEntity and entity_cache.valid(xpTextEntity) then
        local uiText = component_cache.get(xpTextEntity, UITextComponent)
        if uiText then
            local xp = snapshot.xp or 0
            local xpToNext = snapshot.xp_to_next or 100
            uiText.text = string.format("%d / %d XP", xp, xpToNext)
        end
    end
    
    -- XP bar updates automatically via getValue callback
end

function StatsPanel._onStatsChanged(payload)
    local state = StatsPanel._state
    if not state.visible then return end
    if not state.panelEntity then return end
    
    local newSnapshot = StatsPanel._collectSnapshot()
    if not newSnapshot then return end
    
    local oldSnapshot = state.snapshot
    
    for statKey, newValue in pairs(newSnapshot) do
        if statKey ~= "per_type" and statKey ~= "xp" and statKey ~= "xp_to_next" and statKey ~= "level" then
            local oldValue = oldSnapshot and oldSnapshot[statKey]
            if oldValue ~= newValue then
                StatsPanel._updateStatValue(statKey, newValue, newSnapshot)
            end
        end
    end
    
    if newSnapshot.per_type then
        StatsPanel._updateElementalGrid(newSnapshot.per_type, oldSnapshot and oldSnapshot.per_type)
    end
    
    local headerChanged = not oldSnapshot or
        newSnapshot.level ~= oldSnapshot.level or
        newSnapshot.xp ~= oldSnapshot.xp or
        newSnapshot.xp_to_next ~= oldSnapshot.xp_to_next
    if headerChanged then
        StatsPanel._updateHeader(newSnapshot)
    end
    
    state.snapshot = newSnapshot
    state.snapshotHash = StatsPanel._computeSnapshotHash(newSnapshot)
end

--------------------------------------------------------------------------------
-- Animation & Position
--------------------------------------------------------------------------------
local function getPanelX(progress)
    local screenW, _ = getScreenSize()
    local hiddenX = screenW + 20
    local visibleX = screenW - PANEL_WIDTH - 20
    
    local easedProgress = easeOutQuad(progress)
    return hiddenX + (visibleX - hiddenX) * easedProgress
end

function StatsPanel._updatePosition()
    local state = StatsPanel._state
    if not state.panelEntity then return end
    if not entity_cache or not entity_cache.valid(state.panelEntity) then return end
    
    local t = component_cache.get(state.panelEntity, Transform)
    if not t then return end
    
    local x = getPanelX(state.slideProgress)
    local y = 60
    
    t.actualX = x
    t.actualY = y
    t.visualX = x
    t.visualY = y
end

--------------------------------------------------------------------------------
-- Panel Lifecycle
--------------------------------------------------------------------------------
function StatsPanel._createPanel()
    log_debug("[StatsPanelV2] _createPanel called")
    local state = StatsPanel._state
    
    -- Destroy existing
    if state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity) then
        registry:destroy(state.panelEntity)
    end
    
    local snapshot = state.snapshot
    if not snapshot then
        snapshot = StatsPanel._collectSnapshot()
        state.snapshot = snapshot
        state.snapshotHash = StatsPanel._computeSnapshotHash(snapshot)
    end
    
    if not snapshot then
        log_debug("[StatsPanelV2] No snapshot available")
        return
    end
    
    local ok, def = pcall(buildPanelDefinition, snapshot)
    if not ok then
        log_debug("[StatsPanelV2] buildPanelDefinition failed: " .. tostring(def))
        return
    end
    
    local screenW, _ = getScreenSize()
    
    local spawnOk, entity = pcall(function()
        return dsl.spawn({ x = screenW + 50, y = 60 }, def, "ui")
    end)
    if not spawnOk then
        log_debug("[StatsPanelV2] dsl.spawn failed: " .. tostring(entity))
        return
    end
    
    log_debug("[StatsPanelV2] spawned entity=" .. tostring(entity))
    
    -- Set screen space
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end
    
    -- Set z-order
    local zOrder = z_orders and z_orders.ui_tooltips and (z_orders.ui_tooltips + 10) or 10000
    if layer_order_system and layer_order_system.assignZIndexToEntity then
        layer_order_system.assignZIndexToEntity(entity, zOrder)
    end
    
    -- Set draw layer
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(entity, "ui")
    end
    
    -- Add state tags
    if ui and ui.box then
        ui.box.ClearStateTagsFromUIBox(entity)
        if PLANNING_STATE then ui.box.AddStateTagToUIBox(entity, PLANNING_STATE) end
        if ACTION_STATE then ui.box.AddStateTagToUIBox(entity, ACTION_STATE) end
        if SHOP_STATE then ui.box.AddStateTagToUIBox(entity, SHOP_STATE) end
        if STATS_PANEL_STATE then ui.box.AddStateTagToUIBox(entity, STATS_PANEL_STATE) end
    end
    
    state.panelEntity = entity
    StatsPanel._updatePosition()
end

function StatsPanel._destroyPanel()
    local state = StatsPanel._state
    
    timer.kill_group("stats_panel_v2")
    dsl.cleanupTabs("stats_panel_tabs")
    
    if state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity) then
        registry:destroy(state.panelEntity)
    end
    state.panelEntity = nil
    state.snapshot = nil
    state.snapshotHash = nil
end

local SIGNAL_DEBOUNCE_DELAY = 0.05

function StatsPanel._registerSignalHandler()
    local state = StatsPanel._state
    
    if state.signalHandlers then
        state.signalHandlers:cleanup()
    end
    
    state.signalHandlers = signal_group.new("stats_panel_v2")
    
    state.signalHandlers:on("stats_recomputed", function(payload)
        timer.cancel("stats_panel_v2_debounce")
        timer.after_opts({
            delay = SIGNAL_DEBOUNCE_DELAY,
            tag = "stats_panel_v2_debounce",
            group = "stats_panel_v2",
            action = function()
                local ok, err = pcall(StatsPanel._onStatsChanged, payload)
                if not ok then
                    log_debug("[StatsPanelV2] ERROR in _onStatsChanged: " .. tostring(err))
                end
            end
        })
    end)
end

function StatsPanel._unregisterSignalHandler()
    local state = StatsPanel._state
    if state.signalHandlers then
        state.signalHandlers:cleanup()
        state.signalHandlers = nil
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function StatsPanel.show()
    log_debug("[StatsPanelV2] show() called")
    local state = StatsPanel._state
    if state.visible and state.slideDirection ~= "exiting" then
        log_debug("[StatsPanelV2] Already visible")
        return
    end

    state.visible = true
    state.slideDirection = "idle"  -- Snap to full size (no animation)
    state.slideProgress = 1        -- Start at full size

    state.snapshot = StatsPanel._collectSnapshot()
    state.snapshotHash = StatsPanel._computeSnapshotHash(state.snapshot)

    StatsPanel._createPanel()
    StatsPanel._registerSignalHandler()

    if activate_state and STATS_PANEL_STATE then
        activate_state(STATS_PANEL_STATE)
    end
end

function StatsPanel.hide()
    local state = StatsPanel._state
    if not state.visible or state.slideDirection == "exiting" then return end

    -- Snap closed immediately (no animation)
    state.slideDirection = "idle"
    state.slideProgress = 0
    state.visible = false

    StatsPanel._unregisterSignalHandler()
    StatsPanel._destroyPanel()

    if deactivate_state and STATS_PANEL_STATE then
        deactivate_state(STATS_PANEL_STATE)
    end
end

function StatsPanel.toggle()
    log_debug("[StatsPanelV2] toggle() called, visible=" .. tostring(StatsPanel.isVisible()))
    if StatsPanel.isVisible() then
        StatsPanel.hide()
    else
        StatsPanel.show()
    end
end

function StatsPanel.isVisible()
    local state = StatsPanel._state
    return state.visible and state.slideDirection ~= "exiting"
end

function StatsPanel.rebuild()
    if not StatsPanel._state.visible then return end
    StatsPanel._createPanel()
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------
local _debugUpdateCounter = 0
local _lastHeartbeat = 0
function StatsPanel.update(dt)
    local state = StatsPanel._state
    
    _debugUpdateCounter = _debugUpdateCounter + 1
    
    local now = os.clock()
    if now - _lastHeartbeat > 2.0 then
        _lastHeartbeat = now
        log_debug(string.format("[StatsPanelV2] HEARTBEAT: tick=%d, visible=%s, entity=%s, valid=%s",
            _debugUpdateCounter,
            tostring(state.visible),
            tostring(state.panelEntity),
            tostring(state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity))))
        
        if state.visible and state.panelEntity then
            local ok, err = pcall(StatsPanel.debugState)
            if not ok then
                log_debug("[StatsPanelV2] DEBUG ERROR: " .. tostring(err))
            end
        end
    end
    
    if state.slideDirection == "entering" then
        state.slideProgress = math.min(1, state.slideProgress + dt / SLIDE_DURATION)
        if state.slideProgress >= 1 then
            state.slideDirection = "idle"
            state.slideProgress = 1
        end
        StatsPanel._updatePosition()
        
    elseif state.slideDirection == "exiting" then
        local exitDuration = SLIDE_DURATION * 0.8
        state.slideProgress = math.max(0, state.slideProgress - dt / exitDuration)
        if state.slideProgress <= 0 then
            state.slideDirection = "idle"
            state.slideProgress = 0
            state.visible = false
            StatsPanel._destroyPanel()
        else
            StatsPanel._updatePosition()
        end
    end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------
local _debugInputCounter = 0
function StatsPanel.handleInput()
    if not input then return end
    
    local state = StatsPanel._state
    
    _debugInputCounter = _debugInputCounter + 1
    if _debugInputCounter % 60 == 0 then
        log_debug(string.format("[StatsPanelV2] handleInput tick #%d: visible=%s",
            _debugInputCounter, tostring(state.visible)))
    end
    
    if input.action_pressed and input.action_pressed("toggle_stats_panel") then
        log_debug("[StatsPanelV2] toggle_stats_panel action pressed!")
        StatsPanel.toggle()
        return true
    end
    
    if not StatsPanel.isVisible() then return false end
    
    if input.action_pressed and input.action_pressed("stats_panel_close") then
        StatsPanel.hide()
        return true
    end
    
    if input.key_pressed and (input.key_pressed(KEY_ESCAPE) or input.key_pressed(256)) then
        StatsPanel.hide()
        return true
    end
    
    for i = 1, #SECTIONS do
        if input.action_pressed and input.action_pressed("stats_panel_tab_" .. i) then
            local sectionId = SECTIONS[i].id
            dsl.switchTab("stats_panel_tabs", sectionId)
            return true
        end
    end
    
    return false
end

function StatsPanel.debugState()
    local state = StatsPanel._state
    log_debug(string.format("[StatsPanelV2] DEBUG: visible=%s, slideDirection=%s, panelEntity=%s, valid=%s",
        tostring(state.visible),
        tostring(state.slideDirection),
        tostring(state.panelEntity),
        tostring(state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity))))
    
    if state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity) then
        local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
        if scrollPane then
            local scrollValid = entity_cache.valid(scrollPane)
            log_debug(string.format("[StatsPanelV2] DEBUG: scrollPane=%s, valid=%s",
                tostring(scrollPane), tostring(scrollValid)))
            
            if scrollValid then
                local go = component_cache.get(scrollPane, GameObject)
                if go then
                    log_debug(string.format("[StatsPanelV2] DEBUG: scroll collision=%s, hovering=%s",
                        tostring(go.state.collisionEnabled),
                        tostring(go.state.isBeingHovered)))
                end
                
                local t = component_cache.get(scrollPane, Transform)
                if t then
                    log_debug(string.format("[StatsPanelV2] DEBUG: scroll pos=(%.0f,%.0f) size=(%.0f,%.0f)",
                        t.actualX or 0, t.actualY or 0, t.actualW or 0, t.actualH or 0))
                end
            end
        else
            log_debug("[StatsPanelV2] DEBUG: No scroll pane found!")
        end
    end
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
function StatsPanel.init()
    StatsPanel._state = {
        visible = false,
        slideProgress = 0,
        slideDirection = "idle",
        snapshot = nil,
        snapshotHash = nil,
        panelEntity = nil,
        signalHandlers = nil,
    }
end

-- Initialize on load
StatsPanel.init()

_G.__STATS_PANEL_V2__ = StatsPanel
return StatsPanel
