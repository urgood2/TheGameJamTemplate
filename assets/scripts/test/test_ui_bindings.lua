-- test_ui_bindings.lua
-- UI bindings coverage tests (Phase 2 A2)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function get_registry()
    return _G.registry or registry
end

local function ensure_ui_builders()
    TestUtils.assert_not_nil(_G.UIElementTemplateNodeBuilder, "UIElementTemplateNodeBuilder available")
    TestUtils.assert_not_nil(_G.UIConfigBuilder, "UIConfigBuilder available")
    TestUtils.assert_not_nil(_G.UITypeEnum, "UITypeEnum available")
end

local function build_node(node_type, id)
    ensure_ui_builders()
    local config = UIConfigBuilder.create()
    if config.addId then
        config:addId(id)
    end
    if config.addMinWidth then
        config:addMinWidth(16)
    end
    if config.addMinHeight then
        config:addMinHeight(16)
    end
    if _G.AlignmentFlag and _G.bit and config.addAlign then
        config:addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
    end
    if config.build then
        config = config:build()
    end
    return UIElementTemplateNodeBuilder.create()
        :addType(node_type)
        :addConfig(config)
        :build()
end

local function build_root_with_child(child_id)
    local child = build_node(UITypeEnum.RECT_SHAPE, child_id or "child")
    local root_config = UIConfigBuilder.create()
    if root_config.addId then
        root_config:addId("root")
    end
    if root_config.addMinWidth then
        root_config:addMinWidth(32)
    end
    if root_config.addMinHeight then
        root_config:addMinHeight(32)
    end
    if _G.AlignmentFlag and _G.bit and root_config.addAlign then
        root_config:addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
    end
    if root_config.build then
        root_config = root_config:build()
    end

    return UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(root_config)
        :addChild(child)
        :build()
end

local function init_uibox()
    local ui = _G.ui
    TestUtils.assert_not_nil(ui, "ui table available")
    TestUtils.assert_not_nil(ui.box, "ui.box table available")
    TestUtils.assert_true(type(ui.box.Initialize) == "function", "ui.box.Initialize exists")

    local root = build_root_with_child("child")
    local box = ui.box.Initialize({ x = 0, y = 0 }, root)
    TestUtils.assert_not_nil(box, "ui.box.Initialize returned entity")

    local registry = get_registry()
    if registry and registry.valid then
        TestUtils.assert_true(registry:valid(box), "uiBox entity valid")
    end

    return box
end

TestRunner.register("ui.box.initialize.basic", "ui", function()
    TestUtils.reset_world()
    init_uibox()
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_initialize"},
    requires = {"test_scene"},
})

TestRunner.register("ui.box.renew_alignment.basic", "ui", function()
    TestUtils.reset_world()
    local registry = get_registry()
    TestUtils.assert_not_nil(registry, "registry available")

    local ui_box = init_uibox()
    TestUtils.assert_true(type(_G.ui.box.RenewAlignment) == "function", "ui.box.RenewAlignment exists")
    local ok = pcall(_G.ui.box.RenewAlignment, registry, ui_box)
    TestUtils.assert_true(ok, "RenewAlignment executed")
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_renewalignment"},
    requires = {"test_scene"},
})

TestRunner.register("ui.box.add_state_tag.basic", "ui", function()
    TestUtils.reset_world()
    local ui_box = init_uibox()
    TestUtils.assert_true(type(_G.ui.box.AddStateTagToUIBox) == "function", "ui.box.AddStateTagToUIBox exists")
    local ok = pcall(_G.ui.box.AddStateTagToUIBox, ui_box, "test_state")
    TestUtils.assert_true(ok, "AddStateTagToUIBox executed")
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_addstatetagtouibox"},
    requires = {"test_scene"},
})

TestRunner.register("ui.box.set_draw_layer.basic", "ui", function()
    TestUtils.reset_world()
    local ui_box = init_uibox()
    TestUtils.assert_true(type(_G.ui.box.set_draw_layer) == "function", "ui.box.set_draw_layer exists")
    local ok = pcall(_G.ui.box.set_draw_layer, ui_box, "ui")
    TestUtils.assert_true(ok, "set_draw_layer executed")
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_set_draw_layer"},
    requires = {"test_scene"},
})

TestRunner.register("ui.box.get_uie_by_id.basic", "ui", function()
    TestUtils.reset_world()
    local registry = get_registry()
    TestUtils.assert_not_nil(registry, "registry available")

    local ui_box = init_uibox()
    TestUtils.assert_true(type(_G.ui.box.GetUIEByID) == "function", "ui.box.GetUIEByID exists")
    local element = _G.ui.box.GetUIEByID(registry, ui_box, "child")
    TestUtils.assert_not_nil(element, "GetUIEByID returned element")
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_getuiebyid"},
    requires = {"test_scene"},
})

TestRunner.register("ui.box.replace_children.basic", "ui", function()
    TestUtils.reset_world()
    local registry = get_registry()
    TestUtils.assert_not_nil(registry, "registry available")

    local ui_box = init_uibox()
    local parent = _G.ui.box.GetUIEByID(registry, ui_box, "child")
    TestUtils.assert_not_nil(parent, "parent element available")

    TestUtils.assert_true(type(_G.ui.box.ReplaceChildren) == "function", "ui.box.ReplaceChildren exists")
    local new_child = build_node(UITypeEnum.RECT_SHAPE, "child_replacement")
    local ok = _G.ui.box.ReplaceChildren(parent, new_child)
    TestUtils.assert_true(ok, "ReplaceChildren returned true")
    TestUtils.reset_world()
end, {
    tags = {"ui", "bindings"},
    doc_ids = {"sol2_function_ui_box_replacechildren"},
    requires = {"test_scene"},
})
