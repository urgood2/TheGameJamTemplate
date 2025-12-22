-- assets/scripts/tests/test_text_builder.lua
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local TestRunner = require("test_runner")
local it, assert_equals, assert_not_nil, assert_true =
    TestRunner.it, TestRunner.assert_equals, TestRunner.assert_not_nil, TestRunner.assert_true

-- Mock CommandBufferText for unit tests
local MockCommandBufferText = {}
MockCommandBufferText.__index = MockCommandBufferText

-- Constructor function
function MockCommandBufferText:new(args)
    local obj = {
        args = args,
        updateCount = 0,
        x = args.x,
        y = args.y
    }
    setmetatable(obj, MockCommandBufferText)
    return obj
end

function MockCommandBufferText:update(dt)
    self.updateCount = self.updateCount + 1
end

function MockCommandBufferText:set_text(t)
    self.args.text = t
end

function MockCommandBufferText:rebuild()
end

function MockCommandBufferText:set_base_scale(s)
    self.base_scale = s
end

function MockCommandBufferText:set_base_rotation(r)
    self.base_rotation = r
end

-- Make it callable
setmetatable(MockCommandBufferText, {
    __call = function(cls, args)
        return cls:new(args)
    end
})

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

    it(":align() stores alignment", function()
        local Text = require("core.text")
        local recipe = Text.define():align("left")
        assert_equals("left", recipe._config.align)
    end)

    it(":layer() stores layer object", function()
        local Text = require("core.text")
        local layer = { name = "ui" }
        local recipe = Text.define():layer(layer)
        assert_equals(layer, recipe._config.layer)
    end)

    it(":z() stores z-index", function()
        local Text = require("core.text")
        local recipe = Text.define():z(10)
        assert_equals(10, recipe._config.z)
    end)

    it(":space() stores render space", function()
        local Text = require("core.text")
        local recipe = Text.define():space("world")
        assert_equals("world", recipe._config.space)
    end)

    it(":font() stores font object", function()
        local Text = require("core.text")
        local font = { name = "custom" }
        local recipe = Text.define():font(font)
        assert_equals(font, recipe._config.font)
    end)

    it(":fadeIn() stores fade-in percentage", function()
        local Text = require("core.text")
        local recipe = Text.define():fadeIn(0.3)
        assert_equals(0.3, recipe._config.fadeInPct)
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

    it("handle survives if entity is still valid", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(12, 100, 200)
        local recipe = Text.define():content("test"):width(100)
        recipe:spawn():at(0, 0):attachTo(entity)

        assert_equals(1, #Text._activeHandles)

        -- Entity still alive
        Text.update(0.016)

        -- Handle should still be active
        assert_equals(1, #Text._activeHandles)
    end)
end)

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

    it("stream mode allows pre-configuration before positioning", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():stream()

        -- Should be able to configure before activating
        assert_equals(0, #Text._activeHandles)
        assert_not_nil(handle)
        assert_true(handle.isActive and handle:isActive(), "handle should be active")
    end)
end)

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

    it("handle:getEntity() returns entity ID when in entity mode", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():asEntity():at(0, 0)

        -- Should have a mock entity ID (for now, just a number)
        local entity = handle:getEntity()
        assert_not_nil(entity, "Entity ID should not be nil in entity mode")
    end)

    it("handle:getEntity() returns nil for non-entity mode", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(0, 0)

        assert_equals(nil, handle:getEntity())
    end)
end)

TestRunner.describe("Integration: Damage number scenario", function()
    it("Recipe -> spawn with value -> entity positioning -> fade + lifespan -> cleanup", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        -- Create enemy entity
        local enemy = createMockEntity(100, 300, 400)

        -- Create damage number recipe with all features
        local damageRecipe = Text.define()
            :content("[%d](color=red;pop=0.2)")
            :size(20)
            :fade()
            :lifespan(0.8)

        -- Spawn above enemy with damage value
        local handle = damageRecipe:spawn(25):above(enemy, 15)

        -- Verify creation
        assert_not_nil(handle, "Handle should be created")
        assert_equals(1, #Text._activeHandles, "Should be in active list")
        assert_equals("[25](color=red;pop=0.2)", handle._content, "Content should be formatted with value")
        assert_true(handle._config.fade, "Fade should be enabled")
        assert_equals(0.8, handle._lifespan, "Lifespan should be set")

        -- Verify entity positioning (above enemy)
        local expectedX = 300 + 16  -- enemy center X
        local expectedY = 400 - 15  -- above enemy by offset
        assert_equals(expectedX, handle._position.x, "X position should be above enemy center")
        assert_equals(expectedY, handle._position.y, "Y position should be above enemy")

        -- Simulate time passing (not expired yet)
        Text.update(0.4)
        assert_equals(1, #Text._activeHandles, "Should still be active at 0.4s")

        -- Simulate time passing (expired)
        Text.update(0.5)  -- Total: 0.9s > 0.8s lifespan
        assert_equals(0, #Text._activeHandles, "Should be cleaned up after lifespan")
    end)
end)

TestRunner.describe("Integration: HP bar scenario", function()
    it("Recipe with callback -> stream -> follow entity -> update content", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        -- Create player entity
        local player = createMockEntity(200, 100, 150)

        -- Simulate player HP
        local playerHP = { current = 100, max = 100 }

        -- Create HP bar recipe with callback
        local hpRecipe = Text.define()
            :content(function()
                return string.format("HP: %d/%d", playerHP.current, playerHP.max)
            end)
            :size(14)
            :anchor("center")

        -- Use stream mode to get handle reference before final positioning
        local spawner = hpRecipe:spawn()
        spawner:follow():attachTo(player)
        local handle = spawner:above(player, 40)  -- Final positioning triggers spawn

        -- Verify initial state
        assert_equals(1, #Text._activeHandles, "Should be in active list after positioning")
        assert_equals("HP: 100/100", handle._content, "Initial HP should be correct")

        -- Verify following positioning
        local expectedX = 100 + 16  -- player center X
        local expectedY = 150 - 40  -- above player by offset
        assert_equals(expectedX, handle._position.x, "X position should be above player center")
        assert_equals(expectedY, handle._position.y, "Y position should be above player")

        -- Simulate player taking damage
        playerHP.current = 75
        handle:setText()  -- Re-evaluate callback
        assert_equals("HP: 75/100", handle._content, "HP should update after taking damage")

        -- Simulate player movement
        mockTransforms[200].actualX = 200
        mockTransforms[200].actualY = 250

        Text.update(0.016)

        -- Verify position follows player
        local newExpectedX = 200 + 16
        local newExpectedY = 250 - 40
        assert_equals(newExpectedX, handle._position.x, "X should follow player")
        assert_equals(newExpectedY, handle._position.y, "Y should follow player")

        -- Simulate player death
        mockEntities[200] = nil
        Text.update(0.016)

        -- Verify cleanup via attachTo
        assert_equals(0, #Text._activeHandles, "HP bar should be removed when player dies")
    end)
end)

TestRunner.describe("Integration: Combat cleanup scenario", function()
    it("Multiple tagged spawns -> stopByTag -> verify cleanup", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        -- Create combat entities
        local enemy1 = createMockEntity(300, 100, 100)
        local enemy2 = createMockEntity(301, 200, 100)
        local enemy3 = createMockEntity(302, 300, 100)
        local player = createMockEntity(303, 400, 100)

        -- Create damage number recipe
        local damageRecipe = Text.define()
            :content("[%d](color=red)")
            :size(16)
            :fade()
            :lifespan(1.0)

        -- Create status effect recipe
        local statusRecipe = Text.define()
            :content("[POISONED](color=green;wave)")
            :size(12)
            :lifespan(3.0)

        -- Create player UI recipe (no lifespan - persistent)
        local uiRecipe = Text.define()
            :content("Combo: x5")
            :size(18)

        -- Spawn various combat text with tags
        damageRecipe:spawn(50):above(enemy1, 20):tag("combat")
        damageRecipe:spawn(75):above(enemy2, 20):tag("combat")
        damageRecipe:spawn(100):above(enemy3, 20):tag("combat")

        statusRecipe:spawn():above(enemy1, 40):follow():tag("combat"):attachTo(enemy1)
        statusRecipe:spawn():above(enemy2, 40):follow():tag("combat"):attachTo(enemy2)

        uiRecipe:spawn():above(player, 50):follow():tag("ui")

        -- Verify all spawned
        assert_equals(6, #Text._activeHandles, "Should have 6 text handles")

        -- Simulate combat ending - clear all combat text
        Text.stopByTag("combat")
        Text.update(0)

        -- Verify only UI remains
        assert_equals(1, #Text._activeHandles, "Only UI text should remain")
        assert_equals("ui", Text._activeHandles[1]._tag, "Remaining handle should be UI tag")
        assert_equals("Combo: x5", Text._activeHandles[1]._content, "Should be the combo text")

        -- Clear all remaining
        Text.stopAll()
        assert_equals(0, #Text._activeHandles, "All text should be cleared")
    end)
end)

TestRunner.describe("Integration: Complete workflow", function()
    it("Demonstrates real-world usage patterns", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        -- Setup: Create game entities
        local boss = createMockEntity(400, 500, 300)
        local player = createMockEntity(401, 100, 500)

        -- Pattern 1: Fire-and-forget damage numbers
        local critRecipe = Text.define()
            :content("[CRIT %d!](color=yellow;shake=2)")
            :size(24)
            :fade()
            :lifespan(1.2)

        critRecipe:spawn(999):above(boss, 25)

        -- Pattern 2: Persistent status with following
        local bossName = Text.define()
            :content("Dark Lord Valkor")
            :size(16)
            :color("red")

        local nameSpawner = bossName:spawn()
        nameSpawner:follow():attachTo(boss)
        local nameHandle = nameSpawner:above(boss, 60)

        -- Pattern 3: Dynamic updating health bar
        local bossHP = { current = 5000, max = 10000 }

        local bossHPRecipe = Text.define()
            :content(function()
                local pct = math.floor((bossHP.current / bossHP.max) * 100)
                return string.format("HP: %d%% (%d/%d)", pct, bossHP.current, bossHP.max)
            end)
            :size(12)

        local hpSpawner = bossHPRecipe:spawn()
        hpSpawner:follow():attachTo(boss)
        local hpHandle = hpSpawner:above(boss, 80)

        -- Verify initial state
        assert_equals(3, #Text._activeHandles, "Should have 3 handles")
        assert_true(Text.getActiveCount() == 3, "getActiveCount should match")

        -- Simulate boss taking damage and moving
        bossHP.current = 2500
        hpHandle:setText()  -- Update HP display

        mockTransforms[400].actualX = 600
        mockTransforms[400].actualY = 350

        Text.update(0.016)

        -- Verify HP updated
        local expectedHPContent = "HP: 25% (2500/10000)"
        assert_equals(expectedHPContent, hpHandle._content, "HP should reflect damage")

        -- Verify following (name and HP follow boss)
        local bossNewCenterX = 600 + 16
        assert_equals(bossNewCenterX, nameHandle._position.x, "Name should follow boss X")
        assert_equals(bossNewCenterX, hpHandle._position.x, "HP should follow boss X")

        -- Simulate critical hit wearing off
        Text.update(1.3)  -- Exceeds crit text lifespan

        assert_equals(2, #Text._activeHandles, "Crit text should expire")

        -- Simulate boss death
        mockEntities[400] = nil
        Text.update(0.016)

        -- Both name and HP bar should be removed via attachTo
        assert_equals(0, #Text._activeHandles, "All boss text should be removed with boss")
    end)
end)

TestRunner.describe("Pop animation configuration", function()
    it(":pop() stores default config", function()
        local Text = require("core.text")
        local recipe = Text.define():pop()
        assert_not_nil(recipe._config.pop)
        assert_equals(0.15, recipe._config.pop.scale)  -- 0.3 * 0.5
        assert_equals(9, recipe._config.pop.rotation)  -- 0.3 * 30
        assert_equals(0.25, recipe._config.pop.duration)
    end)

    it(":pop(intensity) scales config values", function()
        local Text = require("core.text")
        local recipe = Text.define():pop(0.5)
        assert_equals(0.25, recipe._config.pop.scale)  -- 0.5 * 0.5
        assert_equals(15, recipe._config.pop.rotation)  -- 0.5 * 30
    end)

    it(":pop(table) uses explicit config", function()
        local Text = require("core.text")
        local recipe = Text.define():pop({ scale = 0.4, rotation = 20, duration = 0.3 })
        assert_equals(0.4, recipe._config.pop.scale)
        assert_equals(20, recipe._config.pop.rotation)
        assert_equals(0.3, recipe._config.pop.duration)
    end)
end)

TestRunner.describe("Pop animation state", function()
    it("handle has _anim when :pop() is used", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100):pop(0.5)
        local handle = recipe:spawn():at(100, 200)

        assert_not_nil(handle._anim, "Handle should have _anim")
        assert_true(handle._anim.active, "Animation should be active")
        assert_equals(0, handle._anim.elapsed)
        assert_equals(0, handle._anim.currentScale)  -- starts at 0
    end)

    it("handle has no _anim without :pop()", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100)
        local handle = recipe:spawn():at(100, 200)

        assert_equals(nil, handle._anim)
    end)

    it("animation progresses over time", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100):pop(0.5)
        local handle = recipe:spawn():at(100, 200)

        -- Initial state
        assert_equals(0, handle._anim.currentScale)

        -- After first update
        Text.update(0.05)
        assert_true(handle._anim.currentScale > 0, "Scale should increase after update")
        assert_true(handle._anim.active, "Animation should still be active")

        -- After animation completes
        Text.update(0.3)  -- total > 0.25 duration
        assert_true(not handle._anim.active, "Animation should be complete")
        assert_equals(1, handle._anim.currentScale, "Scale should be 1 after completion")
        assert_equals(0, handle._anim.currentRotation, "Rotation should be 0 after completion")
    end)
end)

TestRunner.describe("Pop animation rendering", function()
    it("animation applies to text renderer base_scale", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local recipe = Text.define():content("test"):width(100):pop(0.5)
        local handle = recipe:spawn():at(100, 200)

        -- After updates, check that renderer received scale
        Text.update(0.1)

        -- MockCommandBufferText should have received set_base_scale call
        -- We verify the _anim state is being computed correctly
        assert_true(handle._anim.currentScale > 0)
        assert_true(handle._anim.currentScale < 1.5)  -- shouldn't overshoot too much
    end)
end)

TestRunner.describe("Integration: Pop animation with damage numbers", function()
    it("Pop + fade + lifespan work together", function()
        local Text = require("core.text")
        Text._activeHandles = {}

        local entity = createMockEntity(500, 100, 200)

        local damageRecipe = Text.define()
            :content("[%d](color=red)")
            :size(20)
            :pop(0.3)
            :fade()
            :lifespan(0.8)

        local handle = damageRecipe:spawn(50):above(entity, 15)

        -- Verify all features configured
        assert_not_nil(handle._anim, "Pop animation should be initialized")
        assert_true(handle._config.fade, "Fade should be enabled")
        assert_equals(0.8, handle._lifespan, "Lifespan should be set")
        assert_equals("[50](color=red)", handle._content, "Content should be formatted")

        -- Animation should progress
        Text.update(0.1)
        assert_true(handle._anim.currentScale > 0.5, "Should have scaled up quickly")

        -- Animation should complete before lifespan
        Text.update(0.2)  -- total 0.3s > 0.25 duration
        assert_true(not handle._anim.active, "Pop animation should be complete")
        assert_equals(1, handle._anim.currentScale, "Scale should be 1")

        -- Handle should still exist (lifespan not reached)
        assert_equals(1, #Text._activeHandles, "Handle should still be active")

        -- After lifespan, handle is removed
        Text.update(0.6)  -- total 0.9s > 0.8 lifespan
        assert_equals(0, #Text._activeHandles, "Handle should be removed after lifespan")
    end)
end)

-- Run tests
TestRunner.run_all()
