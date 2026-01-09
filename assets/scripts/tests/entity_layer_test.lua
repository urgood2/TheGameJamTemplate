local entity_layer = require("core.entity_layer")

local function test_default_layer()
    local entity = registry:create()
    local layer = entity_layer.get(entity)
    assert(layer == "sprites", "Default layer should be 'sprites', got: " .. tostring(layer))
    registry:destroy(entity)
    print("[PASS] test_default_layer")
end

local function test_set_layer_to_ui()
    local entity = registry:create()
    entity_layer.set(entity, "ui")
    local layer = entity_layer.get(entity)
    assert(layer == "ui", "Layer should be 'ui', got: " .. tostring(layer))
    registry:destroy(entity)
    print("[PASS] test_set_layer_to_ui")
end

local function test_set_layer_to_background()
    local entity = registry:create()
    entity_layer.set(entity, "background")
    local layer = entity_layer.get(entity)
    assert(layer == "background", "Layer should be 'background', got: " .. tostring(layer))
    registry:destroy(entity)
    print("[PASS] test_set_layer_to_background")
end

local function test_revert_to_sprites()
    local entity = registry:create()
    entity_layer.set(entity, "ui")
    entity_layer.set(entity, "sprites")
    local layer = entity_layer.get(entity)
    assert(layer == "sprites", "Layer should be 'sprites' after revert, got: " .. tostring(layer))
    registry:destroy(entity)
    print("[PASS] test_revert_to_sprites")
end

local function test_invalid_layer_rejected()
    local entity = registry:create()
    local ok, err = pcall(function()
        entity_layer.set(entity, "invalid_layer")
    end)
    assert(not ok, "Should reject invalid layer name")
    registry:destroy(entity)
    print("[PASS] test_invalid_layer_rejected")
end

local function run_tests()
    print("--- entity_layer tests ---")
    test_default_layer()
    test_set_layer_to_ui()
    test_set_layer_to_background()
    test_revert_to_sprites()
    test_invalid_layer_rejected()
    print("--- All tests passed ---")
end

return { run = run_tests }
