#include <gtest/gtest.h>
#include "systems/shaders/shader_presets.hpp"

TEST(ShaderPresets, GetPresetReturnsNullptrForUnknown) {
    const auto* preset = shader_presets::getPreset("nonexistent");
    EXPECT_EQ(preset, nullptr);
}

TEST(ShaderPresets, HasPresetReturnsFalseForUnknown) {
    EXPECT_FALSE(shader_presets::hasPreset("nonexistent"));
}
