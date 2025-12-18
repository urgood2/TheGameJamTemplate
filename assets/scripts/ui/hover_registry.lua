-- hover_registry.lua
-- Lightweight hover region tracking for immediate-mode Lua UIs
-- Uses double-buffer pattern: register regions during draw, resolve on update()

local HoverRegistry = {}

-- State
local pendingRegions = {}  -- Filled during draw calls
local activeRegions = {}   -- Swapped in on update()
local currentHover = nil   -- Currently hovered region (or nil)

-- Get mouse position with fallback chain
local function getMousePosition()
    if input then
        -- Prefer raw mouse input for screen-space consistency
        if input.getMousePos then
            local m = input.getMousePos()
            if m and m.x and m.y then
                return { x = m.x, y = m.y }
            end
        end
        if input.getMousePosition then
            local m = input.getMousePosition()
            if m and m.x and m.y then
                return { x = m.x, y = m.y }
            end
        end
    end
    return nil
end

-- Check if point is inside rectangle
local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Register a hover region (called during draw)
-- opts: { id, x, y, w, h, z, onHover, onUnhover, data }
function HoverRegistry.region(opts)
    if not opts.id then
        print("[HoverRegistry] Warning: region() called without id")
        return
    end

    table.insert(pendingRegions, {
        id = opts.id,
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 0,
        h = opts.h or 0,
        z = opts.z or 0,
        onHover = opts.onHover,
        onUnhover = opts.onUnhover,
        data = opts.data,
    })
end

-- Update hover state (called once per frame after all regions registered)
function HoverRegistry.update()
    -- Swap buffers
    activeRegions = pendingRegions
    pendingRegions = {}

    -- Sort by z descending (higher z = on top)
    table.sort(activeRegions, function(a, b)
        return a.z > b.z
    end)

    -- Get mouse position
    local mouse = getMousePosition()
    local newHover = nil

    if mouse then
        -- Find topmost region under cursor
        for _, region in ipairs(activeRegions) do
            if pointInRect(mouse.x, mouse.y, region.x, region.y, region.w, region.h) then
                newHover = region
                break  -- First hit wins (already sorted by z)
            end
        end
    end

    -- Fire callbacks on state change (compare by ID, not reference)
    local currentID = currentHover and currentHover.id or nil
    local newID = newHover and newHover.id or nil

    if currentID ~= newID then
        -- Unhover old region
        if currentHover and currentHover.onUnhover then
            local success, err = pcall(currentHover.onUnhover, currentHover.data)
            if not success then
                print("[HoverRegistry] onUnhover error for '" .. (currentHover.id or "?") .. "': " .. tostring(err))
            end
        end

        -- Hover new region
        if newHover and newHover.onHover then
            local success, err = pcall(newHover.onHover, newHover.data)
            if not success then
                print("[HoverRegistry] onHover error for '" .. (newHover.id or "?") .. "': " .. tostring(err))
            end
        end

        currentHover = newHover
    end
end

-- Force clear hover state (for state transitions)
function HoverRegistry.clear()
    -- Fire unhover callback if something is currently hovered
    if currentHover and currentHover.onUnhover then
        local success, err = pcall(currentHover.onUnhover, currentHover.data)
        if not success then
            print("[HoverRegistry] onUnhover error during clear for '" .. (currentHover.id or "?") .. "': " .. tostring(err))
        end
    end

    currentHover = nil
    activeRegions = {}
    pendingRegions = {}
end

return HoverRegistry
