#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include "shader_system.hpp"

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

}  // namespace shader_presets
