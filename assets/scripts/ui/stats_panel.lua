--[[
================================================================================
STATS PANEL - Unified Character Stats Sidebar
================================================================================
Replaces the old two-popup system (Basic + Detailed tooltips) with a single
docked sidebar panel featuring:
- Slay the Spire-inspired compact stat pills
- Tiered stat visibility (Tier 1 always visible, collapsible sections)
- 5 tabs: Combat, Resist, Mods, DoTs, Utility
- Slide in/out animation (300ms ease-out)
- Keyboard controls: 'C' toggle, Tab cycle, Esc close, 1-5 jump to tab

Usage:
    local StatsPanel = require("ui.stats_panel")
    StatsPanel.toggle()  -- Toggle panel visibility
    StatsPanel.show()    -- Show panel
    StatsPanel.hide()    -- Hide panel
    StatsPanel.update(dt) -- Call in game loop

Dependencies:
    - ui.ui_syntax_sugar (DSL)
    - ui.player_stats_accessor
    - core.timer
    - core.component_cache
]]

local StatsPanel = {}

-- Check for reentrant load
if _G.__STATS_PANEL__ then return _G.__STATS_PANEL__ end

--------------------------------------------------------------------------------
-- Dependencies (lazy loaded to avoid circular requires)
--------------------------------------------------------------------------------
local component_cache = require("core.component_cache")
local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")
local PlayerStatsAccessor = nil  -- lazy load

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
local PANEL_WIDTH = 320
local PANEL_PADDING = 10
local SLIDE_DURATION = 0.3  -- 300ms
local TAB_COUNT = 5
local PILL_HEIGHT = 22
local PILL_FONT_SIZE = 14
local HEADER_FONT_SIZE = 12
local TAB_HEIGHT = 28
local TAB_WIDTH = 58

-- Tab definitions
local TABS = {
    { id = "combat",  label = "Combat" },
    { id = "resist",  label = "Resist" },
    { id = "mods",    label = "Mods" },
    { id = "dots",    label = "DoTs" },
    { id = "utility", label = "Utility" },
}

-- Tier 1 stats (always visible at top)
local TIER1_STATS = {
    "level", "health",
    "physique", "cunning", "spirit",
    "damage", "attack_speed", "crit_damage_pct",
    "armor", "dodge_chance_pct"
}

-- Tab-specific stats layout
local TAB_LAYOUTS = {
    combat = {
        { header = "Offense", stats = {
            "all_damage_pct", "weapon_damage_pct", "life_steal_pct",
            "cooldown_reduction", "cast_speed", "offensive_ability"
        }},
        { header = "Melee", stats = {
            "melee_damage_pct", "melee_crit_chance_pct"
        }},
    },
    resist = {
        { header = "Defense", stats = {
            "defensive_ability", "block_chance_pct", "block_amount",
            "percent_absorb_pct", "flat_absorb", "armor_absorption_bonus_pct"
        }},
        { header = "Damage Reduction", stats = {
            "damage_taken_reduction_pct", "max_resist_cap_pct"
        }},
        -- Dynamic: per-element resists added at build time
    },
    mods = {
        { header = "Elemental Damage", stats = {
            "fire_modifier_pct", "cold_modifier_pct", "lightning_modifier_pct",
            "acid_modifier_pct", "vitality_modifier_pct", "aether_modifier_pct", "chaos_modifier_pct"
        }},
        { header = "Physical Damage", stats = {
            "physical_modifier_pct", "pierce_modifier_pct", "penetration_all_pct", "armor_penetration_pct"
        }},
    },
    dots = {
        { header = "Duration Modifiers", stats = {
            "burn_duration_pct", "frostburn_duration_pct", "electrocute_duration_pct",
            "poison_duration_pct", "vitality_decay_duration_pct", "bleed_duration_pct", "trauma_duration_pct"
        }},
        { header = "Burn Effects", stats = {
            "burn_damage_pct", "burn_tick_rate_pct"
        }},
        { header = "Poison Effects", stats = {
            "max_poison_stacks_pct"
        }},
    },
    utility = {
        { header = "Movement", stats = {
            "run_speed", "move_speed_pct"
        }},
        { header = "Resources", stats = {
            "skill_energy_cost_reduction", "experience_gained_pct", "healing_received_pct"
        }},
        { header = "Buffs", stats = {
            "buff_duration_pct", "buff_effect_pct"
        }},
        { header = "Summon", stats = {
            "summon_hp_pct", "summon_damage_pct", "summon_persistence"
        }},
        { header = "Hazard", stats = {
            "hazard_radius_pct", "hazard_damage_pct", "hazard_duration"
        }},
        { header = "Special", stats = {
            "chain_targets", "on_move_proc_frequency_pct", "damage_vs_frozen_pct",
            "barrier_refresh_rate_pct", "reflect_damage_pct"
        }},
    },
}

