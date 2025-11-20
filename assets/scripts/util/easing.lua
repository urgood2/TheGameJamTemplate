-- easing.lua
local PI = math.pi
local sin, cos, sqrt, abs, pow = math.sin, math.cos, math.sqrt, math.abs, function (x, y) return x ^ y end
    

-- Fast, stable numeric derivative on [0,1]
local function dE(E, t, eps)
    eps = eps or 1e-4
    local t1 = (t <= eps) and 0.0 or (t - eps)
    local t2 = (t >= 1 - eps) and 1.0 or (t + eps)
    return (E(t2) - E(t1)) / (t2 - t1)
end

-- Helper to wrap f with a numeric derivative
local function make(f) return { f = f, d = function(t) return dE(f, t) end } end

local Easing = {
    -- Previously used names (kept for compatibility)
    cubic     = make(function(t) return 1 - (1 - t)^3 end),
    quadratic = make(function(t) return 1 - (1 - t)^2 end),
    linear    = make(function(t) return t end),

    -- === Sine ===
    inSine    = make(function(t) return sin(0.5 * PI * t) end),
    outSine   = make(function(t) return 1 + sin(0.5 * PI * (t - 1)) end),
    inOutSine = make(function(t) return 0.5 * (1 + sin(PI * (t - 0.5))) end),

    -- === Quad ===
    inQuad    = make(function(t) return t * t end),
    outQuad   = make(function(t) return t * (2 - t) end),
    inOutQuad = make(function(t) return (t < 0.5) and (2 * t * t) or (t * (4 - 2 * t) - 1) end),

    -- === Cubic ===
    inCubic    = make(function(t) return t * t * t end),
    outCubic   = make(function(t) t = t - 1; return 1 + t * t * t end),
    inOutCubic = make(function(t)
        if t < 0.5 then return 4 * t * t * t
        else t = t - 1; return 1 + (t) * (2 * (t)) * (2 * t) end
    end),

    -- === Quart ===
    inQuart    = make(function(t) t = t * t; return t * t end),
    outQuart   = make(function(t) t = (t - 1) * (t - 1); return 1 - t * t end),
    inOutQuart = make(function(t)
        if t < 0.5 then t = t * t; return 8 * t * t
        else t = (t - 1) * (t - 1); return 1 - 8 * t * t end
    end),

    -- === Quint ===
    inQuint    = make(function(t) local t2 = t * t; return t * t2 * t2 end),
    outQuint   = make(function(t) local t2 = (t - 1) * (t - 1); return 1 + (t - 1) * t2 * t2 end),
    inOutQuint = make(function(t)
        local t2
        if t < 0.5 then t2 = t * t; return 16 * t * t2 * t2
        else t2 = (t - 1) * (t - 1); return 1 + 16 * (t - 1) * t2 * t2 end
    end),

    -- === Expo ===
    inExpo    = make(function(t) return (pow(2, 8 * t) - 1) / 255 end),
    outExpo   = make(function(t) return 1 - pow(2, -8 * t) end),
    inOutExpo = make(function(t)
        if t < 0.5 then return (pow(2, 16 * t) - 1) / 510
        else return 1 - 0.5 * pow(2, -16 * (t - 0.5)) end
    end),

    -- === Circ ===
    inCirc    = make(function(t) return 1 - sqrt(1 - t) end),
    outCirc   = make(function(t) return sqrt(t) end),
    inOutCirc = make(function(t)
        if t < 0.5 then return 0.5 * (1 - sqrt(1 - 2 * t))
        else return 0.5 * (1 + sqrt(2 * t - 1)) end
    end),

    -- === Back ===
    inBack    = make(function(t) return t * t * (2.70158 * t - 1.70158) end),
    outBack   = make(function(t) t = t - 1; return 1 + t * t * (2.70158 * t + 1.70158) end),
    inOutBack = make(function(t)
        if t < 0.5 then return t * t * (7 * t - 2.5) * 2
        else t = t - 1; return 1 + t * t * 2 * (7 * t + 2.5) end
    end),

    -- === Elastic ===
    inElastic = make(function(t) local t2 = t * t; return t2 * t2 * sin(t * PI * 4.5) end),
    outElastic= make(function(t) local u = (t - 1); local t2 = u * u; return 1 - t2 * t2 * cos(t * PI * 4.5) end),
    inOutElastic = make(function(t)
        if t < 0.45 then local t2 = t * t; return 8 * t2 * t2 * sin(t * PI * 9)
        elseif t < 0.55 then return 0.5 + 0.75 * sin(t * PI * 4)
        else local u = (t - 1); local t2 = u * u; return 1 - 8 * t2 * t2 * sin(t * PI * 9) end
    end),

    -- === Bounce ===
    inBounce  = make(function(t) return pow(2, 6 * (t - 1)) * abs(sin(t * PI * 3.5)) end),
    outBounce = make(function(t) return 1 - pow(2, -6 * t) * abs(cos(t * PI * 3.5)) end),
    inOutBounce = make(function(t)
        if t < 0.5 then return 8 * pow(2, 8 * (t - 1)) * abs(sin(t * PI * 7))
        else return 1 - 8 * pow(2, -8 * t) * abs(sin(t * PI * 7)) end
    end),
}

return Easing
