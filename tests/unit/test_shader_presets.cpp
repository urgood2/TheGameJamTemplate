#include <gtest/gtest.h>
#include "systems/shaders/shader_presets.hpp"
#include "sol/sol.hpp"

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