-- Color palette - Use named colors from the palette via util.getColor()
-- This ensures consistent Color objects that work with the DSL
local COLORS = nil
local function getColors()
    if COLORS then return COLORS end

    -- Create a hardcoded fallback Color (BLACK with full opacity)
    -- CRITICAL: Never return nil - Sol2 crashes when passing nil to C++ methods
    -- expecting const Color& (segfault during argument conversion, before pcall can catch it)
    local FALLBACK_COLOR = Color and Color.new and Color.new(0, 0, 0, 255) or nil

    -- Safely get a color from the palette, with fallback
    local function safeGetColor(name, fallbackName)
        if util and util.getColor then
            local ok, c = pcall(util.getColor, name)
            if ok and c then return c end
            if fallbackName then
                local ok2, c2 = pcall(util.getColor, fallbackName)
                if ok2 and c2 then return c2 end
            end
        end
        -- Last resort: return a hardcoded fallback color, NEVER nil
        -- Creating Color objects with raylib's Color.new if available
        if FALLBACK_COLOR then
            return FALLBACK_COLOR
        end
        -- If Color.new isn't available, try one more time with a known-safe color
        if util and util.getColor then
            local ok, c = pcall(util.getColor, "black")
            if ok and c then return c end
        end
        -- This should never happen, but log if it does
        log_debug("[StatsPanel] CRITICAL: Could not create any fallback color!")
        return nil
    end

    COLORS = {
        -- Use named palette colors that work with util.getColor
        bg = safeGetColor("black"),
        header_bg = safeGetColor("dark_gray_slate", "black"),
        pill_bg = safeGetColor("dark_gray_slate", "black"),
        section_bg = safeGetColor("dark_gray_slate", "black"),
        section_content_bg = safeGetColor("black"),
        tab_active = safeGetColor("gray"),
        tab_inactive = safeGetColor("dark_gray_slate", "black"),
        outline = safeGetColor("apricot_cream", "white"),
        positive = safeGetColor("mint_green", "green"),
        negative = safeGetColor("fiery_red", "red"),
        warning_low = safeGetColor("dark_khaki", "brown"),
        warning_critical = safeGetColor("dark_salmon", "red"),
        transparent = safeGetColor("black"),  -- Will need alpha handling separately
        tab_bar_bg = safeGetColor("black"),
    }

    log_debug("[StatsPanel] Colors initialized via util.getColor")
    return COLORS
end

-- Category colors for stat labels
local CATEGORY_COLORS = {
    core = "gold",
    attributes = "orange",
    combat = "cyan",
    offense = "fiery_red",
    defense = "baby_blue",
    utility = "purple",
    movement = "yellow",
    status = "fuchsia",
    buffs = "mint_green",
    special = "pink",
    hazard = "poison",
    summon = "cyan",
    elemental = "cyan",
}

