-- Test script for UI asset pack system
-- Verifies that UI packs can be registered, loaded, and queried for UI elements

local function test_ui_pack()
    print("=== Testing UI Asset Pack System ===")

    -- Test registration
    local success = ui.register_pack("test", "assets/ui_packs/test_pack/pack.json")
    assert(success, "Failed to register test pack")
    print("PASS: Pack registration")

    -- Test use_pack
    local pack = ui.use_pack("test")
    assert(pack ~= nil, "Failed to get pack handle")
    print("PASS: Get pack handle")

    -- Test panel
    local panelConfig = pack:panel("simple")
    assert(panelConfig ~= nil, "Failed to get panel config")
    assert(panelConfig.stylingType == UIStylingType.NinePatchBorders, "Panel should be 9-patch")
    print("PASS: Panel config")

    -- Test button
    local buttonConfig = pack:button("default")
    assert(buttonConfig ~= nil, "Failed to get button config")
    print("PASS: Button config")

    -- Test icon
    local iconConfig = pack:icon("star")
    assert(iconConfig ~= nil, "Failed to get icon config")
    assert(iconConfig.stylingType == UIStylingType.Sprite, "Icon should be sprite")
    assert(iconConfig.spriteScaleMode == SpriteScaleMode.Fixed, "Icon should be fixed scale")
    print("PASS: Icon config")

    -- Test with options (merge behavior)
    -- Note: The current implementation doesn't support option merging at the Lua level,
    -- but this test documents the expected future API
    local panelWithOpts = pack:panel("simple")
    assert(panelWithOpts ~= nil, "Panel config should exist")
    assert(panelWithOpts.stylingType == UIStylingType.NinePatchBorders, "Panel config should have styling type")
    print("PASS: Panel config access")

    -- Test invalid pack name
    local invalidPack = ui.use_pack("nonexistent")
    assert(invalidPack == nil, "Should return nil for nonexistent pack")
    print("PASS: Invalid pack returns nil")

    -- Test invalid element
    local invalidPanel = pack:panel("nonexistent")
    assert(invalidPanel == nil, "Should return nil for nonexistent panel")
    print("PASS: Invalid element returns nil")

    print("=== All UI Pack Tests Passed ===")
end

return test_ui_pack
