-- assets/scripts/tests/test_shader_layer_bindings.lua
-- Shader + layer binding verification tests.

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local t = require("tests.test_runner")
local test_utils = require("tests.test_utils")
local component_cache = require("core.component_cache")

local assert_eq = test_utils.assert_eq
local assert_true = test_utils.assert_true
local assert_not_nil = test_utils.assert_not_nil

local function log(msg)
    test_utils.log("[SHADER-LAYER] " .. msg)
end

local function register(test_id, fn, opts)
    opts = opts or {}
    opts.tags = opts.tags or {"bindings", "shader_layer"}
    opts.requires = opts.requires or {"test_scene"}
    t:register(test_id, "shader_layer", fn, opts)
end

local function get_layer_target()
    if _G.layers and _G.layers.ui then
        return _G.layers.ui
    end
    if _G.layer and _G.layer.CreateLayer then
        return _G.layer.CreateLayer()
    end
    return nil
end

local function pick_shader_name(shaders)
    local candidates = {"bloom", "glow", "flash"}
    if not (shaders and shaders.getShader) then
        return candidates[1]
    end
    for _, name in ipairs(candidates) do
        local ok, value = pcall(shaders.getShader, name)
        if ok and value ~= nil then
            return name
        end
    end
    return candidates[1]
end

register("shader.load.basic", function()
    local shaders = _G.shaders
    assert_not_nil(shaders, "shaders table missing")
    assert_true(type(shaders.loadShadersFromJSON) == "function", "loadShadersFromJSON missing")
    local ok, err = pcall(shaders.loadShadersFromJSON, "shaders/shaders.json")
    assert_true(ok, "loadShadersFromJSON failed: " .. tostring(err))
end, {
    doc_ids = {"binding:shaders.loadShadersFromJSON"},
})

register("shader.set_uniform.basic", function()
    local shaders = _G.shaders
    assert_not_nil(shaders, "shaders table missing")

    local uniform_set = nil
    if type(shaders.ShaderUniformSet) == "function" then
        uniform_set = shaders.ShaderUniformSet()
    elseif type(shaders.ShaderUniformSet) == "table" and type(shaders.ShaderUniformSet.new) == "function" then
        uniform_set = shaders.ShaderUniformSet.new()
    end

    assert_not_nil(uniform_set, "ShaderUniformSet constructor missing")

    uniform_set:set("u_time", 1.25)
    local value = uniform_set:get("u_time")
    assert_eq(value, 1.25, "Uniform value roundtrip")
end, {
    doc_ids = {
        "binding:shaders.ShaderUniformSet.set",
        "binding:shaders.ShaderUniformSet.get",
    },
})

