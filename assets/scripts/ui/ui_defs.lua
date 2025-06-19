
-- build defs here


local ui_defs = {}

local currencyBox = {}
function ui_defs.getCurrencyInfoBox()
    -- shows the list of currencies and their amounts
    
    -- image + name + amount, amount accessed via lambda
    -- non-unlocked ones are greyed out
end


function ui_defs.getShowPurchasedBuildingBox()
    -- shows the purchased building (only one slot)
    
    -- just a inventory square slot with text above it that says "Purchased"
end

function ui_defs.getPossibleUpgradesBox()
    -- shows the possible upgrades purchasable (cycle)
    
    -- A small cycle thing which shows an image of the upgrade at the center. Hover to see more info.
end

function ui_defs.createNewTooltipBox()
    -- generates a new tooltip box. Should be saved and reused on hover.
end

function ui_defs.getSocialsBox()
    
end

function ui_defs.getMainMenuBox()
    
end

function ui_defs.getTooltipBox() 

    
end



return ui_defs