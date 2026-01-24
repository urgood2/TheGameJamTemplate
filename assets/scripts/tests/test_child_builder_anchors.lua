-- assets/scripts/tests/test_child_builder_anchors.lua
--[[
================================================================================
TEST: ChildBuilder Anchor API
================================================================================
Tests for the enhanced ChildBuilder positioning API that exposes the C++
alignment system via fluent methods like :anchor(), :inside(), :gap().

These tests follow TDD - written BEFORE implementation.
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

-- Load engine mocks first
require("tests.mocks.engine_mock")

-- Fix the AlignmentFlag mock to match actual C++ values
_G.AlignmentFlag = {
    NONE = 0,
    HORIZONTAL_LEFT = 1,
    HORIZONTAL_CENTER = 2,
    HORIZONTAL_RIGHT = 4,
    VERTICAL_TOP = 8,
    VERTICAL_CENTER = 16,
    VERTICAL_BOTTOM = 32,
    ALIGN_TO_INNER_EDGES = 64,
}

-- Fix bit library to use proper bitwise OR
_G.bit = _G.bit or {}
_G.bit.bor = function(...)
    local result = 0
    for i = 1, select('#', ...) do
        local v = select(i, ...) or 0
        -- Simple bitwise OR simulation for small positive integers
        -- This works for our use case with alignment flags
        for b = 0, 7 do
            local bit_val = 2^b
            if (v % (2 * bit_val) >= bit_val) or (result % (2 * bit_val) >= bit_val) then
                if result % (2 * bit_val) < bit_val then
                    result = result + bit_val
                end
            end
        end
    end
    return result
end

_G.bit.band = function(a, b)
    local result = 0
    a, b = a or 0, b or 0
    for i = 0, 7 do
        local bit_val = 2^i
        if (a % (2 * bit_val) >= bit_val) and (b % (2 * bit_val) >= bit_val) then
            result = result + bit_val
        end
    end
    return result
end

-- Mock InheritedPropertiesType and InheritedPropertiesSync
_G.InheritedPropertiesType = {
    RoleRoot = 0,
    RoleInheritor = 1,
    RoleCarbonCopy = 2,
    PermanentAttachment = 3,
}

_G.InheritedPropertiesSync = {
    None = 0,
    Strong = 1,
    Weak = 2,
}

-- Mock Vector2
_G.Vector2 = function(t)
    return { x = t.x or 0, y = t.y or 0 }
end

-- Mock transform module
local _last_assign_role_call = nil
local _last_configure_alignment_call = nil

_G.transform = {
    AssignRole = function(reg, entity, roleType, parent, locationBond, sizeBond, rotationBond, scaleBond, offset)
        _last_assign_role_call = {
            entity = entity,
            roleType = roleType,
            parent = parent,
            locationBond = locationBond,
            sizeBond = sizeBond,
            rotationBond = rotationBond,
            scaleBond = scaleBond,
            offset = offset,
        }
    end,
    ConfigureAlignment = function(reg, entity, isChild, parent, xy, wh, rotation, scale, alignment, offset)
        _last_configure_alignment_call = {
            entity = entity,
            isChild = isChild,
            parent = parent,
            xy = xy,
            wh = wh,
            rotation = rotation,
            scale = scale,
            alignment = alignment,
            offset = offset,
        }
    end,
}

-- Mock entt_null
_G.entt_null = -1

-- Mock component types
_G.GameObject = { _type = "GameObject" }
_G.InheritedProperties = { _type = "InheritedProperties" }
_G.Transform = { _type = "Transform" }

-- Enhanced component cache for tests
local _components = {}
_G.component_cache = {
    get = function(entity, compType)
        if not _components[entity] then return nil end
        return _components[entity][compType]
    end,
    set = function(entity, compType, value)
        if not _components[entity] then _components[entity] = {} end
        _components[entity][compType] = value
    end,
    _reset = function()
        _components = {}
        _last_assign_role_call = nil
        _last_configure_alignment_call = nil
    end,
}

-- Helper to get last calls
local function getLastAssignRoleCall()
    return _last_assign_role_call
end

local function getLastConfigureAlignmentCall()
    return _last_configure_alignment_call
end

local function resetMocks()
    _components = {}
    _last_assign_role_call = nil
    _last_configure_alignment_call = nil
end

-- Load test runner
local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- STEP 1: Alignment State Fields
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: State Fields", function()
    t.before_each(function()
        resetMocks()
        -- Clear cached module
        package.loaded["core.child_builder"] = nil
    end)

    t.it("for_entity() initializes _alignment to 0", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder._alignment).to_be(0)
    end)

    t.it("for_entity() initializes _alignInside to false", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder._alignInside).to_be(false)
    end)

    t.it("for_entity() initializes _gap to {x=0, y=0}", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder._gap).to_equal({ x = 0, y = 0 })
    end)
