-- assets/scripts/core/procgen/pattern_builder.lua
-- Fluent builder pattern for Forma pattern operations
--
-- Usage:
--   local PatternBuilder = require("core.procgen.pattern_builder")
--   local pattern = PatternBuilder.new()
--     :square(80, 60)
--     :sample(400)
--     :automata("B5678/S45678", 50)
--     :keepLargest()
--     :build()

local vendor = require("core.procgen.vendor")
local forma = vendor.forma

local PatternBuilder = {}
PatternBuilder.__index = PatternBuilder

--- Create a new PatternBuilder
-- @return PatternBuilder
function PatternBuilder.new()
    local self = setmetatable({}, PatternBuilder)
    self._pattern = forma.pattern.new()
    self._domain = nil  -- Optional domain for operations
    return self
end

--- Create a rectangular domain
-- @param w number Width
-- @param h number Height
-- @return PatternBuilder self for chaining
function PatternBuilder:square(w, h)
    self._pattern = forma.primitives.square(w, h)
    self._domain = self._pattern
    return self
end

--- Create a circular domain
-- @param radius number Circle radius
-- @return PatternBuilder self for chaining
function PatternBuilder:circle(radius)
    self._pattern = forma.primitives.circle(radius)
    self._domain = self._pattern
    return self
end

--- Sample random cells from the current pattern
-- @param n number Number of cells to sample
-- @return PatternBuilder self for chaining
function PatternBuilder:sample(n)
    if self._pattern:size() > 0 then
        self._pattern = forma.pattern.sample(self._pattern, n)
    end
    return self
end

--- Apply cellular automata rules
-- @param ruleStr string Rule string like "B5678/S45678" (birth/survival)
-- @param iterations number Number of iterations
-- @return PatternBuilder self for chaining
function PatternBuilder:automata(ruleStr, iterations)
    if not self._domain then
        self._domain = self._pattern
    end

    -- Create forma rule object from string
    local neighbourhood = forma.neighbourhood.moore()
    local rule = forma.automata.rule(neighbourhood, ruleStr)

    -- Iterate the CA
    for _ = 1, iterations do
        self._pattern = forma.automata.iterate(self._pattern, self._domain, {rule})
    end

    return self
end

--- Apply morphological erosion
-- @return PatternBuilder self for chaining
function PatternBuilder:erode()
    local neighbourhood = forma.neighbourhood.moore()
    self._pattern = forma.pattern.erode(self._pattern, neighbourhood)
    return self
end

--- Apply morphological dilation
-- Expands the pattern by adding cells adjacent to existing cells
-- @return PatternBuilder self for chaining
function PatternBuilder:dilate()
    local neighbourhood = forma.neighbourhood.moore()
    self._pattern = forma.pattern.dilate(self._pattern, neighbourhood)
    return self
end

--- Keep only the largest connected component
-- @return PatternBuilder self for chaining
function PatternBuilder:keepLargest()
    local neighbourhood = forma.neighbourhood.moore()
    local segments = forma.pattern.connected_components(self._pattern, neighbourhood)
    if #segments > 0 then
        -- Find largest
        local largest = segments[1]
        for i = 2, #segments do
            if segments[i]:size() > largest:size() then
                largest = segments[i]
            end
        end
        self._pattern = largest
    end
    return self
end

--- Translate (shift) the pattern by an offset
-- @param dx number X offset
-- @param dy number Y offset
-- @return PatternBuilder self for chaining
function PatternBuilder:translate(dx, dy)
    self._pattern = forma.pattern.translate(self._pattern, dx, dy)
    return self
end

--- Build and return the final pattern
-- @return pattern The forma pattern
function PatternBuilder:build()
    return self._pattern
end

--- Get iterator over cells
-- @return function Iterator yielding cell objects
function PatternBuilder:cells()
    return self._pattern:cells()
end

--- Get connected components
-- @return table Array of pattern objects
function PatternBuilder:components()
    local neighbourhood = forma.neighbourhood.moore()
    return forma.pattern.connected_components(self._pattern, neighbourhood)
end

--- Reset the builder for reuse
-- @return PatternBuilder self for chaining
function PatternBuilder:reset()
    self._pattern = forma.pattern.new()
    self._domain = nil
    return self
end

return PatternBuilder
