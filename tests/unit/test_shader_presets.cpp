#include <gtest/gtest.h>
#include "systems/shaders/shader_presets.hpp"
#include "sol/sol.hpp"
#include "entt/entt.hpp"
#include "systems/shaders/shader_pipeline.hpp"

TEST(ShaderPresets, GetPresetReturnsNullptrForUnknown) {
    const auto* preset = shader_presets::getPreset("nonexistent");
    EXPECT_EQ(preset, nullptr);
}

TEST(ShaderPresets, HasPresetReturnsFalseForUnknown) {
    EXPECT_FALSE(shader_presets::hasPreset("nonexistent"));
}

TEST(ShaderPresets, LoadPresetsFromLuaRegistersPresets) {
    shader_presets::clearPresets();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);

    // Create a minimal preset table
    lua.script(R"(
        ShaderPresets = {
            test_preset = {
                id = "test_preset",
                passes = {"test_shader"},
                uniforms = {
                    intensity = 0.5,
                },
            }
        }
    )");

    shader_presets::loadPresetsFromLuaState(lua);

    EXPECT_TRUE(shader_presets::hasPreset("test_preset"));

    const auto* preset = shader_presets::getPreset("test_preset");
    ASSERT_NE(preset, nullptr);
    EXPECT_EQ(preset->id, "test_preset");
    EXPECT_EQ(preset->passes.size(), 1);
    EXPECT_EQ(preset->passes[0].shaderName, "test_shader");
}

TEST(ShaderPresets, ApplyShaderPresetCreatesComponent) {
    shader_presets::clearPresets();

    // Register a test preset
    shader_presets::ShaderPreset preset;
    preset.id = "test";
    preset.passes.push_back({"test_shader", {}});
    shader_presets::presetRegistry["test"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    sol::table overrides = lua.create_table();

    shader_presets::applyShaderPreset(registry, entity, "test", overrides);

    EXPECT_TRUE(registry.all_of<shader_pipeline::ShaderPipelineComponent>(entity));

    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);
    EXPECT_EQ(pipeline.passes[0].shaderName, "test_shader");
}

TEST(ShaderPresets, ClearShaderPassesRemovesAllPasses) {
    entt::registry registry;
    auto entity = registry.create();

    auto& pipeline = registry.emplace<shader_pipeline::ShaderPipelineComponent>(entity);
    pipeline.addPass("shader1");
    pipeline.addPass("shader2");
    EXPECT_EQ(pipeline.passes.size(), 2);

    shader_presets::clearShaderPasses(registry, entity);

    EXPECT_EQ(pipeline.passes.size(), 0);
}

TEST(ShaderPresets, AppliedPresetWorksWithBatchedPipeline) {
    shader_presets::clearPresets();

    // Register a preset that looks like 3d_skew (auto atlas uniforms)
    shader_presets::ShaderPreset preset;
    preset.id = "test_skew";
    preset.passes.push_back({"3d_skew_test", {}});
    shader_presets::presetRegistry["test_skew"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    sol::table overrides = lua.create_table();

    shader_presets::applyShaderPreset(registry, entity, "test_skew", overrides);

    // Verify pipeline component is set up correctly for batched rendering
    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);
    EXPECT_EQ(pipeline.passes[0].shaderName, "3d_skew_test");
    EXPECT_TRUE(pipeline.passes[0].enabled);
    EXPECT_TRUE(pipeline.passes[0].injectAtlasUniforms);  // auto-detected from 3d_skew prefix
}

TEST(ShaderPresets, UniformOverridesAreApplied) {
    shader_presets::clearPresets();

    shader_presets::ShaderPreset preset;
    preset.id = "test";
    preset.passes.push_back({"test_shader", {}});
    preset.uniforms.set("base_value", 1.0f);
    shader_presets::presetRegistry["test"] = preset;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);
    sol::table overrides = lua.create_table();
    overrides["base_value"] = 2.0f;
    overrides["new_value"] = 3.0f;

    shader_presets::applyShaderPreset(registry, entity, "test", overrides);

    auto& uniformComp = registry.get<shaders::ShaderUniformComponent>(entity);
    const auto* uniformSet = uniformComp.getSet("test_shader");
    ASSERT_NE(uniformSet, nullptr);

    const auto* baseValue = uniformSet->get("base_value");
    ASSERT_NE(baseValue, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*baseValue), 2.0f);  // overridden

    const auto* newValue = uniformSet->get("new_value");
    ASSERT_NE(newValue, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*newValue), 3.0f);  // added
}

