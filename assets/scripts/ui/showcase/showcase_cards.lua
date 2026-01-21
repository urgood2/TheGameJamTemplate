--[[
================================================================================
SHOWCASE CARDS
================================================================================
UI card builders for the Feature Showcase.
Provides consistent layout and badge rendering for each category.

Uses dsl.strict for UI building. Helper functions work standalone.
================================================================================
]]

local ShowcaseCards = {}

-- Try to load DSL (may not be available in standalone tests)
local dsl = nil
local function getDsl()
    if dsl then return dsl end
    local ok, mod = pcall(require, "ui.ui_syntax_sugar")
    if ok then
        dsl = mod
    end
    return dsl
end

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS (standalone, no DSL required)
--------------------------------------------------------------------------------

--- Safe get a value with fallback for nil
--- @param value any Value to check
--- @param fallback any Fallback if value is nil
--- @return any Value or fallback
function ShowcaseCards.safeGet(value, fallback)
    if value == nil then
        return fallback
    end
    return value
end

--- Format effects array into readable string
--- @param effects table|nil Effects array from data
--- @return string Formatted effects string
function ShowcaseCards.formatEffects(effects)
    if not effects or type(effects) ~= "table" or #effects == 0 then
        return "No effects"
    end

    local parts = {}
    for _, eff in ipairs(effects) do
        if eff.type == "stat_buff" then
            local stat = eff.stat or "unknown"
            local value = eff.value or 0
            -- Format nicely: fire_modifier_pct -> Fire +15%
            local displayStat = stat:gsub("_pct$", ""):gsub("_", " ")
            displayStat = displayStat:gsub("^%l", string.upper)
            if stat:match("_pct$") then
                parts[#parts + 1] = displayStat .. " +" .. value .. "%"
            else
                parts[#parts + 1] = displayStat .. " +" .. value
            end
        elseif eff.type == "blessing" then
            local name = eff.name or eff.id or "Blessing"
            local cooldown = eff.cooldown or 0
            parts[#parts + 1] = name .. " (" .. cooldown .. "s CD)"
        elseif eff.type == "rule_change" then
            parts[#parts + 1] = eff.desc or "Rule change"
        elseif eff.type == "proc" then
            local trigger = eff.trigger or "event"
            local effect = eff.effect or "action"
            parts[#parts + 1] = trigger .. " -> " .. effect
        end
    end

    if #parts == 0 then
        return "No readable effects"
    end

    return table.concat(parts, ", ")
end

--- Format stat_mods table into readable string
--- @param stat_mods table|nil Stat mods from status effect
--- @return string Formatted stats string
function ShowcaseCards.formatStatMods(stat_mods)
    if not stat_mods or type(stat_mods) ~= "table" then
        return ""
    end

    local parts = {}
    for stat, value in pairs(stat_mods) do
        local displayStat = stat:gsub("_pct$", ""):gsub("_", " ")
        displayStat = displayStat:gsub("^%l", string.upper)
        local sign = value >= 0 and "+" or ""
        if stat:match("_pct$") then
            parts[#parts + 1] = displayStat .. " " .. sign .. value .. "%"
        else
            parts[#parts + 1] = displayStat .. " " .. sign .. value
        end
    end

    return table.concat(parts, ", ")
end

--- Render a pass/fail badge with visual indicator
--- @param ok boolean Pass or fail status
--- @return table Badge specification (DSL-compatible or plain data)
function ShowcaseCards.renderBadge(ok)
    local d = getDsl()
    -- Use visual symbols for clarity (ASCII-safe)
    local symbol = ok and "[OK]" or "[X]"
    local color = ok and "green" or "red"

    if d and d.strict then
        return d.strict.text(symbol, { fontSize = 12, color = color })
    else
        -- Return plain data for standalone testing
        return {
            text = symbol,
            color = color,
            ok = ok,
        }
    end
end

--------------------------------------------------------------------------------
-- CARD BUILDERS (require DSL for full functionality)
--------------------------------------------------------------------------------

-- Card dimensions (consistent sizing)
local CARD_WIDTH = 280
local CARD_HEIGHT = 120

ShowcaseCards.CARD_WIDTH = CARD_WIDTH
ShowcaseCards.CARD_HEIGHT = CARD_HEIGHT

local function appendErrorLine(d, children, ok, err)
    if ok or not err or err == "" then
        return
    end
    children[#children + 1] = d.strict.text("Issue: " .. err, { fontSize = 10, color = "salmon" })
end

--- Build a God or Class card
--- @param data table God/class definition
--- @param ok boolean Validation status
--- @param err string|nil Validation error
--- @return table DSL node or nil
function ShowcaseCards.buildGodClassCard(data, ok, err)
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - card building requires ui_syntax_sugar")
    end

    local typeLabel = data.type == "god" and "God" or "Class"
    local effectsStr = ShowcaseCards.formatEffects(data.effects)

    local card = d.strict.vbox {
        config = {
            padding = 8,
            spacing = 4,
            minWidth = CARD_WIDTH,
            minHeight = CARD_HEIGHT,
            color = "blackberry",
        },
        children = {
            -- Header row: name + badge
            d.strict.hbox {
                config = { spacing = 8 },
                children = {
                    d.strict.text(ShowcaseCards.safeGet(data.name, data.id or "Unknown"), {
                        fontSize = 16,
                        color = "white",
                    }),
                    ShowcaseCards.renderBadge(ok),
                },
            },
            -- Type label
            d.strict.text(typeLabel, { fontSize = 12, color = "gray" }),
            -- Effects summary
            d.strict.text(effectsStr, { fontSize = 11, color = "lightgray" }),
        },
    }
    appendErrorLine(d, card.children, ok, err)
    return card
end

--- Build a Skill card
--- @param data table Skill definition
--- @param ok boolean Validation status
--- @param err string|nil Validation error
--- @return table DSL node
function ShowcaseCards.buildSkillCard(data, ok, err)
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - card building requires ui_syntax_sugar")
    end

    local effectsStr = ShowcaseCards.formatEffects(data.effects)
    local elementColor = {
        fire = "orange",
        ice = "cyan",
        lightning = "yellow",
        void = "purple",
        universal = "white",
    }
    local elemColor = elementColor[data.element] or "white"

    local card = d.strict.vbox {
        config = {
            padding = 8,
            spacing = 4,
            minWidth = CARD_WIDTH,
            minHeight = CARD_HEIGHT,
            color = "blackberry",
        },
        children = {
            -- Header row: name + badge
            d.strict.hbox {
                config = { spacing = 8 },
                children = {
                    d.strict.text(ShowcaseCards.safeGet(data.name, data.id or "Unknown"), {
                        fontSize = 16,
                        color = "white",
                    }),
                    ShowcaseCards.renderBadge(ok),
                },
            },
            -- Element label
            d.strict.text(ShowcaseCards.safeGet(data.element, "unknown"):upper(), {
                fontSize = 12,
                color = elemColor,
            }),
            -- Effects summary
            d.strict.text(effectsStr, { fontSize = 11, color = "lightgray" }),
        },
    }
    appendErrorLine(d, card.children, ok, err)
    return card
end

--- Build an Artifact card
--- @param data table Artifact definition
--- @param ok boolean Validation status
--- @param err string|nil Validation error
--- @return table DSL node
function ShowcaseCards.buildArtifactCard(data, ok, err)
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - card building requires ui_syntax_sugar")
    end

    local rarityColor = {
        Common = "white",
        Uncommon = "green",
        Rare = "blue",
        Epic = "purple",
    }
    local rColor = rarityColor[data.rarity] or "white"

    local card = d.strict.vbox {
        config = {
            padding = 8,
            spacing = 4,
            minWidth = CARD_WIDTH,
            minHeight = CARD_HEIGHT,
            color = "blackberry",
        },
        children = {
            -- Header row: name + badge
            d.strict.hbox {
                config = { spacing = 8 },
                children = {
                    d.strict.text(ShowcaseCards.safeGet(data.name, data.id or "Unknown"), {
                        fontSize = 16,
                        color = "white",
                    }),
                    ShowcaseCards.renderBadge(ok),
                },
            },
            -- Rarity label
            d.strict.text(ShowcaseCards.safeGet(data.rarity, "Unknown"), {
                fontSize = 12,
                color = rColor,
            }),
            -- Description (truncate long text)
            (function()
                local desc = ShowcaseCards.safeGet(data.description, "No description")
                local truncated = #desc > 60 and (desc:sub(1, 60) .. "...") or desc
                return d.strict.text(truncated, { fontSize = 11, color = "lightgray" })
            end)(),
        },
    }
    appendErrorLine(d, card.children, ok, err)
    return card
end

--- Build a Wand card
--- @param data table Wand definition
--- @param ok boolean Validation status
--- @param err string|nil Validation error
--- @return table DSL node
function ShowcaseCards.buildWandCard(data, ok, err)
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - card building requires ui_syntax_sugar")
    end

    local triggerDisplay = (data.trigger_type or "unknown"):gsub("_", " ")
    local manaInfo = "Mana: " .. ShowcaseCards.safeGet(data.mana_max, 0)
    local castInfo = "Cast Block: " .. ShowcaseCards.safeGet(data.cast_block_size, 1)

    local card = d.strict.vbox {
        config = {
            padding = 8,
            spacing = 4,
            minWidth = CARD_WIDTH,
            minHeight = CARD_HEIGHT,
            color = "blackberry",
        },
        children = {
            -- Header row: name + badge
            d.strict.hbox {
                config = { spacing = 8 },
                children = {
                    d.strict.text(ShowcaseCards.safeGet(data.name, data.id or "Unknown"), {
                        fontSize = 16,
                        color = "white",
                    }),
                    ShowcaseCards.renderBadge(ok),
                },
            },
            -- Trigger type
            d.strict.text("Trigger: " .. triggerDisplay, { fontSize = 12, color = "gold" }),
            -- Mana and cast info
            d.strict.hbox {
                config = { spacing = 16 },
                children = {
                    d.strict.text(manaInfo, { fontSize = 11, color = "cyan" }),
                    d.strict.text(castInfo, { fontSize = 11, color = "lightgray" }),
                },
            },
        },
    }
    appendErrorLine(d, card.children, ok, err)
    return card
end

--- Build a Status Effect card
--- @param data table Status effect definition
--- @param ok boolean Validation status
--- @param err string|nil Validation error
--- @return table DSL node
function ShowcaseCards.buildStatusEffectCard(data, ok, err)
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - card building requires ui_syntax_sugar")
    end

    -- Determine effect type
    local effectType = "Unknown"
    if data.buff_type then
        effectType = "Buff"
    elseif data.dot_type then
        effectType = "DoT"
    elseif data.is_mark then
        effectType = "Mark"
    end

    local durationStr = data.duration == 0 and "Permanent" or (data.duration .. "s")
    local statsStr = ShowcaseCards.formatStatMods(data.stat_mods)

    local card = d.strict.vbox {
        config = {
            padding = 8,
            spacing = 4,
            minWidth = CARD_WIDTH,
            minHeight = CARD_HEIGHT,
            color = "blackberry",
        },
        children = {
            -- Header row: name + badge
            d.strict.hbox {
                config = { spacing = 8 },
                children = {
                    d.strict.text(ShowcaseCards.safeGet(data.id, "Unknown"), {
                        fontSize = 16,
                        color = "white",
                    }),
                    ShowcaseCards.renderBadge(ok),
                },
            },
            -- Type and duration
            d.strict.hbox {
                config = { spacing = 16 },
                children = {
                    d.strict.text(effectType, { fontSize = 12, color = "gold" }),
                    d.strict.text("Duration: " .. durationStr, { fontSize = 12, color = "lightgray" }),
                },
            },
            -- Stats if available
            d.strict.text(statsStr ~= "" and statsStr or "Special effect", {
                fontSize = 11,
                color = "lightgray",
            }),
        },
    }
    appendErrorLine(d, card.children, ok, err)
    return card
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Get the card builder function for a category
--- @param category string Category name
--- @return function Card builder function
function ShowcaseCards.getBuilderForCategory(category)
    local builders = {
        gods_classes = ShowcaseCards.buildGodClassCard,
        skills = ShowcaseCards.buildSkillCard,
        artifacts = ShowcaseCards.buildArtifactCard,
        wands = ShowcaseCards.buildWandCard,
        status_effects = ShowcaseCards.buildStatusEffectCard,
    }
    return builders[category]
end

return ShowcaseCards
