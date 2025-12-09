#include "shader_presets.hpp"
#include "util/common_headers.hpp"

namespace shader_presets {

namespace {

ShaderUniformValue tableToUniformValue(sol::object obj) {
    if (obj.is<float>() || obj.is<double>()) {
        return static_cast<float>(obj.as<double>());
    }
    if (obj.is<bool>()) {
        return obj.as<bool>();
    }
    if (obj.is<int>()) {
        return obj.as<int>();
    }
    if (obj.is<sol::table>()) {
        auto t = obj.as<sol::table>();
        size_t size = t.size();
        if (size == 2) {
            return Vector2{t[1].get<float>(), t[2].get<float>()};
        }
        if (size == 3) {
            return Vector3{t[1].get<float>(), t[2].get<float>(), t[3].get<float>()};
        }
        if (size == 4) {
            return Vector4{t[1].get<float>(), t[2].get<float>(), t[3].get<float>(), t[4].get<float>()};
        }
    }
    SPDLOG_WARN("shader_presets: unsupported uniform value type");
    return 0.0f;
}

void parseUniformsTable(sol::table uniformsTable, shaders::ShaderUniformSet& uniformSet) {
    for (auto& [key, value] : uniformsTable) {
        if (key.is<std::string>()) {
            std::string uniformName = key.as<std::string>();
            uniformSet.set(uniformName, tableToUniformValue(value));
        }
    }
}

bool isSkewShader(const std::string& shaderName) {
    return shaderName.find("3d_skew") == 0;
}

}  // anonymous namespace

void loadPresetsFromLuaState(sol::state& lua) {
    sol::optional<sol::table> presetsTableOpt = lua["ShaderPresets"];
    if (!presetsTableOpt) {
        SPDLOG_WARN("shader_presets: ShaderPresets table not found");
        return;
    }

    sol::table presetsTable = *presetsTableOpt;

    for (auto& [key, value] : presetsTable) {
        if (!key.is<std::string>() || !value.is<sol::table>()) {
            continue;
        }

        std::string presetName = key.as<std::string>();
        sol::table presetTable = value.as<sol::table>();

        ShaderPreset preset;
        preset.id = presetTable.get_or<std::string>("id", presetName);

        // Parse passes array
        sol::optional<sol::table> passesOpt = presetTable["passes"];
        if (passesOpt) {
            for (auto& [idx, passName] : *passesOpt) {
                if (passName.is<std::string>()) {
                    ShaderPresetPass pass;
                    pass.shaderName = passName.as<std::string>();
                    preset.passes.push_back(std::move(pass));
                }
            }
        }

        // Parse shared uniforms
        sol::optional<sol::table> uniformsOpt = presetTable["uniforms"];
        if (uniformsOpt) {
            parseUniformsTable(*uniformsOpt, preset.uniforms);
        }

        // Parse per-pass uniforms
        sol::optional<sol::table> passUniformsOpt = presetTable["pass_uniforms"];
        if (passUniformsOpt) {
            for (auto& pass : preset.passes) {
                sol::optional<sol::table> passSpecificOpt = (*passUniformsOpt)[pass.shaderName];
                if (passSpecificOpt) {
                    parseUniformsTable(*passSpecificOpt, pass.defaultUniforms);
                }
            }
        }

        // Determine needsAtlasUniforms - explicit flag or auto-detect from 3d_skew
        sol::optional<bool> needsAtlasOpt = presetTable["needs_atlas_uniforms"];
        if (needsAtlasOpt) {
            preset.needsAtlasUniforms = *needsAtlasOpt;
        } else {
            // Auto-detect: if any pass is a 3d_skew shader, enable atlas uniforms
            for (const auto& pass : preset.passes) {
                if (isSkewShader(pass.shaderName)) {
                    preset.needsAtlasUniforms = true;
                    break;
                }
            }
        }

        presetRegistry[presetName] = std::move(preset);
        SPDLOG_DEBUG("shader_presets: loaded preset '{}'", presetName);
    }

    SPDLOG_INFO("shader_presets: loaded {} presets", presetRegistry.size());
}

void loadPresetsFromLuaFile(sol::state& lua, const std::string& path) {
    auto result = lua.safe_script_file(path, sol::script_pass_on_error);
    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("shader_presets: failed to load '{}': {}", path, err.what());
        return;
    }
    loadPresetsFromLuaState(lua);
}

}  // namespace shader_presets
