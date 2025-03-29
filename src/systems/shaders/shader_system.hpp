#pragma once

#include <string>
#include "raylib.h"
#include <functional>
#include <variant>
#include <unordered_map>

#include "systems/layer/layer.hpp"

#include "third_party/rlImGui/rlImGui.h"
#include "third_party/rlImGui/imgui.h"

using ShaderUniformValue = std::variant<
        float,
        Vector2,
        Vector3,
        Vector4,
        Texture2D
    >;
// #include "third_party/rlImGui/imgui.h"
// #include "third_party/rlImGui/imgui_internal.h"



namespace shaders {

    template<typename T>
    struct always_false : std::false_type {};

    /**
     * @struct ShaderUniformSet
     * @brief Represents a collection of shader uniform values, allowing for setting and retrieving them by name.
     * 
     * This structure is used to manage a set of shader uniform values, which are stored in an unordered map
     * with their names as keys. It provides methods to set a uniform value and retrieve a uniform value by name.
     */    
    struct ShaderUniformSet {
        std::unordered_map<std::string, ShaderUniformValue> uniforms;
        /**
         * @brief Sets a shader uniform value in the collection.
         * 
         * If a uniform with the specified name already exists, its value is updated. Otherwise, a new uniform
         * is added to the collection.
         * 
         * @param name The name of the uniform to set.
         * @param value The value of the uniform to set.
         */
        void set(const std::string& name, ShaderUniformValue value) {
            uniforms[name] = std::move(value);
            // SPDLOG_DEBUG("Set uniform {}", name);
        }
        /**
         * @brief Retrieves a shader uniform value by name.
         * 
         * Searches for a uniform with the specified name in the collection. If found, a pointer to the value
         * is returned. If not found, a `nullptr` is returned.
         * 
         * @param name The name of the uniform to retrieve.
         * @return A pointer to the ShaderUniformValue if found, or `nullptr` if not found.
         */    
        const ShaderUniformValue* get(const std::string& name) const {
            auto it = uniforms.find(name);
            // SPDLOG_DEBUG("Get uniform {}", name);
            return it != uniforms.end() ? &it->second : nullptr;
        }
    };

    // attach this to a sprite entity, for example
    /**
     * @struct ShaderUniformComponent
     * @brief Manages a collection of shader uniform sets, allowing for setting and retrieving uniform values for specific shaders.
     * 
     * This structure provides functionality to store and manage uniform values for multiple shaders. Each shader is identified
     * by its name, and its associated uniform values are stored in a `ShaderUniformSet`.
     * 
     * @var shaderUniforms
     * A map that associates shader names (as strings) with their corresponding `ShaderUniformSet` objects.
     * 
     * @fn void set(const std::string& shaderName, const std::string& uniformName, ShaderUniformValue value)
     * @brief Sets a uniform value for a specific shader.
     * 
     * @param shaderName The name of the shader for which the uniform value is being set.
     * @param uniformName The name of the uniform variable to set.
     * @param value The value to assign to the uniform variable.
     * 
     * This function ensures that the specified uniform value is stored in the appropriate `ShaderUniformSet` for the given shader.
     * If the shader does not already exist in the map, it will be created.
     * 
     * @fn const ShaderUniformSet* getSet(const std::string& shaderName) const
     * @brief Retrieves the `ShaderUniformSet` associated with a specific shader.
     * 
     * @param shaderName The name of the shader whose uniform set is being retrieved.
     * @return A pointer to the `ShaderUniformSet` associated with the shader, or `nullptr` if the shader does not exist in the map.
     * 
     * This function allows for read-only access to the uniform set of a specific shader.
     */
    struct ShaderUniformComponent {
        std::unordered_map<std::string, ShaderUniformSet> shaderUniforms;
        
        void set(const std::string& shaderName, const std::string& uniformName, ShaderUniformValue value) {
            shaderUniforms[shaderName].set(uniformName, std::move(value));
            // SPDLOG_DEBUG("Set uniform {} for shader {}", uniformName, shaderName);
        }
    
        const ShaderUniformSet* getSet(const std::string& shaderName) const {
            auto it = shaderUniforms.find(shaderName);
            // SPDLOG_DEBUG("Get uniform set for shader {}", shaderName);
            return it != shaderUniforms.end() ? &it->second : nullptr;
        }
    };

    extern auto ApplyUniformsToShader(Shader shader, const ShaderUniformSet& set) -> void;

    inline void TryApplyUniforms(Shader shader, const ShaderUniformComponent& component, const std::string& shaderName) {
        if (const auto* uniformSet = component.getSet(shaderName)) {
            ApplyUniformsToShader(shader, *uniformSet);
        }
    }
    
    extern auto loadShadersFromJSON(std::string jsonPath) -> void;
    extern auto unloadShaders() -> void;
    
    extern auto disableAllShadersViaOverride(bool enabled) -> void;
    extern auto hotReloadShaders() -> void;
    
    extern auto setShaderMode(std::string shaderName) -> void;
    extern auto unsetShaderMode() -> void;
    
    extern auto getShader(std::string shaderName) -> Shader;
    
    
    extern auto registerUniformUpdate(std::string shaderName, std::function<void(Shader&)> updateLambda) -> void;
    extern auto updateAllShaderUniforms() -> void; 

    // auto checkImGUIWindowExists(std::string windowName) -> void;
    // auto beginImGUIWindowWithCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) -> void;
    // auto endImGUIShaderCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) ->void;
    
    
    extern auto update(float dt) -> void;

    extern void ShowShaderEditorUI(ShaderUniformComponent& component);
}