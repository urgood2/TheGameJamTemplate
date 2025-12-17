# TextBuilder Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a fluent API for game text that matches the Particle Builder pattern (Recipe → Spawner → Handle).

**Architecture:** Three-layer system wrapping CommandBufferText. Recipe stores immutable config, Spawner configures position and triggers creation, Handle manages lifecycle. Global `Text.update(dt)` updates all active handles.

**Tech Stack:** Lua, CommandBufferText (existing), draw.local_command (for entity mode), entity_cache/component_cache (for following)

**Worktree:** `.worktrees/text-builder` (branch: `feature/text-builder`)

**Test File:** `assets/scripts/tests/test_text_builder.lua`

**Implementation File:** `assets/scripts/core/text.lua`

---

## Task 1: Module Skeleton + Test Infrastructure

**Files:**
- Create: `assets/scripts/core/text.lua`
- Create: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write the test file skeleton**

```lua
-- assets/scripts/tests/test_text_builder.lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local TestRunner = require("test_runner")
local it, assert_equals, assert_not_nil, assert_true =
    TestRunner.it, TestRunner.assert_equals, TestRunner.assert_not_nil, TestRunner.assert_true

-- Mock CommandBufferText for unit tests
local MockCommandBufferText = {}
MockCommandBufferText.__index = MockCommandBufferText
function MockCommandBufferText:init(args)
    self.args = args
    self.updateCount = 0
end
function MockCommandBufferText:update(dt)
    self.updateCount = self.updateCount + 1
end
function MockCommandBufferText:set_text(t) self.args.text = t end
function MockCommandBufferText:rebuild() end

-- Inject mock before requiring Text module
_G._MockCommandBufferText = MockCommandBufferText

TestRunner.describe("Text.define()", function()
    it("returns a Recipe object", function()
        local Text = require("core.text")
        local recipe = Text.define()
        assert_not_nil(recipe, "define() should return a recipe")
        assert_not_nil(recipe._config, "recipe should have _config")
    end)
end)

return function()
    TestRunner.run_all()
end
```

**Step 2: Write the module skeleton**

```lua
-- assets/scripts/core/text.lua
--[[
================================================================================
TEXT BUILDER - Fluent API for Game Text
================================================================================
Particle-style API for text rendering with three layers:
- Recipe: Immutable text definition
- Spawner: Position configuration
- Handle: Lifecycle control

Usage:
    local Text = require("core.text")

    local recipe = Text.define()
        :content("[%d](color=red)")
        :size(20)
        :fade()
        :lifespan(0.8)

    recipe:spawn(25):above(enemy, 10)

    -- In game loop:
    Text.update(dt)
]]

-- Singleton guard
if _G.__TEXT_BUILDER__ then
    return _G.__TEXT_BUILDER__
end

local Text = {}

-- Active handles list (managed by Text.update)
Text._activeHandles = {}

--------------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------------

local RecipeMethods = {}
RecipeMethods.__index = RecipeMethods

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a new text recipe
--- @return Recipe
function Text.define()
    local recipe = setmetatable({}, RecipeMethods)
    recipe._config = {
        size = 16,
        color = "white",
        anchor = "center",
        space = "screen",
        z = 0,
    }
    return recipe
end

_G.__TEXT_BUILDER__ = Text
return Text
```

**Step 3: Run test to verify it passes**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: 1 test passing

**Step 4: Commit**

```bash
git add assets/scripts/core/text.lua assets/scripts/tests/test_text_builder.lua
git commit -m "feat(text): add module skeleton with Text.define()"
```

---

## Task 2: Recipe Configuration Methods

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests for Recipe methods**

Add to test file after existing describe block:

