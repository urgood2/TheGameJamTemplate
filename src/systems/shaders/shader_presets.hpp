#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include "shader_system.hpp"
#include "sol/sol.hpp"

namespace shader_presets {

struct ShaderPresetPass {
    std::string shaderName;
    shaders::ShaderUniformSet defaultUniforms;
};

struct ShaderPreset {
    std::string id;
    std::vector<ShaderPresetPass> passes;
    shaders::ShaderUniformSet uniforms;  // shared defaults (all passes)
    bool needsAtlasUniforms = false;
};

// Registry storage
inline std::unordered_map<std::string, ShaderPreset> presetRegistry;

inline const ShaderPreset* getPreset(const std::string& name) {
    auto it = presetRegistry.find(name);
    return it != presetRegistry.end() ? &it->second : nullptr;
}

inline bool hasPreset(const std::string& name) {
    return presetRegistry.find(name) != presetRegistry.end();
}

inline void clearPresets() {
    presetRegistry.clear();
}

// Forward declarations for Lua loading functions
void loadPresetsFromLuaState(sol::state& lua);
void loadPresetsFromLuaFile(sol::state& lua, const std::string& path);

}  // namespace shader_presets
