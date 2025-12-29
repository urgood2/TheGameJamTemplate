local effects = require("ui.text_effects")

effects.register("typewriter", function(ctx, dt, char, speed, cursor)
    speed = tonumber(speed) or 20
    cursor = cursor ~= false
    
    char.effect_data.typewriter = char.effect_data.typewriter or {}
    local data = char.effect_data.typewriter
    
    if not data.startTime then
        data.startTime = ctx.elapsed or 0
    end
    
    local charDelay = (char.i - 1) / speed
    local localTime = (ctx.elapsed or 0) - data.startTime
    
    if localTime < charDelay then
        char.alpha = 0
        return
    end
    
    local revealProgress = math.min(1, (localTime - charDelay) * 10)
    char.alpha = math.floor(255 * revealProgress)
    
    if revealProgress < 1 then
        char.ox = (1 - revealProgress) * 3
    end
    
    if cursor and char.i == ctx.char_count then
        local cursorBlink = math.sin((ctx.elapsed or 0) * 8) > 0
        if cursorBlink and localTime >= charDelay then
            char.suffix = "_"
        else
            char.suffix = ""
        end
    end
end)

effects.register("reveal", function(ctx, dt, char, duration, stagger)
    duration = tonumber(duration) or 0.5
    stagger = tonumber(stagger) or 0.02
    
    char.effect_data.reveal = char.effect_data.reveal or {}
    local data = char.effect_data.reveal
    
    if not data.startTime then
        data.startTime = ctx.elapsed or 0
    end
    
    local charDelay = (char.i - 1) * stagger
    local localTime = (ctx.elapsed or 0) - data.startTime - charDelay
    
    if localTime < 0 then
        char.alpha = 0
        char.scaleX = 0.5
        char.scaleY = 0.5
        return
    end
    
    local progress = math.min(1, localTime / duration)
    local eased = 1 - (1 - progress) * (1 - progress)
    
    char.alpha = math.floor(255 * eased)
    char.scaleX = 0.5 + 0.5 * eased
    char.scaleY = 0.5 + 0.5 * eased
    
    if progress < 1 then
        char.oy = (1 - eased) * -10
    end
    
    if progress >= 1 then
        char.effect_finished = char.effect_finished or {}
        char.effect_finished.reveal = true
    end
end)

effects.register("dialogue_pop", function(ctx, dt, char, delay, bounce)
    delay = tonumber(delay) or 0.03
    bounce = tonumber(bounce) or 0.2
    
    char.effect_data.dialogue_pop = char.effect_data.dialogue_pop or {}
    local data = char.effect_data.dialogue_pop
    
    if not data.startTime then
        data.startTime = ctx.elapsed or 0
    end
    
    local charDelay = (char.i - 1) * delay
    local localTime = (ctx.elapsed or 0) - data.startTime - charDelay
    
    if localTime < 0 then
        char.alpha = 0
        char.scaleX = 0
        char.scaleY = 0
        return
    end
    
    local duration = 0.15
    local progress = math.min(1, localTime / duration)
    
    local scale
    if progress < 0.5 then
        scale = progress * 2 * (1 + bounce)
    else
        local t = (progress - 0.5) * 2
        scale = (1 + bounce) - bounce * t
    end
    
    char.alpha = 255
    char.scaleX = scale
    char.scaleY = scale
    
    if progress >= 1 then
        char.effect_finished = char.effect_finished or {}
        char.effect_finished.dialogue_pop = true
    end
end)

effects.register("talk_bounce", function(ctx, dt, char, amp, speed)
    amp = tonumber(amp) or 2
    speed = tonumber(speed) or 8
    
    local phase = (ctx.elapsed or 0) * speed + (char.i * 0.3)
    char.oy = (char.oy or 0) + math.sin(phase) * amp
end)

return effects
