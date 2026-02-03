-- test_ui_components.lua
-- UI component access tests (Phase 3 B3)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function require_globals()
    test_utils.assert_not_nil(_G.UIConfig, "UIConfig available")
    test_utils.assert_not_nil(_G.UIElementCore, "UIElementCore available")
    test_utils.assert_not_nil(_G.UIStyleConfig, "UIStyleConfig available")
    test_utils.assert_not_nil(_G.UIBoxComponent, "UIBoxComponent available")
    test_utils.assert_not_nil(_G.registry, "registry available")
    test_utils.assert_not_nil(_G.component_cache, "component_cache available")
end

TestRunner.register("ui.components.smoke", "components", function()
    require_globals()
    if _G.collision then
        test_utils.assert_not_nil(_G.collision.ScreenSpaceCollisionMarker, "ScreenSpaceCollisionMarker available")
    else
        test_utils.assert_not_nil(_G.ScreenSpaceCollisionMarker, "ScreenSpaceCollisionMarker available")
    end
end, {
    tags = {"ui", "components", "smoke"},
    doc_ids = {
        "component:UIConfig",
        "component:UIElementCore",
        "component:UIStyleConfig",
        "component:UIBoxComponent",
        "component:ScreenSpaceCollisionMarker",
    },
    requires = {"test_scene"},
})

TestRunner.register("ui.components.uiconfig.basic", "components", function()
    require_globals()
    local cfg = UIConfig()
    cfg.id = "test_id"
    cfg.drawLayer = 2
    test_utils.assert_eq(cfg.id, "test_id", "UIConfig.id read/write")
    test_utils.assert_eq(cfg.drawLayer, 2, "UIConfig.drawLayer read/write")
end, {
    tags = {"ui", "components"},
    doc_ids = {"component:UIConfig"},
    requires = {"test_scene"},
})

TestRunner.register("ui.components.uielementcore.basic", "components", function()
    require_globals()
    local core = UIElementCore()
    core.id = "core_id"
    core.treeOrder = 5
    test_utils.assert_eq(core.id, "core_id", "UIElementCore.id read/write")
    test_utils.assert_eq(core.treeOrder, 5, "UIElementCore.treeOrder read/write")
end, {
    tags = {"ui", "components"},
    doc_ids = {"component:UIElementCore"},
    requires = {"test_scene"},
})

TestRunner.register("ui.components.uistyleconfig.basic", "components", function()
    require_globals()
    local style = UIStyleConfig()
    style.outlineThickness = 2
    style.shadow = true
    test_utils.assert_eq(style.outlineThickness, 2, "UIStyleConfig.outlineThickness read/write")
    test_utils.assert_eq(style.shadow, true, "UIStyleConfig.shadow read/write")
end, {
    tags = {"ui", "components"},
    doc_ids = {"component:UIStyleConfig"},
    requires = {"test_scene"},
})

TestRunner.register("ui.components.uiboxcomponent.uiroot_sync", "components", function()
    require_globals()

    local dsl = require("ui.ui_syntax_sugar")
    local def = dsl.root { children = {} }
    local box = dsl.spawn({ x = 0, y = 0 }, def, "ui", 0)

    local boxComp = component_cache.get(box, UIBoxComponent)
    test_utils.assert_not_nil(boxComp, "UIBoxComponent present")
    test_utils.assert_not_nil(boxComp.uiRoot, "UIBoxComponent.uiRoot present")

    local t = component_cache.get(box, Transform)
    local rt = component_cache.get(boxComp.uiRoot, Transform)
    test_utils.assert_not_nil(t, "Transform present on UIBox")
    test_utils.assert_not_nil(rt, "Transform present on uiRoot")

    t.actualX, t.actualY = 120, 240
    rt.actualX, rt.actualY = 120, 240

    test_utils.assert_eq(rt.actualX, t.actualX, "uiRoot X synced with Transform")
    test_utils.assert_eq(rt.actualY, t.actualY, "uiRoot Y synced with Transform")
end, {
    tags = {"ui", "components"},
    doc_ids = {"component:UIBoxComponent"},
    requires = {"test_scene"},
})