-- Element-specific colors
local ELEMENT_COLORS = {
    fire = "fire",
    cold = "ice",
    lightning = "electric",
    acid = "poison",
    vitality = "purple",
    aether = "cyan",
    chaos = "fiery_red",
    physical = "gray",
    pierce = "gray",
}

--------------------------------------------------------------------------------
-- Panel State
--------------------------------------------------------------------------------
StatsPanel._state = {
    visible = false,
    slideProgress = 0,         -- 0 = hidden, 1 = fully visible
    slideDirection = "idle",   -- "entering", "exiting", "idle"
    currentTab = 1,
    expandedSections = {},     -- section_id -> bool
    panelEntity = nil,
    snapshot = nil,
    snapshotHash = nil,
    lastUpdateTime = 0,
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
-- NOTE on colors:
-- 1. dsl.text() expects color as a string NAME (e.g., "gold", "cyan") - the DSL looks it up
-- 2. dsl.hbox/vbox/root config.color expects Color objects (pre-created at load time)
-- 3. Pre-create all Color objects in COLORS table, don't create dynamically in functions

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

local function getStatFormat()
    return StatTooltipSystem and StatTooltipSystem.FORMAT or {
        INT = "int", FLOAT = "float", PCT = "pct", RANGE = "range", FRACTION = "fraction"
    }
end

-- Returns a color NAME string for use with dsl.text()
local function getCategoryColor(statKey)
    local defs = getStatDefs()
    local def = defs[statKey]
    if not def then return "white" end

    local group = def.group

    -- Check for element-specific stats
    if group == "elemental" then
        local element = statKey:match("^(%w+)_modifier")
        if element and ELEMENT_COLORS[element] then
            return ELEMENT_COLORS[element]  -- Already a string like "fire", "ice"
        end
    end

    return CATEGORY_COLORS[group] or "white"  -- Already strings like "gold", "cyan"
end

local function formatStatValue(statKey, value, snapshot)
    if StatTooltipSystem and StatTooltipSystem.formatValue then
        return StatTooltipSystem.formatValue(statKey, value, snapshot, false)
    end
    
    -- Fallback formatting
    if type(value) == "number" then
        if statKey:match("_pct$") then
            return string.format("%d%%", math.floor(value + 0.5))
        end
        return tostring(math.floor(value + 0.5))
    end
    return tostring(value or "-")
end

local function getStatLabel(statKey)
    if StatTooltipSystem and StatTooltipSystem.getLabel then
        return StatTooltipSystem.getLabel(statKey)
    end
    -- Fallback: convert stat_key to "Stat Key"
    return statKey:gsub("_pct$", ""):gsub("_", " "):gsub("^%l", string.upper)
end

-- Returns a color NAME string for use with dsl.text()
local function getValueColor(value)
    if type(value) ~= "number" then return "white" end
    if value > 0 then return "mint_green" end
    if value < 0 then return "fiery_red" end
    return "white"
end

--------------------------------------------------------------------------------
-- Snapshot Collection
--------------------------------------------------------------------------------
function StatsPanel._collectSnapshot()
    local psa = ensurePlayerStatsAccessor()
    if not psa then return nil end
    
    local player = psa.get_player()
    if not player then return nil end
    
    local stats = psa.get_stats()
    if not stats then return nil end
    
    -- Build snapshot similar to collectPlayerStatsSnapshot in gameplay.lua
    local snapshot = {
        level = player.level or 1,
        hp = player.hp or stats:get('health') or 0,
        max_hp = player.max_health or stats:get('health') or 0,
    }
    
    -- Collect all stats from DEFS
    local defs = getStatDefs()
    for key, def in pairs(defs) do
        if def.keys then
            -- Composite stats like health (hp/max_hp)
            for _, subKey in ipairs(def.keys) do
                if not snapshot[subKey] then
                    snapshot[subKey] = stats:get(subKey) or 0
                end
            end
        else
            snapshot[key] = stats:get(key) or 0
        end
    end
    
    -- Per-element data
    local perType = {}
    if CombatSystem and CombatSystem.Core and CombatSystem.Core.DAMAGE_TYPES then
        for _, dt in ipairs(CombatSystem.Core.DAMAGE_TYPES) do
            perType[#perType + 1] = {
                type = dt,
                dmg = stats:get(dt .. "_damage"),
                mod = stats:get(dt .. "_modifier_pct"),
                resist = stats:get(dt .. "_resist_pct"),
                duration = stats:get(dt .. "_duration_pct")
            }
        end
    end
    snapshot.per_type = perType
    
    return snapshot
end

function StatsPanel._computeSnapshotHash(snapshot)
    if StatTooltipSystem and StatTooltipSystem.computeHash then
        return StatTooltipSystem.computeHash(snapshot)
    end
    
    -- Fallback hash
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

local function easeInQuad(t)
    return t * t
end

--------------------------------------------------------------------------------
-- UI Components
--------------------------------------------------------------------------------

-- Creates a single stat pill: [Label: Value]
local function createStatPill(statKey, snapshot, opts)
    opts = opts or {}
    local defs = getStatDefs()
    local def = defs[statKey]
    
    local value
    if def and def.keys then
        value = snapshot[def.keys[1]]
    else
        value = snapshot[statKey]
    end
    
    -- Skip zero/nil values unless forced
    local isZero = value == nil or (type(value) == "number" and math.abs(value) < 0.001)
    if isZero and not opts.showZeros then
        return nil
    end
    
    local formatted = formatStatValue(statKey, value, snapshot)
    if not formatted then return nil end
    
    local label = getStatLabel(statKey)
    local labelColor = getCategoryColor(statKey)
    local valueColor = opts.colorValues and getValueColor(value) or "white"
    
    -- Warning state for health
    local pillBg = getColors().pill_bg
    if statKey == "health" and snapshot.hp and snapshot.max_hp then
        local ratio = snapshot.hp / math.max(1, snapshot.max_hp)
        if ratio <= 0.10 then
            pillBg = getColors().warning_critical
        elseif ratio <= 0.25 then
            pillBg = getColors().warning_low
        end
    end
    
    return dsl.hbox {
        config = {
            padding = 3,
            color = pillBg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            minHeight = PILL_HEIGHT,
        },
        children = {
            dsl.text(label .. ":", {
                fontSize = PILL_FONT_SIZE,
                color = labelColor,
                shadow = false,
            }),
            dsl.spacer(4),
            dsl.text(formatted, {
                fontSize = PILL_FONT_SIZE,
                color = valueColor,
                shadow = false,
            }),
        }
    }
end

-- Creates a collapsible section header
local function createSectionHeader(sectionId, title, isExpanded, onToggle)
    local icon = isExpanded and "▼ " or "▶ "
    
    return dsl.hbox {
        config = {
            padding = 4,
            color = getColors().section_bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            minHeight = 24,
            buttonCallback = onToggle,
            hover = true,
        },
        children = {
            dsl.text(icon .. title, {
                fontSize = HEADER_FONT_SIZE,
                color = "apricot_cream",
                shadow = true,
            }),
        }
    }
end

-- Creates the tab bar at the bottom
local function createTabBar(currentTab, onTabChange)
    local children = {}
    
    for i, tab in ipairs(TABS) do
        local isActive = (i == currentTab)
        local bgColor = isActive and getColors().tab_active or getColors().tab_inactive
        local textColor = isActive and "apricot_cream" or "gray"
        
        table.insert(children, dsl.hbox {
            config = {
                padding = 3,
                color = bgColor,
                minWidth = TAB_WIDTH,
                minHeight = TAB_HEIGHT,
                buttonCallback = function() onTabChange(i) end,
                hover = true,
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            },
            children = {
                dsl.text(tab.label, {
                    fontSize = 11,
                    color = textColor,
                    shadow = isActive,
                }),
            }
        })
    end
    
    return dsl.hbox {
        config = {
            padding = 2,
            color = getColors().tab_bar_bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = children,
    }
end

--------------------------------------------------------------------------------
-- Panel Building
--------------------------------------------------------------------------------

-- Build Tier 1 section (always visible)
local function buildTier1Section(snapshot)
    local rows = {}
    
    -- Group stats into rows of 2
    for i = 1, #TIER1_STATS, 2 do
        local rowChildren = {}
        for j = 0, 1 do
            local statKey = TIER1_STATS[i + j]
            if statKey then
                local pill = createStatPill(statKey, snapshot, { showZeros = true, colorValues = true })
                if pill then
                    table.insert(rowChildren, pill)
                    if j == 0 then table.insert(rowChildren, dsl.spacer(4)) end
                end
            end
        end
        if #rowChildren > 0 then
            table.insert(rows, dsl.hbox {
                config = { padding = 1 },
                children = rowChildren,
            })
        end
    end
    
    return dsl.vbox {
        config = {
            padding = 6,
            color = getColors().section_bg,
        },
        children = rows,
    }
end

-- Build a single section with its stats
local function buildSection(sectionDef, snapshot, sectionId)
    local state = StatsPanel._state
    local isExpanded = state.expandedSections[sectionId] ~= false
    
    -- Collect non-zero stats
    local statPills = {}
    for _, statKey in ipairs(sectionDef.stats) do
        local pill = createStatPill(statKey, snapshot, { showZeros = false, colorValues = true })
        if pill then
            table.insert(statPills, pill)
        end
    end
    
    -- Skip section if no stats
    if #statPills == 0 then return nil end
    
    local children = {
        createSectionHeader(sectionId, sectionDef.header, isExpanded, function()
            state.expandedSections[sectionId] = not isExpanded
            StatsPanel.rebuild()
        end)
    }
    
    if isExpanded then
        table.insert(children, dsl.vbox {
            config = {
                padding = 4,
                color = getColors().section_content_bg,
            },
            children = statPills,
        })
    end
    
    return dsl.vbox {
        config = { padding = 0 },
        children = children,
    }
end

-- Build elemental resistance grid (for Resist tab)
local function buildElementalResistGrid(snapshot)
    if not snapshot.per_type or #snapshot.per_type == 0 then return nil end
    
    local state = StatsPanel._state
    local sectionId = "elemental_resists"
    local isExpanded = state.expandedSections[sectionId] ~= false
    
    local resistRows = {}
    for _, entry in ipairs(snapshot.per_type) do
        local resist = entry.resist
        if resist and math.abs(resist) > 0.01 then
            local elementColor = ELEMENT_COLORS[entry.type] or "white"
            local valueColor = resist >= 0 and "mint_green" or "fiery_red"
            
            table.insert(resistRows, dsl.hbox {
                config = { padding = 2 },
                children = {
                    dsl.text(entry.type:sub(1,1):upper() .. entry.type:sub(2), {
                        fontSize = PILL_FONT_SIZE,
                        color = elementColor,
                    }),
                    dsl.spacer(4),
                    dsl.text(string.format("%d%%", math.floor(resist + 0.5)), {
                        fontSize = PILL_FONT_SIZE,
                        color = valueColor,
                    }),
                }
            })
        end
    end
    
    if #resistRows == 0 then return nil end
    
    local function toggleSection()
        state.expandedSections[sectionId] = not isExpanded
        StatsPanel.rebuild()
    end
    
    local children = {
        createSectionHeader(sectionId, "Elemental Resists", isExpanded, toggleSection),
    }
    
    if isExpanded then
        table.insert(children, dsl.vbox {
            config = {
                padding = 4,
                color = getColors().section_content_bg,
            },
            children = resistRows,
        })
    end
    
    return dsl.vbox {
        config = { padding = 0 },
        children = children,
    }
end

-- Build tab content
local function buildTabContent(tabIndex, snapshot)
    local tab = TABS[tabIndex]
    if not tab then return dsl.text("Invalid tab", { color = "red" }) end
    
    local layout = TAB_LAYOUTS[tab.id]
    if not layout then return dsl.text("No data", { color = "gray" }) end
    
    local sections = {}
    
    for i, sectionDef in ipairs(layout) do
        local sectionId = tab.id .. "_" .. i
        local section = buildSection(sectionDef, snapshot, sectionId)
        if section then
            table.insert(sections, section)
            table.insert(sections, dsl.spacer(2))
        end
    end
    
    -- Add elemental resists for Resist tab
    if tab.id == "resist" then
        local resistGrid = buildElementalResistGrid(snapshot)
        if resistGrid then
            table.insert(sections, resistGrid)
        end
    end
    
    if #sections == 0 then
        return dsl.text("No stats in this category", { fontSize = 11, color = "gray" })
    end
    
    return dsl.vbox {
        config = { padding = 4 },
        children = sections,
    }
end

-- Build the complete panel definition
local function buildPanelDefinition(snapshot)
    local state = StatsPanel._state
    
    return dsl.root {
        config = {
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
                    -- Title bar
                    dsl.hbox {
                        config = {
                            padding = 6,
                            color = getColors().header_bg,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                        },
                        children = {
                            dsl.text(L("stats_panel.title", "Character Stats"), {
                                fontSize = 16,
                                color = "apricot_cream",
                                shadow = true,
                            }),
                        }
                    },
                    
                    dsl.spacer(4),
                    
                    -- Tier 1 stats
                    buildTier1Section(snapshot),
                    
                    dsl.spacer(4),
                    
                    -- Divider
                    dsl.divider("horizontal", { color = "gray", thickness = 1, length = PANEL_WIDTH - 24 }),
                    
                    dsl.spacer(4),
                    
                    -- Tab content
                    buildTabContent(state.currentTab, snapshot),
                    
                    dsl.spacer(4),
                    
                    -- Tab bar
                    createTabBar(state.currentTab, function(newTab)
                        state.currentTab = newTab
                        StatsPanel.rebuild()
                    end),
                    
                    dsl.spacer(4),
                    
                    -- Keyboard hint
                    dsl.text("C: toggle  Tab: cycle  1-5: jump  Esc: close", {
                        fontSize = 9,
                        color = "gray",
                        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                    }),
                }
            }
        }
    }
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
    local y = 60  -- Below top UI
    
    t.actualX = x
    t.actualY = y
    t.visualX = x
    t.visualY = y
