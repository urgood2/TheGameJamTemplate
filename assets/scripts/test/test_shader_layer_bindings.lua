-- test_shader_layer_bindings.lua
-- Shader and layer bindings coverage tests (Phase 2 A6)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function get_registry()
    return _G.registry or registry
end

local function get_layer_handle()
    local layers = _G.layers
    if layers then
        if layers.ui then
            return layers.ui
        end
        if layers.sprites then
            return layers.sprites
        end
        for _, handle in pairs(layers) do
            return handle
        end
    end
    return nil
end

local function ensure_layer_handle()
    local layer_mod = _G.layer
    TestUtils.assert_not_nil(layer_mod, "layer module available")

    local handle = get_layer_handle()
    if not handle and layer_mod.CreateLayerWithSize then
        handle = layer_mod.CreateLayerWithSize(64, 64)
    elseif not handle and layer_mod.CreateLayer then
        handle = layer_mod.CreateLayer()
    end
    TestUtils.assert_not_nil(handle, "layer handle available")
    return handle
end

local function ensure_shaders_loaded()
    local shaders = _G.shaders
    TestUtils.assert_not_nil(shaders, "shaders table available")

    if shaders.loadShadersFromJSON then
        local ok = pcall(shaders.loadShadersFromJSON, "assets/shaders/shaders.json")
        TestUtils.assert_true(ok, "loadShadersFromJSON succeeded")
    end
    return shaders
end

TestRunner.register("shader.load.basic", "shader", function()
    TestUtils.reset_world()
    local shaders = ensure_shaders_loaded()

    TestUtils.assert_true(type(shaders.loadShadersFromJSON) == "function", "loadShadersFromJSON exists")
    if shaders.getShader then
        local ok = pcall(shaders.getShader, "crt")
        TestUtils.assert_true(ok, "getShader succeeded")
    end
    TestUtils.reset_world()
end, {
    tags = {"shader", "smoke"},
    doc_ids = {"sol2_function_sh_loadshadersfromjson", "sol2_function_sh_getshader"},
    requires = {"test_scene"},
})

TestRunner.register("shader.set_uniform.basic", "shader", function()
    TestUtils.reset_world()
    local registry = get_registry()
    local shaders = _G.shaders
    TestUtils.assert_not_nil(registry, "registry available")
    TestUtils.assert_not_nil(shaders, "shaders table available")
    TestUtils.assert_not_nil(shaders.ShaderUniformComponent, "ShaderUniformComponent available")

    local entity = TestUtils.spawn_test_entity()
    local uniform_comp = registry:emplace(entity, shaders.ShaderUniformComponent)
    TestUtils.assert_not_nil(uniform_comp, "uniform component created")

    uniform_comp:set("crt", "enable_bloom", 1.0)
    local value = uniform_comp:get("crt", "enable_bloom")
    TestUtils.assert_eq(value, 1.0, "uniform value roundtrip")
    TestUtils.reset_world()
end, {
    tags = {"shader"},
    doc_ids = {"sol2_usertype_shaders_shaderuniformcomponent"},
    requires = {"test_scene"},
})

TestRunner.register("shader_pipeline.add_pass.basic", "shader", function()
    TestUtils.reset_world()
    local registry = get_registry()
    TestUtils.assert_not_nil(registry, "registry available")
    TestUtils.assert_true(type(_G.addShaderPass) == "function", "addShaderPass exists")

    local entity = TestUtils.spawn_test_entity()
    local ok = pcall(_G.addShaderPass, registry, entity, "gamejam", {})
    TestUtils.assert_true(ok, "addShaderPass executed")
    TestUtils.reset_world()
end, {
    tags = {"shader", "pipeline"},
    doc_ids = {"sol2_function_addshaderpass"},
    requires = {"test_scene"},
})

TestRunner.register("layer.create.basic", "layer", function()
    TestUtils.reset_world()
    local layer_mod = _G.layer
    TestUtils.assert_not_nil(layer_mod, "layer module available")

    local handle = nil
    if layer_mod.CreateLayerWithSize then
        handle = layer_mod.CreateLayerWithSize(32, 32)
    elseif layer_mod.CreateLayer then
        handle = layer_mod.CreateLayer()
    end

    TestUtils.assert_not_nil(handle, "layer created")
    TestUtils.reset_world()
end, {
    tags = {"layer"},
    doc_ids = {"sol2_function_createlayer", "sol2_function_createlayerwithsize", "sol2_usertype_layer_layer"},
    requires = {"test_scene"},
})