end)

--------------------------------------------------------------------------------
-- STEP 2: String-Based :anchor() Method
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: :anchor() Method", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil
    end)

    t.it(":anchor('top') sets VERTICAL_TOP flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("top")
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_TOP)).to_be(AlignmentFlag.VERTICAL_TOP)
    end)

    t.it(":anchor('bottom') sets VERTICAL_BOTTOM flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("bottom")
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_BOTTOM)).to_be(AlignmentFlag.VERTICAL_BOTTOM)
    end)

    t.it(":anchor('left') sets HORIZONTAL_LEFT flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("left")
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_LEFT)).to_be(AlignmentFlag.HORIZONTAL_LEFT)
    end)

    t.it(":anchor('right') sets HORIZONTAL_RIGHT flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("right")
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_RIGHT)).to_be(AlignmentFlag.HORIZONTAL_RIGHT)
    end)

    t.it(":anchor('centerx') sets HORIZONTAL_CENTER flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("centerx")
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_CENTER)).to_be(AlignmentFlag.HORIZONTAL_CENTER)
    end)

    t.it(":anchor('centery') sets VERTICAL_CENTER flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("centery")
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_CENTER)).to_be(AlignmentFlag.VERTICAL_CENTER)
    end)

    t.it(":anchor('center') sets both center flags", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("center")
        local expected = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchor('top', 'right') sets multiple flags", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("top", "right")
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_RIGHT)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchor() is case-insensitive", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchor("TOP", "LEFT")
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_LEFT)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchor() returns self for chaining", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        local result = builder:anchor("top")
        t.expect(result).to_be(builder)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 3: Explicit Anchor Methods
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: Explicit Methods", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil
    end)

    t.it(":anchorTop() sets VERTICAL_TOP flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorTop()
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_TOP)).to_be(AlignmentFlag.VERTICAL_TOP)
    end)

    t.it(":anchorBottom() sets VERTICAL_BOTTOM flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorBottom()
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_BOTTOM)).to_be(AlignmentFlag.VERTICAL_BOTTOM)
    end)

    t.it(":anchorLeft() sets HORIZONTAL_LEFT flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorLeft()
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_LEFT)).to_be(AlignmentFlag.HORIZONTAL_LEFT)
    end)

    t.it(":anchorRight() sets HORIZONTAL_RIGHT flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorRight()
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_RIGHT)).to_be(AlignmentFlag.HORIZONTAL_RIGHT)
    end)

    t.it(":anchorCenterX() sets HORIZONTAL_CENTER flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorCenterX()
        t.expect(bit.band(builder._alignment, AlignmentFlag.HORIZONTAL_CENTER)).to_be(AlignmentFlag.HORIZONTAL_CENTER)
    end)

    t.it(":anchorCenterY() sets VERTICAL_CENTER flag", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorCenterY()
        t.expect(bit.band(builder._alignment, AlignmentFlag.VERTICAL_CENTER)).to_be(AlignmentFlag.VERTICAL_CENTER)
    end)

    t.it(":anchorCenter() sets both center flags", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorCenter()
        local expected = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it("explicit methods return self for chaining", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder:anchorTop()).to_be(builder)
        t.expect(builder:anchorCenterX()).to_be(builder)
    end)

    t.it("explicit methods can be chained to combine flags", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorTop():anchorCenterX()
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 4: :inside() / :outside() Methods
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: Inside/Outside", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil
    end)

    t.it(":inside() sets _alignInside to true", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):inside()
        t.expect(builder._alignInside).to_be(true)
    end)

    t.it(":outside() sets _alignInside to false", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):inside():outside()
        t.expect(builder._alignInside).to_be(false)
    end)

    t.it(":inside() returns self for chaining", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder:inside()).to_be(builder)
    end)

    t.it(":outside() returns self for chaining", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder:outside()).to_be(builder)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 5: :gap() Methods
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: Gap Methods", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil
    end)

    t.it(":gap(x, y) sets both gap values", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):gap(10, 20)
        t.expect(builder._gap).to_equal({ x = 10, y = 20 })
    end)

    t.it(":gap(x) sets x and defaults y to 0", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):gap(15)
        t.expect(builder._gap).to_equal({ x = 15, y = 0 })
    end)

    t.it(":gapX(x) sets only x gap", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):gap(5, 5):gapX(10)
        t.expect(builder._gap.x).to_be(10)
        t.expect(builder._gap.y).to_be(5)
    end)

    t.it(":gapY(y) sets only y gap", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):gap(5, 5):gapY(15)
        t.expect(builder._gap.x).to_be(5)
        t.expect(builder._gap.y).to_be(15)
    end)

    t.it(":gap() methods return self for chaining", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001)
        t.expect(builder:gap(1, 2)).to_be(builder)
        t.expect(builder:gapX(3)).to_be(builder)
        t.expect(builder:gapY(4)).to_be(builder)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 6: :apply() Uses ConfigureAlignment
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: :apply() Integration", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil

        -- Setup mock entities with required components
        local parent = 2001
        local child = 2002

        component_cache.set(parent, GameObject, {
            children = {},
            orderedChildren = {},
        })
        component_cache.set(child, InheritedProperties, {
            offset = Vector2 { x = 0, y = 0 },
        })
    end)

    t.it("uses AssignRole when no alignment set (backward compat)", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(2002)
            :attachTo(2001)
            :offset(10, 20)
            :apply()

        local call = getLastAssignRoleCall()
        t.expect(call).never().to_be_nil()
        t.expect(call.entity).to_be(2002)
        t.expect(call.parent).to_be(2001)
        t.expect(call.offset.x).to_be(10)
        t.expect(call.offset.y).to_be(20)

        -- Should NOT call ConfigureAlignment
        t.expect(getLastConfigureAlignmentCall()).to_be_nil()
    end)

    t.it("uses ConfigureAlignment when anchor is set", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(2002)
            :attachTo(2001)
            :anchor("top")
            :anchorCenterX()
            :gapY(-5)
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()
        t.expect(call.entity).to_be(2002)
        t.expect(call.parent).to_be(2001)
        t.expect(call.isChild).to_be(true)

        -- Check alignment has VERTICAL_TOP and HORIZONTAL_CENTER
        local expectedAlignment = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(call.alignment).to_be(expectedAlignment)

        -- Check gap offset
        t.expect(call.offset.x).to_be(0)
        t.expect(call.offset.y).to_be(-5)
    end)

    t.it("includes ALIGN_TO_INNER_EDGES when :inside() called", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(2002)
            :attachTo(2001)
            :anchor("top", "right")
            :inside()
            :gap(-4, 4)
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()

        -- Check alignment has ALIGN_TO_INNER_EDGES
        local hasInnerEdge = bit.band(call.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES) == AlignmentFlag.ALIGN_TO_INNER_EDGES
        t.expect(hasInnerEdge).to_be(true)

        -- Check gap
        t.expect(call.offset.x).to_be(-4)
        t.expect(call.offset.y).to_be(4)
    end)

    t.it("excludes ALIGN_TO_INNER_EDGES when :outside() (default)", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(2002)
            :attachTo(2001)
            :anchor("top")
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()

        -- Check alignment does NOT have ALIGN_TO_INNER_EDGES
        local hasInnerEdge = bit.band(call.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES) == AlignmentFlag.ALIGN_TO_INNER_EDGES
        t.expect(hasInnerEdge).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 7: Convenience Shorthand Methods
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: Shorthand Methods", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil
    end)

    t.it(":anchorTopCenter() sets top + centerX", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorTopCenter()
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorBottomCenter() sets bottom + centerX", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorBottomCenter()
        local expected = bit.bor(AlignmentFlag.VERTICAL_BOTTOM, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorLeftCenter() sets left + centerY", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorLeftCenter()
        local expected = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorRightCenter() sets right + centerY", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorRightCenter()
        local expected = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_CENTER)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorTopLeft() sets top + left", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorTopLeft()
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_LEFT)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorTopRight() sets top + right", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorTopRight()
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_RIGHT)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorBottomLeft() sets bottom + left", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorBottomLeft()
        local expected = bit.bor(AlignmentFlag.VERTICAL_BOTTOM, AlignmentFlag.HORIZONTAL_LEFT)
        t.expect(builder._alignment).to_be(expected)
    end)

    t.it(":anchorBottomRight() sets bottom + right", function()
        local ChildBuilder = require("core.child_builder")
        local builder = ChildBuilder.for_entity(1001):anchorBottomRight()
        local expected = bit.bor(AlignmentFlag.VERTICAL_BOTTOM, AlignmentFlag.HORIZONTAL_RIGHT)
        t.expect(builder._alignment).to_be(expected)
    end)