end

--------------------------------------------------------------------------------
-- Panel Lifecycle
--------------------------------------------------------------------------------
function StatsPanel._createPanel()
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
        log_debug("[StatsPanel] No snapshot available")
        return
    end
    
    local ok, def = pcall(buildPanelDefinition, snapshot)
    if not ok then
        log_debug("[StatsPanel] buildPanelDefinition failed: " .. tostring(def))
        return
    end
    local screenW, _ = getScreenSize()
    log_debug("[StatsPanel] screenW=" .. tostring(screenW))
    
    local spawnOk, entity = pcall(function()
        return dsl.spawn({ x = screenW + 50, y = 60 }, def, "ui")
    end)
    if not spawnOk then
        log_debug("[StatsPanel] dsl.spawn failed: " .. tostring(entity))
        return
    end
    log_debug("[StatsPanel] spawned entity=" .. tostring(entity))
    
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
    
    -- Add state tags for visibility during gameplay
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
    if state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity) then
        registry:destroy(state.panelEntity)
    end
    state.panelEntity = nil
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function StatsPanel.show()
    log_debug("[StatsPanel] show() called")
    local state = StatsPanel._state
    if state.visible and state.slideDirection ~= "exiting" then 
        log_debug("[StatsPanel] Already visible, skipping")
        return 
    end
    
    state.visible = true
    state.slideDirection = "entering"
    state.slideProgress = 0
    
    state.snapshot = StatsPanel._collectSnapshot()
    log_debug("[StatsPanel] snapshot collected: " .. tostring(state.snapshot ~= nil))
    state.snapshotHash = StatsPanel._computeSnapshotHash(state.snapshot)
    
    StatsPanel._createPanel()
    log_debug("[StatsPanel] panel entity: " .. tostring(state.panelEntity))
    
    if activate_state and STATS_PANEL_STATE then
        activate_state(STATS_PANEL_STATE)
    end
