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
local PANEL_WIDTH = 320
local PANEL_PADDING = 10
local SLIDE_DURATION = 0.3
local TAB_COUNT = 5
local PILL_HEIGHT = 22
local PILL_FONT_SIZE = 14
local HEADER_FONT_SIZE = 12
local TAB_HEIGHT = 28
local TAB_WIDTH = 58
local SCROLL_VIEWPORT_HEIGHT = 400

-- Tab definitions
local TABS = {
    { id = "combat",  label = "Combat" },
    { id = "resist",  label = "Resist" },
    { id = "mods",    label = "Mods" },
    { id = "dots",    label = "DoTs" },
    { id = "utility", label = "Utility" },
}

-- Tier 1 stats organized into 6 always-visible category groups (21 stats total)
-- Per spec: these are always expanded, never collapsible
local TIER1_GROUPS = {
    {
        id = "vitals",
        header = "Vitals",
        stats = { "level", "xp", "health", "health_regen" }
    },
    {
        id = "attributes",
        header = "Attributes",
        stats = { "physique", "cunning", "spirit" }
    },
    {
        id = "offense",
        header = "Offense",
        stats = { "offensive_ability", "damage", "attack_speed", "cast_speed", "crit_damage_pct", "all_damage_pct", "life_steal_pct" }
    },
    {
        id = "defense",
        header = "Defense",
        stats = { "defensive_ability", "armor", "dodge_chance_pct" }
    },
    {
        id = "utility",
        header = "Utility",
        stats = { "cooldown_reduction", "skill_energy_cost_reduction" }
    },
    {
        id = "movement",
        header = "Movement",
        stats = { "run_speed", "move_speed_pct" }
    },
}