end)

--------------------------------------------------------------------------------
-- STEP 8: Static setAnchor() Helper
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: setAnchor() Static Helper", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil

        -- Setup entity with InheritedProperties
        component_cache.set(3001, InheritedProperties, {
            flags = {
                alignment = 0,
                extraAlignmentFinetuningOffset = Vector2 { x = 0, y = 0 },
            },
            master = 3000,
        })
    end)

    t.it("setAnchor(entity, 'top') updates alignment flags", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.setAnchor(3001, "top")

        local ip = component_cache.get(3001, InheritedProperties)
        t.expect(bit.band(ip.flags.alignment, AlignmentFlag.VERTICAL_TOP)).to_be(AlignmentFlag.VERTICAL_TOP)
    end)

    t.it("setAnchor(entity, {'top', 'center'}) sets multiple flags", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.setAnchor(3001, { "top", "centerx" })

        local ip = component_cache.get(3001, InheritedProperties)
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(ip.flags.alignment).to_be(expected)
    end)

    t.it("setAnchor with inside=true adds ALIGN_TO_INNER_EDGES", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.setAnchor(3001, "top", true)

        local ip = component_cache.get(3001, InheritedProperties)
        local hasInner = bit.band(ip.flags.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES) == AlignmentFlag.ALIGN_TO_INNER_EDGES
        t.expect(hasInner).to_be(true)
    end)

    t.it("setAnchor with gap sets extraAlignmentFinetuningOffset", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.setAnchor(3001, "top", false, { x = 5, y = 10 })

        local ip = component_cache.get(3001, InheritedProperties)
        t.expect(ip.flags.extraAlignmentFinetuningOffset.x).to_be(5)
        t.expect(ip.flags.extraAlignmentFinetuningOffset.y).to_be(10)
    end)

    t.it("setAnchor clears existing alignment before applying new", function()
        local ChildBuilder = require("core.child_builder")

        -- Set initial alignment
        local ip = component_cache.get(3001, InheritedProperties)
        ip.flags.alignment = bit.bor(AlignmentFlag.VERTICAL_BOTTOM, AlignmentFlag.HORIZONTAL_RIGHT)

        -- Change to top-left
        ChildBuilder.setAnchor(3001, { "top", "left" })

        ip = component_cache.get(3001, InheritedProperties)
        local expected = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_LEFT)
        t.expect(ip.flags.alignment).to_be(expected)
    end)

    t.it("setAnchor returns entity for chaining", function()
        local ChildBuilder = require("core.child_builder")

        local result = ChildBuilder.setAnchor(3001, "top")
        t.expect(result).to_be(3001)
    end)

    t.it("setAnchor handles missing InheritedProperties gracefully", function()
        local ChildBuilder = require("core.child_builder")

        -- Entity without InheritedProperties
        local result = ChildBuilder.setAnchor(9999, "top")
        t.expect(result).to_be(9999)  -- Returns entity, doesn't crash
    end)
