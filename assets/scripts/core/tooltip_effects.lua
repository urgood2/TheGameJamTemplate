local TooltipEffects = {}

--------------------------------------------------------------------------------
-- ENTRANCE EFFECTS (one-time animations when tooltip appears)
--------------------------------------------------------------------------------
TooltipEffects.ENTRANCE = {
    pop_in = "pop=0.2,0.05,in",
    slide_left = "slide=0.25,0.03,in,l",
    slide_right = "slide=0.25,0.03,in,r",
    slide_up = "slide=0.25,0.03,in,b",
    bounce = "bounce=500,-12,0.4,0.03",
    scramble = "scramble=0.3,0.05,20",
}

--------------------------------------------------------------------------------
-- PERSISTENT EFFECTS (continuous animations)
--------------------------------------------------------------------------------
TooltipEffects.PERSISTENT = {
    gentle_float = "float=2,3,0.2",
    pulse = "pulse=0.95,1.05,2,0.1",
    wiggle = "wiggle=8,5,0.5",
    rainbow = "rainbow=30,5,60",
    highlight = "highlight=3,0.3,0.3,right",
    shimmer = "highlight=4,0.4,0.15,right,bleed",
    glow_pulse = "pulse=0.92,1.08,1.2,0.05",
}

--------------------------------------------------------------------------------
-- RARITY COLORS (for card names)
--------------------------------------------------------------------------------
TooltipEffects.RARITY_COLORS = {
    common = "white",
    uncommon = "lime",
    rare = "cyan",
    epic = "purple",
    legendary = "gold",
    mythic = "magenta",
}

--------------------------------------------------------------------------------
-- PRESETS (combined entrance + persistent effects)
--------------------------------------------------------------------------------
TooltipEffects.PRESETS = {
    -- Generic content types
    default = "pop=0.15,0.03,in",
    card = "pop=0.18,0.025,in",
    trigger = "bounce=500,-10,0.35,0.02",
    joker = "pop=0.2,0.04,in;float=1.5,2,0.15",
    wand = "slide=0.18,0.02,in,r",
    stats = "pop=0.12,0.02,in",
    status = "pop=0.15,0.02,in;wiggle=6,3,0.3",

    -- Rarity-based effects (increasingly dramatic)
    common = "pop=0.15,0.02,in",
    uncommon = "pop=0.18,0.025,in;highlight=3,0.15,0.2,right",
    rare = "pop=0.2,0.03,in;highlight=2.5,0.25,0.15,right,bleed;pulse=0.97,1.03,2,0.08",
    epic = "slide=0.22,0.035,in,l;highlight=2,0.35,0.12,right,bleed;pulse=0.95,1.05,1.5,0.06",
    legendary = "pop=0.25,0.04,in;rainbow=50,6,0;pulse=0.93,1.07,1.2,0.05",
    mythic = "scramble=0.25,0.03,12;rainbow=80,8,0;pulse=0.9,1.1,1,0.04;wiggle=4,2,0.3",
}

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------

--- Get effect string for a content type
--- @param contentType string Preset name (e.g., "legendary", "card")
--- @return string Effect string for C++ text system
function TooltipEffects.get(contentType)
    return TooltipEffects.PRESETS[contentType] or TooltipEffects.PRESETS.default
end

--- Get rarity color name
--- @param rarity string Rarity name (e.g., "legendary")
--- @return string Color name
function TooltipEffects.getColor(rarity)
    return TooltipEffects.RARITY_COLORS[rarity:lower()] or "apricot_cream"
end

--- Combine multiple effects into a single string
--- @vararg string Effect names or raw effect strings
--- @return string Combined effect string
function TooltipEffects.combine(...)
    local effects = {}
    for _, effect in ipairs({...}) do
        local resolved = TooltipEffects.PRESETS[effect]
            or TooltipEffects.ENTRANCE[effect]
            or TooltipEffects.PERSISTENT[effect]
            or effect
        table.insert(effects, resolved)
    end
    return table.concat(effects, ";")
end

--- Build a complete styled text string with effects and color
--- @param text string The text to style
--- @param rarity string? Rarity for effects/color (e.g., "legendary")
--- @param extraEffects string? Additional effects to append
--- @return string Styled text for C++ text system
function TooltipEffects.styledText(text, rarity, extraEffects)
    rarity = rarity and rarity:lower() or "common"
    local effects = TooltipEffects.get(rarity)
    local color = TooltipEffects.getColor(rarity)

    if extraEffects then
        effects = effects .. ";" .. extraEffects
    end

    return string.format("[%s](%s;color=%s)", text, effects, color)
end

return TooltipEffects
