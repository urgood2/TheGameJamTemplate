-- Shared UI scaling helpers.
-- Base UI measurements were authored at sprite scale 2.0 (player_inventory baseline).
-- We scale them to the current UI sprite scale (2.5) for consistent sizing.

local UiScale = {}

UiScale.BASE_SPRITE_SCALE = 2.0
UiScale.SPRITE_SCALE = 2.5
UiScale.UI_SCALE = UiScale.SPRITE_SCALE / UiScale.BASE_SPRITE_SCALE

local function round(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

-- Scale a UI pixel value authored at BASE_SPRITE_SCALE.
function UiScale.ui(value)
    return round(value * UiScale.UI_SCALE)
end

function UiScale.ui_float(value)
    return value * UiScale.UI_SCALE
end

-- Scale a sprite dimension from source pixels.
function UiScale.sprite(value)
    return round(value * UiScale.SPRITE_SCALE)
end

function UiScale.sprite_float(value)
    return value * UiScale.SPRITE_SCALE
end

-- Expose as globals for convenience in UI modules.
_G.UI_SCALE = UiScale.UI_SCALE
_G.UI_SPRITE_SCALE = UiScale.SPRITE_SCALE

return UiScale