```lua
TestRunner.describe("Recipe configuration", function()
    it(":content() stores template string", function()
        local Text = require("core.text")
        local recipe = Text.define():content("[%d](color=red)")
        assert_equals("[%d](color=red)", recipe._config.content)
    end)

    it(":content() stores callback function", function()
        local Text = require("core.text")
        local fn = function() return "test" end
        local recipe = Text.define():content(fn)
        assert_equals(fn, recipe._config.content)
    end)

    it(":size() stores font size", function()
        local Text = require("core.text")
        local recipe = Text.define():size(24)
        assert_equals(24, recipe._config.size)
    end)

    it(":color() stores base color", function()
        local Text = require("core.text")
        local recipe = Text.define():color("red")
        assert_equals("red", recipe._config.color)
    end)

    it(":effects() stores default effects", function()
        local Text = require("core.text")
        local recipe = Text.define():effects("shake=2;float")
        assert_equals("shake=2;float", recipe._config.effects)
    end)

    it(":fade() enables fade", function()
        local Text = require("core.text")
        local recipe = Text.define():fade()
        assert_true(recipe._config.fade)
    end)

    it(":lifespan() stores duration", function()
        local Text = require("core.text")
        local recipe = Text.define():lifespan(1.5)
        assert_equals(1.5, recipe._config.lifespanMin)
        assert_equals(1.5, recipe._config.lifespanMax)
    end)

    it(":lifespan() stores range", function()
        local Text = require("core.text")
        local recipe = Text.define():lifespan(0.5, 1.0)
        assert_equals(0.5, recipe._config.lifespanMin)
        assert_equals(1.0, recipe._config.lifespanMax)
    end)

    it(":width() stores wrap width", function()
        local Text = require("core.text")
        local recipe = Text.define():width(200)
        assert_equals(200, recipe._config.width)
    end)

    it(":anchor() stores anchor mode", function()
        local Text = require("core.text")
        local recipe = Text.define():anchor("topleft")
        assert_equals("topleft", recipe._config.anchor)
    end)

    it("methods chain correctly", function()
        local Text = require("core.text")
        local recipe = Text.define()
            :content("test")
            :size(24)
            :color("red")
            :fade()
        assert_equals("test", recipe._config.content)
        assert_equals(24, recipe._config.size)
        assert_equals("red", recipe._config.color)
        assert_true(recipe._config.fade)
    end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: Multiple failures (methods not defined)

**Step 3: Implement Recipe methods**

Add to `text.lua` after `RecipeMethods.__index = RecipeMethods`:

```lua
--- Set text content (template string, literal, or callback)
--- @param contentOrFn string|function Content template or callback
--- @return self
function RecipeMethods:content(contentOrFn)
    self._config.content = contentOrFn
    return self
end

--- Set font size
--- @param fontSize number Font size in pixels
--- @return self
function RecipeMethods:size(fontSize)
    self._config.size = fontSize
    return self
end

--- Set base color
--- @param colorName string Color name or Color object
--- @return self
function RecipeMethods:color(colorName)
    self._config.color = colorName
    return self
end

--- Set default effects for all characters
--- @param effectStr string Effect string (e.g., "shake=2;float")
--- @return self
function RecipeMethods:effects(effectStr)
    self._config.effects = effectStr
    return self
end

--- Enable alpha fade over lifespan
--- @return self
function RecipeMethods:fade()
    self._config.fade = true
    return self
end

--- Set fade-in percentage
--- @param pct number Percentage of lifespan for fade-in (0-1)
--- @return self
function RecipeMethods:fadeIn(pct)
    self._config.fadeInPct = pct
    return self
end

--- Set auto-destroy lifespan
--- @param minOrFixed number Lifespan in seconds, or min if max provided
--- @param max number? Max lifespan for random range
--- @return self
function RecipeMethods:lifespan(minOrFixed, max)
    self._config.lifespanMin = minOrFixed
    self._config.lifespanMax = max or minOrFixed
    return self
end

--- Set wrap width for multi-line text
--- @param w number Width in pixels
--- @return self
function RecipeMethods:width(w)
    self._config.width = w
    return self
end

--- Set anchor mode
--- @param mode string "center" | "topleft"
--- @return self
function RecipeMethods:anchor(mode)
    self._config.anchor = mode
    return self
end

--- Set text alignment
--- @param align string "left" | "center" | "right" | "justify"
--- @return self
function RecipeMethods:align(align)
    self._config.align = align
    return self
end

--- Set render layer
--- @param layerObj any Layer object
--- @return self
function RecipeMethods:layer(layerObj)
    self._config.layer = layerObj
    return self
end

--- Set z-index
--- @param zIndex number Z-index for draw order
--- @return self
function RecipeMethods:z(zIndex)
    self._config.z = zIndex
    return self
end

--- Set render space
--- @param spaceName string "screen" | "world"
--- @return self
function RecipeMethods:space(spaceName)
    self._config.space = spaceName
    return self
end

--- Set custom font
--- @param fontObj any Font object
--- @return self
function RecipeMethods:font(fontObj)
    self._config.font = fontObj
    return self
end
```

**Step 4: Run tests to verify they pass**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: All tests passing

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add Recipe configuration methods"
```

---

## Task 3: Spawner Basics (:spawn, :at)

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests for Spawner**

Add to test file:

```lua
TestRunner.describe("Spawner basics", function()
    it(":spawn() returns a Spawner", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test")
        local spawner = recipe:spawn()
        assert_not_nil(spawner, "spawn() should return spawner")
        assert_not_nil(spawner._recipe, "spawner should reference recipe")
    end)

    it(":spawn(value) stores value for template", function()
        local Text = require("core.text")
        local recipe = Text.define():content("[%d](red)")
        local spawner = recipe:spawn(25)
        assert_equals(25, spawner._value)
    end)

    it(":at() triggers spawn and returns Handle", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(100, 200)
        assert_not_nil(handle, "at() should return handle")
        assert_true(handle.isActive and handle:isActive(), "handle should be active")
    end)

    it(":at() registers handle in active list", function()
        local Text = require("core.text")
        Text._activeHandles = {}  -- Reset
        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(100, 200)
        assert_equals(1, #Text._activeHandles)
    end)
end)
```