end)

--------------------------------------------------------------------------------
-- Integration: Real-World Use Cases
--------------------------------------------------------------------------------

t.describe("ChildBuilder Anchor: Integration Tests", function()
    t.before_each(function()
        resetMocks()
        package.loaded["core.child_builder"] = nil

        -- Setup entities
        local parent = 4001
        local child = 4002

        component_cache.set(parent, GameObject, {
            children = {},
            orderedChildren = {},
        })
        component_cache.set(child, InheritedProperties, {
            offset = Vector2 { x = 0, y = 0 },
        })
    end)

    t.it("health bar above enemy example", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(4002)
            :attachTo(4001)
            :anchor("top")
            :anchorCenterX()
            :gapY(-5)
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()

        local expectedAlignment = bit.bor(AlignmentFlag.VERTICAL_TOP, AlignmentFlag.HORIZONTAL_CENTER)
        t.expect(call.alignment).to_be(expectedAlignment)
        t.expect(call.offset.y).to_be(-5)
    end)

    t.it("badge in top-right corner example", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(4002)
            :attachTo(4001)
            :anchor("top", "right")
            :inside()
            :gap(-4, 4)
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()

        local expectedAlignment = bit.bor(
            AlignmentFlag.VERTICAL_TOP,
            AlignmentFlag.HORIZONTAL_RIGHT,
            AlignmentFlag.ALIGN_TO_INNER_EDGES
        )
        t.expect(call.alignment).to_be(expectedAlignment)
        t.expect(call.offset.x).to_be(-4)
        t.expect(call.offset.y).to_be(4)
    end)

    t.it("weapon on right side with rotation example", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(4002)
            :attachTo(4001)
            :anchor("right")
            :rotateWith()
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()
        t.expect(call.alignment).to_be(AlignmentFlag.HORIZONTAL_RIGHT)
        t.expect(call.rotation).to_be(InheritedPropertiesSync.Strong)
    end)

    t.it("shadow below sprite (inside) example", function()
        local ChildBuilder = require("core.child_builder")

        ChildBuilder.for_entity(4002)
            :attachTo(4001)
            :anchor("bottom")
            :anchorCenterX()
            :inside()
            :gapY(5)
            :apply()

        local call = getLastConfigureAlignmentCall()
        t.expect(call).never().to_be_nil()

        local hasInner = bit.band(call.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES) == AlignmentFlag.ALIGN_TO_INNER_EDGES
        t.expect(hasInner).to_be(true)
        t.expect(call.offset.y).to_be(5)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

t.run_all()