-- Flat list for backward compatibility
local TIER1_STATS = {}
for _, group in ipairs(TIER1_GROUPS) do
    for _, stat in ipairs(group.stats) do
        TIER1_STATS[#TIER1_STATS + 1] = stat
    end
end

-- Tab-specific stats layout
local TAB_LAYOUTS = {
    combat = {
        { header = "Offense", stats = {
            "all_damage_pct", "weapon_damage_pct", "crit_damage_pct", "life_steal_pct",
            "cooldown_reduction", "attack_speed", "cast_speed", "offensive_ability"
        }},
        { header = "Melee", stats = {
            "melee_damage_pct", "melee_crit_chance_pct"
        }},
    },
    resist = {
        { header = "Defense", stats = {
            "defensive_ability", "armor", "dodge_chance_pct", "block_chance_pct", "block_amount",
            "block_recovery_reduction_pct", "percent_absorb_pct", "flat_absorb", "armor_absorption_bonus_pct"
        }},
        { header = "Damage Reduction", stats = {
            "damage_taken_reduction_pct", "reflect_damage_pct", "max_resist_cap_pct", "min_resist_cap_pct"
        }},
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
            "skill_energy_cost_reduction", "experience_gained_pct", "healing_received_pct", "health_pct"
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
-- Reset to nil on each load to pick up any changes during hot reload
local COLORS = nil

-- Force color cache reset (useful for hot reload)
function StatsPanel._resetColorCache()
    COLORS = nil
    log_debug("[StatsPanel] Color cache reset")
end
local function getColors()
    if COLORS then return COLORS end

    -- Create a hardcoded fallback Color (BLACK with full opacity)
    -- CRITICAL: Never return nil - Sol2 crashes when passing nil to C++ methods
    -- expecting const Color& (segfault during argument conversion, before pcall can catch it)
    local FALLBACK_COLOR = Color and Color.new and Color.new(0, 0, 0, 255) or nil

    -- Safely get a color from the palette, with fallback
    -- CRITICAL: Must validate that we get userdata (Color), not table
    local function safeGetColor(name, fallbackName)
        if util and util.getColor then
            local ok, c = pcall(util.getColor, name)
            if ok and c and type(c) == "userdata" then return c end
            if ok and c and type(c) ~= "userdata" then
                log_debug("[StatsPanel] WARNING: util.getColor('" .. name .. "') returned " .. type(c) .. ", expected userdata")
            end
            if fallbackName then
                local ok2, c2 = pcall(util.getColor, fallbackName)
                if ok2 and c2 and type(c2) == "userdata" then return c2 end
            end
        end
        -- Last resort: return a hardcoded fallback color, NEVER nil
        -- Creating Color objects with raylib's Color.new if available
        if FALLBACK_COLOR and type(FALLBACK_COLOR) == "userdata" then
            return FALLBACK_COLOR
        end
        -- If Color.new isn't available, try one more time with a known-safe color
        if util and util.getColor then
            local ok, c = pcall(util.getColor, "black")
            if ok and c and type(c) == "userdata" then return c end
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

    -- Validate all colors are userdata
    for k, v in pairs(COLORS) do
        if type(v) ~= "userdata" then
            log_debug("[StatsPanel] ERROR: COLORS." .. k .. " is " .. type(v) .. ", expected userdata!")
        end
    end

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
    slideProgress = 0,
    slideDirection = "idle",
    currentTab = 1,
    expandedSections = {},
    snapshot = nil,
    snapshotHash = nil,
    lastUpdateTime = 0,
    previousSnapshot = nil,
    tabScrollOffsets = {},
    
    panelEntity = nil,
    headerEntity = nil,
    tier1Entity = nil,
    scrollPaneEntity = nil,
    tabContentEntity = nil,
    tabBarEntity = nil,
    footerEntity = nil,
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

local function createScrollPane(children, opts)
    opts = opts or {}
    local height = opts.height or SCROLL_VIEWPORT_HEIGHT
    local padding = opts.padding or 4
    local bgColor = opts.color or getColors().bg
    
    return ui.definitions.def {
        type = "SCROLL_PANE",
        config = {
            id = opts.id or "stats_panel_scroll",
            maxHeight = height,
            height = height,
            padding = padding,
            color = bgColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = children,
    }
end

local function getStatDefs()
    local defs = StatTooltipSystem and StatTooltipSystem.DEFS or {}
    if not StatTooltipSystem then
        log_debug("[StatsPanel] getStatDefs: StatTooltipSystem is nil!")
    elseif not StatTooltipSystem.DEFS then
        log_debug("[StatsPanel] getStatDefs: StatTooltipSystem.DEFS is nil!")
    end
    return defs
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

local function getStatRawData(statKey)
    local psa = ensurePlayerStatsAccessor()
    if not psa then return nil end
    return psa.get_raw(statKey)
end

local function buildStatTooltipBody(statKey, value, snapshot)
    local raw = getStatRawData(statKey)
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

local function formatStatValue(statKey, value, snapshot, showDelta)
    local formatted = nil
    
    if StatTooltipSystem and StatTooltipSystem.formatValue then
        formatted = StatTooltipSystem.formatValue(statKey, value, snapshot, false)
    else
        if type(value) == "number" then
            if statKey:match("_pct$") then
                formatted = string.format("%d%%", math.floor(value + 0.5))
            else
                formatted = tostring(math.floor(value + 0.5))
            end
        else
            formatted = tostring(value or "-")
        end
    end
    
    if showDelta and type(value) == "number" then
        local baseValue = getStatBaseValue(statKey)
        if baseValue and type(baseValue) == "number" then
            local delta = value - baseValue
            local deltaStr = formatDelta(delta)
            if deltaStr then
                formatted = formatted .. " " .. deltaStr
            end
        end
    end
    
    return formatted
end

local function formatFallbackLabel(statKey)
    return statKey
        :gsub("_pct$", "")
        :gsub("_", " ")
        :gsub("(%a)([%w]*)", function(first, rest)
            return first:upper() .. rest
        end)
end

local function getStatLabel(statKey)
    if StatTooltipSystem and StatTooltipSystem.getLabel then
        local label = StatTooltipSystem.getLabel(statKey)
        if label and label ~= statKey then
            return label
        end
    end
    return formatFallbackLabel(statKey)
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
    if not psa then
        log_debug("[StatsPanel] _collectSnapshot: PlayerStatsAccessor not available")
        return nil
    end

    local player = psa.get_player()
    if not player then
        log_debug("[StatsPanel] _collectSnapshot: No player (combat_context.side1[1] is nil)")
        return nil
    end

    local stats = psa.get_stats()
    if not stats then
        log_debug("[StatsPanel] _collectSnapshot: Player has no stats")
        return nil
    end

    log_debug("[StatsPanel] _collectSnapshot: Got player and stats successfully")
    
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
-- Scroll State Management
--------------------------------------------------------------------------------

function StatsPanel._getScrollOffset()
    local state = StatsPanel._state
    if not state.panelEntity or not entity_cache or not entity_cache.valid(state.panelEntity) then
        return nil
    end

    local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
    if not scrollPane or not entity_cache.valid(scrollPane) then
        return nil
    end

    -- UIScrollComponent may not be bound to Lua yet - guard against nil
    if not UIScrollComponent then
        return nil
    end

    local scrollComp = component_cache.get(scrollPane, UIScrollComponent)
    if scrollComp then
        return scrollComp.offset, scrollComp.maxOffset
    end
    return nil
end

-- Debug function to check scroll state
function StatsPanel.debugScrollState()
    local state = StatsPanel._state
    if not state.panelEntity then
        log_debug("[StatsPanel DEBUG] No panel entity")
        return
    end

    local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
    if not scrollPane then
        log_debug("[StatsPanel DEBUG] No scroll pane found")
        return
    end

    log_debug(string.format("[StatsPanel DEBUG] scrollPane entity=%s, valid=%s",
        tostring(scrollPane),
        tostring(entity_cache and entity_cache.valid(scrollPane))))

    local scrollComp = UIScrollComponent and component_cache.get(scrollPane, UIScrollComponent)
    if scrollComp then
        local atBottom = scrollComp.offset >= (scrollComp.maxOffset or 0) - 0.1
        local atTop = scrollComp.offset <= (scrollComp.minOffset or 0) + 0.1
        log_debug(string.format("[StatsPanel DEBUG] offset=%.1f, maxOffset=%.1f, prevOffset=%.1f, vertical=%s, atTop=%s, atBottom=%s",
            scrollComp.offset or 0,
            scrollComp.maxOffset or 0,
            scrollComp.prevOffset or 0,
            tostring(scrollComp.vertical),
            tostring(atTop),
            tostring(atBottom)))
    else
        log_debug("[StatsPanel DEBUG] No UIScrollComponent")
    end

    -- Check if scroll pane has collision enabled
    local go = component_cache.get(scrollPane, GameObject)
    if go then
        log_debug(string.format("[StatsPanel DEBUG] collisionEnabled=%s, isColliding=%s, isHovered=%s",
            tostring(go.state.collisionEnabled),
            tostring(go.state.isColliding),
            tostring(go.state.isBeingHovered)))
    end

    -- Check transform bounds
    local t = component_cache.get(scrollPane, Transform)
    if t then
        log_debug(string.format("[StatsPanel DEBUG] bounds: x=%.0f, y=%.0f, w=%.0f, h=%.0f",
            t.actualX or 0, t.actualY or 0, t.actualW or 0, t.actualH or 0))
    end

    -- Check mouse position relative to scroll pane
    if input and input.getMousePos then
        local mx, my = input.getMousePos()
        if t then
            local inBounds = mx >= t.actualX and mx <= (t.actualX + t.actualW) and
                             my >= t.actualY and my <= (t.actualY + t.actualH)
            log_debug(string.format("[StatsPanel DEBUG] mouse=(%.0f, %.0f), inBounds=%s",
                mx or 0, my or 0, tostring(inBounds)))
        end
    end
end

-- Continuous debug logging (call from update loop temporarily)
local debugCounter = 0
function StatsPanel._debugUpdateTick()
    debugCounter = debugCounter + 1
    if debugCounter % 60 == 0 then -- Log every ~1 second at 60fps
        StatsPanel.debugScrollState()
    end
end

function StatsPanel._restoreScrollOffset()
    local state = StatsPanel._state
    local savedOffset = state.tabScrollOffsets[state.currentTab]

    -- Store reference to the new scroll pane for collision detection
    local scrollPane = ui.box.GetUIEByID(registry, state.panelEntity, "stats_panel_scroll")
    state.scrollPaneEntity = scrollPane

    if not savedOffset or savedOffset == 0 then
        -- No need to clear activeScrollPane - the C++ side will detect the old entity
        -- is invalid and clear it automatically, then re-detect the new scroll pane
        return
    end

    if not scrollPane or not entity_cache or not entity_cache.valid(scrollPane) then
        return
    end

    -- UIScrollComponent may not be bound to Lua yet - guard against nil
    if not UIScrollComponent then
        return
    end

    local scrollComp = component_cache.get(scrollPane, UIScrollComponent)
    if scrollComp then
        scrollComp.offset = math.min(savedOffset, scrollComp.maxOffset or savedOffset)
        scrollComp.prevOffset = scrollComp.offset

        ui.box.TraverseUITreeBottomUp(registry, scrollPane, function(child)
            local go = component_cache.get(child, GameObject)
            if go then
                go.scrollPaneDisplacement = { x = 0, y = -scrollComp.offset }
            end
        end, true)
    end

    -- Note: We intentionally do NOT call clearActiveScrollPane() here anymore.
    -- The C++ input system will automatically:
    -- 1. Detect the old scroll pane entity is invalid (registry.valid() returns false)
    -- 2. Clear activeScrollPane to null in the else branch
    -- 3. Re-detect the new scroll pane via MarkEntitiesCollidingWithCursor
    -- Calling clearActiveScrollPane() here was redundant and could cause timing issues.
end

--------------------------------------------------------------------------------
-- UI Components
--------------------------------------------------------------------------------

local function createStatPill(statKey, snapshot, opts)
    opts = opts or {}
    local defs = getStatDefs()
    local def = defs[statKey]
    
    local value
    if def and def.keys then
        value = snapshot[def.keys[1]]
    elseif def then
        value = snapshot[statKey]
    else
        value = snapshot[statKey]
    end
    
    if value == nil then
        value = 0
    end
    
    local isZero = type(value) == "number" and math.abs(value) < 0.001
    if isZero and not opts.showZeros then
        return nil
    end
    
    local showDelta = opts.showDelta ~= false
    local baseFormatted = formatStatValue(statKey, value, snapshot, false)
    if not baseFormatted then
        if type(value) == "number" then
            if statKey:match("_pct$") then
                baseFormatted = string.format("%d%%", math.floor(value + 0.5))
            else
                baseFormatted = tostring(math.floor(value + 0.5))
            end
        else
            baseFormatted = tostring(value)
        end
    end
    
    local label = getStatLabel(statKey)
    local labelColor = getCategoryColor(statKey)
    local valueColor = opts.colorValues and getValueColor(value) or "white"
    
    local pillBg = getColors().pill_bg
    if statKey == "health" and snapshot.hp and snapshot.max_hp then
        local ratio = snapshot.hp / math.max(1, snapshot.max_hp)
        if ratio <= 0.10 then
            pillBg = getColors().warning_critical
        elseif ratio <= 0.25 then
            pillBg = getColors().warning_low
        end
    end
    
    local children = {
        dsl.strict.text(label .. ":", {
            fontSize = PILL_FONT_SIZE,
            color = labelColor,
            shadow = false,
        }),
        dsl.strict.spacer(4),
        dsl.strict.text(baseFormatted, {
            fontSize = PILL_FONT_SIZE,
            color = valueColor,
            shadow = false,
        }),
    }
    
    if showDelta and type(value) == "number" then
        local baseValue = getStatBaseValue(statKey)
        if baseValue and type(baseValue) == "number" then
            local delta = value - baseValue
            local deltaStr = formatDelta(delta)
            if deltaStr then
                local deltaColor = delta > 0 and "mint_green" or "fiery_red"
                table.insert(children, dsl.strict.spacer(2))
                table.insert(children, dsl.strict.text(deltaStr, {
                    fontSize = PILL_FONT_SIZE - 2,
                    color = deltaColor,
                    shadow = false,
                }))
            end
        end
    end
    
    local tooltipBody = buildStatTooltipBody(statKey, value, snapshot)
    
    return dsl.strict.hbox {
        config = {
            id = "stat_pill_" .. statKey,
            padding = 3,
            color = pillBg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            minHeight = PILL_HEIGHT,
            hover = tooltipBody ~= nil,
            tooltip = tooltipBody and {
                title = label,
                body = tooltipBody,
            } or nil,
        },
        children = children,
    }
end

-- Creates a collapsible section header
local function createSectionHeader(sectionId, title, isExpanded, onToggle)
    -- Use simple ASCII arrows instead of unicode (unicode can render too large)
    local icon = isExpanded and "- " or "+ "
    
    return dsl.strict.hbox {
        config = {
            padding = 4,
            color = getColors().section_bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            minHeight = 24,
            buttonCallback = onToggle,
            hover = true,
        },
        children = {
            dsl.strict.text(icon .. title, {
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
        
        table.insert(children, dsl.strict.hbox {
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
                dsl.strict.text(tab.label, {
                    fontSize = 11,
                    color = textColor,
                    shadow = isActive,
                }),
            }
        })
    end
    
    return dsl.strict.hbox {
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

local function buildTier1GroupHeader(title)
    return dsl.strict.hbox {
        config = {
            padding = 2,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.strict.text(title, {
                fontSize = 10,
                color = "gray",
                shadow = false,
            }),
        }
    }
end

local function buildTier1Section(snapshot)
    log_debug("[StatsPanel] buildTier1Section called, snapshot keys: " ..
        (snapshot and tostring((function() local c=0; for _ in pairs(snapshot) do c=c+1 end; return c end)()) or "nil"))
    local groupElements = {}
    local totalPills = 0

    for _, group in ipairs(TIER1_GROUPS) do
        local groupChildren = {}

        table.insert(groupChildren, buildTier1GroupHeader(group.header))

        local statsRow = {}
        for i, statKey in ipairs(group.stats) do
            local pill = createStatPill(statKey, snapshot, { showZeros = true, colorValues = true })
            if pill then
                totalPills = totalPills + 1
                table.insert(statsRow, pill)
                if i < #group.stats then
                    table.insert(statsRow, dsl.strict.spacer(4))
                end
            end
        end
        
        if #statsRow > 0 then
            table.insert(groupChildren, dsl.strict.hbox {
                config = {
                    padding = 2,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                },
                children = statsRow,
            })
        end

        table.insert(groupElements, dsl.strict.vbox {
            config = { padding = 2 },
            children = groupChildren,
        })
    end

    return dsl.strict.vbox {
        config = {
            padding = 6,
            color = getColors().section_bg,
        },
        children = groupElements,
    }
end

-- Build a single section with its stats
local function buildSection(sectionDef, snapshot, sectionId)
    local state = StatsPanel._state
    local isExpanded = state.expandedSections[sectionId] ~= false

    -- Show all stats including zeros so tabs aren't empty
    local statPills = {}
    for _, statKey in ipairs(sectionDef.stats) do
        local pill = createStatPill(statKey, snapshot, { showZeros = true, colorValues = true })
        if pill then
            table.insert(statPills, pill)
        end
    end

    -- Skip section if no stats defined (shouldn't happen)
    if #statPills == 0 then return nil end
    
    local children = {
        createSectionHeader(sectionId, sectionDef.header, isExpanded, function()
            state.expandedSections[sectionId] = not isExpanded
            StatsPanel._rebuildTabContent()
        end)
    }

    if isExpanded then
        table.insert(children, dsl.strict.vbox {
            config = {
                padding = 4,
                color = getColors().section_content_bg,
            },
            children = statPills,
        })
    end

    return dsl.strict.vbox {
        config = { padding = 0 },
        children = children,
    }
end

local ELEMENT_ICONS = {
    fire = "🔥", cold = "❄️", lightning = "⚡", acid = "☠️",
    vitality = "💀", aether = "✨", chaos = "🌀",
    physical = "🗡️", pierce = "🗡️", bleed = "🩸",
}

local function formatGridValue(value, hasResist)
    if value == nil then
        return hasResist and "--" or "--"
    end
    if math.abs(value) < 0.01 then
        return "0%"
    end
    local sign = value > 0 and "+" or ""
    return string.format("%s%d%%", sign, math.floor(value + 0.5))
end

local function getGridValueColor(value)
    if value == nil or math.abs(value or 0) < 0.01 then
        return "gray"
    end
    return value > 0 and "mint_green" or "fiery_red"
end

local function buildElementalResistGrid(snapshot)
    if not snapshot.per_type or #snapshot.per_type == 0 then return nil end
    
    local state = StatsPanel._state
    local sectionId = "elemental_resists"
    local isExpanded = state.expandedSections[sectionId] ~= false
    
    local COL_WIDTH = 55
    local ELEMENT_COL_WIDTH = 75

    local headerRow = dsl.strict.hbox {
        config = {
            padding = 2,
            color = getColors().section_bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.strict.text("Element", { fontSize = 10, color = "gray", minWidth = ELEMENT_COL_WIDTH }),
            dsl.strict.text("Resist", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
            dsl.strict.text("Damage", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
            dsl.strict.text("Duration", { fontSize = 10, color = "gray", minWidth = COL_WIDTH }),
        }
    }
    
    local gridRows = { headerRow }
    
    for _, entry in ipairs(snapshot.per_type) do
        local elementType = entry.type
        local elementColor = ELEMENT_COLORS[elementType] or "white"
        local icon = ELEMENT_ICONS[elementType] or ""
        local displayName = elementType:sub(1,1):upper() .. elementType:sub(2)
        
        local hasResist = elementType ~= "physical" and elementType ~= "pierce" and elementType ~= "bleed"
        local hasDuration = elementType ~= "physical" and elementType ~= "pierce"
        
        local resistText = hasResist and formatGridValue(entry.resist, true) or "--"
        local modText = formatGridValue(entry.mod, false)
        local durationText = hasDuration and formatGridValue(entry.duration, false) or "--"
        
        table.insert(gridRows, dsl.strict.hbox {
            config = {
                padding = 2,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            },
            children = {
                dsl.strict.text(icon .. " " .. displayName, {
                    fontSize = PILL_FONT_SIZE - 1,
                    color = elementColor,
                    minWidth = ELEMENT_COL_WIDTH,
                }),
                dsl.strict.text(resistText, {
                    fontSize = PILL_FONT_SIZE - 1,
                    color = hasResist and getGridValueColor(entry.resist) or "gray",
                    minWidth = COL_WIDTH,
                }),
                dsl.strict.text(modText, {
                    fontSize = PILL_FONT_SIZE - 1,
                    color = getGridValueColor(entry.mod),
                    minWidth = COL_WIDTH,
                }),
                dsl.strict.text(durationText, {
                    fontSize = PILL_FONT_SIZE - 1,
                    color = hasDuration and getGridValueColor(entry.duration) or "gray",
                    minWidth = COL_WIDTH,
                }),
            }
        })
    end
    
    local function toggleSection()
        state.expandedSections[sectionId] = not isExpanded
        StatsPanel._rebuildTabContent()
    end
    
    local children = {
        createSectionHeader(sectionId, "Elemental Grid", isExpanded, toggleSection),
    }
    
    if isExpanded then
        table.insert(children, dsl.strict.vbox {
            config = {
                padding = 4,
                color = getColors().section_content_bg,
            },
            children = gridRows,
        })
    end

    return dsl.strict.vbox {
        config = { padding = 0 },
        children = children,
    }
end

-- Build tab content
local function buildTabContent(tabIndex, snapshot)
    log_debug("[StatsPanel] buildTabContent called, tabIndex=" .. tostring(tabIndex))
    local tab = TABS[tabIndex]
    if not tab then
        log_debug("[StatsPanel] buildTabContent: invalid tab index")
        return dsl.strict.text("Invalid tab", { color = "red" })
    end

    local layout = TAB_LAYOUTS[tab.id]
    if not layout then
        log_debug("[StatsPanel] buildTabContent: no layout for tab " .. tab.id)
        return dsl.strict.text("No data", { color = "gray" })
    end

    local sections = {}

    for i, sectionDef in ipairs(layout) do
        local sectionId = tab.id .. "_" .. i
        local section = buildSection(sectionDef, snapshot, sectionId)
        if section then
            table.insert(sections, section)
            table.insert(sections, dsl.strict.spacer(2))
        end
    end

    -- Add elemental resists for Resist tab
    if tab.id == "resist" then
        local resistGrid = buildElementalResistGrid(snapshot)
        if resistGrid then
            table.insert(sections, resistGrid)
        end
    end

    log_debug("[StatsPanel] buildTabContent: " .. #sections .. " sections for tab " .. tab.id)
    if #sections == 0 then
        return dsl.strict.text("No stats in this category", { fontSize = 11, color = "gray" })
    end

    return dsl.strict.vbox {
        config = { padding = 4 },
        children = sections,
    }
end

local function buildHeader()
    return dsl.strict.hbox {
        config = {
            id = "stats_panel_header",
            padding = 6,
            color = getColors().header_bg,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.strict.text(L("stats_panel.title", "Character Stats"), {
                fontSize = 16,
                color = "apricot_cream",
                shadow = true,
            }),
        }
    }
end

local function buildFooter()
    return dsl.strict.text("C: toggle  1-5: tabs  Esc: close", {
        fontSize = 9,
        color = "gray",
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
    })
end

local function buildTabContentContainer(snapshot)
    local state = StatsPanel._state
    return dsl.strict.vbox {
        config = {
            id = "stats_panel_tab_content",
            padding = 0,
        },
        children = {
            buildTabContent(state.currentTab, snapshot),
        }
    }
end

local function buildScrollableContent(snapshot)
    return dsl.strict.vbox {
        config = {
            id = "stats_panel_scrollable_content",
            padding = 0,
        },
        children = {
            buildTier1Section(snapshot),

            dsl.strict.spacer(4),

            dsl.strict.divider("horizontal", { color = "gray", thickness = 1, length = PANEL_WIDTH - 24 }),

            dsl.strict.spacer(4),

            buildTabContentContainer(snapshot),
        }
    }
end

local function buildPanelDefinition(snapshot)
    local state = StatsPanel._state

    local scrollableContent = buildScrollableContent(snapshot)
    local scrollPane = createScrollPane({ scrollableContent }, {
        id = "stats_panel_scroll",
        height = SCROLL_VIEWPORT_HEIGHT,
    })

    return dsl.strict.root {
        config = {
            id = "stats_panel_root",
            color = getColors().bg,
            padding = PANEL_PADDING,
            outlineThickness = 2,
            outlineColor = getColors().outline,
            minWidth = PANEL_WIDTH,
            shadow = true,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            dsl.strict.vbox {
                config = {
                    id = "stats_panel_main_container",
                    padding = 0,
                },
                children = {
                    buildHeader(),

                    dsl.strict.spacer(4),

                    scrollPane,

                    dsl.strict.spacer(4),

                    createTabBar(state.currentTab, function(newTab)
                        log_debug("[StatsPanel] Tab clicked: " .. tostring(newTab))
                        state.currentTab = newTab
                        StatsPanel._rebuildTabContent()
                    end),

                    dsl.strict.spacer(4),

                    buildFooter(),
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
    log_debug("[StatsPanel] _createPanel called")
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

    -- Log some key snapshot values for debugging
    local keyCount = 0
    for _ in pairs(snapshot) do keyCount = keyCount + 1 end
    log_debug("[StatsPanel] Snapshot has " .. keyCount .. " keys, level=" ..
        tostring(snapshot.level) .. ", hp=" .. tostring(snapshot.hp))

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
    
    StatsPanel._stopHPWarningPulse()
    timer.kill_group("stat_anim")
    
    if state.panelEntity and entity_cache and entity_cache.valid(state.panelEntity) then
        registry:destroy(state.panelEntity)
    end
    state.panelEntity = nil
    state.tabContentEntity = nil
end

function StatsPanel._rebuildTabContent()
    log_debug("[StatsPanel] _rebuildTabContent called, currentTab=" .. tostring(StatsPanel._state.currentTab))
    local state = StatsPanel._state
    
    local currentScrollOffset = StatsPanel._getScrollOffset()
    if currentScrollOffset then
        state.tabScrollOffsets[state.currentTab] = currentScrollOffset
    end
    
    local savedSlideProgress = state.slideProgress
    local savedSlideDirection = state.slideDirection

    StatsPanel._createPanel()

    state.slideProgress = savedSlideProgress
    state.slideDirection = savedSlideDirection
    StatsPanel._updatePosition()
    
    StatsPanel._restoreScrollOffset()
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

    -- Save current scroll position before rebuilding
    local state = StatsPanel._state
    local currentOffset = StatsPanel._getScrollOffset()
    if currentOffset then
        state.tabScrollOffsets[state.currentTab] = currentOffset
    end

    -- Save slide state
    local savedSlideProgress = state.slideProgress
    local savedSlideDirection = state.slideDirection

    -- Rebuild panel
    StatsPanel._createPanel()

    -- Restore slide state
    state.slideProgress = savedSlideProgress
    state.slideDirection = savedSlideDirection
    StatsPanel._updatePosition()

    -- Restore scroll position
    StatsPanel._restoreScrollOffset()
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
    
    if state.visible and state.panelEntity then
        state.lastUpdateTime = (state.lastUpdateTime or 0) + dt
        if state.lastUpdateTime > 0.5 then
            state.lastUpdateTime = 0
            local newSnapshot = StatsPanel._collectSnapshot()
            if newSnapshot then
                local newHash = StatsPanel._computeSnapshotHash(newSnapshot)
                if newHash ~= state.snapshotHash then
                    local changedStats = StatsPanel._detectChangedStats(state.previousSnapshot, newSnapshot)
                    
                    state.previousSnapshot = state.snapshot
                    state.snapshot = newSnapshot
                    state.snapshotHash = newHash
                    
                    StatsPanel.rebuild()
                    
                    if changedStats and #changedStats > 0 then
                        StatsPanel._triggerValueAnimations(changedStats)
                    end
                    
                    StatsPanel._checkHPWarningState()
                end
            end
        end
    end
end

function StatsPanel._detectChangedStats(oldSnapshot, newSnapshot)
    if not oldSnapshot or not newSnapshot then return nil end
    
    local changed = {}
    for key, newValue in pairs(newSnapshot) do
        if key ~= "per_type" and type(newValue) == "number" then
            local oldValue = oldSnapshot[key]
            if oldValue and type(oldValue) == "number" then
                if math.abs(newValue - oldValue) > 0.01 then
                    table.insert(changed, {
                        key = key,
                        oldValue = oldValue,
                        newValue = newValue,
                        delta = newValue - oldValue,
                    })
                end
            end
        end
    end
    return changed
end

function StatsPanel._triggerValueAnimations(changedStats)
    local state = StatsPanel._state
    if not state.panelEntity or not entity_cache.valid(state.panelEntity) then return end
    
    for _, change in ipairs(changedStats) do
        local pillId = "stat_pill_" .. change.key
        local pillEntity = ui.box.GetUIEByID(registry, state.panelEntity, pillId)
        
        if pillEntity and entity_cache.valid(pillEntity) then
            local flashColor = change.delta > 0 and "mint_green" or "fiery_red"
            
            timer.sequence("stat_anim_" .. change.key)
                :do_now(function()
                    local uie = component_cache.get(pillEntity, UIElementComponent)
                    if uie then
                        uie._originalColor = uie.settings.color
                        uie.settings.color = util.getColor(flashColor)
                    end
                end)
                :wait(0.3)
                :do_now(function()
                    local uie = component_cache.get(pillEntity, UIElementComponent)
                    if uie and uie._originalColor then
                        uie.settings.color = uie._originalColor
                        uie._originalColor = nil
                    end
                end)
                :start()
        end
    end
end

function StatsPanel._startHPWarningPulse()
    local state = StatsPanel._state
    if state.hpPulseActive then return end
    
    state.hpPulseActive = true
    state.hpPulsePhase = false
    
    timer.every_opts({
        delay = 0.5,
        tag = "hp_warning_pulse",
        action = function()
            if not StatsPanel.isVisible() then
                StatsPanel._stopHPWarningPulse()
                return
            end
            
            local pillEntity = ui.box.GetUIEByID(registry, state.panelEntity, "stat_pill_health")
            if not pillEntity or not entity_cache.valid(pillEntity) then return end
            
            local uie = component_cache.get(pillEntity, UIElementComponent)
            if not uie then return end

            state.hpPulsePhase = not state.hpPulsePhase
            
            local snapshot = state.snapshot
            local ratio = snapshot and snapshot.hp and snapshot.max_hp 
                and (snapshot.hp / math.max(1, snapshot.max_hp)) or 1
            
            if ratio <= 0.10 then
                uie.settings.color = state.hpPulsePhase 
                    and getColors().warning_critical 
                    or getColors().pill_bg
            elseif ratio <= 0.25 then
                uie.settings.color = state.hpPulsePhase 
                    and getColors().warning_low 
                    or getColors().pill_bg
            else
                uie.settings.color = getColors().pill_bg
                StatsPanel._stopHPWarningPulse()
            end
        end,
    })
end

function StatsPanel._stopHPWarningPulse()
    local state = StatsPanel._state
    if not state.hpPulseActive then return end
    
    timer.kill("hp_warning_pulse")
    state.hpPulseActive = false
    state.hpPulsePhase = false
end

function StatsPanel._checkHPWarningState()
    local state = StatsPanel._state
    if not state.snapshot then return end
    
    local hp = state.snapshot.hp or 0
    local maxHp = state.snapshot.max_hp or 1
    local ratio = hp / math.max(1, maxHp)
    
    if ratio <= 0.25 then
        StatsPanel._startHPWarningPulse()
    else
        StatsPanel._stopHPWarningPulse()
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
    
    if input.key_pressed and (input.key_pressed(KEY_ESCAPE) or input.key_pressed(256)) then
        StatsPanel.hide()
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
        snapshot = nil,
        snapshotHash = nil,
        lastUpdateTime = 0,
        previousSnapshot = nil,
        tabScrollOffsets = {},
        
        panelEntity = nil,
        headerEntity = nil,
        tier1Entity = nil,
        scrollPaneEntity = nil,
        tabContentEntity = nil,
        tabBarEntity = nil,
        footerEntity = nil,
    }
end

-- Initialize on load
StatsPanel.init()

_G.__STATS_PANEL__ = StatsPanel
return StatsPanel