**Step 2: Run tests to verify they fail**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: Failures (spawn not defined)

**Step 3: Implement Spawner**

Add to `text.lua`:

```lua
--------------------------------------------------------------------------------
-- SPAWNER
--------------------------------------------------------------------------------

local SpawnerMethods = {}
SpawnerMethods.__index = SpawnerMethods

--- Set absolute position and trigger spawn
--- @param x number X position
--- @param y number Y position
--- @return Handle
function SpawnerMethods:at(x, y)
    self._position = { x = x, y = y }
    return self:_spawn()
end

--- Internal: Create the text handle
--- @return Handle
function SpawnerMethods:_spawn()
    local handle = Text._createHandle(self)
    table.insert(Text._activeHandles, handle)
    return handle
end

-- Add to Recipe:
--- Create a spawner for this recipe
--- @param value any? Value for template substitution
--- @return Spawner
function RecipeMethods:spawn(value)
    local spawner = setmetatable({}, SpawnerMethods)
    spawner._recipe = self
    spawner._value = value
    spawner._position = nil
    spawner._followEntity = nil
    spawner._followOffset = nil
    spawner._attachedEntity = nil
    spawner._asEntity = false
    spawner._shaders = nil
    spawner._tag = nil
    return spawner
end

--------------------------------------------------------------------------------
-- HANDLE
--------------------------------------------------------------------------------

local HandleMethods = {}
HandleMethods.__index = HandleMethods

--- Check if handle is still active
--- @return boolean
function HandleMethods:isActive()
    return self._active
end

--- Stop and remove this text
function HandleMethods:stop()
    self._active = false
end

--- Internal: Create handle from spawner config
--- @param spawner Spawner
--- @return Handle
function Text._createHandle(spawner)
    local config = spawner._recipe._config
    local handle = setmetatable({}, HandleMethods)

    handle._active = true
    handle._spawner = spawner
    handle._config = config
    handle._position = spawner._position or { x = 0, y = 0 }
    handle._elapsed = 0
    handle._lifespan = nil

    -- Calculate lifespan if set
    if config.lifespanMin then
        if config.lifespanMin == config.lifespanMax then
            handle._lifespan = config.lifespanMin
        else
            handle._lifespan = config.lifespanMin +
                math.random() * (config.lifespanMax - config.lifespanMin)
        end
    end

    -- Resolve content
    local content = config.content or ""
    if type(content) == "function" then
        content = content()
    elseif spawner._value ~= nil and type(content) == "string" then
        content = string.format(content, spawner._value)
    end
    handle._content = content

    -- Create CommandBufferText (or mock)
    local CBT = _G._MockCommandBufferText or require("ui.command_buffer_text")
    handle._textRenderer = CBT({
        text = handle._content,
        w = config.width or 200,
        x = handle._position.x,
        y = handle._position.y,
        font_size = config.size or 16,
        anchor = config.anchor or "center",
        layer = config.layer or (_G.layers and _G.layers.ui),
        z = config.z or 0,
        space = config.space,
    })

    return handle
end
```