end

function StatsPanel.hide()
    local state = StatsPanel._state
    if not state.visible or state.slideDirection == "exiting" then return end
    
    state.slideDirection = "exiting"
    
    if deactivate_state and STATS_PANEL_STATE then
        deactivate_state(STATS_PANEL_STATE)
    end
end

function StatsPanel.toggle()
    log_debug("[StatsPanel] toggle() called, visible=" .. tostring(StatsPanel.isVisible()))
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

function StatsPanel.setTab(tabIndex)
    if tabIndex < 1 or tabIndex > TAB_COUNT then return end
    local state = StatsPanel._state
    if state.currentTab ~= tabIndex then
        state.currentTab = tabIndex
        StatsPanel.rebuild()
    end
end

function StatsPanel.nextTab()
    local state = StatsPanel._state
    state.currentTab = (state.currentTab % TAB_COUNT) + 1
    StatsPanel.rebuild()
end

--------------------------------------------------------------------------------
-- Update Loop
--------------------------------------------------------------------------------
function StatsPanel.update(dt)
    local state = StatsPanel._state
    
    -- Handle slide animation
    if state.slideDirection == "entering" then
        state.slideProgress = math.min(1, state.slideProgress + dt / SLIDE_DURATION)
        if state.slideProgress >= 1 then
            state.slideDirection = "idle"
            state.slideProgress = 1
        end
        StatsPanel._updatePosition()
        
    elseif state.slideDirection == "exiting" then
        -- Use faster exit animation
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
    
    -- Refresh snapshot periodically when visible
    if state.visible and state.panelEntity then
        state.lastUpdateTime = (state.lastUpdateTime or 0) + dt
        if state.lastUpdateTime > 0.5 then  -- Check every 0.5s
            state.lastUpdateTime = 0
            local newSnapshot = StatsPanel._collectSnapshot()
            if newSnapshot then
                local newHash = StatsPanel._computeSnapshotHash(newSnapshot)
                if newHash ~= state.snapshotHash then
                    state.snapshot = newSnapshot
                    state.snapshotHash = newHash
                    StatsPanel.rebuild()
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------
function StatsPanel.handleInput()
    if not input then return end
    
    if input.action_pressed and input.action_pressed("toggle_stats_panel") then
        log_debug("[StatsPanel] toggle_stats_panel action pressed!")
        StatsPanel.toggle()
        return true
    end
    
    if not StatsPanel.isVisible() then return false end
    
    if input.action_pressed and input.action_pressed("stats_panel_close") then
        StatsPanel.hide()
        return true
    end
    
    if input.action_pressed and input.action_pressed("stats_panel_next_tab") then
        StatsPanel.nextTab()
        return true
    end
    
    for i = 1, TAB_COUNT do
        if input.action_pressed and input.action_pressed("stats_panel_tab_" .. i) then
            StatsPanel.setTab(i)
            return true
        end
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
function StatsPanel.init()
    StatsPanel._state = {
        visible = false,
        slideProgress = 0,
        slideDirection = "idle",
        currentTab = 1,
        expandedSections = {},
        panelEntity = nil,
        snapshot = nil,
        snapshotHash = nil,
        lastUpdateTime = 0,
    }
end

-- Initialize on load
StatsPanel.init()

_G.__STATS_PANEL__ = StatsPanel
return StatsPanel
