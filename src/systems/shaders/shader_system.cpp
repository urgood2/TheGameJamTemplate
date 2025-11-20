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

#include "sol/sol.hpp"

using json = nlohmann::json;
#include <unordered_map>
#include <functional>
#include <filesystem>

#include "systems/scripting/binding_recorder.hpp"

namespace shaders
{
    auto exposeToLua(sol::state& lua) -> void {
        

        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        // Create the top-level shaders table if it doesn't exist
        sol::table sh = lua["shaders"].get_or_create<sol::table>();

        // 1) Recorder: Top-level namespace documentation
        rec.add_type("shaders").doc = "Manages shaders, their uniforms, and rendering modes.";

        // --- ShaderUniformSet ---

        // 2a) Bind with sol2
        sh.new_usertype<shaders::ShaderUniformSet>("ShaderUniformSet",
            sol::constructors<>(),
            // your existing setter stays the same
            "set", [](shaders::ShaderUniformSet& s, const std::string& name, sol::object value) {
                if (value.is<float>()) {
                    s.set(name, value.as<float>());
                }
                else if (value.is<bool>()) {
                    s.set(name, value.as<bool>());
                }
                else if (value.is<Texture2D>()) {
                    s.set(name, value.as<Texture2D>());
                }
                else if (value.is<Vector2>()) {
                    s.set(name, value.as<Vector2>());
                }
                else if (value.is<Vector3>()) {
                    s.set(name, value.as<Vector3>());
                }
                else if (value.is<Vector4>()) {
                    s.set(name, value.as<Vector4>());
                }
                else {
                    SPDLOG_ERROR("Unsupported uniform value type for uniform '{}'", name);
                }
            },
            // new 'get' override:
            "get", [](shaders::ShaderUniformSet& s, sol::this_state ts, const std::string& name) {
                auto L = ts.lua_state();
                if (const ShaderUniformValue* v = s.get(name)) {
                    // dispatch on the variant contents
                    return std::visit([&](auto&& val) -> sol::object {
                        using T = std::decay_t<decltype(val)>;
                        // primitives come back as Lua numbers or booleans
                        if constexpr (std::is_same_v<T, float> ||
                                      std::is_same_v<T, double> ||
                                      std::is_same_v<T, int> ||
                                      std::is_same_v<T, bool>) {
                            return sol::make_object(L, val);
                        }
                        // vector types we return as tables
                        else if constexpr (std::is_same_v<T, Vector2>) {
                            sol::table t = sol::state_view(L).create_table_with("x", val.x, "y", val.y);
                            return sol::make_object(L, t);
                        }
                        else if constexpr (std::is_same_v<T, Vector3>) {
                            sol::table t = sol::state_view(L).create_table_with("x", val.x, "y", val.y, "z", val.z);
                            return sol::make_object(L, t);
                        }
                        else if constexpr (std::is_same_v<T, Vector4>) {
                            sol::table t = sol::state_view(L).create_table_with("x", val.x, "y", val.y, "z", val.z, "w", val.w);
                            return sol::make_object(L, t);
                        }
                        // Texture2D and other usertypes are pushed directly
                        else {
                            return sol::make_object(L, val);
                        }
                    }, *v);
                }
                // not found → nil
                return sol::make_object(L, sol::lua_nil);
            },
            "type_id", []() { return entt::type_hash<shaders::ShaderUniformSet>::value(); }
        );

        // 2b) Document with BindingRecorder
        auto& sus_type = rec.add_type("shaders.ShaderUniformSet");
        sus_type.doc = "A collection of uniform values to be applied to a shader.";

        rec.record_method("shaders.ShaderUniformSet", {
            "set",
            "---@param name string # The name of the uniform to set.\n"
            "---@param value any # The value to set (e.g., number, boolean, Vector2, Texture2D, etc.).",
            "Sets or updates a uniform value by name within the set."
        });

        rec.record_method("shaders.ShaderUniformSet", {
            "get",
            "---@param name string # The name of the uniform to retrieve.\n"
            "---@return any|nil # The value of the uniform, or nil if not found.",
            "Gets a uniform's value by its name."
        });

        // --- ShaderUniformComponent ---

        // 3a) Bind with sol2 (as you provided)
        sh.new_usertype<shaders::ShaderUniformComponent>("ShaderUniformComponent",
            sol::constructors<>(),
            "set", &shaders::ShaderUniformComponent::set,
            "registerEntityUniformCallback", &shaders::ShaderUniformComponent::registerEntityUniformCallback,
            "getSet", &shaders::ShaderUniformComponent::getSet,
            // --- OVERRIDE get for Lua: ---
                "get", [](ShaderUniformComponent& comp,
                    sol::this_state ts,
                    const std::string& shaderName,
                    const std::string& uniformName) -> sol::object
            {
            auto L = ts.lua_state();
            if (const ShaderUniformValue* v = comp.get(shaderName, uniformName)) {
                return std::visit([&](auto&& val) -> sol::object {
                    using T = std::decay_t<decltype(val)>;
                    // primitive types → numbers/booleans
                    if constexpr (std::is_same_v<T, float> ||
                                    std::is_same_v<T, double> ||
                                    std::is_same_v<T, int> ||
                                    std::is_same_v<T, bool>) {
                        return sol::make_object(L, val);
                    }
                    // vectors → tables
                    else if constexpr (std::is_same_v<T, Vector2>) {
                        return sol::make_object(L,
                            sol::state_view(L).create_table_with("x", val.x, "y", val.y));
                    }
                    else if constexpr (std::is_same_v<T, Vector3>) {
                        return sol::make_object(L,
                            sol::state_view(L).create_table_with(
                                "x", val.x, "y", val.y, "z", val.z));
                    }
                    else if constexpr (std::is_same_v<T, Vector4>) {
                        return sol::make_object(L,
                            sol::state_view(L).create_table_with(
                                "x", val.x, "y", val.y, "z", val.z, "w", val.w));
                    }
                    // Texture2D (or any other bound usertype) → userdata
                    else {
                        return sol::make_object(L, val);
                    }
                }, *v);
            }
            // not found → nil
            return sol::make_object(L, sol::lua_nil);
            },
            "applyToShaderForEntity", &shaders::ShaderUniformComponent::applyToShaderForEntity,
            "type_id", []() { return entt::type_hash<shaders::ShaderUniformComponent>::value(); }
        );

        // 3b) Document with BindingRecorder
        auto& suc_type = rec.add_type("shaders.ShaderUniformComponent");
        suc_type.doc = "An entity component for managing per-entity shader uniforms.";

        rec.record_method("shaders.ShaderUniformComponent", {
            "set",
            "---@param shaderName string # The name of the shader this uniform belongs to.\n"
            "---@param uniformName string # The name of the uniform to set.\n"
            "---@param value any # The value to assign to the uniform.",
            "Sets a static uniform value for a specific shader within this component."
        });

        rec.record_method("shaders.ShaderUniformComponent", {
            "registerEntityUniformCallback",
            "---@param shaderName string # The shader this callback applies to.\n"
            "---@param callback fun(shader: Shader, entity: Entity) # A function called just before rendering the entity.",
            "Registers a callback to dynamically compute and apply uniforms for an entity."
        });

        rec.record_method("shaders.ShaderUniformComponent", {
            "getSet",
            "---@param shaderName string # The name of the shader.\n"
            "---@return shaders.ShaderUniformSet|nil",
            "Returns the underlying ShaderUniformSet for a specific shader, or nil if not found."
        });

        rec.record_method("shaders.ShaderUniformComponent", {
            "applyToShaderForEntity",
            "---@param shader Shader # The target shader.\n"
            "---@param shaderName string # The name of the shader configuration to apply.\n"
            "---@param entity Entity # The entity to source dynamic uniform values from.",
            "Applies this component's static uniforms and executes its dynamic callbacks for a given entity."
        });



        // --- Free Functions ---

        // 4a) Bind with sol2
        sh.set_function("ApplyUniformsToShader", &shaders::ApplyUniformsToShader);
        sh.set_function("loadShadersFromJSON",   &shaders::loadShadersFromJSON);
        sh.set_function("unloadShaders",         &shaders::unloadShaders);
        sh.set_function("disableAllShadersViaOverride", &shaders::disableAllShadersViaOverride);
        sh.set_function("hotReloadShaders",      &shaders::hotReloadShaders);
        sh.set_function("setShaderMode",         &shaders::setShaderMode);
        sh.set_function("unsetShaderMode",       &shaders::unsetShaderMode);
        sh.set_function("getShader",             &shaders::getShader);
        sh.set_function("registerUniformUpdate", &shaders::registerUniformUpdate);
        sh.set_function("updateAllShaderUniforms",&shaders::updateAllShaderUniforms);
        sh.set_function("updateShaders",         &shaders::update);
        sh.set_function("ShowShaderEditorUI",    &shaders::ShowShaderEditorUI);

        
        // 4b) Document with BindingRecorder
        rec.record_free_function({"shaders"}, {
            "ApplyUniformsToShader",
            "---@param shader Shader\n"
            "---@param uniforms shaders.ShaderUniformSet # A table of uniform names to values.\n"
            "---@return nil",
            "Applies a set of uniforms to a specific shader instance."
        });

        rec.record_free_function({"shaders"}, {
            "loadShadersFromJSON",
            "---@param path string # Filepath to the JSON definition file.\n"
            "---@return nil",
            "Loads and compiles shaders from a JSON file."
        });

        rec.record_free_function({"shaders"}, {
            "unloadShaders",
            "---@return nil",
            "Unloads all shaders, freeing their GPU resources."
        });

        rec.record_free_function({"shaders"}, {
            "disableAllShadersViaOverride",
            "---@param disabled boolean # True to disable all shaders, false to re-enable them.\n"
            "---@return nil",
            "Globally forces all shader effects off or on, overriding individual settings."
        });

        rec.record_free_function({"shaders"}, {
            "hotReloadShaders",
            "---@return nil",
            "Checks all loaded shaders for changes on disk and reloads them if necessary."
        });

        rec.record_free_function({"shaders"}, {
            "setShaderMode",
            "---@param shaderName string # The name of the shader to begin as a full-screen effect.\n"
            "---@return nil",
            "Begins a full-screen shader mode, e.g., for post-processing effects."
        });

        rec.record_free_function({"shaders"}, {
            "unsetShaderMode",
            "---@return nil",
            "Ends the current full-screen shader mode."
        });

        rec.record_free_function({"shaders"}, {
            "getShader",
            "---@param name string # The unique name of the shader.\n"
            "---@return Shader|nil # The shader object, or nil if not found.",
            "Retrieves a loaded shader by its unique name."
        });

        rec.record_free_function({"shaders"}, {
            "registerUniformUpdate",
            "---@param uniformName string # The uniform to target (e.g., 'time').\n"
            "---@param callback fun():any # A function that returns the latest value for the uniform.\n"
            "---@return nil",
            "Registers a global callback to update a specific uniform's value across all shaders that use it."
        });

        rec.record_free_function({"shaders"}, {
            "updateAllShaderUniforms",
            "---@return nil",
            "Invokes all registered global uniform update callbacks immediately."
        });

        rec.record_free_function({"shaders"}, {
            "updateShaders",
            "---@param dt number # Delta time since the last frame.\n"
            "---@return nil",
            "Updates internal shader state, such as timers for built-in 'time' uniforms."
        });

        rec.record_free_function({"shaders"}, {
            "ShowShaderEditorUI",
            "---@return nil",
            "Displays the ImGui-based shader editor window for real-time debugging and uniform tweaking."
        });

        // TryApplyUniforms(
        //     shader: Shader,
        //     component: ShaderUniformComponent,
        //     shaderName: string
        // ) -> void
        rec.bind_function(lua, {"shaders"}, "TryApplyUniforms",
            &shaders::TryApplyUniforms,
            R"lua(
        ---@param shader Shader                    # The target Shader handle
        ---@param component ShaderUniformComponent # Holds named uniform‐sets
        ---@param shaderName string                 # Key of the uniform set to apply
        ---@return nil
        )lua",
            "If the component has a uniform set registered under shaderName, applies those uniforms to shader"
        );
        
    }

    // Map to store loaded shaders, keyed by their name
    static std::unordered_map<std::string, Shader> loadedShaders;

    // Map to track last modification times for shaders
    static std::unordered_map<std::string, std::pair<long, long>> shaderFileModificationTimes;

    // Map to store uniform update lambdas for shaders
    static std::unordered_map<std::string, std::function<void(Shader &)>> uniformUpdateCallbacks;

    // map to store vertex and fragment shader paths
    static std::unordered_map<std::string, std::pair<std::string, std::string>> shaderPaths;

    bool shaderEnabledOverride = false;

    void ApplyUniformsToShader(Shader shader, const ShaderUniformSet &set)
    {
        for (const auto &[name, value] : set.uniforms)
        {
            int loc = GetShaderLocation(shader, name.c_str());
            
            if (loc < 0) {
                // SPDLOG_WARN("Shader uniform '{}' not found in shader ID {}. Skipping.", name, shader.id);
                continue;  // skip missing uniforms
            }
            if (name == "atlas") {
                // SPDLOG_DEBUG("Found atlas uniform '{}' at location {} in shader ID {}", name, loc, shader.id);
            }
            std::visit([&](auto &&val)
            {
                using T = std::decay_t<decltype(val)>;
                if constexpr (std::is_same_v<T, float>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_FLOAT);
                } else if constexpr (std::is_same_v<T, int>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_INT);
                } else if constexpr (std::is_same_v<T, Vector2>) {
                    // SPDLOG_DEBUG("Setting Vector2 uniform '{}' at location {} in shader ID {}", name, loc, shader.id);
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC2);
                } else if constexpr (std::is_same_v<T, Vector3>) {
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC3);
                } else if constexpr (std::is_same_v<T, Vector4>) {
                    // SPDLOG_DEBUG("Setting Vector4 uniform '{}' at location {} in shader ID {}", name, loc, shader.id);
                    SetShaderValue(shader, loc, &val, SHADER_UNIFORM_VEC4);
                } else if constexpr (std::is_same_v<T, Texture2D>) {
                    // SPDLOG_DEBUG("Setting texture uniform '{}' at location {} in shader ID {}", name, loc, shader.id);
                    // Bind a Texture2D to the sampler uniform slot
                    SetShaderValueTexture(shader, loc, val);
                }
            }, value);
        }
    }


    // Disable all shaders via override
    auto disableAllShadersViaOverride(bool disabled) -> void
    {
        shaderEnabledOverride = disabled;
    }

    // Load shaders from JSON and initialize modification times
    auto loadShadersFromJSON(std::string jsonPath) -> void
    {
        auto path = util::getRawAssetPathNoUUID(jsonPath);

        std::ifstream jsonFile(path);
        if (!jsonFile.is_open())
        {
            SPDLOG_ERROR("Failed to open shader JSON file: {}", path);
            return;
        }

        json shaderData;
        try
        {
            jsonFile >> shaderData;
        }
        catch (const std::exception &e)
        {
            SPDLOG_ERROR("Failed to parse JSON: {}", e.what());
            return;
        }


        for (const auto &[shaderName, shaderPathsJSON] : shaderData.items())
        {
            std::string vertexPath, fragmentPath;

#ifdef __EMSCRIPTEN__
            // Check for web-specific paths
            if (shaderPathsJSON.contains("web"))
            {
                auto webPaths = shaderPathsJSON["web"];
                if (webPaths.contains("vertex") && webPaths["vertex"].is_string())
                { 
                    vertexPath =  util::getRawAssetPathNoUUID("shaders/" + webPaths["vertex"].get<std::string>());
                    SPDLOG_DEBUG("Web Vertex path: {}", vertexPath);
                }
                if (webPaths.contains("fragment") && webPaths["fragment"].is_string())
                {
                    fragmentPath = util::getRawAssetPathNoUUID("shaders/" + webPaths["fragment"].get<std::string>());
                    SPDLOG_DEBUG("Web Fragment path: {}", fragmentPath);
                }
            }
#endif

            // Fallback to default paths if web-specific paths are not present
            if (vertexPath.empty() && shaderPathsJSON.contains("vertex") && shaderPathsJSON["vertex"].is_string())
            {
                vertexPath = util::getRawAssetPathNoUUID("shaders/" + shaderPathsJSON["vertex"].get<std::string>());
                SPDLOG_DEBUG("Default Vertex path: {}", vertexPath);
            }
            if (fragmentPath.empty() && shaderPathsJSON.contains("fragment") && shaderPathsJSON["fragment"].is_string())
            {
                fragmentPath = util::getRawAssetPathNoUUID("shaders/" + shaderPathsJSON["fragment"].get<std::string>());
                SPDLOG_DEBUG("Default Fragment path: {}", fragmentPath);
            }

            Shader shader;
            if (!vertexPath.empty() && !fragmentPath.empty())
            {
                shader = LoadShader(vertexPath.c_str(), fragmentPath.c_str());
                shaderPaths[shaderName] = {vertexPath, fragmentPath};
            }
            else if (!vertexPath.empty())
            {
                shader = LoadShader(vertexPath.c_str(), nullptr);
                shaderPaths[shaderName] = {vertexPath, ""};
            }
            else if (!fragmentPath.empty())
            {
                shader = LoadShader(nullptr, fragmentPath.c_str());
                shaderPaths[shaderName] = {"", fragmentPath};
            }
            else
            {
                SPDLOG_WARN("Shader {} has no valid paths. Skipping.", shaderName);
                continue;
            }

            loadedShaders[shaderName] = shader;

            // After you assign loadedShaders[shaderName] = shader;
            std::error_code ec;

            // only query times if the paths aren’t empty AND actually exist
            auto getTime = [&](const std::string &p){
                if (p.empty() || !std::filesystem::exists(p, ec)) {
                    SPDLOG_WARN("Shader file not found (or empty path): {}", p);
                    return uint64_t{0};
                }
                auto ft = std::filesystem::last_write_time(p, ec);
                if (ec) {
                    SPDLOG_WARN("Could not get write time for {}: {}", p, ec.message());
                    return uint64_t{0};
                }
                return uint64_t{(uint64_t) ft.time_since_epoch().count()};
            };

            shaderFileModificationTimes[shaderName] = {
                getTime(vertexPath),
                getTime(fragmentPath)
            };

            SPDLOG_INFO("Loaded shader: {}", shaderName);
        }
    }

    auto hotReloadShaders() -> void
    {
        ZONE_SCOPED("HotReloadShaders"); // custom label
        for (auto &[shaderName, shader] : loadedShaders)
        {
            // Retrieve shader paths from the map
            if (shaderPaths.find(shaderName) == shaderPaths.end())
            {
                SPDLOG_WARN("Paths for shader {} not found. Skipping hot reload.", shaderName);
                continue;
            }

            const auto &[vertexPath, fragmentPath] = shaderPaths[shaderName];

            // Check if paths are valid
            if (vertexPath.empty() && fragmentPath.empty())
            {
                SPDLOG_WARN("Shader {} has no valid paths. Skipping hot reload.", shaderName);
                continue;
            }

            // Get the last modified times
            long newVertexModTime = vertexPath.empty() ? 0 : std::filesystem::last_write_time(vertexPath).time_since_epoch().count();
            long newFragmentModTime = fragmentPath.empty() ? 0 : std::filesystem::last_write_time(fragmentPath).time_since_epoch().count();

            // Get the stored modification times
            auto &[vertexModTime, fragmentModTime] = shaderFileModificationTimes[shaderName];

            // Check if the files have been modified
            if (newVertexModTime != vertexModTime || newFragmentModTime != fragmentModTime)
            {
                SPDLOG_INFO("Shader {} modified. Reloading...", shaderName);

                // Reload the shader
                Shader updatedShader = LoadShader(
                    vertexPath.empty() ? nullptr : vertexPath.c_str(),
                    fragmentPath.empty() ? nullptr : fragmentPath.c_str());

                if (updatedShader.id != rlGetShaderIdDefault())
                {
                    UnloadShader(shader);
                    shader = updatedShader;

                    // Update modification times
                    shaderFileModificationTimes[shaderName] = {newVertexModTime, newFragmentModTime};

                    SPDLOG_INFO("Shader {} reloaded successfully.", shaderName);
                }
                else
                {
                    SPDLOG_WARN("Failed to reload shader: {}", shaderName);
                }
            }
        }
    }

    // Set shader mode
    auto setShaderMode(std::string shaderName) -> void
    {
        if (shaderEnabledOverride)
        {
            return;
        }

        if (loadedShaders.find(shaderName) == loadedShaders.end())
        {
            // SPDLOG_WARN("Shader {} not found.", shaderName);
            return;
        }

        BeginShaderMode(loadedShaders[shaderName]);
    }

    // Unset shader mode
    auto unsetShaderMode() -> void
    {
        if (shaderEnabledOverride)
        {
            return;
        }
        EndShaderMode();
    }

    auto getShader(std::string shaderName) -> Shader
    {
        if (loadedShaders.find(shaderName) == loadedShaders.end())
        {
            // SPDLOG_WARN("Shader {} not found.", shaderName);
            return {0};
        }
        return loadedShaders[shaderName];
    }

    // Register a lambda for uniform updates
    auto registerUniformUpdate(std::string shaderName, std::function<void(Shader &)> updateLambda) -> void
    {
        if (loadedShaders.find(shaderName) == loadedShaders.end())
        {
            // SPDLOG_WARN("Shader {} not found. Cannot register uniform update.", shaderName);
            return;
        }
        uniformUpdateCallbacks[shaderName] = updateLambda;
        SPDLOG_INFO("Registered uniform update for shader: {}", shaderName);
    }

    // Update all shader uniforms
    auto updateAllShaderUniforms() -> void
    {
        ZONE_SCOPED("UpdateAllShaderUniforms"); // custom label
        for (const auto &[shaderName, updateLambda] : uniformUpdateCallbacks)
        {
            if (loadedShaders.find(shaderName) != loadedShaders.end())
            {
                Shader &shader = loadedShaders[shaderName];
                updateLambda(shader);
                // SPDLOG_INFO("Updated uniforms for shader: {}", shaderName);
            }
            else
            {
                // SPDLOG_WARN("Shader {} not found during uniform update.", shaderName);
            }
        }
    }

    // Called every frame to update shader system
    auto update(float dt) -> void
    {
        ZONE_SCOPED("Shaders update");

        updateAllShaderUniforms();
        // FIXME: perforamnce intensive on windows, commenting out for now
    #ifndef __EMSCRIPTEN__
         hotReloadShaders(); // Check for shader file modifications
    #endif
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
    auto unloadShaders() -> void
    {
        for (auto &[name, shader] : loadedShaders)
        {
            UnloadShader(shader);
            SPDLOG_INFO("Unloaded shader: {}", name);
        }
        loadedShaders.clear();
        shaderFileModificationTimes.clear();
    }

    void ShowShaderEditorUI(ShaderUniformComponent &component)
    {
        if (!ImGui::Begin("Shader Editor"))
            return;

        if (ImGui::BeginTabBar("Shaders"))
        {
            for (auto &[shaderName, uniformSet] : component.shaderUniforms)
            {
                if (ImGui::BeginTabItem(shaderName.c_str()))
                {
                    // "Log Uniforms" button
                    if (ImGui::Button("Log Uniforms"))
                    {
                        SPDLOG_INFO("Uniforms for shader '{}':", shaderName);
                        for (const auto &[uniformName, uniformValue] : uniformSet.uniforms)
                        {
                            std::visit([&](const auto &value)
                                       {
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
                                } }, uniformValue);
                        }
                    }

                    ImGui::Separator();

                    // Live-edit uniforms
                    for (auto &[uniformName, uniformValue] : uniformSet.uniforms)
                    {
                        ImGui::PushID(uniformName.c_str());

                        std::visit([&](auto &value)
                                   {
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
                            else if constexpr (std::is_same_v<T, int>) {
                                ImGui::DragInt(uniformName.c_str(), &value, 1);
                            }
                            else if constexpr (std::is_same_v<T, Texture2D>) {
                                ImGui::Text("%s: Texture2D (id: %d, size: %dx%d)", uniformName.c_str(), value.id, value.width, value.height);
                                // Optional preview
                                // ImGui::Image((ImTextureID)(intptr_t)value.id, ImVec2(64, 64));
                            } else {
                                static_assert(always_false<T>::value, "Unsupported uniform type");
                            } }, uniformValue);

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