**Step 4: Run tests to verify they pass**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: All tests passing

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add Spawner and Handle basics"
```

---

## Task 4: Global Update Loop

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests for Text.update()**

Add to test file:

```lua
TestRunner.describe("Text.update()", function()
    it("updates all active handles", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local h1 = recipe:spawn():at(0, 0)
        local h2 = recipe:spawn():at(100, 100)

        Text.update(0.016)

        assert_equals(1, h1._textRenderer.updateCount)
        assert_equals(1, h2._textRenderer.updateCount)
    end)

    it("removes handles with expired lifespan", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100):lifespan(0.5)
        recipe:spawn():at(0, 0)

        assert_equals(1, #Text._activeHandles)

        Text.update(0.6)  -- Exceeds lifespan

        assert_equals(0, #Text._activeHandles)
    end)

    it("removes stopped handles", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0)

        handle:stop()
        Text.update(0.016)

        assert_equals(0, #Text._activeHandles)
    end)

    it("Text.getActiveCount() returns count", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(0, 0)
        recipe:spawn():at(100, 100)

        assert_equals(2, Text.getActiveCount())
    end)

    it("Text.stopAll() removes all handles", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(0, 0)
        recipe:spawn():at(100, 100)

        Text.stopAll()

        assert_equals(0, #Text._activeHandles)
    end)
end)
```

**Step 2: Run tests to verify they fail**

Expected: Failures (Text.update not defined)

**Step 3: Implement Text.update() and helpers**

Add to `text.lua` in PUBLIC API section:

```lua
--- Update all active text handles (call once per frame)
--- @param dt number Delta time in seconds
function Text.update(dt)
    -- Iterate backwards for safe removal
    for i = #Text._activeHandles, 1, -1 do
        local handle = Text._activeHandles[i]

        -- Check if still active
        if not handle._active then
            table.remove(Text._activeHandles, i)
        else
            -- Update elapsed time
            handle._elapsed = handle._elapsed + dt

            -- Check lifespan
            if handle._lifespan and handle._elapsed >= handle._lifespan then
                handle._active = false
                table.remove(Text._activeHandles, i)
            else
                -- Update renderer
                if handle._textRenderer and handle._textRenderer.update then
                    handle._textRenderer:update(dt)
                end
            end
        end
    end
end

--- Get count of active text handles
--- @return number
function Text.getActiveCount()
    return #Text._activeHandles
end

--- Get copy of active handles list (for debugging)
--- @return table
function Text.getActiveHandles()
    local copy = {}
    for i, h in ipairs(Text._activeHandles) do
        copy[i] = h
    end
    return copy
end

--- Stop and remove all active text
function Text.stopAll()
    for _, handle in ipairs(Text._activeHandles) do
        handle._active = false
    end
    Text._activeHandles = {}
end
```

**Step 4: Run tests to verify they pass**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: All tests passing

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add global Text.update() loop"
```

---

## Task 5: Entity-Relative Positioning

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests for entity positioning**

Add to test file:

```lua
-- Mock entity and component system
local mockEntities = {}
local mockTransforms = {}

_G.entity_cache = {
    valid = function(eid) return mockEntities[eid] ~= nil end
}
_G.component_cache = {
    get = function(eid, comp)
        if comp == _G.Transform then return mockTransforms[eid] end
        return nil
    end
}
_G.Transform = {}

local function createMockEntity(id, x, y)
    mockEntities[id] = true
    mockTransforms[id] = { actualX = x, actualY = y, actualW = 32, actualH = 32 }
    return id
end

TestRunner.describe("Entity-relative positioning", function()
    it(":above(entity, offset) positions above entity", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(1, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():above(entity, 20)

        -- Should be at entity center X, above entity by offset
        assert_equals(100 + 16, handle._position.x)  -- centerX
        assert_equals(200 - 20, handle._position.y)  -- above by offset
    end)

    it(":below(entity, offset) positions below entity", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(2, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():below(entity, 10)

        assert_equals(100 + 16, handle._position.x)
        assert_equals(200 + 32 + 10, handle._position.y)  -- below entity
    end)

    it(":center(entity) positions at entity center", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(3, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():center(entity)

        assert_equals(100 + 16, handle._position.x)
        assert_equals(200 + 16, handle._position.y)
    end)

    it(":follow() updates position each frame", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(4, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():above(entity, 20):follow()

        -- Move entity
        mockTransforms[4].actualX = 150
        mockTransforms[4].actualY = 250

        Text.update(0.016)

        assert_equals(150 + 16, handle._position.x)
        assert_equals(250 - 20, handle._position.y)
    end)
end)
```

**Step 2: Run tests to verify they fail**

Expected: Failures (above/below/center not defined)

**Step 3: Implement entity positioning**

Add to SpawnerMethods in `text.lua`:

```lua
--- Position above entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels above entity (default: 0)
--- @return Handle
function SpawnerMethods:above(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "above"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position below entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels below entity (default: 0)
--- @return Handle
function SpawnerMethods:below(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "below"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position at entity center (triggers spawn)
--- @param entity any Entity to center on
--- @return Handle
function SpawnerMethods:center(entity)
    self._followEntity = entity
    self._followMode = "center"
    self._followOffset = 0
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position left of entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels left of entity (default: 0)
--- @return Handle
function SpawnerMethods:left(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "left"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position right of entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels right of entity (default: 0)
--- @return Handle
function SpawnerMethods:right(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "right"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Enable position following (call before :at/:above/etc)
--- @return self
function SpawnerMethods:follow()
    self._shouldFollow = true
    return self
end

--- Internal: Calculate position from entity
function SpawnerMethods:_calculateEntityPosition()
    local entity_cache = _G.entity_cache or require("core.entity_cache")
    local component_cache = _G.component_cache or require("core.component_cache")
    local Transform = _G.Transform

    if not self._followEntity or not entity_cache.valid(self._followEntity) then
        return { x = 0, y = 0 }
    end

    local t = component_cache.get(self._followEntity, Transform)
    if not t then return { x = 0, y = 0 } end

    local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
    local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
    local offset = self._followOffset or 0

    if self._followMode == "above" then
        return { x = centerX, y = (t.actualY or 0) - offset }
    elseif self._followMode == "below" then
        return { x = centerX, y = (t.actualY or 0) + (t.actualH or 0) + offset }
    elseif self._followMode == "left" then
        return { x = (t.actualX or 0) - offset, y = centerY }
    elseif self._followMode == "right" then
        return { x = (t.actualX or 0) + (t.actualW or 0) + offset, y = centerY }
    else -- center
        return { x = centerX, y = centerY }
    end
end
```

Update `Text._createHandle` to store follow info:

```lua
-- Add after handle._lifespan calculation:
    -- Store follow info
    handle._followEntity = spawner._followEntity
    handle._followMode = spawner._followMode
    handle._followOffset = spawner._followOffset
    handle._shouldFollow = spawner._shouldFollow
```

Update `Text.update()` to handle following, add before renderer update:

```lua
                -- Update following position
                if handle._shouldFollow and handle._followEntity then
                    local entity_cache = _G.entity_cache or require("core.entity_cache")
                    local component_cache = _G.component_cache or require("core.component_cache")
                    local Transform = _G.Transform

                    if entity_cache.valid(handle._followEntity) then
                        local t = component_cache.get(handle._followEntity, Transform)
                        if t then
                            local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
                            local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
                            local offset = handle._followOffset or 0

                            if handle._followMode == "above" then
                                handle._position = { x = centerX, y = (t.actualY or 0) - offset }
                            elseif handle._followMode == "below" then
                                handle._position = { x = centerX, y = (t.actualY or 0) + (t.actualH or 0) + offset }
                            elseif handle._followMode == "left" then
                                handle._position = { x = (t.actualX or 0) - offset, y = centerY }
                            elseif handle._followMode == "right" then
                                handle._position = { x = (t.actualX or 0) + (t.actualW or 0) + offset, y = centerY }
                            else
                                handle._position = { x = centerX, y = centerY }
                            end

                            -- Update renderer position
                            if handle._textRenderer then
                                handle._textRenderer.x = handle._position.x
                                handle._textRenderer.y = handle._position.y
                            end
                        end
                    end
                end
```

**Step 4: Run tests to verify they pass**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder.lua`
Expected: All tests passing

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add entity-relative positioning with follow"
```

---

## Task 6: Lifecycle Binding (:attachTo)

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests**

Add to test file:

```lua
TestRunner.describe("Lifecycle binding", function()
    it(":attachTo(entity) stores entity reference", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(10, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0):attachTo(entity)

        assert_equals(entity, handle._attachedEntity)
    end)

    it("handle is removed when attached entity dies", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(11, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(0, 0):attachTo(entity)

        assert_equals(1, #Text._activeHandles)

        -- Simulate entity death
        mockEntities[11] = nil

        Text.update(0.016)

        assert_equals(0, #Text._activeHandles)
    end)
end)
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement :attachTo()**

Add to SpawnerMethods:

```lua
--- Attach lifecycle to entity (text dies when entity dies)
--- @param entity any Entity to attach to
--- @return self
function SpawnerMethods:attachTo(entity)
    self._attachedEntity = entity
    return self
end
```

Update `Text._createHandle`:

```lua
    -- Store attached entity
    handle._attachedEntity = spawner._attachedEntity
```

Update `Text.update()` to check attached entity, add after active check:

```lua
            -- Check attached entity
            if handle._attachedEntity then
                local entity_cache = _G.entity_cache or require("core.entity_cache")
                if not entity_cache.valid(handle._attachedEntity) then
                    handle._active = false
                    table.remove(Text._activeHandles, i)
                    goto continue
                end
            end
```

Add at end of loop: `::continue::`

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add lifecycle binding with :attachTo()"
```

---

## Task 7: Tags and Bulk Operations

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests**

Add to test file:

```lua
TestRunner.describe("Tags and bulk operations", function()
    it(":tag() stores tag on handle", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0):tag("combat")

        assert_equals("combat", handle._tag)
    end)

    it("Text.stopByTag() removes only tagged handles", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(0, 0):tag("combat")
        recipe:spawn():at(100, 0):tag("combat")
        recipe:spawn():at(200, 0):tag("ui")

        assert_equals(3, #Text._activeHandles)

        Text.stopByTag("combat")
        Text.update(0)  -- Process removals

        assert_equals(1, #Text._activeHandles)
        assert_equals("ui", Text._activeHandles[1]._tag)
    end)
end)
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement tags**

Add to SpawnerMethods:

```lua
--- Tag this text for bulk operations
--- @param tagName string Tag name
--- @return self
function SpawnerMethods:tag(tagName)
    self._tag = tagName
    return self
end
```

Update HandleMethods (add :tag() that can be called on handle):

```lua
--- Tag this handle (can be called after spawn)
--- @param tagName string Tag name
--- @return self
function HandleMethods:tag(tagName)
    self._tag = tagName
    return self
end
```

Update `Text._createHandle`:

```lua
    handle._tag = spawner._tag
```

Add to Text module:

```lua
--- Stop all text with a specific tag
--- @param tagName string Tag to match
function Text.stopByTag(tagName)
    for _, handle in ipairs(Text._activeHandles) do
        if handle._tag == tagName then
            handle._active = false
        end
    end
end
```

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add tags and Text.stopByTag()"
```

---

## Task 8: Handle Content Updates

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests**

Add to test file:

```lua
TestRunner.describe("Handle content updates", function()
    it(":setText() updates content with template", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("[%d](red)"):width(100)
        local handle = recipe:spawn(25):at(0, 0)

        handle:setText(50)

        assert_equals("[50](red)", handle._content)
    end)

    it(":setContent() replaces entire content", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("old"):width(100)
        local handle = recipe:spawn():at(0, 0)

        handle:setContent("[NEW](shake)")

        assert_equals("[NEW](shake)", handle._content)
    end)

    it(":moveTo() updates position", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0)

        handle:moveTo(150, 250)

        assert_equals(150, handle._position.x)
        assert_equals(250, handle._position.y)
    end)

    it(":moveBy() offsets position", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(100, 100)

        handle:moveBy(50, -25)

        assert_equals(150, handle._position.x)
        assert_equals(75, handle._position.y)
    end)

    it(":getPosition() returns current position", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(123, 456)

        local pos = handle:getPosition()

        assert_equals(123, pos.x)
        assert_equals(456, pos.y)
    end)
end)
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement Handle update methods**

Add to HandleMethods:

```lua
--- Update content using template with new value
--- @param newValue any Value for template substitution
function HandleMethods:setText(newValue)
    local content = self._config.content or ""
    if type(content) == "string" and newValue ~= nil then
        self._content = string.format(content, newValue)
    elseif type(content) == "function" then
        self._content = content()
    end
    if self._textRenderer and self._textRenderer.set_text then
        self._textRenderer:set_text(self._content)
    end
end

--- Replace entire content string
--- @param newContent string New content string
function HandleMethods:setContent(newContent)
    self._content = newContent
    if self._textRenderer and self._textRenderer.set_text then
        self._textRenderer:set_text(self._content)
    end
end

--- Move to absolute position
--- @param x number X position
--- @param y number Y position
function HandleMethods:moveTo(x, y)
    self._position = { x = x, y = y }
    if self._textRenderer then
        self._textRenderer.x = x
        self._textRenderer.y = y
    end
end

--- Move by relative offset
--- @param dx number X offset
--- @param dy number Y offset
function HandleMethods:moveBy(dx, dy)
    self._position.x = self._position.x + dx
    self._position.y = self._position.y + dy
    if self._textRenderer then
        self._textRenderer.x = self._position.x
        self._textRenderer.y = self._position.y
    end
end

--- Get current position
--- @return table { x, y }
function HandleMethods:getPosition()
    return { x = self._position.x, y = self._position.y }
end
```

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add Handle content and position updates"
```

---

## Task 9: Stream Mode

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests**

Add to test file:

```lua
TestRunner.describe("Stream mode", function()
    it(":stream() returns handle without triggering spawn", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():stream()

        assert_not_nil(handle)
        -- Not yet in active list (no position set)
        assert_equals(0, #Text._activeHandles)
    end)

    it("stream handle can set position later with :at()", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():stream()

        handle:at(100, 200)

        assert_equals(1, #Text._activeHandles)
        assert_equals(100, handle._position.x)
    end)
end)
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement stream mode**

Add to SpawnerMethods:

```lua
--- Create handle without triggering spawn (deferred positioning)
--- @return Handle
function SpawnerMethods:stream()
    local handle = Text._createHandle(self)
    handle._streamed = true
    -- Don't add to active list yet
    return handle
end
```

Add to HandleMethods:

```lua
--- Set position (for streamed handles)
--- @param x number X position
--- @param y number Y position
--- @return self
function HandleMethods:at(x, y)
    self._position = { x = x, y = y }
    if self._textRenderer then
        self._textRenderer.x = x
        self._textRenderer.y = y
    end
    -- Add to active list if streamed
    if self._streamed and self._active then
        table.insert(Text._activeHandles, self)
        self._streamed = false
    end
    return self
end
```

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add stream mode for deferred positioning"
```

---

## Task 10: Entity Mode Skeleton

**Files:**
- Modify: `assets/scripts/core/text.lua`
- Modify: `assets/scripts/tests/test_text_builder.lua`

**Step 1: Write failing tests**

Add to test file:

```lua
TestRunner.describe("Entity mode", function()
    it(":asEntity() marks spawner for entity creation", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test"):width(100)
        local spawner = recipe:spawn():asEntity()

        assert_true(spawner._asEntity)
    end)

    it(":withShaders() stores shader list", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test"):width(100)
        local spawner = recipe:spawn():asEntity():withShaders({ "3d_skew_holo" })

        assert_equals(1, #spawner._shaders)
        assert_equals("3d_skew_holo", spawner._shaders[1])
    end)

    it(":richEffects() enables per-character rendering", function()
        local Text = require("core.text")
        local recipe = Text.define():content("test"):width(100)
        local spawner = recipe:spawn():asEntity():richEffects()

        assert_true(spawner._richEffects)
    end)

    it("handle:getEntity() returns nil for non-entity mode", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0)

        assert_equals(nil, handle:getEntity())
    end)
end)
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement entity mode methods**

Add to SpawnerMethods:

```lua
--- Enable entity mode (creates ECS entity with Transform)
--- @return self
function SpawnerMethods:asEntity()
    self._asEntity = true
    return self
end

--- Set shaders for entity mode
--- @param shaderList table List of shader names
--- @return self
function SpawnerMethods:withShaders(shaderList)
    self._shaders = shaderList
    return self
end

--- Enable per-character effects in entity mode (expensive)
--- @return self
function SpawnerMethods:richEffects()
    self._richEffects = true
    return self
end
```

Add to HandleMethods:

```lua
--- Get ECS entity (only valid if :asEntity() was used)
--- @return any|nil Entity ID or nil
function HandleMethods:getEntity()
    return self._entity
end
```

Update `Text._createHandle` to store entity mode flags:

```lua
    handle._asEntity = spawner._asEntity
    handle._shaders = spawner._shaders
    handle._richEffects = spawner._richEffects
    handle._entity = nil  -- Will be set when entity mode is fully implemented
```

**Step 4: Run tests to verify they pass**

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(text): add entity mode skeleton"
```

---

## Task 11: Integration Test

**Files:**
- Create: `assets/scripts/tests/test_text_builder_integration.lua`

**Step 1: Write integration test demonstrating full usage**

```lua
-- assets/scripts/tests/test_text_builder_integration.lua
-- Integration test demonstrating TextBuilder usage patterns

package.path = package.path .. ";./assets/scripts/?.lua"

local Text = require("core.text")

print("=== TextBuilder Integration Test ===\n")

-- Reset state
Text._activeHandles = {}

-- Mock CommandBufferText
_G._MockCommandBufferText = {
    new = function(self, args)
        local obj = { args = args, updateCount = 0 }
        setmetatable(obj, { __index = self })
        return obj
    end,
    update = function(self, dt) self.updateCount = self.updateCount + 1 end,
    set_text = function(self, t) self.args.text = t end,
}
_G._MockCommandBufferText.__index = _G._MockCommandBufferText
setmetatable(_G._MockCommandBufferText, { __call = function(t, args) return t:new(args) end })

-- Test 1: Fire-and-forget damage number
print("Test 1: Damage number recipe")
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)

local h1 = damageRecipe:spawn(25):at(100, 200)
print("  Created damage text at (100, 200)")
print("  Content: " .. h1._content)
print("  Lifespan: " .. tostring(h1._lifespan))
assert(h1._content == "[25](color=red;pop=0.2)", "Content should be formatted")
assert(h1._lifespan <= 0.8, "Lifespan should be set")
print("  PASS\n")

-- Test 2: Persistent HP bar with callback
print("Test 2: HP bar with callback")
local playerHP = 100
local hpRecipe = Text.define()
    :content(function() return "HP: " .. playerHP end)
    :size(14)
    :anchor("center")

local h2 = hpRecipe:spawn():at(50, 50)
print("  Initial content: " .. h2._content)
assert(h2._content == "HP: 100", "Callback should be evaluated")

playerHP = 75
h2:setText()  -- Re-evaluate callback
print("  After HP change: " .. h2._content)
-- Note: setText() without arg re-evaluates callback for callback content
print("  PASS\n")

-- Test 3: Tagged text and bulk removal
print("Test 3: Tags and bulk removal")
Text._activeHandles = {}

local tagRecipe = Text.define():content("test"):width(100)
tagRecipe:spawn():at(0, 0):tag("combat")
tagRecipe:spawn():at(100, 0):tag("combat")
tagRecipe:spawn():at(200, 0):tag("ui")

print("  Active handles: " .. #Text._activeHandles)
assert(#Text._activeHandles == 3, "Should have 3 handles")

Text.stopByTag("combat")
Text.update(0)

print("  After stopByTag('combat'): " .. #Text._activeHandles)
assert(#Text._activeHandles == 1, "Should have 1 handle")
print("  PASS\n")

-- Test 4: Lifespan auto-cleanup
print("Test 4: Lifespan auto-cleanup")
Text._activeHandles = {}

local shortRecipe = Text.define():content("brief"):width(100):lifespan(0.5)
shortRecipe:spawn():at(0, 0)

print("  Initial handles: " .. #Text._activeHandles)
assert(#Text._activeHandles == 1, "Should have 1 handle")

-- Simulate time passing
Text.update(0.6)

print("  After 0.6s: " .. #Text._activeHandles)
assert(#Text._activeHandles == 0, "Should auto-remove after lifespan")
print("  PASS\n")

-- Test 5: Stream mode
print("Test 5: Stream mode")
Text._activeHandles = {}

local streamRecipe = Text.define():content("deferred"):width(100)
local h5 = streamRecipe:spawn():stream()

print("  After stream(): " .. #Text._activeHandles .. " active")
assert(#Text._activeHandles == 0, "Should not be active yet")

h5:at(100, 100)
print("  After :at(): " .. #Text._activeHandles .. " active")
assert(#Text._activeHandles == 1, "Should be active after position set")
print("  PASS\n")

print("=== All Integration Tests Passed ===")
```

**Step 2: Run integration test**

Run: `cd .worktrees/text-builder && lua assets/scripts/tests/test_text_builder_integration.lua`
Expected: All tests pass

**Step 3: Commit**

```bash
git add -A
git commit -m "test(text): add integration tests"
```

---

## Final Task: Documentation Update

**Files:**
- Modify: `CLAUDE.md` (add TextBuilder section)

**Step 1: Add TextBuilder documentation to CLAUDE.md**

Add after the Timer section:

```markdown
---

## Text Builder API

### Fluent Text Creation

\`\`\`lua
local Text = require("core.text")

-- Define a reusable text recipe
local damageRecipe = Text.define()
    :content("[%d](color=red;pop=0.2)")
    :size(20)
    :fade()
    :lifespan(0.8)

-- Spawn at position (fire-and-forget)
damageRecipe:spawn(25):at(enemy.x, enemy.y)

-- Spawn relative to entity
damageRecipe:spawn(50):above(enemy, 10)

-- Persistent text with following
local hpText = Text.define()
    :content(function() return "HP: " .. player.hp end)
    :size(14)
    :spawn()
    :above(player, 40)
    :follow()
    :attachTo(player)

-- Update in game loop (REQUIRED)
function update(dt)
    Text.update(dt)
end
\`\`\`

### Recipe Methods

| Method | Description |
|--------|-------------|
| `:content(str\|fn)` | Template string or callback |
| `:size(n)` | Font size |
| `:color(name)` | Base color |
| `:effects(str)` | Default effects for all chars |
| `:fade()` | Fade over lifespan |
| `:lifespan(n)` | Auto-destroy after N seconds |
| `:width(n)` | Wrap width |
| `:anchor("center"\|"topleft")` | Anchor mode |

### Spawner Methods

| Method | Description |
|--------|-------------|
| `:at(x, y)` | Absolute position (triggers spawn) |
| `:above(entity, offset)` | Above entity (triggers spawn) |
| `:below(entity, offset)` | Below entity (triggers spawn) |
| `:follow()` | Keep following entity position |
| `:attachTo(entity)` | Die when entity dies |
| `:tag(name)` | Tag for bulk operations |
| `:stream()` | Deferred spawn (set position later) |

### Handle Methods

| Method | Description |
|--------|-------------|
| `:setText(value)` | Update with template |
| `:setContent(str)` | Replace content |
| `:moveTo(x, y)` | Move to position |
| `:stop()` | Remove text |
| `:isActive()` | Check if alive |

### Module Functions

| Function | Description |
|----------|-------------|
| `Text.update(dt)` | Update all text (call each frame) |
| `Text.stopAll()` | Remove all text |
| `Text.stopByTag(tag)` | Remove tagged text |
| `Text.getActiveCount()` | Get active text count |
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add TextBuilder API to CLAUDE.md"
```

---

## Summary

**Tasks:**
1. Module skeleton + test infrastructure
2. Recipe configuration methods
3. Spawner basics (:spawn, :at)
4. Global update loop
5. Entity-relative positioning
6. Lifecycle binding (:attachTo)
7. Tags and bulk operations
8. Handle content updates
9. Stream mode
10. Entity mode skeleton
11. Integration test
12. Documentation update

**Total estimated time:** 60-90 minutes with TDD approach

**Not included (future work):**
- Full entity mode implementation (creating ECS entity, shader integration)
- Rich effects mode in entity mode (per-character local commands)
- Integration with real CommandBufferText (vs mock)
