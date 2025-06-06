#include "shader_system.hpp"

#include <raylib.h>
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>
#include <string>
#include <unordered_map>

#include "rlgl.h"

// #include "third_party/rlImGui/imgui.h"
// #include "third_party/rlImGui/imgui_internal.h"

#include "../../util/utilities.hpp"
#include "util/common_headers.hpp"

using json = nlohmann::json;
#include <unordered_map>
#include <functional>
#include <filesystem>

namespace shaders {

    // Map to store loaded shaders, keyed by their name
    static std::unordered_map<std::string, Shader> loadedShaders;

    // Map to track last modification times for shaders
    static std::unordered_map<std::string, std::pair<long, long>> shaderFileModificationTimes;

    // Map to store uniform update lambdas for shaders
    static std::unordered_map<std::string, std::function<void(Shader&)>> uniformUpdateCallbacks;
    
    // map to store vertex and fragment shader paths
    static std::unordered_map<std::string, std::pair<std::string, std::string>> shaderPaths;


    bool shaderEnabledOverride = false;

    void ApplyUniformsToShader(Shader shader, const ShaderUniformSet& set) {
        for (const auto& [name, value] : set.uniforms) {
            int loc = GetShaderLocation(shader, name.c_str());
            std::visit([&](auto&& val) {
                using T = std::decay_t<decltype(val)>;
                if constexpr (std::is_same_v<T, float>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_FLOAT);
                } else if constexpr (std::is_same_v<T, Vector2>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC2);
                } else if constexpr (std::is_same_v<T, Vector3>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC3);
                } else if constexpr (std::is_same_v<T, Vector4>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC4);
                } else if constexpr (std::is_same_v<T, Texture2D>) {
                    SetShaderValueTexture(shader, loc, val);
                }
            }, value);
        }
    }

    // Disable all shaders via override
    auto disableAllShadersViaOverride(bool disabled) -> void {
        shaderEnabledOverride = disabled;
    }

    // Load shaders from JSON and initialize modification times
    auto loadShadersFromJSON(std::string jsonPath) -> void {
    auto path = util::getAssetPathUUIDVersion(jsonPath);

    std::ifstream jsonFile(path);
    if (!jsonFile.is_open()) {
        SPDLOG_ERROR("Failed to open shader JSON file: {}", path);
        return;
    }

    json shaderData;
    try {
        jsonFile >> shaderData;
    } catch (const std::exception &e) {
        SPDLOG_ERROR("Failed to parse JSON: {}", e.what());
        return;
    }

    for (const auto &[shaderName, shaderPathsJSON] : shaderData.items()) {
        std::string vertexPath, fragmentPath;

#ifdef __EMSCRIPTEN__
        // Check for web-specific paths
        if (shaderPathsJSON.contains("web")) {
            auto webPaths = shaderPathsJSON["web"];
            if (webPaths.contains("vertex") && webPaths["vertex"].is_string()) {
                vertexPath = loading::getAssetPath("shaders/" + webPaths["vertex"].get<std::string>());
                SPDLOG_DEBUG("Web Vertex path: {}", vertexPath);
            }
            if (webPaths.contains("fragment") && webPaths["fragment"].is_string()) {
                fragmentPath = loading::getAssetPath("shaders/" + webPaths["fragment"].get<std::string>());
                SPDLOG_DEBUG("Web Fragment path: {}", fragmentPath);
            }
        }
#endif

        // Fallback to default paths if web-specific paths are not present
        if (vertexPath.empty() && shaderPathsJSON.contains("vertex") && shaderPathsJSON["vertex"].is_string()) {
            vertexPath = util::getAssetPathUUIDVersion("shaders/" + shaderPathsJSON["vertex"].get<std::string>());
            SPDLOG_DEBUG("Default Vertex path: {}", vertexPath);
        }
        if (fragmentPath.empty() && shaderPathsJSON.contains("fragment") && shaderPathsJSON["fragment"].is_string()) {
            fragmentPath = util::getAssetPathUUIDVersion("shaders/" + shaderPathsJSON["fragment"].get<std::string>());
            SPDLOG_DEBUG("Default Fragment path: {}", fragmentPath);
        }

        Shader shader;
        if (!vertexPath.empty() && !fragmentPath.empty()) {
            shader = LoadShader(vertexPath.c_str(), fragmentPath.c_str());
            shaderPaths[shaderName] = {vertexPath, fragmentPath};
        } else if (!vertexPath.empty()) {
            shader = LoadShader(vertexPath.c_str(), nullptr);
            shaderPaths[shaderName] = {vertexPath, ""};
        } else if (!fragmentPath.empty()) {
            shader = LoadShader(nullptr, fragmentPath.c_str());
            shaderPaths[shaderName] = {"", fragmentPath};
        } else {
            SPDLOG_WARN("Shader {} has no valid paths. Skipping.", shaderName);
            continue;
        }

        loadedShaders[shaderName] = shader;

        // Store initial modification times
        shaderFileModificationTimes[shaderName] = {
            std::filesystem::last_write_time(vertexPath).time_since_epoch().count(),
            std::filesystem::last_write_time(fragmentPath).time_since_epoch().count()};

        SPDLOG_INFO("Loaded shader: {}", shaderName);
    }
}

    auto hotReloadShaders() -> void {
        ZoneScopedN("HotReloadShaders"); // custom label
        for (auto& [shaderName, shader] : loadedShaders) {
            // Retrieve shader paths from the map
            if (shaderPaths.find(shaderName) == shaderPaths.end()) {
                SPDLOG_WARN("Paths for shader {} not found. Skipping hot reload.", shaderName);
                continue;
            }

            const auto& [vertexPath, fragmentPath] = shaderPaths[shaderName];

            // Check if paths are valid
            if (vertexPath.empty() && fragmentPath.empty()) {
                SPDLOG_WARN("Shader {} has no valid paths. Skipping hot reload.", shaderName);
                continue;
            }

            // Get the last modified times
            long newVertexModTime = vertexPath.empty() ? 0 : std::filesystem::last_write_time(vertexPath).time_since_epoch().count();
            long newFragmentModTime = fragmentPath.empty() ? 0 : std::filesystem::last_write_time(fragmentPath).time_since_epoch().count();

            // Get the stored modification times
            auto& [vertexModTime, fragmentModTime] = shaderFileModificationTimes[shaderName];

            // Check if the files have been modified
            if (newVertexModTime != vertexModTime || newFragmentModTime != fragmentModTime) {
                SPDLOG_INFO("Shader {} modified. Reloading...", shaderName);

                // Reload the shader
                Shader updatedShader = LoadShader(
                    vertexPath.empty() ? nullptr : vertexPath.c_str(),
                    fragmentPath.empty() ? nullptr : fragmentPath.c_str()
                );

                if (updatedShader.id != rlGetShaderIdDefault()) {
                    UnloadShader(shader);
                    shader = updatedShader;

                    // Update modification times
                    shaderFileModificationTimes[shaderName] = {newVertexModTime, newFragmentModTime};

                    SPDLOG_INFO("Shader {} reloaded successfully.", shaderName);
                } else {
                    SPDLOG_WARN("Failed to reload shader: {}", shaderName);
                }
            }
        }
    }


    // Set shader mode
    auto setShaderMode(std::string shaderName) -> void {
        if (shaderEnabledOverride) {
            return;
        }

        if (loadedShaders.find(shaderName) == loadedShaders.end()) {
            SPDLOG_WARN("Shader {} not found.", shaderName);
            return;
        }

        BeginShaderMode(loadedShaders[shaderName]);
    }

    // Unset shader mode
    auto unsetShaderMode() -> void {
        if (shaderEnabledOverride) {
            return;
        }
        EndShaderMode();
    }
    
    auto getShader(std::string shaderName) -> Shader {
        if (loadedShaders.find(shaderName) == loadedShaders.end()) {
            SPDLOG_WARN("Shader {} not found.", shaderName);
            return {0};
        }
        return loadedShaders[shaderName];
    }

    // Register a lambda for uniform updates
    auto registerUniformUpdate(std::string shaderName, std::function<void(Shader&)> updateLambda) -> void {
        if (loadedShaders.find(shaderName) == loadedShaders.end()) {
            SPDLOG_WARN("Shader {} not found. Cannot register uniform update.", shaderName);
            return;
        }
        uniformUpdateCallbacks[shaderName] = updateLambda;
        SPDLOG_INFO("Registered uniform update for shader: {}", shaderName);
    }

    // Update all shader uniforms
    auto updateAllShaderUniforms() -> void {
        ZoneScopedN("UpdateAllShaderUniforms"); // custom label
        for (const auto& [shaderName, updateLambda] : uniformUpdateCallbacks) {
            if (loadedShaders.find(shaderName) != loadedShaders.end()) {
                Shader& shader = loadedShaders[shaderName];
                updateLambda(shader);
                // SPDLOG_INFO("Updated uniforms for shader: {}", shaderName);
            } else {
                SPDLOG_WARN("Shader {} not found during uniform update.", shaderName);
            }
        }
    }

    // Called every frame to update shader system
    auto update(float dt) -> void {
        ZoneScopedN("Shaders update");
        
        updateAllShaderUniforms();
        //FIXME: perforamnce intensive on windows, commenting out for now
        // hotReloadShaders(); // Check for shader file modifications
    }

    // call this before suing beginImGUIWindowWithCallback
    // auto checkImGUIWindowExists(std::string windowName) -> void {
    //     auto window = ImGui::FindWindowByName(windowName.c_str());
    //     if (window == nullptr ) {
    //         ImGui::Begin(windowName.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize);
    //         ImGui::End();
    //         return;
    //     }
    //     if (window->DrawList == nullptr) {
    //         return ;
    //     }
    // }

    // auto beginImGUIWindowWithCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) -> void {
        
    //     auto window = ImGui::FindWindowByName(imguiWindow.c_str());
    //     ImGui::Begin(imguiWindow.c_str(), NULL, ImGuiWindowFlags_AlwaysAutoResize, [&]() {
    //         window->DrawListInst.AddCallback(callback.target<void(const ImDrawList*, const ImDrawCmd*)>(), nullptr);
    //     });

    // }

    // auto endImGUIShaderCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) ->void {
    //     auto window = ImGui::FindWindowByName(imguiWindow.c_str());
    //     if (window != nullptr  && window->DrawList != nullptr) {
    //         window->DrawListInst.AddCallback(callback.target<void(const ImDrawList*, const ImDrawCmd*)>(), nullptr);
    //     }
    //     else {
    //         SPDLOG_DEBUG("endImGUIShaderCallback - DrawList is null");
    //     }
    //     ImGui::End();
    // }

    // Unload shaders
    auto unloadShaders() -> void {
        for (auto& [name, shader] : loadedShaders) {
            UnloadShader(shader);
            SPDLOG_INFO("Unloaded shader: {}", name);
        }
        loadedShaders.clear();
        shaderFileModificationTimes.clear();
    }

    void ShowShaderEditorUI(ShaderUniformComponent& component) {
        if (!ImGui::Begin("Shader Editor")) return;
    
        if (ImGui::BeginTabBar("Shaders")) {
            for (auto& [shaderName, uniformSet] : component.shaderUniforms) {
                if (ImGui::BeginTabItem(shaderName.c_str())) {
                    // "Log Uniforms" button
                    if (ImGui::Button("Log Uniforms")) {
                        SPDLOG_INFO("Uniforms for shader '{}':", shaderName);
                        for (const auto& [uniformName, uniformValue] : uniformSet.uniforms) {
                            std::visit([&](const auto& value) {
                                using T = std::decay_t<decltype(value)>;
                                if constexpr (std::is_same_v<T, float>) {
                                    SPDLOG_INFO("  {}: float = {}", uniformName, value);
                                } else if constexpr (std::is_same_v<T, Vector2>) {
                                    SPDLOG_INFO("  {}: Vector2 = ({}, {})", uniformName, value.x, value.y);
                                } else if constexpr (std::is_same_v<T, Vector3>) {
                                    SPDLOG_INFO("  {}: Vector3 = ({}, {}, {})", uniformName, value.x, value.y, value.z);
                                } else if constexpr (std::is_same_v<T, Vector4>) {
                                    SPDLOG_INFO("  {}: Vector4 = ({}, {}, {}, {})", uniformName, value.x, value.y, value.z, value.w);
                                } else if constexpr (std::is_same_v<T, Texture2D>) {
                                    ImGui::Text("%s (Texture ID: %d, %dx%d)", uniformName.c_str(), value.id, value.width, value.height);
                                }
                                else if constexpr (std::is_same_v<T, bool>) {
                                    SPDLOG_INFO("  {}: bool = {}", uniformName, value ? "true" : "false");
                                }
                                else {
                                    SPDLOG_WARN("  {}: Unknown uniform type", uniformName);
                                }
                            }, uniformValue);
                        }
                    }
    
                    ImGui::Separator();
    
                    // Live-edit uniforms
                    for (auto& [uniformName, uniformValue] : uniformSet.uniforms) {
                        ImGui::PushID(uniformName.c_str());
                    
                        std::visit([&](auto& value) {
                            using T = std::decay_t<decltype(value)>;
                            if constexpr (std::is_same_v<T, float>) {
                                ImGui::DragFloat(uniformName.c_str(), &value, 0.01f);
                            } else if constexpr (std::is_same_v<T, Vector2>) {
                                ImGui::DragFloat2(uniformName.c_str(), &value.x, 0.01f);
                            } else if constexpr (std::is_same_v<T, Vector3>) {
                                ImGui::DragFloat3(uniformName.c_str(), &value.x, 0.01f);
                            } else if constexpr (std::is_same_v<T, Vector4>) {
                                ImGui::ColorEdit4(uniformName.c_str(), &value.x);
                            } else if constexpr (std::is_same_v<T, bool>) {
                                ImGui::Checkbox(uniformName.c_str(), &value);
                            }                          
                            else if constexpr (std::is_same_v<T, Texture2D>) {
                                ImGui::Text("%s: Texture2D (id: %d, size: %dx%d)", uniformName.c_str(), value.id, value.width, value.height);
                                // Optional preview
                                // ImGui::Image((ImTextureID)(intptr_t)value.id, ImVec2(64, 64));
                            } else {
                                static_assert(always_false<T>::value, "Unsupported uniform type");
                            }
                        }, uniformValue);
                    
                        ImGui::PopID();
                    }
    
                    ImGui::EndTabItem();
                }
            }
            ImGui::EndTabBar();
        }
    
        ImGui::End();
    }
} // namespace shaders
