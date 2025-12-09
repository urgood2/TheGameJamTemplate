#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include "shader_system.hpp"
#include "sol/sol.hpp"
#include "entt/entt.hpp"
#include "shader_pipeline.hpp"

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

// Entity API functions
void applyShaderPreset(entt::registry& reg, entt::entity e,
                       const std::string& presetName,
                       const sol::table& overrides);

void addShaderPreset(entt::registry& reg, entt::entity e,
                     const std::string& presetName,
                     const sol::table& overrides);

void clearShaderPasses(entt::registry& reg, entt::entity e);

void addShaderPass(entt::registry& reg, entt::entity e,
                   const std::string& shaderName,
                   const sol::table& uniforms);

}  // namespace shader_presets