register("shader_pipeline.add_pass.basic", function()
    local registry = _G.registry
    assert_not_nil(registry, "registry missing")
    assert_true(type(_G.addShaderPass) == "function", "addShaderPass missing")
    assert_true(_G.shader_pipeline and _G.shader_pipeline.ShaderPipelineComponent ~= nil, "ShaderPipelineComponent missing")

    local entity = registry:create()
    _G.addShaderPass(registry, entity, "flash", {})

    local pipeline = nil
    if component_cache and _G.shader_pipeline and _G.shader_pipeline.ShaderPipelineComponent then
        pipeline = component_cache.get(entity, _G.shader_pipeline.ShaderPipelineComponent)
    end
    if not pipeline and registry.get and _G.shader_pipeline and _G.shader_pipeline.ShaderPipelineComponent then
        pipeline = registry:get(entity, _G.shader_pipeline.ShaderPipelineComponent)
    end

    assert_not_nil(pipeline, "ShaderPipelineComponent missing after addShaderPass")
    local passes = pipeline.passes or {}
    assert_true(#passes >= 1, "Expected at least one shader pass")
end, {
    doc_ids = {
        "binding:addShaderPass",
        "binding:shader_pipeline.ShaderPipelineComponent.addPass",
    },
})

register("layer.create.basic", function()
    local layer_tbl = _G.layer
    assert_not_nil(layer_tbl, "layer table missing")
    assert_true(type(layer_tbl.CreateLayer) == "function", "CreateLayer missing")
    local created = layer_tbl.CreateLayer()
    assert_not_nil(created, "CreateLayer returned nil")
end, {
    doc_ids = {"binding:layer.CreateLayer"},
})

register("command_buffer.queueDraw.basic", function()
    local cb = _G.command_buffer
    assert_not_nil(cb, "command_buffer missing")
    assert_true(type(cb.queueDrawRectangle) == "function", "queueDrawRectangle missing")

    local layer_target = get_layer_target()
    assert_not_nil(layer_target, "layer target missing")

    cb.queueDrawRectangle(layer_target, function(cmd)
        cmd.x, cmd.y, cmd.width, cmd.height = 10, 10, 32, 24
        if _G.WHITE then
            cmd.color = _G.WHITE
        end
    end, 100, _G.layer.DrawCommandSpace.Screen)

    if layer_target.commands then
        assert_true(#layer_target.commands >= 1, "Expected queued commands")
    end
end, {
    doc_ids = {
        "binding:command_buffer.queueDrawRectangle",
        "binding:layer.DrawCommandSpace.Screen",
    },
})

register("command_buffer.execute.basic", function()
    local cb = _G.command_buffer
    assert_not_nil(cb, "command_buffer missing")
    assert_true(type(cb.executeDrawRectangle) == "function", "executeDrawRectangle missing")

    local layer_target = get_layer_target()
    assert_not_nil(layer_target, "layer target missing")

    local ok, err = pcall(cb.executeDrawRectangle, layer_target, function(cmd)
        cmd.x, cmd.y, cmd.width, cmd.height = 16, 16, 12, 12
        if _G.WHITE then
            cmd.color = _G.WHITE
        end
    end)
    assert_true(ok, "executeDrawRectangle failed: " .. tostring(err))
end, {
    doc_ids = {"binding:command_buffer.executeDrawRectangle"},
})

register("shader.bloom.visual", function()
    local shaders = _G.shaders
    assert_not_nil(shaders, "shaders table missing")
    if shaders.loadShadersFromJSON then
        pcall(shaders.loadShadersFromJSON, "shaders/shaders.json")
    end

    local shader_name = pick_shader_name(shaders)
    log("Using shader mode: " .. tostring(shader_name))
    if shaders.setShaderMode then
        pcall(shaders.setShaderMode, shader_name)
    end

    test_utils.screenshot_after_frames("shader.bloom.visual", 5)

    if shaders.unsetShaderMode then
        pcall(shaders.unsetShaderMode)
    end
end, {
    tags = {"visual", "shader"},
    requires = {"test_scene", "screenshot"},
    doc_ids = {
        "binding:shaders.setShaderMode",
        "binding:shaders.unsetShaderMode",
    },
})

register("layer.ordering.visual", function()
    local cb = _G.command_buffer
    assert_not_nil(cb, "command_buffer missing")
    assert_true(type(cb.queueDrawRectangle) == "function", "queueDrawRectangle missing")

    local layer_target = get_layer_target()
    assert_not_nil(layer_target, "layer target missing")

    cb.queueDrawRectangle(layer_target, function(cmd)
        cmd.x, cmd.y, cmd.width, cmd.height = 40, 40, 90, 60
        if _G.RED then
            cmd.color = _G.RED
        end
    end, 10, _G.layer.DrawCommandSpace.Screen)

    cb.queueDrawRectangle(layer_target, function(cmd)
        cmd.x, cmd.y, cmd.width, cmd.height = 60, 55, 90, 60
        if _G.BLUE then
            cmd.color = _G.BLUE
        end
    end, 20, _G.layer.DrawCommandSpace.Screen)

    test_utils.screenshot_after_frames("layer.ordering.visual", 5)
end, {
    tags = {"visual", "layer"},
    requires = {"test_scene", "screenshot"},
    doc_ids = {
        "binding:command_buffer.queueDrawRectangle",
        "binding:layer.DrawCommandSpace.Screen",
    },
})
