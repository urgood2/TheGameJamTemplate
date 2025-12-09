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