TestRunner.register("command_buffer.queueDraw.basic", "layer", function()
    TestUtils.reset_world()
    local command_buffer = _G.command_buffer
    TestUtils.assert_not_nil(command_buffer, "command_buffer available")

    local layer_handle = ensure_layer_handle()
    local ok = pcall(command_buffer.queueDrawRectangle, layer_handle, function(cmd)
        cmd.x = 8
        cmd.y = 8
        cmd.width = 24
        cmd.height = 16
        cmd.color = { r = 255, g = 120, b = 80, a = 255 }
    end, 900)
    TestUtils.assert_true(ok, "queueDrawRectangle executed")
    TestUtils.reset_world()
end, {
    tags = {"layer", "queue"},
    doc_ids = {"sol2_usertype_command_buffer", "sol2_usertype_layer_drawcommandspace"},
    requires = {"test_scene"},
})

TestRunner.register("command_buffer.execute.basic", "layer", function()
    TestUtils.reset_world()
    local command_buffer = _G.command_buffer
    TestUtils.assert_not_nil(command_buffer, "command_buffer available")
    TestUtils.assert_true(type(command_buffer.executeDrawRectangle) == "function", "executeDrawRectangle exists")

    local layer_handle = ensure_layer_handle()
    local ok = pcall(command_buffer.executeDrawRectangle, layer_handle, function(cmd)
        cmd.x = 40
        cmd.y = 10
        cmd.width = 24
        cmd.height = 16
        cmd.color = { r = 80, g = 200, b = 255, a = 255 }
    end)
    TestUtils.assert_true(ok, "executeDrawRectangle executed")
    TestUtils.reset_world()
end, {
    tags = {"layer", "execute"},
    doc_ids = {"sol2_usertype_command_buffer"},
    requires = {"test_scene"},
})

TestRunner.register("shader.bloom.visual", "shader", function()
    TestUtils.reset_world()
    local shaders = ensure_shaders_loaded()
    local uniforms = _G.globalShaderUniforms
    local command_buffer = _G.command_buffer
    local layer_handle = ensure_layer_handle()

    if uniforms and uniforms.set then
        uniforms:set("crt", "enable_bloom", 1.0)
        uniforms:set("crt", "bloom_strength", 0.2)
        uniforms:set("crt", "bloom_radius", 2.0)
    end

    if shaders.setShaderMode then
        pcall(shaders.setShaderMode, "crt")
    end

    if command_buffer and command_buffer.queueDrawRectangle then
        command_buffer.queueDrawRectangle(layer_handle, function(cmd)
            cmd.x = 100
            cmd.y = 60
            cmd.width = 120
            cmd.height = 80
            cmd.color = { r = 255, g = 255, b = 255, a = 255 }
        end, 1200)
    end

    TestUtils.screenshot_after_frames("shader.bloom.visual", 2)

    if shaders.unsetShaderMode then
        pcall(shaders.unsetShaderMode)
    end
    TestUtils.reset_world()
end, {
    tags = {"shader", "visual"},
    doc_ids = {"sol2_function_sh_setshadermode", "sol2_function_sh_unsetshadermode"},
    requires = {"test_scene", "screenshot"},
})

TestRunner.register("layer.ordering.visual", "layer", function()
    TestUtils.reset_world()
    local command_buffer = _G.command_buffer
    local layer_handle = ensure_layer_handle()

    TestUtils.assert_not_nil(command_buffer, "command_buffer available")

    command_buffer.queueDrawRectangle(layer_handle, function(cmd)
        cmd.x = 20
        cmd.y = 20
        cmd.width = 140
        cmd.height = 90
        cmd.color = { r = 40, g = 120, b = 255, a = 255 }
    end, 800)

    command_buffer.queueDrawRectangle(layer_handle, function(cmd)
        cmd.x = 60
        cmd.y = 40
        cmd.width = 140
        cmd.height = 90
        cmd.color = { r = 255, g = 80, b = 80, a = 255 }
    end, 900)

    TestUtils.screenshot_after_frames("layer.ordering.visual", 2)
    TestUtils.reset_world()
end, {
    tags = {"layer", "visual"},
    doc_ids = {"sol2_usertype_command_buffer", "sol2_usertype_layer_drawcommandspace"},
    requires = {"test_scene", "screenshot"},
})
