--[[
================================================================================
popup.lua - Quick popup text helpers for common game feedback
================================================================================
Reduces boilerplate for showing damage numbers, healing, and floating text.

Usage:
    local popup = require("core.popup")

    -- Show healing number above entity
    popup.heal(entity, 25)

    -- Show damage number above entity
    popup.damage(entity, 50)

    -- Show custom text above entity
    popup.above(entity, "Level Up!", { color = "gold", duration = 2.0 })

    -- Show text at specific position
    popup.at(100, 200, "Hello!", { color = "white" })
]]

-- Singleton guard
if _G.__popup__ then return _G.__popup__ end

local popup = {}

-- Dependencies
local Q = require("core.Q")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

popup.defaults = {
    duration = 3.0,
    heal_color = "pastel_pink",
    damage_color = "red",
    mana_color = "pastel_blue",
    gold_color = "gold",
    xp_color = "pastel_purple",
    offset_y = -20,  -- Offset above entity center
}

--------------------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------------------

--- Show popup text at specific position
--- @param x number X position (center of text)
--- @param y number Y position (center of text)
--- @param text string Text to display
--- @param opts table|nil Options: { color, duration, effect }
function popup.at(x, y, text, opts)
    opts = opts or {}
    local duration = opts.duration or popup.defaults.duration
    local effect = opts.effect or ""

    if opts.color then
        effect = "color=" .. opts.color .. (effect ~= "" and ";" .. effect or "")
    end

    newTextPopup(tostring(text), x, y, duration, effect)
end

--- Show popup text above an entity
--- @param entity number Entity ID
--- @param text string Text to display
--- @param opts table|nil Options: { color, duration, effect, offset_y }
--- @return boolean success True if entity was valid and popup shown
function popup.above(entity, text, opts)
    local cx, cy = Q.visualCenter(entity)
    if not cx then return false end

    opts = opts or {}
    local offset_y = opts.offset_y or popup.defaults.offset_y

    popup.at(cx, cy + offset_y, text, opts)
    return true
end

--- Show popup text below an entity
--- @param entity number Entity ID
--- @param text string Text to display
--- @param opts table|nil Options: { color, duration, effect, offset_y }
--- @return boolean success True if entity was valid and popup shown
function popup.below(entity, text, opts)
    local cx, cy = Q.visualCenter(entity)
    if not cx then return false end

    local _, h = Q.size(entity)
    h = h or 32

    opts = opts or {}
    local offset_y = opts.offset_y or math.abs(popup.defaults.offset_y)

    popup.at(cx, cy + h/2 + offset_y, text, opts)
    return true
end

--------------------------------------------------------------------------------
-- Convenience Functions for Common Game Feedback
--------------------------------------------------------------------------------

--- Show healing number above entity
--- @param entity number Entity ID
--- @param amount number Healing amount
--- @param opts table|nil Additional options
--- @return boolean success
function popup.heal(entity, amount, opts)
    opts = opts or {}
    opts.color = opts.color or popup.defaults.heal_color
    return popup.above(entity, "+ " .. tostring(amount), opts)
end

--- Show damage number above entity
--- @param entity number Entity ID
--- @param amount number Damage amount
--- @param opts table|nil Additional options (color, critical)
--- @return boolean success
function popup.damage(entity, amount, opts)
    opts = opts or {}
    opts.color = opts.color or popup.defaults.damage_color

    local text = "- " .. tostring(amount)
    if opts.critical then
        text = text .. "!"
        opts.effect = (opts.effect or "") .. ";pop=0.2"
    end

    return popup.above(entity, text, opts)
end

--- Show mana change above entity
--- @param entity number Entity ID
--- @param amount number Mana amount (positive = gain, negative = cost)
--- @param opts table|nil Additional options
--- @return boolean success
function popup.mana(entity, amount, opts)
    opts = opts or {}
    opts.color = opts.color or popup.defaults.mana_color

    local prefix = amount >= 0 and "+ " or ""
    return popup.above(entity, prefix .. tostring(amount) .. " MP", opts)
end

--- Show gold change above entity
--- @param entity number Entity ID
--- @param amount number Gold amount
--- @param opts table|nil Additional options
--- @return boolean success
function popup.gold(entity, amount, opts)
    opts = opts or {}
    opts.color = opts.color or popup.defaults.gold_color

    local prefix = amount >= 0 and "+ " or ""
    return popup.above(entity, prefix .. tostring(amount) .. " G", opts)
end

--- Show XP gain above entity
--- @param entity number Entity ID
--- @param amount number XP amount
--- @param opts table|nil Additional options
--- @return boolean success
function popup.xp(entity, amount, opts)
    opts = opts or {}
    opts.color = opts.color or popup.defaults.xp_color
    return popup.above(entity, "+ " .. tostring(amount) .. " XP", opts)
end

--- Show status text above entity (e.g., "Stunned!", "Immune!")
--- @param entity number Entity ID
--- @param status string Status text
--- @param opts table|nil Additional options
--- @return boolean success
function popup.status(entity, status, opts)
    opts = opts or {}
    opts.duration = opts.duration or 1.5
    return popup.above(entity, status, opts)
end

--- Show miss text above entity
--- @param entity number Entity ID
--- @param opts table|nil Additional options
--- @return boolean success
function popup.miss(entity, opts)
    opts = opts or {}
    opts.color = opts.color or "gray"
    opts.duration = opts.duration or 1.0
    return popup.above(entity, "Miss!", opts)
end

--- Show blocked text above entity
--- @param entity number Entity ID
--- @param opts table|nil Additional options
--- @return boolean success
function popup.blocked(entity, opts)
    opts = opts or {}
    opts.color = opts.color or "gray"
    opts.duration = opts.duration or 1.0
    return popup.above(entity, "Blocked!", opts)
end

--- Show critical hit indicator
--- @param entity number Entity ID
--- @param amount number Damage amount
--- @param opts table|nil Additional options
--- @return boolean success
function popup.critical(entity, amount, opts)
    opts = opts or {}
    opts.critical = true
    opts.color = opts.color or "gold"
    return popup.damage(entity, amount, opts)
end

_G.__popup__ = popup
return popup
