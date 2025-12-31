local TooltipEffects = {}

TooltipEffects.ENTRANCE = {
    pop_in = "pop=0.2,0.05,in",
    slide_left = "slide=0.25,0.03,in,l",
    slide_right = "slide=0.25,0.03,in,r",
    slide_up = "slide=0.25,0.03,in,b",
    bounce = "bounce=500,-12,0.4,0.03",
    scramble = "scramble=0.3,0.05,20",
}

TooltipEffects.PERSISTENT = {
    gentle_float = "float=2,3,0.2",
    pulse = "pulse=0.95,1.05,2,0.1",
    wiggle = "wiggle=8,5,0.5",
    rainbow = "rainbow=30,5,60",
    highlight = "highlight=3,0.3,0.3,right",
}

TooltipEffects.PRESETS = {
    default = "pop=0.15,0.03,in",
    card = "slide=0.2,0.02,in,l",
    trigger = "bounce=500,-10,0.35,0.02",
    joker = "pop=0.2,0.04,in;float=1.5,2,0.15",
    wand = "slide=0.18,0.02,in,r",
    stats = "pop=0.12,0.02,in",
    legendary = "pop=0.25,0.05,in;pulse=0.95,1.05,1.5,0.08;rainbow=40,8,0",
    epic = "slide=0.2,0.03,in,l;highlight=2.5,0.25,0.25,right,bleed",
    status = "pop=0.15,0.02,in;wiggle=6,3,0.3",
}

function TooltipEffects.get(contentType)
    return TooltipEffects.PRESETS[contentType] or TooltipEffects.PRESETS.default
end

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

return TooltipEffects
