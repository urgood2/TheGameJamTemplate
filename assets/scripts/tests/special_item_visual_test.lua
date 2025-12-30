local SpecialItem = require("core.special_item")
local component_cache = require("core.component_cache")

local VisualTest = {}
VisualTest.test_items = {}

local function get_screen_center()
    local screen_w = globals and globals.screenWidth and globals.screenWidth() or 800
    local screen_h = globals and globals.screenHeight and globals.screenHeight() or 600
    return screen_w / 2, screen_h / 2
end

local function find_sprite()
    local sprite_options = {
        "frame0012.png",
        "b8090.png",
    }
    
    for _, sprite_id in ipairs(sprite_options) do
        local ok, entity = pcall(function()
            return animation_system.createAnimatedObjectWithTransform(sprite_id, true)
        end)
        if ok and entity then
            pcall(function() registry:destroy(entity) end)
            return sprite_id
        end
    end
    return nil
end

function VisualTest.run()
    print("")
    print("================================================================================")
    print("SPECIAL ITEM VISUAL TEST - Starting")
    print("================================================================================")
    
    local center_x, center_y = get_screen_center()
    local sprite = find_sprite()
    
    if not sprite then
        print("[WARN] No sprites found - using nil sprite")
    end
    
    local item1 = SpecialItem.create({
        sprite = sprite,
        position = { x = center_x - 200, y = center_y },
        size = { 64, 64 },
        shader = "3d_skew_holo",
        particles = { enabled = true, preset = "bubble", colors = { "cyan", "magenta" } },
        outline = { enabled = true, color = "gold", thickness = 2 },
    })
    table.insert(VisualTest.test_items, item1)
    print("[Test 1] Created: Holographic + Bubble particles + Gold outline")
    
    local item2 = SpecialItem.new(sprite)
        :at(center_x, center_y)
        :size(64, 64)
        :shader("3d_skew_prismatic")
        :particles("sparkle", { colors = { "white", "gold" } })
        :outline("cyan", 3)
        :build()
    table.insert(VisualTest.test_items, item2)
    print("[Test 2] Created: Prismatic + Sparkle particles + Cyan outline")
    
    local item3 = SpecialItem.create({
        sprite = sprite,
        position = { x = center_x + 200, y = center_y },
        size = { 64, 64 },
        shader = "3d_skew_foil",
        particles = { enabled = true, preset = "magical", colors = { "purple", "blue", "pink" } },
        outline = { enabled = true, color = "purple", thickness = 2, type = 1 },
    })
    table.insert(VisualTest.test_items, item3)
    print("[Test 3] Created: Foil + Magical particles + Purple outline (4-way)")
    
    local item4 = SpecialItem.new(sprite)
        :at(center_x - 100, center_y + 150)
        :size(64, 64)
        :shader("3d_skew_crystalline")
        :particles("rainbow")
        :outline("white", 2)
        :build()
    table.insert(VisualTest.test_items, item4)
    print("[Test 4] Created: Crystalline + Rainbow particles + White outline")
    
    local item5 = SpecialItem.create({
        sprite = sprite,
        position = { x = center_x + 100, y = center_y + 150 },
        size = { 64, 64 },
        shader = "3d_skew_plasma",
        particles = { enabled = true, preset = "fire", density = 1.5 },
        outline = { enabled = true, color = "red", thickness = 3 },
    })
    table.insert(VisualTest.test_items, item5)
    print("[Test 5] Created: Plasma + Fire particles + Red outline")
    
    print("")
    print("================================================================================")
    print("SPECIAL ITEM VISUAL TEST - Complete")
    print("================================================================================")
    print("Created " .. #VisualTest.test_items .. " test items")
    print("Call SpecialItem.update(dt) in game loop to animate particles")
    print("Call SpecialItemVisualTest.cleanup() to remove test items")
    print("")
    
    return true
end

function VisualTest.cleanup()
    print("[SpecialItem Visual Test] Cleaning up " .. #VisualTest.test_items .. " test items...")
    for _, item in ipairs(VisualTest.test_items) do
        if item and item.destroy then
            item:destroy()
        end
    end
    VisualTest.test_items = {}
    print("[SpecialItem Visual Test] Cleanup complete")
end

if ... == nil then
    VisualTest.run()
end

_G.SpecialItemVisualTest = VisualTest

return VisualTest