TEST(ShaderPresets, AddShaderPresetAppendsToExistingPasses) {
    shader_presets::clearPresets();

    // Register two presets
    shader_presets::ShaderPreset preset1;
    preset1.id = "preset1";
    preset1.passes.push_back({"shader1", {}});
    shader_presets::presetRegistry["preset1"] = preset1;

    shader_presets::ShaderPreset preset2;
    preset2.id = "preset2";
    preset2.passes.push_back({"shader2", {}});
    shader_presets::presetRegistry["preset2"] = preset2;

    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    sol::table overrides = lua.create_table();

    // Apply first preset
    shader_presets::applyShaderPreset(registry, entity, "preset1", overrides);
    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);

    // Add second preset (should append, not replace)
    shader_presets::addShaderPreset(registry, entity, "preset2", overrides);
    EXPECT_EQ(pipeline.passes.size(), 2);
    EXPECT_EQ(pipeline.passes[0].shaderName, "shader1");
    EXPECT_EQ(pipeline.passes[1].shaderName, "shader2");
}

TEST(ShaderPresets, AddShaderPassCreatesPassWithUniforms) {
    entt::registry registry;
    auto entity = registry.create();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);
    sol::table uniforms = lua.create_table();
    uniforms["intensity"] = 0.75f;
    uniforms["color"] = lua.create_table_with("r", 1.0f, "g", 0.5f, "b", 0.0f);

    shader_presets::addShaderPass(registry, entity, "custom_shader", uniforms);

    // Verify pipeline has the pass
    auto& pipeline = registry.get<shader_pipeline::ShaderPipelineComponent>(entity);
    EXPECT_EQ(pipeline.passes.size(), 1);
    EXPECT_EQ(pipeline.passes[0].shaderName, "custom_shader");
    EXPECT_TRUE(pipeline.passes[0].enabled);

    // Verify uniforms were set
    auto& uniformComp = registry.get<shaders::ShaderUniformComponent>(entity);
    const auto* uniformSet = uniformComp.getSet("custom_shader");
    ASSERT_NE(uniformSet, nullptr);

    const auto* intensity = uniformSet->get("intensity");
    ASSERT_NE(intensity, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*intensity), 0.75f);
}

TEST(ShaderPresets, UniformParsingFromLua) {
    shader_presets::clearPresets();

    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table);

    // Create a preset with various uniform types
    lua.script(R"(
        ShaderPresets = {
            test_parsing = {
                id = "test_parsing",
                passes = {"test_shader"},
                uniforms = {
                    intensity = 0.5,
                    threshold = 0.25,
                    count = 10,
                    enabled = true,
                },
            }
        }
    )");

    shader_presets::loadPresetsFromLuaState(lua);

    const auto* preset = shader_presets::getPreset("test_parsing");
    ASSERT_NE(preset, nullptr);

    // Verify uniform values were parsed correctly
    const auto* intensity = preset->uniforms.get("intensity");
    ASSERT_NE(intensity, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*intensity), 0.5f);

    const auto* threshold = preset->uniforms.get("threshold");
    ASSERT_NE(threshold, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*threshold), 0.25f);

    const auto* count = preset->uniforms.get("count");
    ASSERT_NE(count, nullptr);
    // Lua integers are parsed as floats in tableToUniformValue due to check order
    EXPECT_FLOAT_EQ(std::get<float>(*count), 10.0f);

    const auto* enabled = preset->uniforms.get("enabled");
    ASSERT_NE(enabled, nullptr);
    EXPECT_TRUE(std::get<bool>(*enabled));
}
