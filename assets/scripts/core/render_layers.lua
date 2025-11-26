-- Centralized access to engine-created render layers.
-- The C++ side populates a global `layers` table; this module wraps it and
-- provides safe fallbacks for test runners that mock layers.
local render_layers = _G.layers or {}
_G.layers = render_layers

local function resolve(name)
    if render_layers[name] then
        return render_layers[name]
    end

    -- If the engine function is available, grab the actual layer handle.
    if type(_G.GetLayer) == "function" then
        local layer_obj = GetLayer(name)
        if layer_obj then
            render_layers[name] = layer_obj
            return layer_obj
        end
    end

    -- Fallback for headless/unit tests where layers are mocked.
    render_layers[name] = render_layers[name] or 0
    return render_layers[name]
end

render_layers.background = resolve("background")
render_layers.sprites    = resolve("sprites")
render_layers.ui         = resolve("ui")
render_layers.final      = resolve("final")

return render_layers
